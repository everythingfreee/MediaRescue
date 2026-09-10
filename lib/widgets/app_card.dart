import 'package:flutter/material.dart';
import '../app/theme/app_radius.dart';
import '../app/theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.borderColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.cardTheme.color;
    final bColor = borderColor ?? theme.colorScheme.outline;

    Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: bColor, width: 1),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: AppRadius.borderLg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderLg,
          child: content,
        ),
      );
    }

    return content;
  }
}
