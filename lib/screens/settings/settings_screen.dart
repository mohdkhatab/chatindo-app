import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';

class SettingsScreen extends StatefulWidget {
  static const route = '/settings';

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _saving = false;

  ChatindoApi get api => context.read<ChatindoApi>();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final body = await api.rawGet('notifications-settings-get');
    final settings = body['settings'];
    return settings is Map ? Map<String, dynamic>.from(settings as Map) : <String, dynamic>{};
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _saving = true);
    try {
      await api.setNotificationPrefs({key: value});
      setState(() => _future = _load());
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: GlassBackground(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final settings = snap.data ?? const {};
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _section('Push notifications', [
                  _toggleRow(settings, 'message_notifications', 'Messages', 'New DM or group message', (v) => _toggle('message_notifications', v)),
                  _toggleRow(settings, 'call_notifications', 'Calls', 'Incoming voice & video calls', (v) => _toggle('call_notifications', v)),
                  _toggleRow(settings, 'group_notifications', 'Groups', 'Activity in group chats', (v) => _toggle('group_notifications', v)),
                  _toggleRow(settings, 'sounds', 'Sounds', 'Alert tones and vibration', (v) => _toggle('sounds', v)),
                ]),
                const SizedBox(height: 14),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  radius: 20,
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: AppColors.mint),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Push token', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text('Register in notifications-register-token via APNs/FCM. This build simulates registration.', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      GlassButton(
                        label: 'Register',
                        gradient: const [AppColors.mint, AppColors.violet],
                        onPressed: _saving
                            ? null
                            : () async {
                                try {
                                  await api.registerPushToken('demo-${DateTime.now().millisecondsSinceEpoch}', platform: 'ios');
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device token registered')));
                                } on ApiException catch (e) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                                }
                              },
                      ),
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

  Widget _section(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 10),
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        ),
        GlassCard(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(children: rows)),
      ],
    );
  }

  Widget _toggleRow(Map<String, dynamic> settings, String key, String title, String subtitle, ValueChanged<bool> onChanged) {
    final value = settings[key] == true;
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      value: value,
      activeTrackColor: AppColors.violet.withOpacity(0.7),
      activeThumbColor: AppColors.cyan,
      onChanged: onChanged,
    );
  }
}