import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/api_client.dart';
import '../../core/crypto_service.dart';
import '../../core/realtime_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId, required this.title, this.chatType});

  final String chatId;
  final String title;
  final String? chatType;

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final List<ApiMessage> _messages = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _crypto = CryptoService.instance;

  late final ChatindoApi _api;
  late final String _meId;

  StreamSubscription<Map<String, dynamic>>? _msgSub;
  StreamSubscription<RealtimeTyping>? _typingSub;
  ApiMessage? _replyingTo;
  Timer? _typingDebounce;
  bool _othersTyping = false;
  bool _loading = true;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ChatindoApi>();
    _meId = _api.session.currentUserId ?? '';
    _load();
    _subscribe();
    _api.ping(online: true);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _typingSub?.cancel();
    _typingDebounce?.cancel();
    _input.dispose();
    _scroll.dispose();
    _api.ping(online: false);
    super.dispose();
  }

  Future<void> _load({bool older = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final wasAtTop = older && _messages.isNotEmpty;
      final before = older && _messages.isNotEmpty ? _messages.first.createdAt : null;
      final res = await _api.messageHistory(widget.chatId, before: before, limit: 50);
      if (!mounted) return;
      setState(() {
        if (older) {
          _messages.insertAll(0, res);
        } else {
          _messages
            ..clear()
            ..addAll(res);
        }
        _hasMore = res.length >= 50;
        _error = null;
      });
      if (!older || wasAtTop) _scrollToBottom(instant: true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load messages');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribe() {
    final rt = context.read<RealtimeService>();
    _msgSub = rt.onMessages(widget.chatId).listen((row) {
      final msg = ApiMessage.fromJson(row);
      if (msg.id.isEmpty) return;
      if (_messages.any((m) => m.id == msg.id)) return;
      setState(() {
        _messages.add(msg);
        if (msg.isDeleted != true && msg.senderId != _meId) _api.setStatus(msg.id, 'read');
      });
      _scrollToBottom(instant: false);
    });
    _typingSub = rt.onTyping(widget.chatId).listen((t) {
      if (t.userId == _meId) return;
      setState(() => _othersTyping = t.isTyping);
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels <= 40 && _hasMore && !_loading) {
      _load(older: true);
    }
  }

  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      _scroll.animateTo(target, duration: instant ? Duration.zero : const Duration(milliseconds: 260), curve: Curves.easeOut);
    });
  }

  Future<String> _encrypt(String text) => _crypto.encrypt(widget.chatId, text);

  Future<String?> _decrypt(ApiMessage m) async {
    if (m.ciphertext == null) return null;
    return _crypto.decrypt(widget.chatId, m.ciphertext!);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _sendTyping(false);
    try {
      final cipher = await _encrypt(text);
      final msg = await _api.sendMessage(widget.chatId, cipher, messageType: 'text', replyToId: _replyingTo?.id);
      setState(() => _replyingTo = null);
      if (!_messages.any((m) => m.id == msg.id)) {
        setState(() => _messages.add(msg));
      }
      _scrollToBottom();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _attach() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final url = await _api.uploadMedia(bytes, name: file.name);
      final cipher = await _encrypt('📎 $url');
      final msg = await _api.sendMessage(widget.chatId, cipher, messageType: 'media', replyToId: _replyingTo?.id);
      setState(() => _replyingTo = null);
      if (!_messages.any((m) => m.id == msg.id)) setState(() => _messages.add(msg));
      _scrollToBottom();
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not attach that image');
    }
  }

  void _sendTyping(bool on) {
    _typingDebounce?.cancel();
    _api.typing(widget.chatId, on: on);
    if (on) {
      _typingDebounce = Timer(const Duration(milliseconds: 1600), () {
        _api.typing(widget.chatId, on: false);
      });
    }
  }

  Future<void> _edit(ApiMessage m) async {
    final current = await _decrypt(m) ?? '';
    final controller = TextEditingController(text: current);
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.inkAlt,
        title: const Text('Edit message'),
        content: GlassTextField(controller: controller, hint: 'Message', onSubmitted: (v) => Navigator.of(context).pop(v)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      final cipher = await _encrypt(text.trim());
      await _api.editMessage(m.id, cipher);
      final idx = _messages.indexWhere((x) => x.id == m.id);
      if (idx >= 0) {
        setState(() {
          _messages[idx] = ApiMessage.fromJson({..._rowOf(m), 'ciphertext': cipher, 'edited_at': DateTime.now().toUtc().toIso8601String()});
        });
      }
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _delete(ApiMessage m) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: GlassCard(
          padding: EdgeInsets.zero,
          radius: 26,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.delete_outline_rounded), title: const Text('Delete for me'), onTap: () => Navigator.of(context).pop('me')),
              ListTile(leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger), title: const Text('Delete for everyone'), onTap: () => Navigator.of(context).pop('everyone')),
            ],
          ),
        ),
      ),
    );
    if (mode == null) return;
    try {
      await _api.deleteMessage(m.id, everyone: mode == 'everyone');
      setState(() => _messages.removeWhere((x) => x.id == m.id));
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _react(ApiMessage m) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          radius: 26,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['❤️', '😂', '🔥', '👍', '😮']
                .map((e) => GestureDetector(
                      onTap: () => Navigator.of(context).pop(e),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle),
                        child: Text(e, style: const TextStyle(fontSize: 26)),
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
    if (emoji == null) return;
    try {
      await _api.toggleReaction(m.id, emoji);
      _toast('Reaction updated');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _onInput(String _) => _sendTyping(true);

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, dynamic> _rowOf(ApiMessage m) => {
        'id': m.id,
        'chat_id': m.chatId,
        'sender_id': m.senderId,
        'message_type': m.messageType,
        'ciphertext': m.ciphertext,
        'media_url': m.mediaUrl,
        'reply_to_id': m.replyToId,
        'created_at': m.createdAt,
        'edited_at': m.editedAt,
        'is_deleted': m.isDeleted,
        'enc_metadata': m.encMetadata,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GlassAvatar(name: widget.title, radius: 17),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(
                  _othersTyping ? 'typing…' : 'end-to-end encrypted',
                  style: TextStyle(fontSize: 11.5, color: _othersTyping ? AppColors.cyan : AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: _openSearch),
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () => _startCall('audio')),
          const SizedBox(width: 6),
        ],
      ),
      body: GlassBackground(
        child: Column(
          children: [
            Expanded(child: _buildList()),
            _replyBar(),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _messages.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 14),
            GlassButton(label: 'Retry', onPressed: () => _load()),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text('Say hello — everything is encrypted.', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        final mine = m.senderId == _meId;
        return _MessageBubble(
          message: m,
          mine: mine,
          decrypt: () => _decrypt(m),
          onLongPress: () => _actions(m, mine),
        );
      },
    );
  }

  Future<void> _actions(ApiMessage m, bool mine) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: GlassCard(
          padding: EdgeInsets.zero,
          radius: 26,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mine)
                ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Edit'), onTap: () => Navigator.of(context).pop('edit')),
              ListTile(leading: const Icon(Icons.mood_outlined), title: const Text('React'), onTap: () => Navigator.of(context).pop('react')),
              ListTile(leading: const Icon(Icons.reply_outlined), title: const Text('Reply'), onTap: () => Navigator.of(context).pop('reply')),
              ListTile(leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), title: const Text('Delete'), onTap: () => Navigator.of(context).pop('delete')),
            ],
          ),
        ),
      ),
    );
    switch (action) {
      case 'edit':
        await _edit(m);
      case 'react':
        await _react(m);
      case 'reply':
        setState(() => _replyingTo = m);
      case 'delete':
        await _delete(m);
    }
  }

  void _startCall(String type) async {
    try {
      final call = await _api.initiateCall(widget.chatId, type);
      _toast('Call started (${call.status})');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _openSearch() async {
    final q = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.inkAlt,
        title: const Text('Search messages'),
        content: GlassTextField(controller: TextEditingController(), hint: 'Search words…', onSubmitted: (v) => Navigator.of(context).pop(v)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ],
      ),
    );
    if (q == null || q.trim().isEmpty) return;
    try {
      final results = await _api.searchMessages(widget.chatId, q: q.trim());
      if (!mounted) return;
      if (results.isEmpty) {
        _toast('No matches');
        return;
      }
      final target = results.firstWhere((m) => _messages.any((x) => x.id == m.id), orElse: () => results.first);
      if (_messages.any((x) => x.id == target.id)) {
        final idx = _messages.indexWhere((x) => x.id == target.id);
        _scroll.animateTo(idx * 120.0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      } else {
        _toast('${results.length} match(es) — messages search only surfaces what you can decrypt.');
      }
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Widget _replyBar() {
    if (_replyingTo == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(color: AppColors.violet.withOpacity(0.14)),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            const Icon(Icons.reply_rounded, color: AppColors.cyan, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Replying to a message…', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ),
            GestureDetector(onTap: () => setState(() => _replyingTo = null), child: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18)),
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.cyan), onPressed: _attach),
                Expanded(
                  child: GlassTextField(
                    controller: _input,
                    hint: 'Message…',
                    enabled: true,
                    onSubmitted: (_) => _send(),
                    onChanged: _onInput,
                  ),
                ),
                const SizedBox(width: 6),
                _SendButton(onTap: _send),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: AppColors.gradientPrimary),
        ),
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine, required this.decrypt, required this.onLongPress});

  final ApiMessage message;
  final bool mine;
  final Future<String?> Function() decrypt;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GlassAvatar(name: message.sender?.name ?? '?', radius: 14),
              ),
            Flexible(
              child: GestureDetector(
                onLongPress: onLongPress,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 270),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(mine ? 22 : 6),
                      bottomRight: Radius.circular(mine ? 6 : 22),
                    ),
                    gradient: mine
                        ? const LinearGradient(colors: AppColors.gradientPrimary)
                        : LinearGradient(colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)]),
                    boxShadow: [
                      if (mine) BoxShadow(color: AppColors.violet.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: _BubbleContent(message: message, mine: mine, decrypt: decrypt),
                ),
              ),
            ),
            if (mine) const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _BubbleContent extends StatefulWidget {
  const _BubbleContent({required this.message, required this.mine, required this.decrypt});
  final ApiMessage message;
  final bool mine;
  final Future<String?> Function() decrypt;

  @override
  State<_BubbleContent> createState() => _BubbleContentState();
}

class _BubbleContentState extends State<_BubbleContent> {
  String? _text;
  String? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  void _resolve() {
    widget.decrypt().then((t) {
      if (!mounted) return;
      setState(() {
        _text = t;
        _url = _extractUrl(t);
      });
    });
  }

  String? _extractUrl(String? text) {
    if (widget.message.mediaUrl != null && widget.message.mediaUrl!.isNotEmpty) return widget.message.mediaUrl;
    if (text == null) return null;
    final url = RegExp(r'https?://[^\s]+').firstMatch(text);
    return url?.group(0);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.mine ? Colors.white : AppColors.textPrimary;
    if (widget.message.messageType == 'media') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_url != null)
            _mediaThumb(_url!)
          else if (_text != null)
            Text('image: ${_text!.replaceAll('📎 ', '')}', style: TextStyle(color: color, fontSize: 13)),
          const SizedBox(height: 6),
          _timeRow(color),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_text == null)
          const Text('🔒', style: TextStyle(color: Colors.white))
        else
          Text(_text!, style: TextStyle(color: color, fontSize: 15, height: 1.35)),
        if (widget.message.editedAt != null) Text('edited', style: TextStyle(color: color.withOpacity(0.6), fontSize: 10.5)),
        SizedBox(height: 4),
        _timeRow(color),
      ],
    );
  }

  Widget _timeRow(Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_time(widget.message.createdAt), style: TextStyle(color: color.withOpacity(0.65), fontSize: 10.5)),
        const SizedBox(width: 4),
        if (widget.mine) const Icon(Icons.done_all_rounded, size: 12, color: Colors.white70),
      ],
    );
  }

  Widget _mediaThumb(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: 200,
        height: 150,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 200,
          height: 150,
          color: Colors.white.withOpacity(0.08),
          child: const Icon(Icons.broken_image_outlined, color: Colors.white54),
        ),
      ),
    );
  }

  String _time(String? iso) {
    if (iso == null) return '';
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}