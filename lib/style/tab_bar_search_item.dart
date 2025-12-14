import 'package:flutter/widgets.dart';
import 'sf_symbol.dart';

/// Configuration for a search tab in [CNTabBar].
///
/// When provided to [CNTabBar.searchItem], this creates a dedicated search tab
/// that follows iOS 26's native behavior:
/// - Appears as a separate floating circular button on the right
/// - Expands into a full search bar when tapped
/// - Collapses other tabs to icon-only mode during search
///
/// Example:
/// ```dart
/// CNTabBar(
///   items: [...],
///   searchItem: CNTabBarSearchItem(
///     placeholder: 'Find customer',
///     onSearchChanged: (query) => filterResults(query),
///     onSearchSubmit: (query) => executeSearch(query),
///     style: CNTabBarSearchStyle(
///       iconSize: 22,
///       activeIconColor: Colors.blue,
///       searchBarPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
///     ),
///   ),
/// )
/// ```
@immutable
class CNTabBarSearchItem {
  /// Creates a search tab configuration.
  const CNTabBarSearchItem({
    this.icon,
    this.activeIcon,
    this.label = 'Search',
    this.placeholder = 'Search',
    this.onSearchChanged,
    this.onSearchSubmit,
    this.onSearchActiveChanged,
    this.automaticallyActivatesSearch = true,
    this.style = const CNTabBarSearchStyle(),
  });

  /// The icon to display in the search tab button (collapsed state).
  ///
  /// Defaults to the system magnifyingglass SF Symbol if not provided.
  final CNSymbol? icon;

  /// The icon to display when search is active.
  ///
  /// If not provided, uses [icon].
  final CNSymbol? activeIcon;

  /// Label shown under the search icon button.
  ///
  /// Defaults to 'Search'. This matches the style of tab labels.
  final String label;

  /// Placeholder text shown in the search bar when empty.
  ///
  /// Defaults to 'Search'.
  final String placeholder;

  /// Called when the search text changes.
  ///
  /// Use this for live filtering as the user types.
  final ValueChanged<String>? onSearchChanged;

  /// Called when the user submits the search (presses enter/search).
  final ValueChanged<String>? onSearchSubmit;

  /// Called when the search bar expands or collapses.
  ///
  /// - `true`: Search bar is expanded and active
  /// - `false`: Search bar is collapsed back to button
  final ValueChanged<bool>? onSearchActiveChanged;

  /// Whether tapping the search tab automatically activates the search field.
  ///
  /// When `true` (default), tapping the search tab immediately opens the
  /// keyboard and focuses the search field. When `false`, the tab expands
  /// but the keyboard doesn't appear until the user taps the search field.
  ///
  /// This mirrors `UISearchTab.automaticallyActivatesSearch` in UIKit.
  final bool automaticallyActivatesSearch;

  /// Visual styling options for the search tab.
  final CNTabBarSearchStyle style;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CNTabBarSearchItem &&
        other.icon == icon &&
        other.activeIcon == activeIcon &&
        other.label == label &&
        other.placeholder == placeholder &&
        other.automaticallyActivatesSearch == automaticallyActivatesSearch &&
        other.style == style;
  }

  @override
  int get hashCode => Object.hash(
    icon,
    activeIcon,
    label,
    placeholder,
    automaticallyActivatesSearch,
    style,
  );
}

/// Visual styling options for the search tab in [CNTabBar].
///
/// Use this to customize colors, sizes, padding, and animations.
@immutable
class CNTabBarSearchStyle {
  /// Creates search tab styling configuration.
  const CNTabBarSearchStyle({
    this.iconSize,
    this.iconColor,
    this.activeIconColor,
    this.searchBarBackgroundColor,
    this.searchBarTextColor,
    this.searchBarPlaceholderColor,
    this.clearButtonColor,
    this.buttonSize,
    this.searchBarHeight,
    this.searchBarBorderRadius,
    this.searchBarPadding,
    this.contentPadding,
    this.spacing,
    this.animationDuration,
    this.showClearButton = true,
    this.collapsedTabIcon,
  });

  /// Size of the search icon in the collapsed button.
  ///
  /// Defaults to 20.
  final double? iconSize;

  /// Color of the search icon when collapsed/inactive.
  final Color? iconColor;

  /// Color of the search icon when expanded/active.
  final Color? activeIconColor;

  /// Background color of the expanded search bar.
  ///
  /// On iOS 26+, this is applied with glass effect.
  final Color? searchBarBackgroundColor;

  /// Text color inside the search bar.
  final Color? searchBarTextColor;

  /// Placeholder text color.
  final Color? searchBarPlaceholderColor;

  /// Color of the clear (X) button.
  final Color? clearButtonColor;

  /// Size of the collapsed search button (width and height).
  ///
  /// Defaults to 44.
  final double? buttonSize;

  /// Height of the expanded search bar.
  ///
  /// Defaults to 44.
  final double? searchBarHeight;

  /// Border radius of the search bar.
  ///
  /// Defaults to capsule shape (height / 2).
  final double? searchBarBorderRadius;

  /// Internal padding of the search bar content.
  ///
  /// Defaults to EdgeInsets.symmetric(horizontal: 12, vertical: 10).
  final EdgeInsets? searchBarPadding;

  /// Padding around the entire search tab area.
  ///
  /// Defaults to EdgeInsets.symmetric(horizontal: 16, vertical: 8).
  final EdgeInsets? contentPadding;

  /// Spacing between the collapsed tab indicator and search bar.
  ///
  /// Defaults to 12.
  final double? spacing;

  /// Duration of expand/collapse animation.
  ///
  /// Defaults to 400ms with spring physics.
  final Duration? animationDuration;

  /// Whether to show the clear button when text is entered.
  ///
  /// Defaults to true.
  final bool showClearButton;

  /// Custom icon for the collapsed tab indicator (shown when search is active).
  ///
  /// If not provided, uses the first tab's icon.
  final CNSymbol? collapsedTabIcon;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CNTabBarSearchStyle &&
        other.iconSize == iconSize &&
        other.iconColor == iconColor &&
        other.activeIconColor == activeIconColor &&
        other.searchBarBackgroundColor == searchBarBackgroundColor &&
        other.searchBarTextColor == searchBarTextColor &&
        other.searchBarPlaceholderColor == searchBarPlaceholderColor &&
        other.clearButtonColor == clearButtonColor &&
        other.buttonSize == buttonSize &&
        other.searchBarHeight == searchBarHeight &&
        other.searchBarBorderRadius == searchBarBorderRadius &&
        other.searchBarPadding == searchBarPadding &&
        other.contentPadding == contentPadding &&
        other.spacing == spacing &&
        other.animationDuration == animationDuration &&
        other.showClearButton == showClearButton &&
        other.collapsedTabIcon == collapsedTabIcon;
  }

  @override
  int get hashCode => Object.hashAll([
    iconSize,
    iconColor,
    activeIconColor,
    searchBarBackgroundColor,
    searchBarTextColor,
    searchBarPlaceholderColor,
    clearButtonColor,
    buttonSize,
    searchBarHeight,
    searchBarBorderRadius,
    searchBarPadding,
    contentPadding,
    spacing,
    animationDuration,
    showClearButton,
    collapsedTabIcon,
  ]);
}

/// Controller for programmatically managing the search tab state.
///
/// Use this to:
/// - Activate/deactivate search programmatically
/// - Set or clear the search text
/// - Listen to search state changes
///
/// Example:
/// ```dart
/// final searchController = CNTabBarSearchController();
///
/// // Activate search programmatically
/// searchController.activateSearch();
///
/// // Set search text
/// searchController.text = 'query';
///
/// // Listen to changes
/// searchController.addListener(() {
///   print('Search active: ${searchController.isActive}');
///   print('Search text: ${searchController.text}');
/// });
/// ```
class CNTabBarSearchController extends ChangeNotifier {
  String _text = '';
  bool _isActive = false;

  /// The current search text.
  String get text => _text;
  set text(String value) {
    if (_text != value) {
      _text = value;
      notifyListeners();
    }
  }

  /// Whether the search bar is currently expanded/active.
  bool get isActive => _isActive;

  /// Activates the search bar (expands it and shows keyboard).
  void activateSearch() {
    if (!_isActive) {
      _isActive = true;
      notifyListeners();
    }
  }

  /// Deactivates the search bar (collapses it back to button).
  void deactivateSearch() {
    if (_isActive) {
      _isActive = false;
      notifyListeners();
    }
  }

  /// Clears the search text and optionally deactivates search.
  void clear({bool deactivate = false}) {
    _text = '';
    if (deactivate) {
      _isActive = false;
    }
    notifyListeners();
  }

  /// Internal method to update state from native side.
  /// @nodoc
  void updateFromNative({String? text, bool? isActive}) {
    bool changed = false;
    if (text != null && _text != text) {
      _text = text;
      changed = true;
    }
    if (isActive != null && _isActive != isActive) {
      _isActive = isActive;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }
}
