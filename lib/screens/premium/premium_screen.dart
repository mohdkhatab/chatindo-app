import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';

class PremiumScreen extends StatefulWidget {
  static const route = '/premium';

  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  late Future<(List<ApiPlan>, Map<String, dynamic>)> _future;

  ChatindoApi get api => context.read<ChatindoApi>();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<ApiPlan>, Map<String, dynamic>)> _load() async {
    final plans = await api.plans();
    final status = await api.premiumStatus();
    return (plans, status);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _subscribe(ApiPlan plan) async {
    try {
      await api.subscribe(plan.id);
      _toast('Subscription started for ${plan.name} — checkout webhook will activate it.');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.inkAlt,
        title: const Text('Cancel Pro?'),
        content: const Text('Your premium access ends at the billing period close.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cancel', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.cancelPremium();
      _toast('Premium cancelled');
      _reload();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chatindo Pro')),
      body: GlassBackground(
        child: FutureBuilder<(List<ApiPlan>, Map<String, dynamic>)>(
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
                    Text('${snap.error}', style: const TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 12),
                    GlassButton(label: 'Retry', onPressed: _reload),
                  ],
                ),
              );
            }
            final (plans, status) = snap.data!;
            final active = status['status'] == 'active';
            final expiresAt = status['expires_at'] as String?;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const _Hero(),
                const SizedBox(height: 24),
                if (active)
                  GlassCard(
                    fill: 0.1,
                    radius: 22,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: AppColors.amber, size: 20),
                            const SizedBox(width: 8),
                            const Text('Active', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            const Spacer(),
                            Text('until ${_shortDate(expiresAt)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        GlassButton(label: 'Cancel subscription', onPressed: _cancel, gradient: const [Colors.transparent, Colors.transparent]),
                      ],
                    ),
                  )
                else
                  for (final plan in plans) ...[
                    _PlanCard(plan: plan, onSubscribe: () => _subscribe(plan)),
                    const SizedBox(height: 14),
                  ],
                const SizedBox(height: 10),
                const Text('Payment is processed by Stripe. The premium-webhook edge function activates your plan instantly.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            );
          },
        ),
      ),
    );
  }

  String _shortDate(String? iso) {
    final t = DateTime.tryParse(iso ?? '')?.toLocal();
    if (t == null) return '—';
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [Color(0xFF3D2BFF), Color(0xFF8319E8)]),
        boxShadow: [BoxShadow(color: AppColors.violet.withOpacity(0.4), blurRadius: 34, offset: const Offset(0, 14))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Chatindo Pro', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
          SizedBox(height: 6),
          Text('Everything in Free, then some.', style: TextStyle(color: Colors.white70, fontSize: 14)),
          SizedBox(height: 18),
          _Benefit(icon: Icons.infinite_rounded, text: 'Unlimited messages & media'),
          _Benefit(icon: Icons.double_arrow_rounded, text: 'Priority delivery & support'),
          _Benefit(icon: Icons.star_outline_rounded, text: 'Exclusive liquid-glass themes'),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onSubscribe});
  final ApiPlan plan;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final price = plan.price;
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 26,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppColors.amber, AppColors.pink]),
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    '${plan.currency ?? '\$'}$price / ${plan.period ?? 'month'}',
                    style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: GlassButton(
                label: 'Subscribe',
                gradient: const [AppColors.pink, AppColors.violet],
                onPressed: onSubscribe,
              ),
            ),
          ],
        ),
      ),
    );
  }
}