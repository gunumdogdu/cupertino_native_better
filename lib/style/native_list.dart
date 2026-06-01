import 'sf_symbol.dart';

/// A single row in a [CNNativeList].
///
/// Rows are rendered **natively** (so the list is a real `UIScrollView` that
/// can drive the iOS 26 tab bar minimize). They are configured from Dart data,
/// but are limited to this model — not arbitrary Flutter widgets.
class CNListItem {
  /// Primary text.
  final String title;

  /// Optional secondary (subtitle) text.
  final String? subtitle;

  /// Optional leading SF Symbol shown in a rounded container.
  final CNSymbol? leadingSymbol;

  /// Whether to show a trailing chevron.
  final bool showChevron;

  /// Creates a row for a [CNNativeList].
  const CNListItem({
    required this.title,
    this.subtitle,
    this.leadingSymbol,
    this.showChevron = false,
  });
}

/// A natively-rendered, scrollable list used as the content of a tab.
///
/// Attach one to a `CNTab` (via `nativeList:`) when that tab should drive the
/// iOS 26 minimize-on-scroll behavior — iOS only minimizes the tab bar when it
/// observes a real native scroll view, which a Flutter list cannot provide.
class CNNativeList {
  /// The rows to render, top to bottom.
  final List<CNListItem> items;

  /// Creates a native list from [items].
  const CNNativeList({required this.items});
}
