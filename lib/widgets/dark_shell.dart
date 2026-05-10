import 'package:flutter/material.dart';

import '../core/constants.dart';

class DarkShell extends StatelessWidget {
  const DarkShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 16),
    this.maxWidth = 620,
  });

  final Widget child;
  final EdgeInsets padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [
                  AppConstants.darkBackground,
                  AppConstants.darkSurface,
                  AppConstants.darkBackground,
                ]
              : const [
                  AppConstants.surface,
                  AppConstants.background,
                  AppConstants.surfaceHigh,
                ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class FinanceCard extends StatelessWidget {
  const FinanceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = 26,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = color ??
        (dark ? AppConstants.darkSurface : Theme.of(context).colorScheme.surface);
    final borderColor = dark ? AppConstants.darkStroke : AppConstants.lightStroke;
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.26)
                : Colors.black.withValues(alpha: 0.07),
            blurRadius: dark ? 24 : 18,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AmountText extends StatelessWidget {
  const AmountText({
    super.key,
    required this.amount,
    this.currency = 'JMD',
    this.color,
    this.showSign = false,
    this.compact = false,
  });

  final double amount;
  final String currency;
  final Color? color;
  final bool showSign;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final prefix = showSign && amount > 0 ? '+' : '';
    final textColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Text(
      '$prefix$currency ${amount.toStringAsFixed(compact ? 0 : 2)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: textColor,
        fontSize: compact ? 16 : 31,
        fontWeight: FontWeight.w900,
        height: 1.05,
      ),
    );
  }
}

class AppLogoMark extends StatelessWidget {
  const AppLogoMark({
    super.key,
    this.size = 52,
    this.glow = false,
  });

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final markColor = colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? AppConstants.darkSurfaceHigh : AppConstants.surfaceHigh,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: markColor.withValues(alpha: dark ? 0.72 : 0.75),
          width: 1.5,
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        painter: _LedgerMarkPainter(color: markColor),
      ),
    );
  }
}

class _LedgerMarkPainter extends CustomPainter {
  const _LedgerMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * 0.075;

    final page = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.27, size.height * 0.18, size.width * 0.48, size.height * 0.64),
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(page, stroke);

    final fold = Path()
      ..moveTo(size.width * 0.57, size.height * 0.18)
      ..lineTo(size.width * 0.75, size.height * 0.36)
      ..lineTo(size.width * 0.57, size.height * 0.36)
      ..close();
    canvas.drawPath(fold, stroke);

    canvas.drawLine(
      Offset(size.width * 0.38, size.height * 0.47),
      Offset(size.width * 0.64, size.height * 0.47),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.38, size.height * 0.60),
      Offset(size.width * 0.64, size.height * 0.60),
      stroke,
    );
    canvas.drawCircle(Offset(size.width * 0.39, size.height * 0.34), size.width * 0.035, stroke);
  }

  @override
  bool shouldRepaint(covariant _LedgerMarkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.centered = false,
    this.showLogo = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final bool centered;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: dark ? 0.62 : 0.68);
    final surface = dark ? AppConstants.darkSurface : AppConstants.surface;

    final titleWidget = Text(
      title,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        color: centered ? Theme.of(context).colorScheme.primary : onSurface,
        fontSize: centered ? 32 : 27,
        fontWeight: FontWeight.w900,
        height: 1.02,
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, centered ? 28 : 20, 22, 24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: dark ? AppConstants.darkStroke : AppConstants.lightStroke),
      ),
      child: centered
          ? Column(
              children: [
                if (showLogo) ...[
                  const AppLogoMark(size: 54, glow: true),
                  const SizedBox(height: 16),
                ],
                titleWidget,
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.35, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            )
          : Row(
              children: [
                if (icon != null || showLogo) ...[
                  showLogo
                      ? const AppLogoMark(size: 48)
                      : AppIconBadge(icon: icon!),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: muted,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
    );
  }
}

class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.color,
    this.size = 48,
  });

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final badgeColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: dark ? 0.13 : 0.18),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, color: badgeColor, size: size * 0.52),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(color: muted, fontWeight: FontWeight.w800),
          ),
      ],
    );
  }
}
