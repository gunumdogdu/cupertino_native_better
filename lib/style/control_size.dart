/// The size class of a native control, as `NSControl.ControlSize` on macOS
/// and SwiftUI's `ControlSize`.
///
/// iOS controls have fewer sizes; each widget documents how it maps these.
enum CNControlSize {
  /// The smallest size.
  mini,

  /// Smaller than [regular].
  small,

  /// The default size.
  regular,

  /// Larger than [regular] (macOS 11+).
  large,

  /// The largest size (macOS 26+; [large] on older macOS).
  extraLarge,
}
