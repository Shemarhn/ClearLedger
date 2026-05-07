import 'package:flutter/material.dart';

import '../core/constants.dart';

class DarkShell extends StatelessWidget {
  const DarkShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  final Widget child;
  final EdgeInsets padding;

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
                  Color(0xFF0C1A16),
                  AppConstants.darkBackground,
                  Color(0xFF050B0A),
                ]
              : const [
                  Color(0xFFF7FBF8),
                  AppConstants.background,
                  Color(0xFFEAF3EE),
                ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: padding,
          child: child,
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
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = color ??
        (dark ? AppConstants.darkSurface : Theme.of(context).colorScheme.surface);
    final borderColor = dark ? AppConstants.darkStroke : const Color(0xFFDCE6E1);
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: dark ? 20 : 16,
            offset: const Offset(0, 10),
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
        fontSize: compact ? 16 : 28,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
    );
  }
}
