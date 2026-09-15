import 'package:flutter/foundation.dart' show listEquals;
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

/// One rounded rectangle of a multi-part glass shape, in logical points relative to the container's
/// own top-left. A square with `radius` at half its side is a circle.
@immutable
class CNGlassPart {
  /// Creates one part of a multi-part glass shape.
  const CNGlassPart({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.radius,
  });

  /// Offset from the container's left edge.
  final double left;

  /// Offset from the container's top edge.
  final double top;

  /// Part width.
  final double width;

  /// Part height.
  final double height;

  /// Corner radius, clamped natively to half the shorter side.
  final double radius;

  /// Wire format for the platform channel.
  Map<String, double> toMap() => <String, double>{
    'left': left,
    'top': top,
    'width': width,
    'height': height,
    'radius': radius,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CNGlassPart &&
          left == other.left &&
          top == other.top &&
          width == other.width &&
          height == other.height &&
          radius == other.radius;

  @override
  int get hashCode => Object.hash(left, top, width, height, radius);
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

  /// Renders one glass effect whose shape is these disjoint parts, overriding [shape]. One effect
  /// means one backdrop sample, so the parts cannot drift apart in colour, and the rim follows every
  /// part's own outline — unlike clipping a single-shape container, which rims only the shape it was
  /// given. Null (the default) keeps the [shape] behaviour.
  final List<CNGlassPart>? parts;

  /// Creates a configuration for Liquid Glass effects.
  const LiquidGlassConfig({
    this.effect = CNGlassEffect.regular,
    this.shape = CNGlassEffectShape.capsule,
    this.cornerRadius,
    this.tint,
    this.interactive = false,
    this.parts,
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
          listEquals(parts, other.parts);

  @override
  int get hashCode =>
      effect.hashCode ^
      shape.hashCode ^
      (cornerRadius?.hashCode ?? 0) ^
      (tint?.hashCode ?? 0) ^
      interactive.hashCode ^
      Object.hashAll(parts ?? const <CNGlassPart>[]);
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
  Widget liquidGlass({
    CNGlassEffect effect = CNGlassEffect.regular,
    CNGlassEffectShape shape = CNGlassEffectShape.capsule,
    double? cornerRadius,
    Color? tint,
    bool interactive = false,
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
      ),
      child: this,
    );
  }
}
