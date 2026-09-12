import 'package:flutter/material.dart';
import '../app/theme/app_radius.dart';
import '../app/theme/app_spacing.dart';

class AppBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final Widget? icon;

  const AppBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = color ?? theme.colorScheme.primary.withValues(alpha:0.15);
    final fgColor = textColor ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.borderPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
