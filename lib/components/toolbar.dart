import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/sf_symbol.dart';
import '../style/tab_bar_search_item.dart' show CNTabBarSearchController;
import '../utils/icon_renderer.dart';
import '../utils/modal_hide_mixin.dart';
import '../utils/optional_method_call.dart';
import '../utils/popup_menu_encoder.dart';
import '../utils/popup_menu_fallback_sheet.dart';
import '../utils/theme_helper.dart';
import '../utils/version_detector.dart';
import 'icon.dart';
import 'popup_menu_button.dart';

/// How the window toolbar of a [CNToolbar] is laid out on macOS.
enum CNToolbarStyle {
  /// The window title and the items share one bar
  /// (`NSWindow.ToolbarStyle.unified`), the standard look of an app window.
  unified,

  /// As [unified] with smaller margins, for a window whose content should
  /// get the focus (`.unifiedCompact`).
  unifiedCompact,

  /// The title above the items, each with its label under its icon
  /// (`.expanded`).
  expanded,
}

/// The look of a [CNToolbarButton].
enum CNToolbarItemStyle {
  /// The standard look of a toolbar item.
  plain,

  /// A tinted item that stands out, for the action people take most, such
  /// as Done or Compose (`NSToolbarItem.Style.prominent` on macOS 26+,
  /// `UIBarButtonItem.Style.prominent` on iOS 26+). It takes
  /// [CNToolbarButton.tint], or the accent colour.
  prominent,
}

/// How the segments of a [CNToolbarSegmentedGroup] are selected.
enum CNToolbarSelectionMode {
  /// One segment is selected at a time.
  selectOne,

  /// Any number of segments are selected; a click toggles one.
  selectAny,

  /// No segment stays selected: each one is a button.
  momentary,
}

/// What a [CNToolbarSegmentedGroup] is for, which macOS 27 shows with a
/// look of its own (`NSToolbarItemGroup.Role`). Earlier systems and iOS
/// draw every group the same.
enum CNToolbarGroupRole {
  /// Let the system decide.
  automatic,

  /// The segments switch between the window's sections, as tabs do.
  tabs,

  /// The segments pick a value, such as a view mode.
  valueSelection,
}

/// A badge on a [CNToolbarButton]: a count, a short text, or a dot.
///
/// `NSItemBadge` on macOS 26+, `UIBarButtonItem.Badge` on iOS 27+ (iOS 26
/// draws bar button badges in navigation bars only). Older systems have no
/// toolbar badges, so there the badge is not shown; the Flutter toolbar of
/// iOS below 26 draws one.
@immutable
class CNToolbarBadge {
  /// A badge showing [count].
  const CNToolbarBadge.count(int this.count) : text = null;

  /// A badge showing a short [text], such as "New".
  const CNToolbarBadge.text(String this.text) : count = null;

  /// A small dot without content.
  const CNToolbarBadge.indicator() : count = null, text = null;

  /// The number shown, for [CNToolbarBadge.count].
  final int? count;

  /// The text shown, for [CNToolbarBadge.text].
  final String? text;

  Map<String, Object?> _encode() {
    if (count != null) return {'type': 'count', 'value': count};
    if (text != null) return {'type': 'text', 'value': text};
    return {'type': 'indicator'};
  }

  @override
  bool operator ==(Object other) =>
      other is CNToolbarBadge && other.count == count && other.text == text;

  @override
  int get hashCode => Object.hash(count, text);
}

/// An item of a [CNToolbar].
///
/// The kinds are [CNToolbarButton], [CNToolbarSegmentedGroup],
/// [CNToolbarMenu], [CNToolbarSearch], [CNToolbarSpace] and the window items
/// [CNToolbarSidebarToggle], [CNToolbarSidebarTrackingSeparator],
/// [CNToolbarInspectorToggle] and [CNToolbarInspectorTrackingSeparator].
sealed class CNToolbarItem {
  const CNToolbarItem({this.id});

  /// Identifies the item across rebuilds, so a change updates the native
  /// item in place. Unique within a toolbar. Without one, an item is known
  /// by its kind and its position among the items of that kind.
  final String? id;

  String get _kind;
}

/// A toolbar button: an icon or a text label, with an optional badge.
///
/// [label] names the button for VoiceOver, for the overflow menu when the
/// window is too narrow, and under the icon in the [CNToolbarStyle.expanded]
/// style. A button without an icon shows the label as its title.
class CNToolbarButton extends CNToolbarItem {
  /// Creates a toolbar button.
  const CNToolbarButton({
    super.id,
    required this.label,
    this.icon,
    this.customIcon,
    this.imageAsset,
    this.tooltip,
    this.enabled = true,
    this.badge,
    this.style = CNToolbarItemStyle.plain,
    this.tint,
    this.isNavigational = false,
    this.centered = false,
    this.onPressed,
  });

  /// The name of the button (see the class documentation).
  final String label;

  /// SF Symbol shown on the button. The toolbar sizes it; its colour and
  /// rendering mode are kept. Priority: [imageAsset] > [customIcon] >
  /// [icon].
  final CNSymbol? icon;

  /// An icon font glyph shown on the button, rendered by Flutter.
  final IconData? customIcon;

  /// An image (PNG, JPG or SVG asset, or bytes) shown on the button. A
  /// single-colour image without a colour takes the toolbar's colour, as a
  /// symbol does.
  final CNImageAsset? imageAsset;

  /// Help text shown when the pointer rests on the button (macOS).
  final String? tooltip;

  /// Whether the button can be pressed.
  final bool enabled;

  /// A badge on the button (macOS 26+, iOS 27+).
  final CNToolbarBadge? badge;

  /// [CNToolbarItemStyle.prominent] tints the button (macOS 26+, iOS 26+).
  final CNToolbarItemStyle style;

  /// Colour of a [CNToolbarItemStyle.prominent] button. On iOS it colours a
  /// plain button's icon and title too.
  final Color? tint;

  /// Whether the button navigates, as Back and Forward do. macOS puts
  /// navigation items at the leading edge, next to the window title.
  final bool isNavigational;

  /// Whether the button sits in the middle of the window toolbar (macOS
  /// 13+).
  final bool centered;

  /// Called when the button is pressed.
  final VoidCallback? onPressed;

  @override
  String get _kind => 'button';
}

/// One segment of a [CNToolbarSegmentedGroup].
@immutable
class CNToolbarSegment {
  /// Creates a segment.
  const CNToolbarSegment({
    required this.label,
    this.icon,
    this.customIcon,
    this.imageAsset,
    this.tooltip,
    this.enabled = true,
  });

  /// The segment's title, or its VoiceOver label when every segment of the
  /// group has an icon.
  final String label;

  /// SF Symbol of the segment. The group shows icons when every segment has
  /// one, else titles.
  final CNSymbol? icon;

  /// An icon font glyph, rendered by Flutter.
  final IconData? customIcon;

  /// An image asset or bytes.
  final CNImageAsset? imageAsset;

  /// Help text shown when the pointer rests on the segment (macOS).
  final String? tooltip;

  /// Whether the segment can be chosen.
  final bool enabled;

  bool get _hasImage =>
      icon != null || customIcon != null || imageAsset != null;
}

/// A group of segments in the toolbar, such as view modes or filters.
///
/// - **macOS**: an `NSToolbarItemGroup` with a segmented control.
/// - **iOS 26+**: [CNToolbarSelectionMode.selectOne] is a
///   `UISegmentedControl`; the other modes are toolbar buttons grouped on
///   one Liquid Glass background, toggles for
///   [CNToolbarSelectionMode.selectAny].
class CNToolbarSegmentedGroup extends CNToolbarItem {
  /// Creates a segmented group.
  const CNToolbarSegmentedGroup({
    super.id,
    required this.label,
    required this.segments,
    this.selectionMode = CNToolbarSelectionMode.selectOne,
    this.selectedIndices = const <int>{},
    this.role = CNToolbarGroupRole.automatic,
    this.enabled = true,
    this.centered = false,
    this.onSelected,
    this.onSelectionChanged,
  });

  /// The name of the group, for VoiceOver and the overflow menu.
  final String label;

  /// The segments, in order.
  final List<CNToolbarSegment> segments;

  /// How segments are selected.
  final CNToolbarSelectionMode selectionMode;

  /// The selected segments. Ignored for [CNToolbarSelectionMode.momentary].
  final Set<int> selectedIndices;

  /// What the group is for (macOS 27).
  final CNToolbarGroupRole role;

  /// Whether the group can be used.
  final bool enabled;

  /// Whether the group sits in the middle of the window toolbar (macOS
  /// 13+).
  final bool centered;

  /// Called with the index of the segment that was clicked, in every mode.
  final ValueChanged<int>? onSelected;

  /// Called with the selection after a click, for
  /// [CNToolbarSelectionMode.selectOne] and
  /// [CNToolbarSelectionMode.selectAny].
  final ValueChanged<Set<int>>? onSelectionChanged;

  @override
  String get _kind => 'segmented';
}

/// A toolbar button that opens a menu.
///
/// The entries are those of [CNPopupMenuButton] (items with icons,
/// subtitles, checkmarks; dividers; submenus). `NSMenuToolbarItem` on
/// macOS, a `UIBarButtonItem` with a `UIMenu` on iOS 26+.
class CNToolbarMenu extends CNToolbarItem {
  /// Creates a menu item.
  const CNToolbarMenu({
    super.id,
    required this.label,
    required this.items,
    this.icon,
    this.customIcon,
    this.imageAsset,
    this.tooltip,
    this.enabled = true,
    this.showsIndicator = true,
    this.centered = false,
    this.onSelected,
  });

  /// The name of the menu button; its title when it has no icon.
  final String label;

  /// The entries of the menu.
  final List<CNPopupMenuEntry> items;

  /// SF Symbol of the button. Priority: [imageAsset] > [customIcon] >
  /// [icon].
  final CNSymbol? icon;

  /// An icon font glyph, rendered by Flutter.
  final IconData? customIcon;

  /// An image asset or bytes.
  final CNImageAsset? imageAsset;

  /// Help text shown when the pointer rests on the button (macOS).
  final String? tooltip;

  /// Whether the menu can be opened.
  final bool enabled;

  /// Whether the button shows a small arrow (macOS).
  final bool showsIndicator;

  /// Whether the button sits in the middle of the window toolbar (macOS
  /// 13+).
  final bool centered;

  /// Called with the path of the chosen entry, as
  /// [CNPopupMenuButton.onPathSelected] reports it: `[2]` is `items[2]`,
  /// `[3, 1]` the second entry of the submenu at `items[3]`.
  final ValueChanged<List<int>>? onSelected;

  @override
  String get _kind => 'menu';
}

/// The search field of a window toolbar (`NSSearchToolbarItem`, macOS).
///
/// It shrinks to a magnifying-glass button when the window is narrow, and
/// opens again when clicked. Esc clears the text, then ends the search and
/// hands the keyboard back to Flutter.
///
/// iOS has no search field in a bottom toolbar: there the item is left out.
/// Use [CNSearchBar] or [CNSearchScaffold] on iOS.
class CNToolbarSearch extends CNToolbarItem {
  /// Creates a toolbar search field.
  const CNToolbarSearch({
    super.id,
    this.label = 'Search',
    this.placeholder,
    this.text,
    this.width,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onActiveChanged,
  });

  /// The name of the field, for VoiceOver and the overflow menu.
  final String label;

  /// Text shown in the empty field; [label] when null.
  final String? placeholder;

  /// Sets the field's text whenever it changes here. Null leaves the text
  /// to the user (and to [controller]).
  final String? text;

  /// The width the field prefers when there is room, in points.
  final double? width;

  /// Starts or ends the search and sets its text from code; it also
  /// follows what the user types.
  final CNTabBarSearchController? controller;

  /// Called on every change of the text.
  final ValueChanged<String>? onChanged;

  /// Called when the user presses Return.
  final ValueChanged<String>? onSubmitted;

  /// Called with true when the field starts editing and false when it
  /// stops.
  final ValueChanged<bool>? onActiveChanged;

  @override
  String get _kind => 'search';
}

/// Empty space between toolbar items.
class CNToolbarSpace extends CNToolbarItem {
  /// Space that takes the room left, pushing the items after it to the
  /// trailing edge.
  const CNToolbarSpace.flexible({super.id}) : flexible = true;

  /// A standard gap. On iOS 26 it also starts a new Liquid Glass group.
  const CNToolbarSpace.fixed({super.id}) : flexible = false;

  /// Whether the space is flexible.
  final bool flexible;

  @override
  String get _kind => flexible ? 'flexibleSpace' : 'fixedSpace';
}

/// The standard button that shows and hides the window's sidebar
/// (`NSToolbarItem.Identifier.toggleSidebar`, macOS).
///
/// Shown only while the window has a sidebar: a split view controller with
/// a sidebar item, such as the one `CNTabBarNative` installs on macOS. It is
/// left out otherwise, and on iOS.
class CNToolbarSidebarToggle extends CNToolbarItem {
  /// Creates the sidebar toggle.
  const CNToolbarSidebarToggle() : super(id: 'sidebarToggle');

  @override
  String get _kind => 'sidebarToggle';
}

/// Lines the items before it up with the window's sidebar, so they sit
/// over the sidebar and the rest over the content
/// (`NSToolbarItem.Identifier.sidebarTrackingSeparator`, macOS).
///
/// Shown only while the window has a sidebar (see [CNToolbarSidebarToggle]).
class CNToolbarSidebarTrackingSeparator extends CNToolbarItem {
  /// Creates the sidebar tracking separator.
  const CNToolbarSidebarTrackingSeparator()
    : super(id: 'sidebarTrackingSeparator');

  @override
  String get _kind => 'sidebarTrackingSeparator';
}

/// The standard button that shows and hides the window's inspector
/// (`NSToolbarItem.Identifier.toggleInspector`, macOS 14+).
///
/// Shown only while the window has an inspector: a split view controller
/// with an inspector item.
class CNToolbarInspectorToggle extends CNToolbarItem {
  /// Creates the inspector toggle.
  const CNToolbarInspectorToggle() : super(id: 'inspectorToggle');

  @override
  String get _kind => 'inspectorToggle';
}

/// Lines the items after it up with the window's inspector
/// (`NSToolbarItem.Identifier.inspectorTrackingSeparator`, macOS 14+).
///
/// Shown only while the window has an inspector.
class CNToolbarInspectorTrackingSeparator extends CNToolbarItem {
  /// Creates the inspector tracking separator.
  const CNToolbarInspectorTrackingSeparator()
    : super(id: 'inspectorTrackingSeparator');

  @override
  String get _kind => 'inspectorTrackingSeparator';
}

/// The Apple toolbar: at the top of the window on macOS, at the bottom of
/// the screen on iPhone and iPad.
///
/// - **macOS** (every supported version): while the widget is mounted, the
///   window gets an `NSToolbar` with these items, in the [style] chosen,
///   and the window title shows [title] and [subtitle]. The widget itself
///   takes no space: put it anywhere in the page. The window keeps its
///   frame, so the Flutter content is resized to the area under the
///   toolbar. When the widget is removed, or its route is covered by
///   another page, the window gets back the toolbar, title and appearance it
///   had. Of several mounted toolbars the most recently shown one owns the
///   window.
/// - **iOS 26+**: a `UIToolbar` drawn where the widget is laid out, 44
///   points high (typically the bottom of a page, inside its safe area),
///   with Liquid Glass and items grouped on shared glass backgrounds.
///   [CNToolbarSearch] and the sidebar and inspector items have no iOS
///   toolbar counterpart and are left out.
/// - **iOS below 26 and other platforms**: a toolbar drawn in Flutter.
///
/// Changes to the items update the native items in place; give items an
/// [CNToolbarItem.id] to keep them when others are added or removed.
///
/// ```dart
/// CNToolbar(
///   title: 'Inbox',
///   subtitle: '3 unread',
///   items: [
///     CNToolbarButton(
///       label: 'New Message',
///       icon: const CNSymbol('square.and.pencil'),
///       style: CNToolbarItemStyle.prominent,
///       onPressed: compose,
///     ),
///     const CNToolbarSpace.flexible(),
///     CNToolbarSearch(onChanged: filter),
///   ],
/// )
/// ```
///
/// VoiceOver reads each item's label; on macOS the items are also reached
/// with Full Keyboard Access.
class CNToolbar extends StatefulWidget {
  /// Creates a toolbar.
  const CNToolbar({
    super.key,
    required this.items,
    this.title,
    this.subtitle,
    this.showsTitle = true,
    this.style = CNToolbarStyle.unified,
    this.tint,
    this.autoHideOnModal = true,
  });

  /// The items, from the leading edge to the trailing one.
  final List<CNToolbarItem> items;

  /// The window title while the toolbar is shown (macOS). Null keeps the
  /// window's own title.
  final String? title;

  /// A second line under the title (macOS 11+), such as a count.
  final String? subtitle;

  /// Whether the window title is shown in the toolbar (macOS).
  final bool showsTitle;

  /// The layout of the window toolbar (macOS).
  final CNToolbarStyle style;

  /// Colour of the items' icons and titles (iOS).
  final Color? tint;

  /// When true (default), the iOS toolbar is replaced with an empty box of
  /// the same size while a modal sheet covers it (Issue #53). Requires
  /// `CNTabBarRouteObserver()` in the app's `navigatorObservers`.
  final bool autoHideOnModal;

  @override
  State<CNToolbar> createState() => _CNToolbarState();
}

/// Height of the iOS toolbar.
const double _kToolbarHeight = 44;

/// Point size icons are drawn at for a toolbar.
const double _kToolbarIconSize = 18;

/// The window toolbar on macOS: one `NSToolbar` for the window, owned by the
/// most recently shown [CNToolbar].
class _MacToolbarWindow {
  _MacToolbarWindow._();

  static final _MacToolbarWindow instance = _MacToolbarWindow._();

  /// Channel owned by `CNToolbarManager` on macOS. It carries no platform
  /// view: the toolbar belongs to the window.
  static const MethodChannel channel = MethodChannel('cn_toolbar');

  /// Shown toolbars, in the order they were shown; the last one owns the
  /// window.
  final List<_CNToolbarState> _shown = <_CNToolbarState>[];
  bool _installed = false;
  int _nextToken = 1;

  int newToken() => _nextToken++;

  _CNToolbarState? get owner => _shown.isEmpty ? null : _shown.last;

  void show(_CNToolbarState state) {
    final wasOwner = owner == state;
    _shown.remove(state);
    _shown.add(state);
    channel.setMethodCallHandler(_handle);
    if (!wasOwner) state._pushToWindow();
  }

  void hide(_CNToolbarState state) {
    final wasOwner = owner == state;
    if (!_shown.remove(state) || !wasOwner) return;
    final next = owner;
    if (next != null) {
      next._pushToWindow();
    } else if (_installed) {
      _installed = false;
      _invoke('removeToolbar');
    }
  }

  void send(_CNToolbarState state, Map<String, Object?> payload) {
    if (owner != state) return;
    _installed = true;
    _invoke('setToolbar', payload);
  }

  void invokeFor(_CNToolbarState state, String method, Object? args) {
    if (owner != state) return;
    _invoke(method, args);
  }

  void _invoke(String method, [Object? args]) {
    channel.invokeMethod<void>(method, args).catchError((Object e) {
      debugPrint('⚠️ [cupertino_native_better] toolbar $method failed: $e');
    });
  }

  Future<Object?> _handle(MethodCall call) async {
    final args = call.arguments;
    final map = args is Map ? args : const <Object?, Object?>{};
    final owner = this.owner;
    // Events from a toolbar a newer owner has replaced go nowhere.
    if (owner == null || map['token'] != owner._token) return null;
    owner._onNativeEvent(call.method, map);
    return null;
  }

  @visibleForTesting
  void debugReset() {
    _shown.clear();
    _installed = false;
    _nextToken = 1;
  }
}

/// Forgets every shown toolbar, so each test starts from a window without
/// one.
@visibleForTesting
void debugResetCNToolbarWindow() => _MacToolbarWindow.instance.debugReset();

/// Key of a rendered custom icon.
typedef _IconKey = ({IconData icon, double size});

class _CNToolbarState extends State<CNToolbar> with ModalHideMixin<CNToolbar> {
  @override
  bool get autoHideOnModal => widget.autoHideOnModal;

  @override
  MethodChannel? get platformViewChannel => _channel;

  /// Identifies this toolbar's events on the window channel (macOS).
  late final int _token = _MacToolbarWindow.instance.newToken();

  /// The iOS platform view's channel.
  MethodChannel? _channel;

  /// The payload the iOS view is created with, once the icons are ready.
  Map<String, Object?>? _creationPayload;
  Map<String, Object?>? _lastSent;

  /// The items by their resolved id, as last sent.
  Map<String, CNToolbarItem> _itemsById = const {};

  final Map<_IconKey, Uint8List?> _iconBytes = <_IconKey, Uint8List?>{};
  final Map<PopupMenuIconKey, Uint8List?> _menuIconBytes =
      <PopupMenuIconKey, Uint8List?>{};
  final Map<String, String> _assetPaths = <String, String>{};

  /// Per search field: the text Dart last sent, and the text the field last
  /// reported. A text goes out once per change made here, never as an echo
  /// of what the user typed, which could undo a keystroke still on its way.
  final Map<String, String> _sentText = <String, String>{};
  final Map<String, String> _nativeText = <String, String>{};

  int _generation = 0;
  ValueListenable<TickerModeData>? _tickerMode;
  bool _shownInWindow = false;
  final Set<CNTabBarSearchController> _controllers =
      <CNTabBarSearchController>{};
  final Map<CNTabBarSearchController, bool> _controllerActive =
      <CNTabBarSearchController, bool>{};

  bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

  bool get _useNativeIOS =>
      defaultTargetPlatform == TargetPlatform.iOS &&
      PlatformVersion.shouldUseNativeControls;

  @override
  void initState() {
    super.initState();
    _listenToControllers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isMac) {
      final notifier = TickerMode.getValuesNotifier(context);
      if (!identical(notifier, _tickerMode)) {
        _tickerMode?.removeListener(_onTickerModeChanged);
        _tickerMode = notifier;
        notifier.addListener(_onTickerModeChanged);
      }
      _onTickerModeChanged();
    }
    _sync();
  }

  @override
  void didUpdateWidget(covariant CNToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listenToControllers();
    _sync();
  }

  @override
  void dispose() {
    _generation++;
    _tickerMode?.removeListener(_onTickerModeChanged);
    for (final c in _controllers) {
      c.removeListener(_onControllerChanged);
    }
    if (_isMac && _shownInWindow) {
      _shownInWindow = false;
      _MacToolbarWindow.instance.hide(this);
    }
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  /// A route covered by an opaque page has its tickers muted: its toolbar
  /// leaves the window until the page above it is popped.
  void _onTickerModeChanged() {
    final visible = _tickerMode?.value.enabled ?? true;
    if (visible == _shownInWindow) return;
    _shownInWindow = visible;
    if (visible) {
      _MacToolbarWindow.instance.show(this);
    } else {
      _MacToolbarWindow.instance.hide(this);
    }
  }

  /// Sends the whole configuration to the window, which has just been
  /// given to this toolbar.
  void _pushToWindow() {
    _lastSent = null;
    // The window builds fresh items for a new owner.
    _sentText.clear();
    _nativeText.clear();
    _sync();
  }

  // MARK: Search controllers

  void _listenToControllers() {
    final wanted = <CNTabBarSearchController>{
      for (final item in widget.items)
        if (item is CNToolbarSearch && item.controller != null)
          item.controller!,
    };
    for (final c in _controllers.difference(wanted)) {
      c.removeListener(_onControllerChanged);
      _controllerActive.remove(c);
    }
    for (final c in wanted.difference(_controllers)) {
      c.addListener(_onControllerChanged);
      _controllerActive[c] = c.isActive;
    }
    _controllers
      ..clear()
      ..addAll(wanted);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final ids = _resolvedIds(widget.items);
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (item is! CNToolbarSearch) continue;
      final controller = item.controller;
      if (controller == null) continue;
      final wasActive = _controllerActive[controller] ?? false;
      if (controller.isActive != wasActive) {
        _controllerActive[controller] = controller.isActive;
        if (_isMac && controller.isActive) {
          _MacToolbarWindow.instance.invokeFor(this, 'focusSearch', {
            'id': ids[i],
          });
        } else if (_isMac) {
          _MacToolbarWindow.instance.invokeFor(this, 'endSearch', {
            'id': ids[i],
          });
        }
      }
    }
    // The text goes with the configuration.
    _sync();
  }

  // MARK: Payload

  /// The id of each item: its own, or its kind and its index among the
  /// items of that kind.
  static List<String> _resolvedIds(List<CNToolbarItem> items) {
    final counts = <String, int>{};
    return [
      for (final item in items)
        item.id ??
            () {
              final n = counts[item._kind] ?? 0;
              counts[item._kind] = n + 1;
              return '${item._kind}#$n';
            }(),
    ];
  }

  /// Renders custom icons and resolves asset paths not seen yet. Returns
  /// without awaiting anything when everything is ready.
  Future<void> _prepareResources() async {
    final pending = <Future<void>>[];
    void icon(IconData? data) {
      if (data == null) return;
      final key = (icon: data, size: _kToolbarIconSize);
      if (_iconBytes.containsKey(key)) return;
      _iconBytes[key] = null;
      pending.add(
        iconDataToImageBytes(
          data,
          size: _kToolbarIconSize,
        ).then((bytes) => _iconBytes[key] = bytes),
      );
    }

    void asset(CNImageAsset? a) {
      if (a == null || a.imageData != null || a.assetPath.isEmpty) return;
      if (_assetPaths.containsKey(a.assetPath)) return;
      _assetPaths[a.assetPath] = a.assetPath;
      pending.add(
        resolveAssetPathForPixelRatio(
          a.assetPath,
        ).then((path) => _assetPaths[a.assetPath] = path),
      );
    }

    for (final item in widget.items) {
      switch (item) {
        case CNToolbarButton():
          icon(item.customIcon);
          asset(item.imageAsset);
        case CNToolbarMenu():
          icon(item.customIcon);
          asset(item.imageAsset);
          for (final e in walkPopupMenuEntries(item.items)) {
            final key = popupMenuIconKey(e);
            if (key != null && !_menuIconBytes.containsKey(key)) {
              _menuIconBytes[key] = null;
              pending.add(
                iconDataToImageBytes(
                  key.icon,
                  size: key.size,
                  color: key.color,
                ).then((bytes) => _menuIconBytes[key] = bytes),
              );
            }
            asset(popupMenuEntryVisual(e)?.imageAsset);
          }
        case CNToolbarSegmentedGroup():
          for (final s in item.segments) {
            icon(s.customIcon);
            asset(s.imageAsset);
          }
        default:
          break;
      }
    }
    if (pending.isNotEmpty) await Future.wait(pending);
  }

  Map<String, Object?>? _encodeImage(
    BuildContext context, {
    CNSymbol? icon,
    IconData? customIcon,
    CNImageAsset? imageAsset,
  }) {
    int? color(Color? c) => resolveColorToArgb(c, context);
    if (imageAsset != null) {
      final path = _assetPaths[imageAsset.assetPath] ?? imageAsset.assetPath;
      return {
        'assetPath': path,
        'imageData': imageAsset.imageData,
        'format':
            imageAsset.imageFormat ??
            detectImageFormat(path, imageAsset.imageData),
        'color': color(imageAsset.color),
      };
    }
    if (customIcon != null) {
      final bytes = _iconBytes[(icon: customIcon, size: _kToolbarIconSize)];
      if (bytes != null) {
        return {'customIconBytes': bytes, 'color': color(icon?.color)};
      }
    }
    if (icon != null) {
      return {
        'symbol': icon.name,
        'color': color(icon.color),
        'mode': icon.mode?.name,
        'palette': icon.paletteColors?.map(color).toList(),
      };
    }
    return null;
  }

  Map<String, Object?> _payload(BuildContext context) {
    final ids = _resolvedIds(widget.items);
    final byId = <String, CNToolbarItem>{};
    final items = <Map<String, Object?>>[];
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      final id = ids[i];
      assert(!byId.containsKey(id), 'Two toolbar items have the id "$id".');
      byId[id] = item;
      final map = <String, Object?>{'kind': item._kind, 'id': id};
      switch (item) {
        case CNToolbarButton():
          map.addAll({
            'label': item.label,
            'image': _encodeImage(
              context,
              icon: item.icon,
              customIcon: item.customIcon,
              imageAsset: item.imageAsset,
            ),
            'tooltip': item.tooltip,
            'enabled': item.enabled,
            'badge': item.badge?._encode(),
            'style': item.style.name,
            'tint': resolveColorToArgb(item.tint, context),
            'navigational': item.isNavigational,
            'centered': item.centered,
          });
        case CNToolbarSegmentedGroup():
          map.addAll({
            'label': item.label,
            'segments': [
              for (final s in item.segments)
                {
                  'label': s.label,
                  'image': _encodeImage(
                    context,
                    icon: s.icon,
                    customIcon: s.customIcon,
                    imageAsset: s.imageAsset,
                  ),
                  'tooltip': s.tooltip,
                  'enabled': s.enabled,
                },
            ],
            'usesImages':
                item.segments.isNotEmpty &&
                item.segments.every((s) => s._hasImage),
            'selectionMode': item.selectionMode.name,
            'role': item.role.name,
            'selected': item.selectionMode == CNToolbarSelectionMode.momentary
                ? const <int>[]
                : (item.selectedIndices
                      .where((i) => i >= 0 && i < item.segments.length)
                      .toList()
                    ..sort()),
            'enabled': item.enabled,
            'centered': item.centered,
          });
        case CNToolbarMenu():
          final assetPaths = Map<CNPopupMenuEntry, String>.identity();
          for (final e in walkPopupMenuEntries(item.items)) {
            final a = popupMenuEntryVisual(e)?.imageAsset;
            final resolved = a == null ? null : _assetPaths[a.assetPath];
            if (resolved != null) assetPaths[e] = resolved;
          }
          map.addAll({
            'label': item.label,
            'image': _encodeImage(
              context,
              icon: item.icon,
              customIcon: item.customIcon,
              imageAsset: item.imageAsset,
            ),
            'tooltip': item.tooltip,
            'enabled': item.enabled,
            'showsIndicator': item.showsIndicator,
            'centered': item.centered,
            'menu': encodePopupMenuEntries(
              item.items,
              resolveColor: (c) => resolveColorToArgb(c, context),
              customIconBytes: _menuIconBytes,
              assetPaths: assetPaths,
            ),
          });
        case CNToolbarSearch():
          final desired = item.controller?.text ?? item.text;
          String? text;
          // A field starts empty.
          if (desired != null &&
              desired != (_sentText[id] ?? '') &&
              desired != (_nativeText[id] ?? '')) {
            text = desired;
          }
          if (desired != null) _sentText[id] = desired;
          map.addAll({
            'label': item.label,
            'placeholder': item.placeholder ?? item.label,
            // Null leaves the field's text as it is.
            'text': text,
            'width': item.width,
          });
        case CNToolbarSpace():
        case CNToolbarSidebarToggle():
        case CNToolbarSidebarTrackingSeparator():
        case CNToolbarInspectorToggle():
        case CNToolbarInspectorTrackingSeparator():
          break;
      }
      items.add(map);
    }
    _itemsById = byId;
    return <String, Object?>{
      if (_isMac) 'token': _token,
      'items': items,
      'title': widget.title,
      'subtitle': widget.subtitle,
      'showsTitle': widget.showsTitle,
      'style': widget.style.name,
      // macOS: the window follows a theme that sets its own brightness; a
      // theme that follows the system leaves the window's appearance alone.
      'isDark': _isMac
          ? ThemeHelper.themeIsDark(context)
          : ThemeHelper.isDark(context),
      'tint': resolveColorToArgb(widget.tint, context),
    };
  }

  /// Builds the configuration and sends it where it changed: to the window
  /// on macOS, to the platform view on iOS.
  Future<void> _sync() async {
    if (!_isMac && !_useNativeIOS) {
      return;
    }
    final generation = ++_generation;
    await _prepareResources();
    if (!mounted || generation != _generation) return;
    // Only the toolbar that owns the window sends; a new owner sends all.
    if (_isMac &&
        (!_shownInWindow || _MacToolbarWindow.instance.owner != this)) {
      return;
    }
    final payload = _payload(context);
    if (_lastSent != null && _deepEquals(payload, _lastSent)) return;
    if (_isMac) {
      _lastSent = payload;
      _MacToolbarWindow.instance.send(this, payload);
      return;
    }
    final channel = _channel;
    if (_creationPayload == null || channel == null) {
      if (_creationPayload == null) {
        setState(() => _creationPayload = payload);
      }
      return;
    }
    _lastSent = payload;
    channel.invokeOptionalMethod('setItems', payload).catchError((_) {});
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('CNToolbar_$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      _onNativeEvent(call.method, args is Map ? args : const {});
      return null;
    });
    _lastSent = _creationPayload;
    // The view may have been created from an older configuration.
    _sync();
  }

  // MARK: Events

  void _onNativeEvent(String method, Map<Object?, Object?> args) {
    if (!mounted) return;
    final id = args['id'];
    final item = _itemsById[id];
    if (item == null) return;
    switch (method) {
      case 'onButtonPressed':
        if (item is CNToolbarButton && item.enabled) item.onPressed?.call();
      case 'onSegmentSelected':
        if (item is! CNToolbarSegmentedGroup) return;
        final index = (args['index'] as num?)?.toInt();
        if (index == null || index < 0 || index >= item.segments.length) {
          return;
        }
        item.onSelected?.call(index);
        if (item.selectionMode != CNToolbarSelectionMode.momentary) {
          final selected = (args['selected'] as List?)
              ?.whereType<num>()
              .map((n) => n.toInt())
              .toSet();
          if (selected != null) item.onSelectionChanged?.call(selected);
        }
      case 'onMenuSelected':
        if (item is! CNToolbarMenu) return;
        final path = (args['path'] as List?)
            ?.whereType<num>()
            .map((n) => n.toInt())
            .toList();
        if (path != null && path.isNotEmpty) {
          item.onSelected?.call(List<int>.unmodifiable(path));
        }
      case 'onSearchChanged':
        if (item is! CNToolbarSearch) return;
        final text = args['text'] as String? ?? '';
        _nativeText[id as String] = text;
        item.controller?.updateFromNative(text: text);
        item.onChanged?.call(text);
      case 'onSearchSubmitted':
        if (item is! CNToolbarSearch) return;
        item.onSubmitted?.call(args['text'] as String? ?? '');
      case 'onSearchActiveChanged':
        if (item is! CNToolbarSearch) return;
        final active = args['active'] == true;
        final controller = item.controller;
        if (controller != null) {
          _controllerActive[controller] = active;
          controller.updateFromNative(isActive: active);
        }
        item.onActiveChanged?.call(active);
    }
  }

  // MARK: Build

  @override
  Widget build(BuildContext context) {
    // The window toolbar takes no room in the page.
    if (_isMac) return const SizedBox.shrink();
    if (!_useNativeIOS) {
      return _CNToolbarFallback(
        items: widget.items,
        ids: _resolvedIds(widget.items),
        tint: widget.tint,
        onEvent: (method, args) {
          _itemsById = {
            for (final (i, id) in _resolvedIds(widget.items).indexed)
              id: widget.items[i],
          };
          _onNativeEvent(method, args);
        },
      );
    }
    final hidden = maybeHiddenPlaceholder(height: _kToolbarHeight);
    final payload = _creationPayload;
    if (hidden != null || payload == null) {
      return const SizedBox(height: _kToolbarHeight, width: double.infinity);
    }
    return wrapWithModalInteractionGuard(
      SizedBox(
        height: _kToolbarHeight,
        width: double.infinity,
        child: UiKitView(
          viewType: 'CNToolbar',
          creationParams: payload,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
      ),
    );
  }
}

/// Whether two payloads hold the same values, comparing lists, maps and
/// byte arrays by content.
bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// The id [CNToolbar] gives each of [items] in its payload and its events:
/// the item's own [CNToolbarItem.id], or its kind and its index among the
/// items of that kind (`button#0`, `menu#1`).
@visibleForTesting
List<String> debugResolveToolbarItemIds(List<CNToolbarItem> items) =>
    _CNToolbarState._resolvedIds(items);

/// The toolbar drawn in Flutter for iOS below 26 and for platforms without
/// a native one, laid out like `UIToolbar`.
class _CNToolbarFallback extends StatelessWidget {
  const _CNToolbarFallback({
    required this.items,
    required this.ids,
    required this.tint,
    required this.onEvent,
  });

  final List<CNToolbarItem> items;
  final List<String> ids;
  final Color? tint;
  final void Function(String method, Map<Object?, Object?> args) onEvent;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final color = tint ?? theme.primaryColor;
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final widget = _item(context, items[i], ids[i], color);
      if (widget != null) children.add(widget);
    }
    return Container(
      height: _kToolbarHeight,
      decoration: BoxDecoration(
        color: theme.barBackgroundColor,
        border: const Border(
          top: BorderSide(color: Color(0x4D000000), width: 0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: children),
    );
  }

  Widget _icon(
    CNSymbol? icon,
    IconData? customIcon,
    CNImageAsset? imageAsset,
    Color color,
  ) {
    return CNIcon(
      symbol: icon,
      customIcon: customIcon,
      imageAsset: imageAsset,
      size: 22,
      color: icon?.color ?? color,
    );
  }

  Widget _button({
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
    required Widget child,
    bool prominent = false,
    bool selected = false,
    Color? color,
  }) {
    final button = prominent
        ? CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(34, 34),
            borderRadius: BorderRadius.circular(17),
            onPressed: enabled ? onPressed : null,
            child: child,
          )
        : CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(34, 34),
            color: selected ? color?.withValues(alpha: 0.18) : null,
            onPressed: enabled ? onPressed : null,
            child: child,
          );
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: button,
    );
  }

  Widget? _item(
    BuildContext context,
    CNToolbarItem item,
    String id,
    Color color,
  ) {
    switch (item) {
      case CNToolbarButton():
        final hasIcon =
            item.icon != null ||
            item.customIcon != null ||
            item.imageAsset != null;
        final c = item.tint ?? color;
        Widget child = hasIcon
            ? _icon(
                item.icon,
                item.customIcon,
                item.imageAsset,
                item.style == CNToolbarItemStyle.prominent
                    ? CupertinoColors.white
                    : c,
              )
            : Text(item.label);
        final badge = item.badge;
        if (badge != null) {
          child = Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              Positioned(top: -4, right: -8, child: _Badge(badge: badge)),
            ],
          );
        }
        return _button(
          label: item.label,
          enabled: item.enabled,
          prominent: item.style == CNToolbarItemStyle.prominent,
          onPressed: () => onEvent('onButtonPressed', {'id': id}),
          child: item.style == CNToolbarItemStyle.prominent && item.tint != null
              ? CupertinoTheme(
                  data: CupertinoTheme.of(
                    context,
                  ).copyWith(primaryColor: item.tint),
                  child: child,
                )
              : child,
        );
      case CNToolbarMenu():
        final hasIcon =
            item.icon != null ||
            item.customIcon != null ||
            item.imageAsset != null;
        return _button(
          label: item.label,
          enabled: item.enabled,
          onPressed: () async {
            final path = await showPopupMenuFallbackSheet(
              context,
              item.items,
              title: item.label,
            );
            if (path != null) {
              onEvent('onMenuSelected', {'id': id, 'path': path});
            }
          },
          child: hasIcon
              ? _icon(item.icon, item.customIcon, item.imageAsset, color)
              : Text(item.label),
        );
      case CNToolbarSegmentedGroup():
        if (item.segments.isEmpty) return null;
        Widget segmentChild(CNToolbarSegment s, Color c) => s._hasImage
            ? _icon(s.icon, s.customIcon, s.imageAsset, c)
            : Text(s.label);
        if (item.selectionMode == CNToolbarSelectionMode.selectOne) {
          final selected = item.selectedIndices.isEmpty
              ? null
              : item.selectedIndices.first;
          return Semantics(
            label: item.label,
            container: true,
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: selected,
              children: {
                for (final (i, s) in item.segments.indexed)
                  i: Semantics(
                    label: s.label,
                    excludeSemantics: s._hasImage,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: segmentChild(s, CupertinoColors.label),
                    ),
                  ),
              },
              disabledChildren: {
                for (final (i, s) in item.segments.indexed)
                  if (!s.enabled || !item.enabled) i,
              },
              onValueChanged: (i) {
                if (i == null) return;
                onEvent('onSegmentSelected', {
                  'id': id,
                  'index': i,
                  'selected': [i],
                });
              },
            ),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, s) in item.segments.indexed)
              _button(
                label: s.label,
                enabled: s.enabled && item.enabled,
                selected:
                    item.selectionMode == CNToolbarSelectionMode.selectAny &&
                    item.selectedIndices.contains(i),
                color: color,
                onPressed: () {
                  final selected = {...item.selectedIndices};
                  if (!selected.remove(i)) selected.add(i);
                  onEvent('onSegmentSelected', {
                    'id': id,
                    'index': i,
                    'selected': (selected.toList()..sort()),
                  });
                },
                child: segmentChild(s, color),
              ),
          ],
        );
      case CNToolbarSpace():
        return item.flexible ? const Spacer() : const SizedBox(width: 16);
      case CNToolbarSearch():
      case CNToolbarSidebarToggle():
      case CNToolbarSidebarTrackingSeparator():
      case CNToolbarInspectorToggle():
      case CNToolbarInspectorTrackingSeparator():
        // As on iOS: no counterpart in a bottom toolbar.
        return null;
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.badge});

  final CNToolbarBadge badge;

  @override
  Widget build(BuildContext context) {
    final text = badge.count?.toString() ?? badge.text;
    return Container(
      constraints: BoxConstraints(
        minWidth: text == null ? 8 : 16,
        minHeight: text == null ? 8 : 16,
      ),
      padding: text == null
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: text == null
          ? null
          : Text(
              text,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
