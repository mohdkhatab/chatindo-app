import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'auth/login_screen.dart';
import 'home/home_shell.dart';

class SplashScreen extends StatelessWidget {
  static const route = '/';

  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.ready) {
      Future.microtask(() {
        Navigator.of(context).pushReplacementNamed(session.loggedIn ? HomeShell.route : LoginScreen.route);
      });
    }
    return const Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          GlassBackground(child: SizedBox.shrink()),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Orb(),
              SizedBox(height: 28),
              Text('CHATINDO', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 6, color: AppColors.textPrimary)),
              SizedBox(height: 8),
              Text('liquid mathematics of conversation', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              SizedBox(height: 40),
              SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.2)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatefulWidget {
  const _Orb();

  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000), lowerBound: 0, upperBound: 2 * 3.14159)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final scale = 0.92 + 0.08 * (0.5 + 0.5 * _c.value / 3.14159);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: AppColors.gradientPrimary, begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(color: AppColors.violet.withOpacity(0.6), blurRadius: 40, spreadRadius: 8),
                BoxShadow(color: AppColors.cyan.withOpacity(0.35), blurRadius: 90),
              ],
            ),
            child: const Center(
              child: Text('C', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
        );
      },
    );
  }
}