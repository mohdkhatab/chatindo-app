import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../chat/chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  static const route = '/create-group';

  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  Timer? _debounce;
  List<ApiUser> _results = const [];
  final Set<String> _selectedIds = {};
  final Map<String, ApiUser> _selected = {};
  bool _loading = false;
  bool _creating = false;

  ChatindoApi get api => context.read<ChatindoApi>();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _loading = true);
      try {
        final res = await api.searchUsers(q.trim());
        if (mounted) setState(() => _results = res);
      } catch (_) {
        if (mounted) setState(() => _results = const []);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  void _toggle(ApiUser u) {
    setState(() {
      if (!_selectedIds.add(u.id)) {
        _selectedIds.remove(u.id);
        _selected.remove(u.id);
      } else {
        _selected[u.id] = u;
      }
    });
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give the group a name')));
      return;
    }
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one member')));
      return;
    }
    setState(() => _creating = true);
    try {
      final chat = await api.groupChat(name, _selectedIds.toList());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id, title: chat.title)),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<ChatindoApi>().session.currentUserId;
    final others = _results.where((u) => u.id != me).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      body: GlassBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: GlassTextField(controller: _name, hint: 'Group name', prefixIcon: Icons.groups_2_rounded, onSubmitted: (_) => _create()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: GlassTextField(
                controller: _search,
                hint: 'Add members — search people…',
                prefixIcon: Icons.person_search_rounded,
                onChanged: _onChanged,
                suffix: _loading
                    ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : null,
              ),
            ),
            if (_selected.isNotEmpty)
              SizedBox(
                height: 68,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: _selected.values
                      .map((u) => Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Column(
                                  children: [
                                    GlassAvatar(name: u.name, url: u.avatarUrl, radius: 20),
                                    const SizedBox(height: 4),
                                    Text(u.name.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ),
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: GestureDetector(
                                    onTap: () => _toggle(u),
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(color: AppColors.violet, shape: BoxShape.circle),
                                      child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            Expanded(
              child: others.isEmpty
                  ? const Center(child: Text('Search for people to add', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      itemCount: others.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final u = others[i];
                        final selected = _selectedIds.contains(u.id);
                        return GlassCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          radius: 20,
                          onTap: () => _toggle(u),
                          child: Row(
                            children: [
                              GlassAvatar(name: u.name, url: u.avatarUrl, radius: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: selected ? const LinearGradient(colors: AppColors.gradientPrimary) : null,
                                  border: Border.all(color: selected ? Colors.transparent : Colors.white24, width: 2),
                                ),
                                child: selected ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: GlassButton(
                label: _selected.isEmpty ? 'Add members to create group' : 'Create group (${_selected.length})',
                loading: _creating,
                onPressed: _selected.isEmpty ? null : _create,
              ),
            ),
          ],
        ),
      ),
    );
  }
}