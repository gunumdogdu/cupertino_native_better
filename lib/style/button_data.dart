/// Data models for button configuration in glass button groups.
///
/// This library provides [CNButtonData] and [CNButtonDataConfig] for
/// configuring buttons in [CNGlassButtonGroup] without using widget instances.
///
/// {@category Styles}
library;

import 'package:flutter/widgets.dart';

import 'button_style.dart';
import 'sf_symbol.dart';
import 'image_placement.dart';

/// Data model for button configuration in CNGlassButtonGroup.
///
/// This class holds all the properties needed to render a button without
/// being a widget itself. Use this with [CNGlassButtonGroup] for cleaner
/// data-driven button groups.
///
/// Example:
/// ```dart
/// CNGlassButtonGroup(
///   buttons: [
///     CNButtonData.icon(
///       icon: CNSFSymbol.house,
///       onPressed: () => print('Home'),
///     ),
///     CNButtonData.icon(
///       icon: CNSFSymbol.gear,
///       onPressed: () => print('Settings'),
///     ),
///   ],
/// )
/// ```
class CNButtonData {
  /// Creates a button data model with a label.
  const CNButtonData({
    required this.label,
    this.icon,
    this.customIcon,
    this.imageAsset,
    this.onPressed,
    this.enabled = true,
    this.tint,
    this.config = const CNButtonDataConfig(),
  }) : badgeCount = null,
       isIcon = false;

  /// Creates an icon-only button data model.
  const CNButtonData.icon({
    this.icon,
    this.customIcon,
    this.imageAsset,
    this.onPressed,
    this.enabled = true,
    this.tint,
    this.badgeCount,
    this.config = const CNButtonDataConfig(),
  }) : label = null,
       isIcon = true;

  /// The text label for the button. Null for icon-only buttons.
  final String? label;

  /// SF Symbol icon to display.
  final CNSymbol? icon;

  /// Custom Flutter IconData to render as an image.
  final IconData? customIcon;

  /// Image asset to display.
  final CNImageAsset? imageAsset;

  /// Callback when the button is pressed.
  final VoidCallback? onPressed;

  /// Whether the button is enabled.
  final bool enabled;

  /// Tint color for the button.
  final Color? tint;

  /// Configuration for the button appearance.
  final CNButtonDataConfig config;

  /// Optional badge count to display on icon buttons.
  /// Displayed as "99+" for counts > 99. Only applies to icon-only buttons.
  final int? badgeCount;

  /// Whether this is an icon-only button.
  final bool isIcon;

  /// Creates a copy of this data with the given fields replaced.
  CNButtonData copyWith({
    String? label,
    CNSymbol? icon,
    IconData? customIcon,
    CNImageAsset? imageAsset,
    VoidCallback? onPressed,
    bool? enabled,
    Color? tint,
    int? badgeCount,
    CNButtonDataConfig? config,
  }) {
    if (isIcon) {
      return CNButtonData.icon(
        icon: icon ?? this.icon,
        customIcon: customIcon ?? this.customIcon,
        imageAsset: imageAsset ?? this.imageAsset,
        onPressed: onPressed ?? this.onPressed,
        enabled: enabled ?? this.enabled,
        tint: tint ?? this.tint,
        badgeCount: badgeCount ?? this.badgeCount,
        config: config ?? this.config,
      );
    }
    return CNButtonData(
      label: label ?? this.label!,
      icon: icon ?? this.icon,
      customIcon: customIcon ?? this.customIcon,
      imageAsset: imageAsset ?? this.imageAsset,
      onPressed: onPressed ?? this.onPressed,
      enabled: enabled ?? this.enabled,
      tint: tint ?? this.tint,
      config: config ?? this.config,
    );
  }
}

/// Configuration options for CNButtonData.
///
/// This mirrors [CNButtonConfig] but is designed for data models rather
/// than direct widget usage.
class CNButtonDataConfig {
  /// Creates button data configuration.
  const CNButtonDataConfig({
    this.width,
    this.style = CNButtonStyle.glass,
    this.padding,
    this.borderRadius,
    this.minHeight,
    this.imagePadding,
    this.imagePlacement,
    this.glassEffectUnionId,
    this.glassEffectId,
    this.glassEffectInteractive = true,
    this.customIconSize,
    this.interaction = true,
  });

  /// Fixed width for the button.
  final double? width;

  /// Visual style of the button.
  final CNButtonStyle style;

  /// Internal padding.
  final EdgeInsets? padding;

  /// Corner radius for the button.
  final double? borderRadius;

  /// Minimum height constraint.
  final double? minHeight;

  /// Spacing between icon/image and label.
  final double? imagePadding;

  /// Position of the image relative to the label.
  final CNImagePlacement? imagePlacement;

  /// Glass effect union ID for effect blending.
  final String? glassEffectUnionId;

  /// Glass effect ID for individual effect identification.
  final String? glassEffectId;

  /// Whether the glass effect responds to touches.
  final bool glassEffectInteractive;

  /// Size for custom icons (when using [customIcon]).
  ///
  /// If null, defaults to 20.0 points.
  /// This only affects custom icons from IconData (CupertinoIcons, Icons, etc.).
  final double? customIconSize;

  /// Whether the button responds to user interaction.
  ///
  /// When false, the button will not be tappable or respond to touches,
  /// but will maintain its normal visual appearance (no opacity change).
  /// This is different from [CNButtonData.enabled] which also applies
  /// the system's disabled visual styling.
  ///
  /// Defaults to true.
  final bool interaction;

  /// Creates a copy with the given fields replaced.
  CNButtonDataConfig copyWith({
    double? width,
    CNButtonStyle? style,
    EdgeInsets? padding,
    double? borderRadius,
    double? minHeight,
    double? imagePadding,
    CNImagePlacement? imagePlacement,
    String? glassEffectUnionId,
    String? glassEffectId,
    bool? glassEffectInteractive,
    double? customIconSize,
    bool? interaction,
  }) {
    return CNButtonDataConfig(
      width: width ?? this.width,
      style: style ?? this.style,
      padding: padding ?? this.padding,
      borderRadius: borderRadius ?? this.borderRadius,
      minHeight: minHeight ?? this.minHeight,
      imagePadding: imagePadding ?? this.imagePadding,
      imagePlacement: imagePlacement ?? this.imagePlacement,
      glassEffectUnionId: glassEffectUnionId ?? this.glassEffectUnionId,
      glassEffectId: glassEffectId ?? this.glassEffectId,
      glassEffectInteractive:
          glassEffectInteractive ?? this.glassEffectInteractive,
      customIconSize: customIconSize ?? this.customIconSize,
      interaction: interaction ?? this.interaction,
    );
  }
}
