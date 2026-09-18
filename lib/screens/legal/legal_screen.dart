import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';

class LegalScreen extends StatefulWidget {
  static const route = '/legal';

  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  String? _terms;
  String? _privacy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ChatindoApi>();
    try {
      final terms = await api.legalDoc('terms');
      final privacy = await api.legalDoc('privacy');
      if (mounted) setState(() {
        _terms = terms;
        _privacy = privacy;
      });
    } catch (_) {}
  }

  Future<void> _accept(String docId) async {
    try {
      await context.read<ChatindoApi>().acceptLegal(docId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Accepted $docId')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Privacy')),
      body: GlassBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _DocCard(id: 'terms', title: 'Terms of Service', body: _terms ?? 'Loading…', onAccept: () => _accept('terms')),
            const SizedBox(height: 16),
            _DocCard(id: 'privacy_policy', title: 'Privacy Policy', body: _privacy ?? 'Loading…', onAccept: () => _accept('privacy_policy')),
            const SizedBox(height: 28),
            const Text('Account creation records the legal-events you accepted for compliance. Revoking access is available by contacting support.', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.id, required this.title, required this.body, required this.onAccept});
  final String id;
  final String title;
  final String body;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
              GlassChip(label: id),
            ],
          ),
          const SizedBox(height: 12),
          Text(body.isEmpty ? 'No sections returned.' : body, style: const TextStyle(color: AppColors.textMuted, height: 1.5, fontSize: 13.5)),
          const SizedBox(height: 16),
          GlassButton(label: 'I accept', gradient: const [AppColors.violet, AppColors.cyan], onPressed: onAccept),
        ],
      ),
    );
  }
}