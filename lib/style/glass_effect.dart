import 'package:flutter/widgets.dart';
import '../utils/version_detector.dart';
import '../components/liquid_glass_container.dart';

/// Liquid Glass effect variants for iOS 26+.
enum CNGlassEffect {
  /// Regular glass effect with standard blur and transparency.
  ///
  /// Frosts whatever sits behind it. This is the default and the right choice
  /// for glass over arbitrary content, where legibility matters more than
  /// showing the backdrop.
  regular,

  /// Prominent glass effect with enhanced visual prominence.
  ///
  /// **Currently renders identically to [regular].** SwiftUI's `Glass` type
  /// has no prominent counterpart to map onto, so this value falls back. It
  /// is kept so existing code keeps compiling and so the mapping can be
  /// filled in if Apple adds one; don't reach for it expecting a visual
  /// difference today.
  prominent,

  /// Clear glass effect — far more transparent than [regular], for glass that
  /// sits over imagery and should let it through rather than frosting it.
  ///
  /// Maps to SwiftUI's `Glass.clear`. This is what Apple's own media controls
  /// use over video and artwork. Because it barely blurs, content layered on
  /// top of it needs its own contrast handling — a shadow or a scrim — in a
  /// way that [regular] does not.
  clear,
}

/// Shapes for Liquid Glass effects.
enum CNGlassEffectShape {
  /// Capsule shape (default) - rounded ends based on view height.
  capsule,

  /// Rectangle shape with specified corner radius.
  rect,

  /// Circle shape.
  circle,
}

/// Whether Liquid Glass takes the light or the dark look.
///
/// By default ([adaptive]) the glass follows the app's brightness. [light]
/// and [dark] fix the look whatever the app's brightness is.
///
/// On iOS 26 (seen on 26.0 and 26.2) the system also switches small glass
/// by itself according to the content behind it. Small here means less
/// than about 65 pt on its shorter side. Light glass turns dark while near-black content
/// is behind it, and dark glass turns light over near-white content. The
/// glass switches back when that content has gone. No public API turns this
/// off, so [light] and [dark] can't stop it there. Glass of 66 pt or more on
/// its shorter side doesn't switch. On iOS 27 and macOS 27 the glass doesn't
/// switch by itself, so [light] and [dark] hold over any content. Below
/// macOS 26 the setting applies to the translucent material that the
/// container uses there.
///
/// Only the glass changes. A [LiquidGlassContainer]'s child is drawn by
/// Flutter and keeps its own colours, so give it colours that read on the
/// look you choose.
enum CNGlassAppearance {
  /// Light glass in a light app and dark glass in a dark app. The default.
  adaptive,

  /// Light glass, also in a dark app.
  ///
  /// On iOS 26, glass less than about 65 pt on its shorter side still
  /// turns dark while near-black content is behind it. See
  /// [CNGlassAppearance].
  light,

  /// Dark glass, also in a light app.
  ///
  /// On iOS 26, glass less than about 65 pt on its shorter side still
  /// turns light while near-white content is behind it. See
  /// [CNGlassAppearance].
  dark,
}

/// Configuration for Liquid Glass effects.
class LiquidGlassConfig {
  /// The glass effect variant to apply.
  final CNGlassEffect effect;

  /// The shape for the glass effect.
  final CNGlassEffectShape shape;

  /// Corner radius for rectangle shape (only used when shape is rect).
  final double? cornerRadius;

  /// Optional tint color for the glass effect.
  final Color? tint;

  /// Whether the glass effect should be interactive (responds to touch/pointer).
  final bool interactive;

  /// Whether the glass takes the light or the dark look.
  ///
  /// Defaults to [CNGlassAppearance.adaptive], which follows the app's
  /// brightness. [CNGlassAppearance.light] keeps light glass in a dark app,
  /// and [CNGlassAppearance.dark] keeps dark glass in a light app. On iOS
  /// 26 the system still switches small glass over near-black or near-white
  /// content. See [CNGlassAppearance] for the details.
  final CNGlassAppearance appearance;

  /// Creates a configuration for Liquid Glass effects.
  const LiquidGlassConfig({
    this.effect = CNGlassEffect.regular,
    this.shape = CNGlassEffectShape.capsule,
    this.cornerRadius,
    this.tint,
    this.interactive = false,
    this.appearance = CNGlassAppearance.adaptive,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassConfig &&
          runtimeType == other.runtimeType &&
          effect == other.effect &&
          shape == other.shape &&
          cornerRadius == other.cornerRadius &&
          tint == other.tint &&
          interactive == other.interactive &&
          appearance == other.appearance;

  @override
  int get hashCode =>
      Object.hash(effect, shape, cornerRadius, tint, interactive, appearance);
}

/// Extension on Widget to apply Liquid Glass effects.
///
/// Example usage:
/// ```dart
/// Text("Hello, World!")
///   .liquidGlass()
///
/// Text("Hello, World!")
///   .liquidGlass(
///     shape: CNGlassEffectShape.rect,
///     cornerRadius: 16.0,
///   )
///
/// Text("Hello, World!")
///   .liquidGlass(
///     effect: CNGlassEffect.regular,
///     tint: Colors.orange,
///     interactive: true,
///   )
/// ```
extension LiquidGlassExtension on Widget {
  /// Applies a Liquid Glass effect to this widget.
  ///
  /// On iOS 26+ and macOS 26+, this wraps the widget in a native container
  /// that applies the glass effect. On older versions or other platforms,
  /// the widget is returned unchanged.
  ///
  /// The [effect] determines the glass variant — [CNGlassEffect.regular] to
  /// frost the backdrop, [CNGlassEffect.clear] to let it through.
  /// The [shape] determines the shape of the glass effect (capsule, rect, or circle).
  /// The [cornerRadius] is only used when [shape] is [CNGlassEffectShape.rect].
  /// The [tint] applies a color tint to the glass effect.
  /// The [interactive] makes the glass effect respond to touch/pointer interactions.
  /// The [appearance] chooses light or dark glass, or, by default, follows
  /// the app's brightness (see [CNGlassAppearance]).
  Widget liquidGlass({
    CNGlassEffect effect = CNGlassEffect.regular,
    CNGlassEffectShape shape = CNGlassEffectShape.capsule,
    double? cornerRadius,
    Color? tint,
    bool interactive = false,
    CNGlassAppearance appearance = CNGlassAppearance.adaptive,
  }) {
    // Only apply glass effect on iOS 26+ or macOS 26+
    if (!PlatformVersion.supportsLiquidGlass) {
      return this;
    }

    return LiquidGlassContainer(
      config: LiquidGlassConfig(
        effect: effect,
        shape: shape,
        cornerRadius: cornerRadius,
        tint: tint,
        interactive: interactive,
        appearance: appearance,
      ),
      child: this,
    );
  }
}
