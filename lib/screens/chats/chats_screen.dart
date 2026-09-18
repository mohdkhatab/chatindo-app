import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../models/app_chat_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../chat/chat_screen.dart';
import 'create_group_screen.dart';
import 'new_chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late Future<List<ChatItem>> _future;

  ChatindoApi get api => context.read<ChatindoApi>();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ChatItem>> _load() async {
    final chats = await api.chatsList();
    final items = <ChatItem>[];
    for (final c in chats) {
      final ct = (c.customData?['last_message_ciphertext'] as String?) ?? (c.customData?['last_ciphertext'] as String?);
      items.add(ChatItem(chat: c, lastMessage: ct));
    }
    return items;
  }

  void _reload() {
    setState(() => _future = _load());
  }

  void _openCompose() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposeSheet(
        onDirect: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(NewChatScreen.route).then((_) => _reload());
        },
        onGroup: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(CreateGroupScreen.route).then((_) => _reload());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
                  child: Row(
                    children: [
                      const Text('Chats', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const Spacer(),
                      FutureBuilder<Map<String, dynamic>>(
                        future: context.read<ChatindoApi>().premiumStatus(),
                        builder: (_, snap) {
                          final active = snap.data?['status'] == 'active';
                          return GlassChip(
                            label: active ? 'PRO' : 'FREE',
                            color: active ? AppColors.amber : AppColors.textMuted,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<ChatItem>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return _ErrorView(message: '${snap.error}', onRetry: _reload);
                      }
                      final items = snap.data ?? [];
                      if (items.isEmpty) {
                        return _EmptyView(onStart: () => Navigator.of(context).pushNamed(NewChatScreen.route).then((_) => _reload()));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 130),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _ChatTile(item: items[i], onOpen: () {
                          Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: items[i].chat.id, title: items[i].chat.title)))
                              .then((_) => _reload());
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 20,
            bottom: 96,
            child: _ComposeFab(onTap: _openCompose),
          ),
        ],
      ),
    );
  }
}

class _ComposeFab extends StatelessWidget {
  const _ComposeFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: AppColors.gradientPrimary),
          boxShadow: [BoxShadow(color: AppColors.violet.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

class _ComposeSheet extends StatelessWidget {
  const _ComposeSheet({required this.onDirect, required this.onGroup});
  final VoidCallback onDirect;
  final VoidCallback onGroup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 8),
        radius: 26,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetTile(icon: Icons.person_add_alt_1_rounded, label: 'New direct chat', onTap: onDirect),
            _SheetTile(icon: Icons.groups_2_rounded, label: 'New group', onTap: onGroup),
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.cyan),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.item, required this.onOpen});

  final ChatItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final chat = item.chat;
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 20,
      onTap: onOpen,
      child: Row(
        children: [
          GlassAvatar(name: chat.title, url: chat.avatarUrl, radius: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(
                  item.lastMessage ?? 'Encrypted • Tap to open',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _timeLabel(chat.lastMessageAt),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }

  String _timeLabel(String? iso) {
    if (iso == null) return '';
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final local = t.toLocal();
    final now = DateTime.now();
    if (local.day == now.day && local.month == now.month) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${local.day}/${local.month}';
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassAvatar(name: '✉', radius: 34),
          const SizedBox(height: 18),
          const Text('No conversations yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Start an encrypted chat with a friend', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 22),
          GlassButton(label: 'Start chatting', onPressed: onStart),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 14),
          GlassButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}