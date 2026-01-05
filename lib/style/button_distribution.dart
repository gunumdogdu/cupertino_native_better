/// Distribution mode for buttons within a [CNGlassButtonGroup].
///
/// Controls how buttons are sized and distributed within the group layout.
///
/// {@category Style}
enum CNButtonDistribution {
  /// Buttons are equally distributed, taking up equal space.
  ///
  /// All buttons will have the same width (horizontal layout) or height
  /// (vertical layout), regardless of their content. This can cause text
  /// buttons to be compressed if icon-only buttons are present.
  equal,

  /// Buttons use their natural/intrinsic size based on content.
  ///
  /// Each button takes only the space it needs. Icon-only buttons remain
  /// circular, while text buttons expand to fit their label. This is the
  /// recommended mode for mixed button types.
  natural,

  /// Mixed mode: respects individual button's `flexible` property.
  ///
  /// Buttons with `flexible: true` in their config will expand to fill
  /// available space, while buttons with `flexible: false` will maintain
  /// their intrinsic size. If `flexible` is null, defaults to natural sizing
  /// (text buttons flexible, icon-only buttons fixed).
  mixed,
}
