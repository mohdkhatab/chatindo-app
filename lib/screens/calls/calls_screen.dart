import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  late Future<List<ApiCall>> _future;

  ChatindoApi get api => context.read<ChatindoApi>();

  @override
  void initState() {
    super.initState();
    _future = api.callHistory();
  }

  void _reload() {
    setState(() => _future = api.callHistory());
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 18, 24, 6),
              child: Text('Calls', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ),
            Expanded(
              child: FutureBuilder<List<ApiCall>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Could not load calls', style: TextStyle(color: AppColors.textMuted)),
                          const SizedBox(height: 12),
                          GlassButton(label: 'Retry', onPressed: _reload),
                        ],
                      ),
                    );
                  }
                  final calls = snap.data ?? [];
                  if (calls.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.call_outlined, color: AppColors.textMuted, size: 40),
                          SizedBox(height: 12),
                          Text('No calls yet', style: TextStyle(color: AppColors.textMuted)),
                          Text('Start one from inside any chat', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
                    itemCount: calls.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _CallTile(call: calls[i]),
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

class _CallTile extends StatelessWidget {
  const _CallTile({required this.call});
  final ApiCall call;

  @override
  Widget build(BuildContext context) {
    final icon = call.callType == 'video' ? Icons.videocam_rounded : Icons.call_rounded;
    final color = switch (call.status) {
      'completed' => AppColors.cyan,
      'missed' => AppColors.danger,
      'rejected' => AppColors.amber,
      _ => AppColors.mint,
    };
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 20,
      child: Row(
        children: [
          GlassAvatar(name: call.chatId ?? '?', radius: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(call.callType == 'video' ? 'Video call' : 'Voice call', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 6),
                    Text(_status(call.status), style: TextStyle(color: color, fontSize: 12.5)),
                    const SizedBox(width: 10),
                    Text(_time(call.createdAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }

  String _status(String? s) {
    switch (s) {
      case 'ringing':
        return 'Incoming…';
      case 'ongoing':
        return 'Ongoing';
      case 'completed':
        return 'Completed';
      case 'missed':
        return 'Missed';
      case 'rejected':
        return 'Rejected';
      default:
        return s ?? 'Unknown';
    }
  }

  String _time(String? iso) {
    final t = DateTime.tryParse(iso ?? '')?.toLocal();
    if (t == null) return '';
    return '${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}