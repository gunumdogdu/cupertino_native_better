import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../style/sf_symbol.dart';
import '../style/native_list.dart';
import '../utils/version_detector.dart';

/// When the iOS 26 Liquid Glass tab bar collapses to a compact pill.
///
/// Mirrors `UITabBarController.MinimizeBehavior`. Scroll-driven cases
/// ([onScrollDown]/[onScrollUp]) require a tab backed by a [CNNativeList]
/// (iPhone only).
enum CNTabMinimizeBehavior {
  /// System default for the context.
  automatic,

  /// Never minimize; the bar stays fully visible.
  never,

  /// Minimize when scrolling down, expand when scrolling up (iPhone).
  onScrollDown,

  /// Minimize when scrolling up, expand when scrolling down (iPhone).
  onScrollUp,
}

/// The bottom accessory pill that floats above the tab bar and slides inline
/// into it when the bar minimizes (maps to `UITabAccessory`).
class CNTabAccessory {
  /// The text shown in the accessory pill.
  final String text;

  /// Optional leading SF Symbol.
  final CNSymbol? sfSymbol;

  /// Creates a bottom accessory pill.
  const CNTabAccessory({required this.text, this.sfSymbol});
}

/// A configurable native iOS 26 tab bar — the full-screen native take-over
/// (`UITabBarController` via SwiftUI), with **search**, **minimize-on-scroll**,
/// a **bottom accessory**, **native lists**, and optional **Flutter content**
/// per tab — all driven from Dart.
///
/// A tab that wants the minimize behavior must supply a [CNNativeList]
/// (`CNTab(..., nativeList: ...)`) so iOS has a real native scroll view to
/// observe. A tab with no list and no search role hosts your Flutter content
/// (root mode) or a placeholder (modal). iOS 26+ only; a no-op elsewhere.
///
/// ```dart
/// CNTabBarNative.enable(
///   tabs: [
///     CNTab(title: 'Feed', sfSymbol: CNSymbol('list.bullet'),
///           nativeList: CNNativeList(items: myItems)),
///     CNTab(title: 'Profile', sfSymbol: CNSymbol('person')),
///     CNTab(title: 'Search', isSearchTab: true),
///   ],
///   minimizeBehavior: CNTabMinimizeBehavior.onScrollDown,
///   bottomAccessory: CNTabAccessory(text: 'Now playing', sfSymbol: CNSymbol('music.note')),
/// );
/// ```
class CNTabBarNative {
  static const MethodChannel _channel = MethodChannel('cn_native_tab_bar');

  static bool _enabled = false;
  static void Function(int index)? _onTabSelected;
  static void Function(int tabIndex, int itemIndex)? _onListItemTap;
  static void Function(String query)? _onSearchChanged;
  static VoidCallback? _onAccessoryTap;
  static VoidCallback? _onDismissed;

  /// Whether the tab bar is currently presented.
  static bool get isEnabled => _enabled;

  /// Present the native tab bar configured from [tabs].
  static Future<void> enable({
    required List<CNTab> tabs,
    int selectedIndex = 0,
    CNTabMinimizeBehavior minimizeBehavior = CNTabMinimizeBehavior.onScrollDown,
    CNTabAccessory? bottomAccessory,
    Color? tintColor,
    Color? unselectedTintColor,
    bool isDark = false,
    bool asRoot = false,
    bool nativeSearchFilter = true,
    void Function(int index)? onTabSelected,
    void Function(int tabIndex, int itemIndex)? onListItemTap,
    void Function(String query)? onSearchChanged,
    VoidCallback? onAccessoryTap,
    VoidCallback? onDismissed,
  }) async {
    // iOS 26+ only — no-op elsewhere.
    if (defaultTargetPlatform != TargetPlatform.iOS ||
        !PlatformVersion.shouldUseNativeGlass) {
      return;
    }
    if (_enabled) return;

    _onTabSelected = onTabSelected;
    _onListItemTap = onListItemTap;
    _onSearchChanged = onSearchChanged;
    _onAccessoryTap = onAccessoryTap;
    _onDismissed = onDismissed;
    _channel.setMethodCallHandler(_handle);

    await _channel.invokeMethod('enable', {
      'tabs': [
        for (final t in tabs)
          {
            'title': t.title,
            'sfSymbol': t.sfSymbol?.name,
            'isSearch': t.isSearchTab,
            'badgeCount': t.badgeCount,
            if (t.nativeList != null)
              'nativeList': {
                'items': [for (final i in t.nativeList!.items) _itemMap(i)],
              },
          },
      ],
      'selectedIndex': selectedIndex,
      'minimizeBehavior': minimizeBehavior.name,
      if (bottomAccessory != null)
        'bottomAccessory': _accessoryMap(bottomAccessory),
      if (tintColor != null) 'tint': tintColor.toARGB32(),
      if (unselectedTintColor != null)
        'unselectedTint': unselectedTintColor.toARGB32(),
      'isDark': isDark,
      'asRoot': asRoot,
      'nativeSearchFilter': nativeSearchFilter,
    });

    _enabled = true;
  }

  /// Dismiss the native tab bar and return to the Flutter app.
  static Future<void> disable() async {
    if (!_enabled) return;
    await _channel.invokeMethod('disable');
    _reset();
  }

  // ── Mutators: change the bar after enable() ──────────────────────────────

  /// Replace the native list items of the tab at [tabIndex].
  ///
  /// Use this for async/dynamic data and pagination (append by passing the
  /// full new list).
  static Future<void> setItems({
    required int tabIndex,
    required List<CNListItem> items,
  }) async {
    if (!_enabled) return;
    await _channel.invokeMethod('setItems', {
      'tabIndex': tabIndex,
      'items': [for (final i in items) _itemMap(i)],
    });
  }

  /// Programmatically select the tab at [index].
  static Future<void> setSelectedIndex(int index) async {
    if (!_enabled) return;
    await _channel.invokeMethod('setSelectedIndex', {'index': index});
  }

  /// Update badge counts per tab (null/0 clears a badge).
  static Future<void> setBadgeCounts(List<int?> badgeCounts) async {
    if (!_enabled) return;
    await _channel.invokeMethod('setBadgeCounts', {'badgeCounts': badgeCounts});
  }

  /// Show, update, or hide the bottom accessory (pass null to hide).
  ///
  /// Useful to hide the accessory on certain tabs/screens (e.g. call from
  /// [onTabSelected], or before pushing a screen that shouldn't show it).
  static Future<void> setBottomAccessory(CNTabAccessory? accessory) async {
    if (!_enabled) return;
    await _channel.invokeMethod('setBottomAccessory', {
      if (accessory != null) 'bottomAccessory': _accessoryMap(accessory),
    });
  }

  /// Update the selected-tab tint color.
  static Future<void> setStyle({Color? tintColor}) async {
    if (!_enabled) return;
    await _channel.invokeMethod('setStyle', {
      if (tintColor != null) 'tint': tintColor.toARGB32(),
    });
  }

  /// Switch between light and dark appearance.
  static Future<void> setBrightness({required bool isDark}) async {
    if (!_enabled) return;
    await _channel.invokeMethod('setBrightness', {'isDark': isDark});
  }

  /// Change when the tab bar minimizes.
  static Future<void> setMinimizeBehavior(CNTabMinimizeBehavior behavior) async {
    if (!_enabled) return;
    await _channel.invokeMethod('setMinimizeBehavior', {'behavior': behavior.name});
  }

  /// Set the search field's text programmatically.
  static Future<void> setSearchText(String text) async {
    if (!_enabled) return;
    await _channel.invokeMethod('setSearchText', {'text': text});
  }

  /// Select the search tab.
  static Future<void> activateSearch() async {
    if (!_enabled) return;
    await _channel.invokeMethod('activateSearch');
  }

  /// Clear the current search query.
  static Future<void> deactivateSearch() async {
    if (!_enabled) return;
    await _channel.invokeMethod('deactivateSearch');
  }

  static Map<String, dynamic> _itemMap(CNListItem i) => {
        'title': i.title,
        if (i.subtitle != null) 'subtitle': i.subtitle,
        if (i.leadingSymbol != null) 'leadingSfSymbol': i.leadingSymbol!.name,
        'showChevron': i.showChevron,
      };

  static Map<String, dynamic> _accessoryMap(CNTabAccessory a) => {
        'text': a.text,
        if (a.sfSymbol != null) 'sfSymbol': a.sfSymbol!.name,
      };

  static Future<dynamic> _handle(MethodCall call) async {
    final args = call.arguments;
    switch (call.method) {
      case 'onTabSelected':
        _onTabSelected?.call(args['index'] as int);
        break;
      case 'onListItemTap':
        _onListItemTap?.call(args['tabIndex'] as int, args['itemIndex'] as int);
        break;
      case 'onSearchChanged':
        _onSearchChanged?.call(args['query'] as String);
        break;
      case 'onAccessoryTap':
        _onAccessoryTap?.call();
        break;
      case 'onDismissed':
        // The bar was dismissed natively (e.g. the Close button). Notify the
        // app, then reset so a later enable() works again.
        final cb = _onDismissed;
        _reset();
        cb?.call();
        break;
    }
  }

  static void _reset() {
    _enabled = false;
    _onTabSelected = null;
    _onListItemTap = null;
    _onSearchChanged = null;
    _onAccessoryTap = null;
    _onDismissed = null;
    _channel.setMethodCallHandler(null);
  }
}

/// Configuration for a native tab in [CNTabBarNative].
///
/// Each tab can have a title, SF Symbol icon, an optional badge, an optional
/// [CNNativeList] (which makes it drive minimize-on-scroll), and can be marked
/// as the search tab.
class CNTab {
  /// The title of the tab (shown below the icon).
  final String title;

  /// SF Symbol for the tab icon (unselected state).
  final CNSymbol? sfSymbol;

  /// SF Symbol for the tab icon (selected state); falls back to [sfSymbol].
  final CNSymbol? activeSfSymbol;

  /// Whether this tab is the search tab.
  ///
  /// Only one tab should be marked as a search tab. On iOS 26 it renders as the
  /// detached search button that morphs into a search field.
  final bool isSearchTab;

  /// Badge count to display on the tab.
  final int? badgeCount;

  /// Optional native list content for this tab.
  ///
  /// When set, the tab's content is rendered as a native scrollable list,
  /// which is what allows [CNTabBarNative] to drive the iOS 26
  /// minimize-on-scroll behavior.
  final CNNativeList? nativeList;

  /// Creates a tab configuration for [CNTabBarNative].
  const CNTab({
    required this.title,
    this.sfSymbol,
    this.activeSfSymbol,
    this.isSearchTab = false,
    this.badgeCount,
    this.nativeList,
  });
}
