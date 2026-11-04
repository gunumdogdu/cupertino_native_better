/// Button style definitions for Cupertino native controls.
///
/// This library provides [CNButtonStyle] enum with all available button
/// visual styles including Liquid Glass effects for iOS 26+.
///
/// {@category Styles}
library;

/// Visual styles for [CNButton] and related controls.
enum CNButtonStyle {
  /// Minimal, text-only style.
  plain,

  /// Subtle gray background style.
  gray,

  /// Tinted/filled text style.
  tinted,

  /// Bordered button style.
  bordered,

  /// Prominent bordered (accent-colored) style.
  borderedProminent,

  /// Filled background style.
  filled,

  /// Glass effect (iOS 16+/macOS 13+ look-alike).
  glass, // iOS 26+
  /// More prominent glass effect.
  prominentGlass, // iOS 26+
  /// Clear Liquid Glass: more transparent than [glass], for buttons over
  /// photos, video and other rich backgrounds (`UIButton.Configuration
  /// .clearGlass()`, iOS 26+).
  ///
  /// With a `glassEffectUnionId` or `glassEffectId`, the SwiftUI path uses
  /// `Glass.clear`. On macOS 26+ without those IDs, AppKit has no clear
  /// glass bezel, so the button is a borderless button inside a clear
  /// `NSGlassEffectView`. Below iOS/macOS 26 it falls back like [glass].
  clearGlass,

  /// Clear Liquid Glass tinted with the button's tint, the clear
  /// counterpart of [prominentGlass] (`UIButton.Configuration
  /// .prominentClearGlass()`, iOS 26+).
  ///
  /// With a `glassEffectUnionId` or `glassEffectId`, the SwiftUI path uses
  /// `Glass.clear` tinted with the button's tint, since SwiftUI's prominent
  /// glass button style draws its own glass and cannot join a glass union.
  /// On both paths the label and icon are white, as on [prominentGlass]; an
  /// icon colour, or `CNButtonConfig.labelColor` without a glass ID,
  /// overrides it.
  /// On macOS 26+ without those IDs it is a borderless button inside a clear
  /// `NSGlassEffectView` tinted with the tint. Below iOS/macOS 26 it falls
  /// back like [prominentGlass].
  prominentClearGlass,
}
