import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  static const route = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = context.read<SessionController>();
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      _toast('Enter email and password');
      return;
    }
    setState(() => _loading = true);
    try {
      await session.login(_email.text.trim(), _password.text);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Network error — check your connection');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 46),
                const Text('Welcome\nback.', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, height: 1.05, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                const Text('Your private conversations, encrypted end to end.', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                const SizedBox(height: 36),
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GlassTextField(
                        controller: _email,
                        hint: 'you@example.com',
                        prefixIcon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      GlassTextField(
                        controller: _password,
                        hint: 'Password',
                        obscure: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 22),
                      GlassButton(label: 'Sign in', loading: _loading, onPressed: _submit),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('New to Chatindo?', style: TextStyle(color: AppColors.textMuted)),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushNamed(SignupScreen.route),
                      child: const Text('Create account', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Center(
                  child: GestureDetector(
                    onTap: () => _toast('Google sign-in is configured through the deployed /auth-google edge function.'),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      radius: 18,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.g_mobiledata_rounded, color: AppColors.amber, size: 26),
                          SizedBox(width: 10),
                          Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}