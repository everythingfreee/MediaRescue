import 'package:flutter/material.dart';
import '../app/theme/app_radius.dart';
import '../app/theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = theme.colorScheme.primary;
        fg = theme.colorScheme.onPrimary;
        break;
      case AppButtonVariant.secondary:
        bg = theme.colorScheme.surfaceContainerHigh;
        fg = theme.colorScheme.onSurface;
        break;
      case AppButtonVariant.outline:
        bg = Colors.transparent;
        fg = theme.colorScheme.onSurface;
        border = BorderSide(color: theme.colorScheme.outline, width: 1);
        break;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = theme.colorScheme.primary;
        break;
      case AppButtonVariant.danger:
        bg = theme.colorScheme.error;
        fg = Colors.white;
        break;
    }

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          icon!,
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 48,
      child: Material(
        color: onPressed == null ? bg.withValues(alpha:0.5) : bg,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderMd,
          side: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: content,
          ),
        ),
      ),
    );
  }
}
