import 'package:flutter/material.dart';

class DarkShell extends StatelessWidget {
  const DarkShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 16),
    this.maxWidth = 620,
  });

  final Widget child;
  final EdgeInsets padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: scheme.surface),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: dark ? const Color(0xFF080B0A) : const Color(0xFFF4F6F2),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: padding,
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FinanceSurface extends StatelessWidget {
  const FinanceSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color ?? (dark ? scheme.surfaceContainerLowest : Colors.white),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class FinanceHeroPanel extends StatelessWidget {
  const FinanceHeroPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0D241F) : const Color(0xFF10251F),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: dark ? 0.16 : 0.12),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
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
    this.radius = 8,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final surfaceColor =
        color ?? (dark ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest);
    final borderColor = scheme.outlineVariant.withValues(alpha: dark ? 0.52 : 0.84);
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.035),
            blurRadius: dark ? 6 : 12,
            offset: const Offset(0, 6),
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: dark ? 0.46 : 0.34),
          width: 1.2,
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: dark ? 0.18 : 0.14),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        painter: _ClearLedgerMarkPainter(
          primary: colorScheme.primary,
          secondary: colorScheme.tertiary,
          onSurface: colorScheme.onSurface,
          dark: dark,
        ),
      ),
    );
  }
}

enum AppGlyph {
  receipt,
  ledger,
  accounts,
  budget,
  insight,
  settings,
  scan,
  card,
  exchange,
  cash,
  bank,
  wallet,
  transfer,
  inflow,
  outflow,
  document,
}

class _ClearLedgerMarkPainter extends CustomPainter {
  const _ClearLedgerMarkPainter({
    required this.primary,
    required this.secondary,
    required this.onSurface,
    required this.dark,
  });

  final Color primary;
  final Color secondary;
  final Color onSurface;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pageRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.29, h * 0.16, w * 0.46, h * 0.66),
      Radius.circular(w * 0.11),
    );

    final pageFill = Paint()
      ..color = (dark ? Colors.white : Colors.white).withValues(alpha: dark ? 0.08 : 0.58)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(pageRect, pageFill);

    final stroke = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w * 0.072;

    canvas.drawRRect(pageRect, stroke);

    final fold = Path()
      ..moveTo(w * 0.57, h * 0.16)
      ..quadraticBezierTo(w * 0.71, h * 0.22, w * 0.75, h * 0.36)
      ..lineTo(w * 0.58, h * 0.35);
    canvas.drawPath(fold, stroke);

    final checkPaint = Paint()
      ..color = secondary
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w * 0.09;
    final check = Path()
      ..moveTo(w * 0.34, h * 0.56)
      ..lineTo(w * 0.45, h * 0.67)
      ..quadraticBezierTo(w * 0.54, h * 0.54, w * 0.70, h * 0.39);
    canvas.drawPath(check, checkPaint);

    final scanPaint = Paint()
      ..color = onSurface.withValues(alpha: dark ? 0.48 : 0.55)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.035;
    canvas.drawLine(Offset(w * 0.24, h * 0.32), Offset(w * 0.48, h * 0.32), scanPaint);
    canvas.drawLine(Offset(w * 0.52, h * 0.75), Offset(w * 0.78, h * 0.75), scanPaint);
    canvas.drawCircle(Offset(w * 0.28, h * 0.32), w * 0.026, scanPaint);
  }

  @override
  bool shouldRepaint(covariant _ClearLedgerMarkPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.onSurface != onSurface ||
        oldDelegate.dark != dark;
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.glyph,
    this.trailing,
    this.centered = false,
    this.showLogo = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final AppGlyph? glyph;
  final Widget? trailing;
  final bool centered;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.64);

    final titleWidget = Text(
      title,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        color: centered ? Theme.of(context).colorScheme.primary : onSurface,
        fontSize: centered ? 31 : 27,
        fontWeight: FontWeight.w900,
        height: 1.08,
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(2, centered ? 18 : 8, 2, 10),
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
                if (icon != null || glyph != null || showLogo) ...[
                  showLogo
                      ? const AppLogoMark(size: 48)
                      : AppIconBadge(icon: icon, glyph: glyph),
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
    this.icon,
    this.glyph,
    this.color,
    this.size = 48,
  });

  final IconData? icon;
  final AppGlyph? glyph;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    assert(icon != null || glyph != null);
    final scheme = Theme.of(context).colorScheme;
    final hasCustomColor = color != null;
    final badgeColor = color ?? scheme.onPrimaryContainer;
    final badgeFill = hasCustomColor
        ? color!.withValues(alpha: 0.13)
        : scheme.primaryContainer;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badgeFill,
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(
          color: hasCustomColor
              ? badgeColor.withValues(alpha: 0.28)
              : scheme.outlineVariant.withValues(alpha: 0.70),
        ),
      ),
      child: glyph == null
          ? Icon(icon, color: badgeColor, size: size * 0.52)
          : CustomPaint(
              painter: _AppGlyphPainter(glyph: glyph!, color: badgeColor),
            ),
    );
  }
}

class _AppGlyphPainter extends CustomPainter {
  const _AppGlyphPainter({required this.glyph, required this.color});

  final AppGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w * 0.075;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    void page({double left = 0.30, double top = 0.18, double width = 0.42, double height = 0.64}) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * left, h * top, w * width, h * height),
          Radius.circular(w * 0.08),
        ),
        stroke,
      );
    }

    void card({double left = 0.23, double top = 0.31, double width = 0.54, double height = 0.38}) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * left, h * top, w * width, h * height),
        Radius.circular(w * 0.09),
      );
      canvas.drawRRect(rect, fill);
      canvas.drawRRect(rect, stroke);
    }

    switch (glyph) {
      case AppGlyph.receipt:
        page(left: 0.29, width: 0.44);
        canvas.drawLine(Offset(w * 0.40, h * 0.39), Offset(w * 0.62, h * 0.39), stroke);
        canvas.drawLine(Offset(w * 0.40, h * 0.52), Offset(w * 0.58, h * 0.52), stroke);
        canvas.drawLine(Offset(w * 0.40, h * 0.65), Offset(w * 0.64, h * 0.65), stroke);
        break;
      case AppGlyph.ledger:
        page(left: 0.24, top: 0.22, width: 0.52, height: 0.56);
        canvas.drawLine(Offset(w * 0.38, h * 0.34), Offset(w * 0.38, h * 0.72), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.34), Offset(w * 0.66, h * 0.34), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.50), Offset(w * 0.66, h * 0.50), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.66), Offset(w * 0.66, h * 0.66), stroke);
        break;
      case AppGlyph.accounts:
        canvas.drawCircle(Offset(w * 0.37, h * 0.38), w * 0.10, stroke);
        canvas.drawCircle(Offset(w * 0.63, h * 0.38), w * 0.10, stroke);
        canvas.drawArc(Rect.fromLTWH(w * 0.22, h * 0.52, w * 0.30, h * 0.22), 3.24, 2.92, false, stroke);
        canvas.drawArc(Rect.fromLTWH(w * 0.48, h * 0.52, w * 0.30, h * 0.22), 3.24, 2.92, false, stroke);
        canvas.drawLine(Offset(w * 0.43, h * 0.48), Offset(w * 0.57, h * 0.48), stroke);
        break;
      case AppGlyph.budget:
        canvas.drawCircle(Offset(w * 0.50, h * 0.50), w * 0.27, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.50, h * 0.50)
            ..lineTo(w * 0.50, h * 0.22)
            ..arcTo(Rect.fromCircle(center: Offset(w * 0.50, h * 0.50), radius: w * 0.27), -1.57, 1.35, false),
          stroke,
        );
        canvas.drawLine(Offset(w * 0.34, h * 0.68), Offset(w * 0.66, h * 0.68), stroke);
        break;
      case AppGlyph.insight:
        canvas.drawCircle(Offset(w * 0.50, h * 0.42), w * 0.18, stroke);
        canvas.drawLine(Offset(w * 0.41, h * 0.61), Offset(w * 0.59, h * 0.61), stroke);
        canvas.drawLine(Offset(w * 0.44, h * 0.72), Offset(w * 0.56, h * 0.72), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.20), Offset(w * 0.50, h * 0.14), stroke);
        canvas.drawLine(Offset(w * 0.27, h * 0.30), Offset(w * 0.21, h * 0.25), stroke);
        canvas.drawLine(Offset(w * 0.73, h * 0.30), Offset(w * 0.79, h * 0.25), stroke);
        break;
      case AppGlyph.settings:
        canvas.drawCircle(Offset(w * 0.50, h * 0.50), w * 0.12, stroke);
        for (final angle in [0.0, 1.57, 3.14, 4.71]) {
          final start = Offset(w * (0.50 + 0.23 * _cos(angle)), h * (0.50 + 0.23 * _sin(angle)));
          final end = Offset(w * (0.50 + 0.32 * _cos(angle)), h * (0.50 + 0.32 * _sin(angle)));
          canvas.drawLine(start, end, stroke);
        }
        break;
      case AppGlyph.scan:
        page(left: 0.32, top: 0.24, width: 0.36, height: 0.52);
        canvas.drawLine(Offset(w * 0.20, h * 0.36), Offset(w * 0.80, h * 0.36), stroke);
        canvas.drawLine(Offset(w * 0.24, h * 0.64), Offset(w * 0.76, h * 0.64), stroke);
        break;
      case AppGlyph.card:
        card();
        canvas.drawLine(Offset(w * 0.26, h * 0.43), Offset(w * 0.74, h * 0.43), stroke);
        canvas.drawLine(Offset(w * 0.35, h * 0.58), Offset(w * 0.47, h * 0.58), stroke);
        canvas.drawLine(Offset(w * 0.54, h * 0.58), Offset(w * 0.66, h * 0.58), stroke);
        break;
      case AppGlyph.exchange:
        canvas.drawLine(Offset(w * 0.28, h * 0.38), Offset(w * 0.70, h * 0.38), stroke);
        canvas.drawLine(Offset(w * 0.60, h * 0.28), Offset(w * 0.72, h * 0.38), stroke);
        canvas.drawLine(Offset(w * 0.60, h * 0.48), Offset(w * 0.72, h * 0.38), stroke);
        canvas.drawLine(Offset(w * 0.72, h * 0.62), Offset(w * 0.30, h * 0.62), stroke);
        canvas.drawLine(Offset(w * 0.40, h * 0.52), Offset(w * 0.28, h * 0.62), stroke);
        canvas.drawLine(Offset(w * 0.40, h * 0.72), Offset(w * 0.28, h * 0.62), stroke);
        break;
      case AppGlyph.cash:
        card(left: 0.20, top: 0.34, width: 0.60, height: 0.32);
        canvas.drawCircle(Offset(w * 0.50, h * 0.50), w * 0.09, stroke);
        break;
      case AppGlyph.bank:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.22, h * 0.40)
            ..lineTo(w * 0.50, h * 0.22)
            ..lineTo(w * 0.78, h * 0.40),
          stroke,
        );
        for (final x in [0.32, 0.50, 0.68]) {
          canvas.drawLine(Offset(w * x, h * 0.44), Offset(w * x, h * 0.70), stroke);
        }
        canvas.drawLine(Offset(w * 0.24, h * 0.74), Offset(w * 0.76, h * 0.74), stroke);
        break;
      case AppGlyph.wallet:
        card(left: 0.20, top: 0.30, width: 0.60, height: 0.42);
        canvas.drawCircle(Offset(w * 0.66, h * 0.51), w * 0.035, stroke);
        break;
      case AppGlyph.transfer:
        canvas.drawCircle(Offset(w * 0.32, h * 0.50), w * 0.10, stroke);
        canvas.drawCircle(Offset(w * 0.68, h * 0.50), w * 0.10, stroke);
        canvas.drawLine(Offset(w * 0.42, h * 0.43), Offset(w * 0.56, h * 0.43), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.35), Offset(w * 0.58, h * 0.43), stroke);
        canvas.drawLine(Offset(w * 0.58, h * 0.57), Offset(w * 0.44, h * 0.57), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.65), Offset(w * 0.42, h * 0.57), stroke);
        break;
      case AppGlyph.inflow:
        canvas.drawLine(Offset(w * 0.30, h * 0.66), Offset(w * 0.68, h * 0.28), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.28), Offset(w * 0.68, h * 0.28), stroke);
        canvas.drawLine(Offset(w * 0.68, h * 0.28), Offset(w * 0.68, h * 0.46), stroke);
        break;
      case AppGlyph.outflow:
        canvas.drawLine(Offset(w * 0.30, h * 0.34), Offset(w * 0.68, h * 0.72), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.72), Offset(w * 0.68, h * 0.72), stroke);
        canvas.drawLine(Offset(w * 0.68, h * 0.72), Offset(w * 0.68, h * 0.54), stroke);
        break;
      case AppGlyph.document:
        page(left: 0.31, top: 0.18, width: 0.42, height: 0.64);
        final check = Path()
          ..moveTo(w * 0.39, h * 0.56)
          ..lineTo(w * 0.48, h * 0.65)
          ..lineTo(w * 0.64, h * 0.42);
        canvas.drawPath(check, stroke);
        break;
    }
  }

  double _sin(double value) {
    if (value == 0) return 0;
    if (value == 1.57) return 1;
    if (value == 3.14) return 0;
    return -1;
  }

  double _cos(double value) {
    if (value == 0) return 1;
    if (value == 1.57) return 0;
    if (value == 3.14) return -1;
    return 0;
  }

  @override
  bool shouldRepaint(covariant _AppGlyphPainter oldDelegate) {
    return oldDelegate.glyph != glyph || oldDelegate.color != color;
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
