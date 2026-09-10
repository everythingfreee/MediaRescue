import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_radius.dart';
import '../app/theme/app_spacing.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIndex = navigationShell.currentIndex;

    final items = [
      (HugeIcons.strokeRoundedHome01, 'Home'),
      (HugeIcons.strokeRoundedFolder01, 'Browse'),
      (HugeIcons.strokeRoundedImage01, 'Gallery'),
      (HugeIcons.strokeRoundedSearch01, 'Search'),
      (HugeIcons.strokeRoundedSettings01, 'Settings'),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        } else {
          if (context.canPop()) {
            context.pop();
          }
        }
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppRadius.borderPill,
              border: Border.all(color: theme.colorScheme.outline, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final (icon, label) = items[index];
                final isSelected = currentIndex == index;

                return InkWell(
                  onTap: () {
                    navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    );
                  },
                  borderRadius: AppRadius.borderPill,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: AppRadius.borderPill,
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: icon,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (theme.brightness == Brightness.dark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                          size: 22,
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}