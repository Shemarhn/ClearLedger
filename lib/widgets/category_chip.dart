import 'package:flutter/material.dart';

import '../core/constants.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    this.selected = false,
    this.onTap,
  });

  final String category;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppConstants.categoryColors[category] ?? Colors.grey;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(category),
      selected: selected,
      avatar: Icon(AppConstants.categoryIcons[category], size: 16),
      selectedColor: color.withValues(alpha: 0.2),
      onSelected: (_) => onTap?.call(),
      side: BorderSide(
        color: selected
            ? color
            : scheme.outlineVariant.withValues(alpha: dark ? 0.72 : 1),
      ),
    );
  }
}
