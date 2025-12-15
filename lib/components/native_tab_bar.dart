import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../style/sf_symbol.dart';
import '../utils/version_detector.dart';

/// iOS 26+ Native Tab Bar with Search Support
///
/// This enables the native iOS 26 tab bar with search functionality.
/// When enabled, it replaces the Flutter app's root with a native UITabBarController,
/// giving you the true iOS 26 liquid glass morphing search effect.
///
/// **Important**: This replaces your app's root view controller.
/// The Flutter content will be displayed within the selected tab.
///
/// Example:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   CNTabBarNative.enable(
///     tabs: [
///       CNTab(title: 'Home', sfSymbol: CNSymbol('house.fill')),
///       CNTab(title: 'Search', sfSymbol: CNSymbol('magnifyingglass'), isSearchTab: true),
///       CNTab(title: 'Profile', sfSymbol: CNSymbol('person.fill')),
///     ],
///     onTabSelected: (index) {
///       setState(() => _selectedIndex = index);
///     },
///     onSearchChanged: (query) {
///       print('Search query: $query');
///     },
///   );
/// }
///
/// @override
/// void dispose() {
///   CNTabBarNative.disable();
///   super.dispose();
/// }
/// ```
class CNTabBarNative {
  static const MethodChannel _channel = MethodChannel('cn_native_tab_bar');

  static bool _isEnabled = false;
  static void Function(int index)? _onTabSelected;
  static void Function(String query)? _onSearchChanged;
  static void Function(String query)? _onSearchSubmitted;
  static VoidCallback? _onSearchCancelled;
  static void Function(bool isActive)? _onSearchActiveChanged;

  /// Enable native tab bar mode
  ///
  /// This will replace your app's root view controller with a native
  /// UITabBarController. Your Flutter content will be displayed within
  /// the selected tab.
  ///
  /// Only works on iOS 26+. On older versions, this is a no-op.
  static Future<void> enable({
    required List<CNTab> tabs,
    int selectedIndex = 0,
    void Function(int index)? onTabSelected,
    void Function(String query)? onSearchChanged,
    void Function(String query)? onSearchSubmitted,
    VoidCallback? onSearchCancelled,
    void Function(bool isActive)? onSearchActiveChanged,
    Color? tintColor,
    Color? unselectedTintColor,
    bool? isDark,
  }) async {
    // Only works on iOS 26+
    if (defaultTargetPlatform != TargetPlatform.iOS ||
        !PlatformVersion.shouldUseNativeGlass) {
      return;
    }

    if (_isEnabled) {
      return;
    }

    // Store callbacks
    _onTabSelected = onTabSelected;
    _onSearchChanged = onSearchChanged;
    _onSearchSubmitted = onSearchSubmitted;
    _onSearchCancelled = onSearchCancelled;
    _onSearchActiveChanged = onSearchActiveChanged;

    // Setup method call handler for callbacks
    _channel.setMethodCallHandler(_handleMethodCall);

    // Enable native tab bar
    await _channel.invokeMethod('enable', {
      'tabs': tabs
          .map(
            (tab) => {
              'title': tab.title,
              'sfSymbol': tab.sfSymbol?.name,
              'activeSfSymbol': tab.activeSfSymbol?.name,
              'isSearch': tab.isSearchTab,
              'badgeCount': tab.badgeCount,
            },
          )
          .toList(),
      'selectedIndex': selectedIndex,
      'isDark': isDark ?? false,
      if (tintColor != null) 'tint': tintColor.toARGB32(),
      if (unselectedTintColor != null)
        'unselectedTint': unselectedTintColor.toARGB32(),
    });

    _isEnabled = true;
  }

  /// Disable native tab bar and return to Flutter-only mode
  static Future<void> disable() async {
    if (!_isEnabled) {
      return;
    }

    await _channel.invokeMethod('disable');
    _channel.setMethodCallHandler(null);
    _isEnabled = false;
    _onTabSelected = null;
    _onSearchChanged = null;
    _onSearchSubmitted = null;
    _onSearchCancelled = null;
    _onSearchActiveChanged = null;
  }

  /// Set the selected tab index
  static Future<void> setSelectedIndex(int index) async {
    if (!_isEnabled) return;
    await _channel.invokeMethod('setSelectedIndex', {'index': index});
  }

  /// Activate the search (go to search tab and focus search bar)
  static Future<void> activateSearch() async {
    if (!_isEnabled) return;
    await _channel.invokeMethod('activateSearch');
  }

  /// Deactivate the search
  static Future<void> deactivateSearch() async {
    if (!_isEnabled) return;
    await _channel.invokeMethod('deactivateSearch');
  }

  /// Set the search text programmatically
  static Future<void> setSearchText(String text) async {
    if (!_isEnabled) return;
    await _channel.invokeMethod('setSearchText', {'text': text});
  }

  /// Update badge counts for tabs
  static Future<void> setBadgeCounts(List<int?> badgeCounts) async {
    if (!_isEnabled) return;
    await _channel.invokeMethod('setBadgeCounts', {'badgeCounts': badgeCounts});
  }

  /// Update style (tint colors)
  static Future<void> setStyle({
    Color? tintColor,
    Color? unselectedTintColor,
  }) async {
    if (!_isEnabled) return;
    await _channel.invokeMethod('setStyle', {
      if (tintColor != null) 'tint': tintColor.toARGB32(),
      if (unselectedTintColor != null)
        'unselectedTint': unselectedTintColor.toARGB32(),
    });
  }

  /// Update brightness (dark mode)
  static Future<void> setBrightness({required bool isDark}) async {
    if (!_isEnabled) return;
    await _channel.invokeMethod('setBrightness', {'isDark': isDark});
  }

  /// Check if native tab bar is currently enabled
  static Future<bool> checkIsEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isEnabled');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Whether the native tab bar is enabled
  static bool get isEnabled => _isEnabled;

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onTabSelected':
        final index = call.arguments['index'] as int;
        _onTabSelected?.call(index);
        break;
      case 'onSearchChanged':
        final query = call.arguments['query'] as String;
        _onSearchChanged?.call(query);
        break;
      case 'onSearchSubmitted':
        final query = call.arguments['query'] as String;
        _onSearchSubmitted?.call(query);
        break;
      case 'onSearchCancelled':
        _onSearchCancelled?.call();
        break;
      case 'onSearchActiveChanged':
        final isActive = call.arguments['isActive'] as bool;
        _onSearchActiveChanged?.call(isActive);
        break;
      case 'onTabAppeared':
        // Tab appeared - could be used for analytics
        break;
    }
  }
}

/// Configuration for a native tab in [CNTabBarNative].
///
/// Each tab can have a title, SF Symbol icon, and optionally be marked as a search tab.
///
/// Example:
/// ```dart
/// CNTab(
///   title: 'Home',
///   sfSymbol: CNSymbol('house.fill'),
/// )
/// ```
class CNTab {
  /// The title of the tab (shown below icon)
  final String title;

  /// SF Symbol for the tab icon (unselected state)
  final CNSymbol? sfSymbol;

  /// SF Symbol for the tab icon (selected state)
  /// If not provided, uses [sfSymbol]
  final CNSymbol? activeSfSymbol;

  /// Whether this tab is a search tab
  ///
  /// Only one tab should be marked as a search tab.
  /// When selected, the native iOS 26 search bar will appear with
  /// the liquid glass morphing effect.
  final bool isSearchTab;

  /// Badge count to display on the tab
  final int? badgeCount;

  /// Creates a tab configuration for [CNTabBarNative].
  const CNTab({
    required this.title,
    this.sfSymbol,
    this.activeSfSymbol,
    this.isSearchTab = false,
    this.badgeCount,
  });
}
