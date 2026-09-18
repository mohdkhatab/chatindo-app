import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';

class SignupScreen extends StatefulWidget {
  static const route = '/signup';

  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _display = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _display.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = context.read<SessionController>();
    if (_email.text.trim().isEmpty || _password.text.length < 8) {
      _toast('Email required and password must be 8+ characters');
      return;
    }
    setState(() => _loading = true);
    try {
      await session.signup(
        email: _email.text.trim(),
        password: _password.text,
        username: _username.text.trim().isEmpty ? _email.text.split('@').first : _username.text.trim(),
        displayName: _display.text.trim().isEmpty ? _email.text.split('@').first : _display.text.trim(),
      );
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
      appBar: AppBar(title: const Text('Create account')),
      body: GlassBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassTextField(controller: _display, hint: 'Display name', prefixIcon: Icons.badge_outlined, textInputAction: TextInputAction.next),
                  const SizedBox(height: 14),
                  GlassTextField(controller: _username, hint: 'Username (optional)', prefixIcon: Icons.alternate_email_rounded, textInputAction: TextInputAction.next),
                  const SizedBox(height: 14),
                  GlassTextField(controller: _email, hint: 'Email', prefixIcon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next),
                  const SizedBox(height: 14),
                  GlassTextField(controller: _password, hint: 'Password (8+ characters)', obscure: true, prefixIcon: Icons.lock_outline_rounded, textInputAction: TextInputAction.done, onSubmitted: (_) => _submit()),
                  const SizedBox(height: 24),
                  GlassButton(label: 'Create my account', loading: _loading, onPressed: _submit),
                  const SizedBox(height: 14),
                  const Text.rich(
                    TextSpan(
                      text: 'By creating an account you agree to the Terms of Service and Privacy Policy.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}