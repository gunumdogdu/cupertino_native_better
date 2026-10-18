import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Utility class for accessing theme data with fallback support.
///
/// This class provides methods to access theme properties that work
/// even when CupertinoApp is not in the widget tree (e.g., when using
/// MaterialApp with autoroute or other routing solutions).
class ThemeHelper {
  /// Gets the brightness (light/dark mode) from the theme.
  ///
  /// Uses the CupertinoTheme brightness when one is set. Under a MaterialApp
  /// that is the Material theme's brightness. When the theme sets none (a
  /// CupertinoApp following the system), falls back to the platform
  /// brightness.
  static Brightness getBrightness(BuildContext context) =>
      CupertinoTheme.brightnessOf(context);

  /// Gets the primary/accent color from the theme.
  ///
  /// Tries to get color from:
  /// 1. CupertinoTheme primaryColor (if CupertinoApp is present)
  /// 2. Material Theme primaryColor (if MaterialApp is present)
  /// 3. System blue (fallback)
  static Color getPrimaryColor(BuildContext context) {
    try {
      final cupertinoTheme = CupertinoTheme.of(context);
      return cupertinoTheme.primaryColor;
    } catch (_) {
      // CupertinoApp not in tree, try Material theme
      try {
        final materialTheme = Theme.of(context);
        return materialTheme.primaryColor;
      } catch (_) {
        // No theme found, use system blue as fallback
        return CupertinoColors.systemBlue;
      }
    }
  }

  /// Checks if the current theme is dark mode.
  static bool isDark(BuildContext context) {
    return getBrightness(context) == Brightness.dark;
  }
}
