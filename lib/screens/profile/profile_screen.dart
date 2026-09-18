import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/api_client.dart';
import '../../core/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../legal/legal_screen.dart';
import '../premium/premium_screen.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<ApiUser> _me;
  late Future<Map<String, dynamic>> _premium;

  @override
  void initState() {
    super.initState();
    _me = context.read<ChatindoApi>().me();
    _premium = context.read<ChatindoApi>().premiumStatus();
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: SafeArea(
        child: FutureBuilder<ApiUser>(
          future: _me,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final u = snap.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
              children: [
                const Text('Profile', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 22),
                Center(
                  child: GlassAvatar(name: u?.name ?? '?', url: u?.avatarUrl, radius: 42, online: u?.isOnline),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(u?.name ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ),
                if (u?.username != null)
                  Center(child: Text('@${u!.username}', style: const TextStyle(color: AppColors.textMuted))),
                if (u?.statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: GlassChip(label: u!.statusMessage!),
                    ),
                  ),
                const SizedBox(height: 26),
                _PremiumCard(statusFuture: _premium),
                const SizedBox(height: 14),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _Row(icon: Icons.notifications_none_rounded, label: 'Notifications', onTap: () => Navigator.of(context).pushNamed(SettingsScreen.route)),
                      const Divider(indent: 52),
                      _Row(icon: Icons.workspace_premium_outlined, label: 'Chatindo Pro', onTap: () => Navigator.of(context).pushNamed(PremiumScreen.route)),
                      const Divider(indent: 52),
                      _Row(icon: Icons.description_outlined, label: 'Terms & Privacy', onTap: () => Navigator.of(context).pushNamed(LegalScreen.route)),
                      const Divider(indent: 52),
                      _Row(icon: Icons.logout_rounded, label: 'Sign out', destructive: true, onTap: () => _logout(context)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<SessionController>().logout();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    }
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({this.statusFuture});
  final Future<Map<String, dynamic>>? statusFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: statusFuture ?? context.read<ChatindoApi>().premiumStatus(),
      builder: (context, snap) {
        final active = snap.data?['status'] == 'active';
        return GlassCard(
          padding: const EdgeInsets.all(18),
          radius: 22,
          fill: 0.1,
          onTap: () => Navigator.of(context).pushNamed(PremiumScreen.route),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: active ? const LinearGradient(colors: [AppColors.amber, AppColors.pink]) : const LinearGradient(colors: [Colors.white24, Colors.white12]),
                ),
                child: Icon(active ? Icons.workspace_premium_rounded : Icons.workspace_premium_outlined, color: active ? Colors.white : AppColors.textMuted),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(active ? 'Chatindo Pro' : 'Upgrade to Pro', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(
                      active ? 'Your subscription is active' : 'Unlimited messages, media & priority support',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.onTap, this.destructive = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: destructive ? AppColors.danger : AppColors.cyan),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: destructive ? AppColors.danger : AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}