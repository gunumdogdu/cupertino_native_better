import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/sf_symbol.dart';
import '../utils/icon_renderer.dart';
import '../utils/theme_helper.dart';
import '../utils/version_detector.dart';
import 'icon.dart';
import 'tab_bar.dart' show CNTabBarItem;

/// How [CNTabRail] draws its items.
enum CNTabRailStyle {
  /// Icons stacked in a vertical Liquid Glass capsule — the look of the iOS
  /// 27.1 system vertical tab bar.
  rail,

  /// Icon-and-label rows in a glass panel, for wide screens such as the open
  /// inner display of iPhone Duo.
  sidebar,
}

/// A vertical tab bar for the side of the screen.
///
/// On iPhone Duo the system moves tab bars to a vertical bar on one edge — on
/// the outer display, and in landscape on the inner display — but only the
/// tab bars of system containers. [CNTabBar] is a standalone bar, so it stays
/// horizontal; this widget is its vertical counterpart and takes the same
/// [CNTabBarItem]s. [CNTabScaffold] switches between the two automatically.
///
/// Native Liquid Glass on iOS 26 and later; a Cupertino-drawn fallback
/// elsewhere.
class CNTabRail extends StatefulWidget {
  /// Creates a vertical tab rail.
  const CNTabRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.style = CNTabRailStyle.rail,
    this.tint,
  });

  /// The tabs. SF Symbols (`icon` / `activeIcon`), custom icons and badges are
  /// supported; image assets are not.
  final List<CNTabBarItem> items;

  /// The selected tab.
  final int currentIndex;

  /// Called with the index of a tapped tab, including the selected one.
  final ValueChanged<int> onTap;

  /// Rail or sidebar.
  final CNTabRailStyle style;

  /// Colour of the selected tab. Defaults to the theme's primary colour.
  final Color? tint;

  /// Width of the [CNTabRailStyle.rail] style.
  static const double railWidth = 54;

  /// Width of the [CNTabRailStyle.sidebar] style.
  static const double sidebarWidth = 248;

  /// Height of the [CNTabRailStyle.rail] style with [count] items.
  static double railHeight(int count) =>
      count <= 0 ? 0 : count * 44 + (count - 1) * 4 + 10;

  @override
  State<CNTabRail> createState() => _CNTabRailState();
}

class _CNTabRailState extends State<CNTabRail> {
  MethodChannel? _channel;
  Map<String, Object?>? _creationParams;
  int _generation = 0;

  int? _lastIndex;
  Map<String, Object?>? _lastItems;
  Map<String, Object?>? _lastStyle;

  bool get _useNative =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      PlatformVersion.shouldUseNativeGlass;

  Color? get _tint => widget.tint ?? ThemeHelper.getPrimaryColor(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_useNative && _creationParams == null) _prepare();
    _syncStyle();
  }

  @override
  void didUpdateWidget(covariant CNTabRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_useNative) return;
    if (_channel == null) {
      // Still preparing: restart so the view is created with the new items.
      if (!listEquals(oldWidget.items, widget.items)) _prepare();
      return;
    }
    if (widget.currentIndex != _lastIndex) {
      _lastIndex = widget.currentIndex;
      _invoke('setSelectedIndex', <String, Object?>{
        'index': widget.currentIndex,
      });
    }
    if (!listEquals(oldWidget.items, widget.items)) {
      _encodeItems().then((items) {
        if (!mounted || mapEquals(items, _lastItems)) return;
        _lastItems = items;
        _invoke('setItems', items);
      });
    }
    _syncStyle();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  Map<String, Object?> _style() => <String, Object?>{
    'tint': resolveColorToArgb(_tint, context),
    'isDark': ThemeHelper.isDark(context),
    'style': widget.style.name,
  };

  void _syncStyle() {
    if (_channel == null) return;
    final style = _style();
    if (mapEquals(style, _lastStyle)) return;
    _lastStyle = style;
    _invoke('setStyle', style);
  }

  Future<void> _prepare() async {
    final generation = ++_generation;
    final items = await _encodeItems();
    if (!mounted || generation != _generation) return;
    setState(() {
      _lastItems = items;
      _lastIndex = widget.currentIndex;
      _creationParams = <String, Object?>{
        ...items,
        ..._style(),
        'selectedIndex': widget.currentIndex,
      };
    });
  }

  Future<Map<String, Object?>> _encodeItems() async {
    Future<Uint8List?> render(IconData? data) =>
        data == null ? Future<Uint8List?>.value() : iconDataToImageBytes(data);
    final icons = await Future.wait(
      widget.items.map((e) => render(e.customIcon)),
    );
    final activeIcons = await Future.wait(
      widget.items.map((e) => render(e.activeCustomIcon ?? e.customIcon)),
    );
    return <String, Object?>{
      'labels': widget.items.map((e) => e.label ?? '').toList(),
      'sfSymbols': widget.items.map((e) => e.icon?.name ?? '').toList(),
      'activeSfSymbols': widget.items
          .map((e) => e.activeIcon?.name ?? e.icon?.name ?? '')
          .toList(),
      'badges': widget.items.map((e) => e.badge ?? '').toList(),
      'customIconBytes': icons,
      'activeCustomIconBytes': activeIcons,
    };
  }

  Future<void> _invoke(String method, Object? args) async {
    try {
      await _channel?.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // The view is being recreated.
    } on PlatformException {
      // Same.
    }
  }

  void _onCreated(int id) {
    final channel = MethodChannel('CNTabRail_$id');
    _channel = channel;
    _lastStyle = _style();
    channel.setMethodCallHandler((call) async {
      if (call.method == 'valueChanged') {
        final index = ((call.arguments as Map?)?['index'] as num?)?.toInt();
        if (index != null) {
          _lastIndex = index;
          widget.onTap(index);
        }
      }
    });
    // Covers an index change that landed while the view was being created.
    if (_lastIndex != widget.currentIndex) {
      _lastIndex = widget.currentIndex;
      _invoke('setSelectedIndex', <String, Object?>{
        'index': widget.currentIndex,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rail = widget.style == CNTabRailStyle.rail;
    final width = rail ? CNTabRail.railWidth : CNTabRail.sidebarWidth;
    final height = rail ? CNTabRail.railHeight(widget.items.length) : null;

    if (!_useNative) {
      return SizedBox(width: width, height: height, child: _fallback(rail));
    }
    final params = _creationParams;
    if (params == null) return SizedBox(width: width, height: height);
    return SizedBox(
      width: width,
      height: height,
      child: UiKitView(
        viewType: 'CNTabRail',
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onCreated,
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          // Same as CNTabBar (Issue #62): claim every pointer so the rail
          // gets its taps even under an ancestor's recognizer.
          Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
        },
      ),
    );
  }

  Widget _fallback(bool rail) {
    final tint = _tint ?? CupertinoColors.activeBlue;
    final label = CupertinoColors.label.resolveFrom(context);
    final panel = CupertinoColors.secondarySystemBackground.resolveFrom(
      context,
    );

    Widget icon(CNTabBarItem item, bool selected, Color color) {
      final custom = selected
          ? (item.activeCustomIcon ?? item.customIcon)
          : item.customIcon;
      if (custom != null) return Icon(custom, size: 22, color: color);
      final symbol = selected ? (item.activeIcon ?? item.icon) : item.icon;
      if (symbol == null) return Icon(CupertinoIcons.circle, color: color);
      return CNIcon(
        symbol: CNSymbol(symbol.name, size: 20, color: color),
        size: 22,
      );
    }

    final children = <Widget>[
      for (var i = 0; i < widget.items.length; i++)
        Semantics(
          selected: i == widget.currentIndex,
          button: true,
          label: widget.items[i].label,
          value: widget.items[i].badge,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onTap(i),
            child: _FallbackItem(
              rail: rail,
              selected: i == widget.currentIndex,
              tint: tint,
              label: widget.items[i].label ?? '',
              badge: widget.items[i].badge,
              icon: icon(
                widget.items[i],
                i == widget.currentIndex,
                i == widget.currentIndex ? tint : label,
              ),
            ),
          ),
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(rail ? 27 : 28),
      ),
      child: Padding(
        padding: EdgeInsets.all(rail ? 5 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: rail ? MainAxisSize.min : MainAxisSize.max,
          children: rail
              ? <Widget>[
                  for (var i = 0; i < children.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: 4),
                    children[i],
                  ],
                ]
              : children,
        ),
      ),
    );
  }
}

class _FallbackItem extends StatelessWidget {
  const _FallbackItem({
    required this.rail,
    required this.selected,
    required this.tint,
    required this.label,
    required this.badge,
    required this.icon,
  });

  final bool rail;
  final bool selected;
  final Color tint;
  final String label;
  final String? badge;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final highlight = selected
        ? tint.withValues(alpha: rail ? 0.12 : 0.14)
        : const Color(0x00000000);
    if (rail) {
      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: highlight,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            icon,
            if (badge != null && badge!.isNotEmpty)
              Positioned(right: -10, top: -6, child: _Badge(badge!)),
          ],
        ),
      );
    }
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: highlight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(width: 26, child: Center(child: icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? tint
                    : CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
          if (badge != null && badge!.isNotEmpty)
            Text(
              badge!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: EdgeInsets.symmetric(horizontal: text.length > 1 ? 5 : 0),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemRed,
        borderRadius: BorderRadius.all(Radius.circular(9)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: CupertinoColors.white,
        ),
      ),
    );
  }
}
