import 'package:flutter/material.dart';

import '../../services/haptics_service.dart';

/// Theme-level splash factory that adds MediaRescue haptic feedback to every
/// Material tap target in the app.
///
/// Flutter creates exactly one ink feature per press and only for *enabled*
/// tap targets (a disabled button never splashes), which makes the theme's
/// splash factory the single place that reliably covers the whole app:
/// FilledButton, TextButton, IconButton, ListTile, InkWell, Chip,
/// PopupMenuItem, navigation items … all fall back to
/// `Theme.of(context).splashFactory` unless they override it themselves.
///
/// The wrapped factory is delegated to untouched, so the splash looks exactly
/// like before (InkSparkle on Android). The vibration is routed through
/// [HapticsService], which honours the Haptics on/off switch and the intensity
/// selected in Settings, and it fires once per press — never per frame — so
/// long presses and scrolling stay quiet.
class HapticSplashFactory extends InteractiveInkFeatureFactory {
  const HapticSplashFactory(this.delegate);

  /// The factory the splash is really created with.
  final InteractiveInkFeatureFactory delegate;

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    // Soft feedback for the press that produced this splash.
    HapticsService.buttonPress();
    return delegate.create(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      textDirection: textDirection,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
    );
  }
}
