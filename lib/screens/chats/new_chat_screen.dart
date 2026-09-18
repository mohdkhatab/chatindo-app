import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../chat/chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  static const route = '/new-chat';

  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<ApiUser> _results = const [];
  bool _loading = false;
  String? _error;

  ChatindoApi get api => context.read<ChatindoApi>();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _run(q.trim()));
  }

  Future<void> _run(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await api.searchUsers(q);
      if (mounted) setState(() => _results = res);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Search failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openChat(ApiUser user) async {
    try {
      final chat = await api.directChat(user.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id, title: user.name)),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<ChatindoApi>().session.currentUserId;
    final others = _results.where((u) => u.id != me).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('New chat')),
      body: GlassBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: GlassTextField(
                controller: _search,
                hint: 'Search by username or display name…',
                prefixIcon: Icons.search_rounded,
                onChanged: _onChanged,
                suffix: _loading
                    ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : null,
              ),
            ),
            Expanded(
              child: others.isEmpty
                  ? Center(
                      child: Text(_error ?? 'No users found', style: const TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                      itemCount: others.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final u = others[i];
                        return GlassCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          radius: 20,
                          onTap: () => _openChat(u),
                          child: Row(
                            children: [
                              GlassAvatar(name: u.name, url: u.avatarUrl, radius: 22, online: u.isOnline),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                    if (u.username != null)
                                      Text('@${u.username}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.cyan, size: 20),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}