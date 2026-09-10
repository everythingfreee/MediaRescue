import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_radius.dart';
import '../app/theme/app_spacing.dart';

class ScaffoldWithNavBar extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.navigationShell.currentIndex,
    );
  }

  @override
  void didUpdateWidget(covariant ScaffoldWithNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex != oldWidget.navigationShell.currentIndex) {
      if (_pageController.hasClients &&
          _pageController.page?.round() != widget.navigationShell.currentIndex) {
        _pageController.animateToPage(
          widget.navigationShell.currentIndex,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (index != widget.navigationShell.currentIndex) {
      HapticFeedback.selectionClick();
      widget.navigationShell.goBranch(
        index,
        initialLocation: false,
      );
    }
  }

  void _onTabTapped(int index) {
    HapticFeedback.selectionClick();
    if (index == widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(
        index,
        initialLocation: true,
      );
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIndex = widget.navigationShell.currentIndex;

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
        if (widget.navigationShell.currentIndex != 0) {
          _onTabTapped(0);
        } else {
          if (context.canPop()) {
            context.pop();
          }
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: _onPageChanged,
          children: widget.children,
        ),
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
                  onTap: () => _onTabTapped(index),
                  borderRadius: AppRadius.borderPill,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.fastOutSlowIn,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? AppSpacing.md : AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withOpacity(0.14)
                          : Colors.transparent,
                      borderRadius: AppRadius.borderPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedScale(
                          scale: isSelected ? 1.12 : 1.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                          child: HugeIcon(
                            icon: icon,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : (theme.brightness == Brightness.dark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                            size: 22,
                          ),
                        ),
                        ClipRect(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.fastOutSlowIn,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 250),
                                    opacity: isSelected ? 1.0 : 0.0,
                                    child: Text(
                                      label,
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
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