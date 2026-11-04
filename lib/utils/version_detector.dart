import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Utility class for checking OS version with caching and auto-initialization.
///
/// This class provides cached version detection that auto-initializes
/// on first access - no manual initialization needed!
///
/// ```dart
/// if (PlatformVersion.isIOS26OrLater) { ... }
/// ```
class PlatformVersion {
  static int? _cachedIOSVersion;
  static int? _cachedMacOSVersion;
  static bool _isInitialized = false;

  /// Ensures platform info is initialized.
  ///
  /// Called automatically by property accessors - no need to call manually.
  /// Safe to call multiple times.
  static void ensureInitialized() {
    if (_isInitialized) return;

    try {
      if (Platform.isIOS) {
        _cachedIOSVersion = _getIOSVersionManually();
        debugPrint(
          '✅ [cupertino_native_better] iOS version detected: $_cachedIOSVersion',
        );
      } else if (Platform.isMacOS) {
        _cachedMacOSVersion = _getMacOSVersionManually();
        debugPrint(
          '✅ [cupertino_native_better] macOS version detected: $_cachedMacOSVersion',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [cupertino_native_better] Failed to get OS version: $e');
      // On error, assume recent version (iOS 26+ supports Liquid Glass)
      if (Platform.isIOS) {
        _cachedIOSVersion = 26; // Assume modern iOS
      } else if (Platform.isMacOS) {
        _cachedMacOSVersion = 26; // Assume modern macOS
      }
    }

    _isInitialized = true;
  }

  /// Manually gets iOS version by parsing Platform.operatingSystemVersion
  /// Example: "Version 26.1 (Build 23B82)" -> 26
  static int? _getIOSVersionManually() {
    if (!Platform.isIOS) return null;

    try {
      final versionString = Platform.operatingSystemVersion;
      // Example: "Version 26.1 (Build 23B82)"
      final match = RegExp(r'Version (\d+)\.').firstMatch(versionString);
      if (match != null) {
        final version = int.tryParse(match.group(1) ?? '');
        return version;
      }
    } catch (e) {
      debugPrint(
        '⚠️ [cupertino_native_better] Failed to parse iOS version: $e',
      );
    }
    return null;
  }

  /// Manually gets macOS version by parsing Platform.operatingSystemVersion
  static int? _getMacOSVersionManually() {
    if (!Platform.isMacOS) return null;

    try {
      final versionString = Platform.operatingSystemVersion;
      // Example: "Version 26.0 (Build 23A344)"
      final match = RegExp(r'Version (\d+)\.').firstMatch(versionString);
      if (match != null) {
        final version = int.tryParse(match.group(1) ?? '');
        return version;
      }
    } catch (e) {
      debugPrint(
        '⚠️ [cupertino_native_better] Failed to parse macOS version: $e',
      );
    }
    return null;
  }

  /// Gets the iOS major version, auto-initializing if needed.
  static int? get iosVersion {
    ensureInitialized();
    return _cachedIOSVersion;
  }

  /// Gets the macOS major version, auto-initializing if needed.
  static int? get macOSVersion {
    ensureInitialized();
    return _cachedMacOSVersion;
  }

  /// Returns true if running on iOS 26 or later.
  ///
  /// Auto-initializes on first access.
  static bool get isIOS26OrLater {
    if (!Platform.isIOS) return false;
    ensureInitialized();
    return (_cachedIOSVersion ?? 0) >= 26;
  }

  /// Returns true if running on macOS 26 or later.
  ///
  /// Auto-initializes on first access.
  static bool get isMacOS26OrLater {
    if (!Platform.isMacOS) return false;
    ensureInitialized();
    return (_cachedMacOSVersion ?? 0) >= 26;
  }

  /// Returns true if native Liquid Glass effects should be used.
  ///
  /// This is true only on iOS 26+ or macOS 26+.
  /// Auto-initializes on first access.
  static bool get shouldUseNativeGlass => isIOS26OrLater || isMacOS26OrLater;

  /// Returns true if a widget whose native view is a standard AppKit or UIKit
  /// control should use it: on every supported macOS, where those controls
  /// predate Liquid Glass, and on iOS 26 or later. Styling that needs Liquid
  /// Glass keeps checking [isMacOS26OrLater] / [isIOS26OrLater].
  static bool get shouldUseNativeControls => isIOS26OrLater || Platform.isMacOS;

  /// Alias for [shouldUseNativeGlass].
  static bool get supportsLiquidGlass => shouldUseNativeGlass;

  /// Returns true if SF Symbols are supported (iOS/macOS).
  static bool get supportsSFSymbols => Platform.isIOS || Platform.isMacOS;

  /// Returns true if running on iOS (any version).
  static bool get isIOS => Platform.isIOS;

  /// Returns true if running on macOS (any version).
  static bool get isMacOS => Platform.isMacOS;

  /// Returns true if running on Android.
  static bool get isAndroid => Platform.isAndroid;

  /// Returns true if running on Apple platform (iOS or macOS).
  static bool get isApple => Platform.isIOS || Platform.isMacOS;

  /// Checks if iOS version is in the specified range.
  static bool isIOSVersionInRange(int min, [int? max]) {
    if (!Platform.isIOS) return false;
    ensureInitialized();
    final version = _cachedIOSVersion ?? 0;
    if (max != null) {
      return version >= min && version <= max;
    }
    return version >= min;
  }

  /// Checks if macOS version is in the specified range.
  static bool isMacOSVersionInRange(int min, [int? max]) {
    if (!Platform.isMacOS) return false;
    ensureInitialized();
    final version = _cachedMacOSVersion ?? 0;
    if (max != null) {
      return version >= min && version <= max;
    }
    return version >= min;
  }

  /// Pretends the running OS has these major versions, so a test can check
  /// the version gates (e.g. macOS 15, where [shouldUseNativeGlass] is false
  /// but [shouldUseNativeControls] is true). [Platform] itself is not
  /// changed. Call [reset] afterwards.
  @visibleForTesting
  static void debugOverrideVersions({int? iosVersion, int? macOSVersion}) {
    _cachedIOSVersion = iosVersion;
    _cachedMacOSVersion = macOSVersion;
    _isInitialized = true;
  }

  /// Forces a refresh of the cached version (useful for testing).
  ///
  /// This should rarely be needed in production code.
  @visibleForTesting
  static void reset() {
    _cachedIOSVersion = null;
    _cachedMacOSVersion = null;
    _isInitialized = false;
  }
}
