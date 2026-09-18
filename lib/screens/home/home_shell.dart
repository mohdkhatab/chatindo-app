import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/realtime_service.dart';
import '../../theme/app_theme.dart';
import '../calls/calls_screen.dart';
import '../chats/chats_screen.dart';
import '../profile/profile_screen.dart';

class HomeShell extends StatefulWidget {
  static const route = '/home';

  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _titles = ['Chats', 'Calls', 'Profile'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final api = context.read<ChatindoApi>();
      try {
        final token = api.session.session?.accessToken;
        if (token != null) context.read<RealtimeService>().wire(token);
        await api.ping(online: true);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [
      ChatsScreen(),
      CallsScreen(),
      ProfileScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _GlassNavBar(
        index: _index,
        onTap: (i) => setState(() => _index = i),
        titles: _titles,
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.index, required this.onTap, required this.titles});

  final int index;
  final ValueChanged<int> onTap;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    final icons = const [Icons.chat_bubble_rounded, Icons.call_rounded, Icons.person_rounded];
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: const Color(0xCC0B0F22),
            child: SafeArea(
              top: false,
              child: Row(
                children: List.generate(icons.length, (i) {
                  final selected = i == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: selected
                                    ? const LinearGradient(colors: AppColors.gradientPrimary)
                                    : null,
                                boxShadow: selected
                                    ? [BoxShadow(color: AppColors.violet.withOpacity(0.45), blurRadius: 14)]
                                    : null,
                              ),
                              child: Icon(
                                icons[i],
                                color: selected ? Colors.white : AppColors.textMuted,
                                size: 21,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              titles[i],
                              style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? Colors.white : AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}