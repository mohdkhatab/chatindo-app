import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Animated aurora background that sits behind every screen.
class GlassBackground extends StatefulWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * math.pi;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.ink),
            // Aurora blobs drift in a sine pattern.
            _blob(0.15, alignment: Alignment(-0.95, -0.9), phase: t, color: AppColors.violet),
            _blob(0.12, alignment: Alignment(0.95, -0.65), phase: t + math.pi / 2, color: AppColors.cyan),
            _blob(0.2, alignment: Alignment(0.8, 0.95), phase: t + math.pi, color: AppColors.pink),
            // Subtle vignette to keep edges dark for readability.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.6,
                  colors: [Colors.transparent, Color(0xCC05060F)],
                  stops: [0.55, 1],
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }

  /// A soft radial glow that slowly orbits its anchor point.
  Widget _blob(double size, {required Alignment alignment, required double phase, required Color color}) {
    // Wrap in a Transform.rotate via LayoutBuilder to slide the center.
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final dx = math.sin(phase) * w * 0.12;
        final dy = math.cos(phase * 0.83) * h * 0.1;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Align(
            alignment: alignment,
            child: FractionallySizedBox(
              widthFactor: size * 2.2,
              heightFactor: size * 2.2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [color.withOpacity(0.42), color.withOpacity(0)],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Frosted panel with a hairline gradient border — the core "liquid glass" surface.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.radius = 24,
    this.borderOpacity = 0.18,
    this.fill = 0.07,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final double borderOpacity;
  final double fill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(borderOpacity)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(fill + 0.05),
            Colors.white.withOpacity(fill * 0.4),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.violet.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Primary gradient pill button with glow. `loading` shows a spinner.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.gradient = AppColors.gradientPrimary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final List<Color> gradient;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.5,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.5),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  else ...[
                    if (icon != null) ...[Icon(icon, color: Colors.white), const SizedBox(width: 10)],
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted text input.
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffix,
    this.onSubmitted,
    this.onChanged,
    this.textInputAction,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
        color: Colors.white.withOpacity(0.06),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscure,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.textMuted, size: 20) : null,
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient-ring avatar with initials fallback.
class GlassAvatar extends StatelessWidget {
  const GlassAvatar({super.key, this.name, this.url, this.radius = 24, this.online});

  final String? name;
  final String? url;
  final double radius;
  final bool? online;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final ring = radius + 3;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: ring * 2,
          height: ring * 2,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: AppColors.gradientPrimary),
          ),
          child: ClipOval(
            child: url != null && url!.isNotEmpty
                ? Image.network(url!, width: ring * 2, height: ring * 2, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initialsBox(initials))
                : _initialsBox(initials),
          ),
        ),
        if (online == true)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _initialsBox(String text) {
    return Container(
      color: const Color(0xFF232A4D),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: radius * 0.75),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, math.min(2, parts.first.length)).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// Small glowing chip, e.g. online/presence or badges.
class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.label, this.color = AppColors.textMuted});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}