import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../style/native_list.dart';
import '../style/sf_symbol.dart';
import '../utils/list_item_encoder.dart';

/// A resting height of a [CNNativeSheet].
///
/// Maps to `UISheetPresentationController.Detent`.
@immutable
class CNSheetDetent {
  const CNSheetDetent._(this._kind, [this._value = 0]);

  /// About half the screen.
  static const medium = CNSheetDetent._('medium');

  /// Nearly the full screen.
  static const large = CNSheetDetent._('large');

  /// Only the tab bar: a sheet with more than one [CNSheetPage] shrinks to
  /// its tab bar, as Find My's does. Approaching this height the page fades
  /// out and the tab bar settles in the middle of the sheet; on iOS 26 and
  /// later the sheet is drawn as a glass capsule here. A single-page sheet,
  /// which has no tab bar, shows only the top of its page.
  static const collapsed = CNSheetDetent._('collapsed');

  /// A fixed height in points, such as a small sheet that shows only its
  /// title and tab bar.
  const CNSheetDetent.height(double points) : this._('height', points);

  /// A fraction of the largest height the sheet can take, from 0 to 1.
  const CNSheetDetent.fraction(double fraction) : this._('fraction', fraction);

  final String _kind;
  final double _value;

  Map<String, Object> _toMap() => {'kind': _kind, 'value': _value};

  @override
  bool operator ==(Object other) =>
      other is CNSheetDetent && other._kind == _kind && other._value == _value;

  @override
  int get hashCode => Object.hash(_kind, _value);
}

/// A button in a [CNSheetPage]'s navigation bar, at the trailing end of the
/// title.
class CNSheetButton {
  /// Identifies the button in [CNNativeSheet.show]'s `onButtonTap`.
  final String id;

  /// The SF Symbol drawn in the button.
  final CNSymbol? sfSymbol;

  /// The button's text when it has no [sfSymbol], and its VoiceOver label.
  final String? label;

  /// Creates a navigation bar button.
  const CNSheetButton({required this.id, this.sfSymbol, this.label})
    : assert(sfSymbol != null || label != null);
}

/// A page of a [CNNativeSheet]: a title, navigation bar buttons and a native
/// list.
///
/// With more than one page, the sheet shows a tab bar inside it, with a tab
/// per page labeled with [title] and [sfSymbol].
class CNSheetPage {
  /// The page's title, drawn large next to [buttons], and its tab's label.
  final String title;

  /// The SF Symbol of the page's tab.
  final CNSymbol? sfSymbol;

  /// The SF Symbol of the page's tab while it is selected. Defaults to
  /// [sfSymbol].
  final CNSymbol? activeSfSymbol;

  /// Badge count on the page's tab. Null or 0 shows no badge.
  final int? badgeCount;

  /// Buttons at the trailing end of the title.
  final List<CNSheetButton> buttons;

  /// The page's rows.
  final List<CNListItem> items;

  /// Creates a sheet page.
  const CNSheetPage({
    required this.title,
    this.sfSymbol,
    this.activeSfSymbol,
    this.badgeCount,
    this.buttons = const [],
    this.items = const [],
  });
}

/// A native iOS sheet over the Flutter app, drawn by UIKit and SwiftUI.
///
/// The sheet rests at one of its [CNSheetDetent]s and can be dragged
/// between them. Above the detent passed as `undimmedDetent`, the Flutter
/// app behind it stays undimmed and keeps receiving touches, so a map
/// behind a small or medium sheet can still be panned. With
/// `dismissible: false` the sheet never closes by dragging, as in apps
/// whose main screen is a map with a sheet over it. On iOS 26 the sheet is
/// Liquid Glass at its partial heights.
///
/// The content is native, built from [CNSheetPage]s: a title, navigation
/// bar buttons and a list of [CNListItem]s per page, and a tab bar inside
/// the sheet when there is more than one page. Flutter widgets cannot be
/// placed inside the sheet: an iOS app has a single Flutter view, which
/// stays behind the sheet.
///
/// iOS 17 and later. Elsewhere [show] does nothing and returns false.
///
/// ```dart
/// await CNNativeSheet.show(
///   pages: [
///     CNSheetPage(
///       title: 'People',
///       sfSymbol: CNSymbol('person.2.fill'),
///       buttons: [CNSheetButton(id: 'add', sfSymbol: CNSymbol('plus'), label: 'Add')],
///       items: [CNListItem(title: 'Ada', subtitle: 'London · Now', trailingText: '2 km')],
///     ),
///     CNSheetPage(title: 'Devices', sfSymbol: CNSymbol('macbook.and.iphone')),
///   ],
///   detents: const [CNSheetDetent.collapsed, CNSheetDetent.medium, CNSheetDetent.large],
///   initialDetent: CNSheetDetent.medium,
///   undimmedDetent: CNSheetDetent.medium,
///   dismissible: false,
///   onButtonTap: (page, id) {},
///   onItemTap: (page, index) {},
/// );
/// ```
class CNNativeSheet {
  CNNativeSheet._();

  static const MethodChannel _channel = MethodChannel('cn_native_sheet');

  static bool _shown = false;
  static List<CNSheetDetent> _detents = const [];
  static void Function(CNSheetDetent detent)? _onDetentChanged;
  static void Function(int page)? _onPageSelected;
  static void Function(int page, int index)? _onItemTap;
  static void Function(int page, String id)? _onButtonTap;
  static VoidCallback? _onDismissed;

  /// Whether the sheet is showing.
  static bool get isShown => _shown;

  /// Presents the sheet with [pages].
  ///
  /// [detents] are the heights the sheet rests at, and [initialDetent] the
  /// one it opens at (the first by default). Up to and including
  /// [undimmedDetent], the app behind the sheet is not dimmed and stays
  /// interactive; null dims it at every height. [dismissible] false keeps
  /// the sheet from being dragged closed. [isDark] sets the sheet's
  /// appearance; null follows the system.
  ///
  /// Returns whether the sheet was shown.
  static Future<bool> show({
    required List<CNSheetPage> pages,
    List<CNSheetDetent> detents = const [
      CNSheetDetent.medium,
      CNSheetDetent.large,
    ],
    CNSheetDetent? initialDetent,
    CNSheetDetent? undimmedDetent,
    bool dismissible = true,
    bool showGrabber = true,
    int selectedPage = 0,
    Color? tintColor,
    bool? isDark,
    void Function(CNSheetDetent detent)? onDetentChanged,
    void Function(int page)? onPageSelected,
    void Function(int page, int index)? onItemTap,
    void Function(int page, String id)? onButtonTap,
    VoidCallback? onDismissed,
  }) async {
    assert(pages.isNotEmpty && detents.isNotEmpty);
    assert(initialDetent == null || detents.contains(initialDetent));
    assert(undimmedDetent == null || detents.contains(undimmedDetent));
    if (defaultTargetPlatform != TargetPlatform.iOS || kIsWeb) return false;

    _detents = List.unmodifiable(detents);
    _onDetentChanged = onDetentChanged;
    _onPageSelected = onPageSelected;
    _onItemTap = onItemTap;
    _onButtonTap = onButtonTap;
    _onDismissed = onDismissed;
    _channel.setMethodCallHandler(_handle);

    final shown = await _channel.invokeMethod<bool>('show', {
      'pages': [for (final p in pages) _pageMap(p)],
      'detents': [for (final d in detents) d._toMap()],
      'initialDetent': initialDetent == null
          ? 0
          : detents.indexOf(initialDetent),
      if (undimmedDetent != null)
        'undimmedDetent': detents.indexOf(undimmedDetent),
      'dismissible': dismissible,
      'showGrabber': showGrabber,
      'selectedPage': selectedPage,
      if (tintColor != null) 'tint': tintColor.toARGB32(),
      if (isDark != null) 'isDark': isDark,
    });
    _shown = shown ?? false;
    if (!_shown) _reset();
    return _shown;
  }

  /// Dismisses the sheet.
  static Future<void> dismiss() async {
    if (!_shown) return;
    await _channel.invokeMethod('dismiss');
    _reset();
  }

  /// Moves the sheet to [detent], one of the detents it was shown with.
  static Future<void> setDetent(CNSheetDetent detent) async {
    if (!_shown) return;
    final index = _detents.indexOf(detent);
    if (index < 0) return;
    await _channel.invokeMethod('setDetent', {'index': index});
  }

  /// Selects the page at [index].
  static Future<void> setSelectedPage(int index) async {
    if (!_shown) return;
    await _channel.invokeMethod('setSelectedPage', {'index': index});
  }

  /// Replaces the rows of the page at [page].
  static Future<void> setItems({
    required int page,
    required List<CNListItem> items,
  }) async {
    if (!_shown) return;
    await _channel.invokeMethod('setItems', {
      'page': page,
      'items': [for (final i in items) _itemMap(i)],
    });
  }

  /// Updates the badge count of each page's tab. Null or 0 clears a badge.
  static Future<void> setBadgeCounts(List<int?> badgeCounts) async {
    if (!_shown) return;
    await _channel.invokeMethod('setBadgeCounts', {'badgeCounts': badgeCounts});
  }

  /// Switches the sheet between light and dark appearance.
  static Future<void> setBrightness({required bool isDark}) async {
    if (!_shown) return;
    await _channel.invokeMethod('setBrightness', {'isDark': isDark});
  }

  static Map<String, Object?> _pageMap(CNSheetPage p) => {
    'title': p.title,
    if (p.sfSymbol != null) 'sfSymbol': p.sfSymbol!.name,
    if (p.activeSfSymbol != null) 'activeSfSymbol': p.activeSfSymbol!.name,
    if (p.badgeCount != null) 'badgeCount': p.badgeCount,
    'buttons': [
      for (final b in p.buttons)
        {
          'id': b.id,
          if (b.sfSymbol != null) 'sfSymbol': b.sfSymbol!.name,
          if (b.label != null) 'label': b.label,
        },
    ],
    'items': [for (final i in p.items) _itemMap(i)],
  };

  static Map<String, Object?> _itemMap(CNListItem i) => encodeListItem(i);

  static Future<dynamic> _handle(MethodCall call) async {
    final args = call.arguments;
    switch (call.method) {
      case 'onDetentChanged':
        final index = args['index'] as int;
        if (index >= 0 && index < _detents.length) {
          _onDetentChanged?.call(_detents[index]);
        }
        break;
      case 'onPageSelected':
        _onPageSelected?.call(args['index'] as int);
        break;
      case 'onItemTap':
        _onItemTap?.call(args['page'] as int, args['index'] as int);
        break;
      case 'onButtonTap':
        _onButtonTap?.call(args['page'] as int, args['id'] as String);
        break;
      case 'onDismissed':
        final cb = _onDismissed;
        _reset();
        cb?.call();
        break;
    }
  }

  static void _reset() {
    _shown = false;
    _onDetentChanged = null;
    _onPageSelected = null;
    _onItemTap = null;
    _onButtonTap = null;
    _onDismissed = null;
    _channel.setMethodCallHandler(null);
  }
}
