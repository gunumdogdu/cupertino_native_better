import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/sf_symbol.dart';
import '../utils/icon_renderer.dart';
import '../utils/theme_helper.dart';
import 'tab_bar.dart' show CNTabBarItem;
import 'tab_rail.dart';

/// A row of a [CNSidebar]: a title, an icon and an optional badge.
///
/// The icon is, by priority, [imageAsset], then [customIcon], then
/// [sfSymbol], as in [CNTabBarItem]. The `active` variants are drawn while
/// the row is selected and default to the plain ones.
@immutable
class CNSidebarItem {
  /// Creates a sidebar row.
  const CNSidebarItem({
    required this.title,
    this.sfSymbol,
    this.activeSfSymbol,
    this.customIcon,
    this.activeCustomIcon,
    this.imageAsset,
    this.activeImageAsset,
    this.badge,
  });

  /// The row's text, and its VoiceOver label.
  final String title;

  /// The SF Symbol before the title.
  final CNSymbol? sfSymbol;

  /// The SF Symbol while the row is selected. Defaults to [sfSymbol].
  final CNSymbol? activeSfSymbol;

  /// A Flutter icon (`CupertinoIcons`, `Icons`…) drawn as a template
  /// image, tinted like a symbol. Takes precedence over [sfSymbol].
  final IconData? customIcon;

  /// [customIcon] while the row is selected. Defaults to [customIcon].
  final IconData? activeCustomIcon;

  /// An image asset (PNG, JPG or SVG, or raw bytes) before the title. A
  /// single-coloured image is tinted like a symbol. Takes precedence over
  /// [customIcon] and [sfSymbol].
  final CNImageAsset? imageAsset;

  /// [imageAsset] while the row is selected. Defaults to [imageAsset].
  final CNImageAsset? activeImageAsset;

  /// A count or short text at the trailing end of the row, such as an unread
  /// count, read by VoiceOver as the row's value. [dotBadge] shows a dot.
  final String? badge;

  /// A [badge] value that shows a small dot instead of a count. VoiceOver
  /// reads it as "New".
  static const String dotBadge = CNTabBarItem.dotBadge;

  @override
  bool operator ==(Object other) =>
      other is CNSidebarItem &&
      other.title == title &&
      other.sfSymbol?.name == sfSymbol?.name &&
      other.activeSfSymbol?.name == activeSfSymbol?.name &&
      other.customIcon == customIcon &&
      other.activeCustomIcon == activeCustomIcon &&
      other.imageAsset?.assetPath == imageAsset?.assetPath &&
      other.imageAsset?.imageData == imageAsset?.imageData &&
      other.activeImageAsset?.assetPath == activeImageAsset?.assetPath &&
      other.activeImageAsset?.imageData == activeImageAsset?.imageData &&
      other.badge == badge;

  @override
  int get hashCode => Object.hash(
    title,
    sfSymbol?.name,
    activeSfSymbol?.name,
    customIcon,
    activeCustomIcon,
    imageAsset?.assetPath,
    activeImageAsset?.assetPath,
    badge,
  );
}

/// A group of [CNSidebarItem]s, under an optional header such as
/// "Favorites".
@immutable
class CNSidebarSection {
  /// Creates a sidebar section.
  const CNSidebarSection({this.title, required this.items});

  /// The section's header. Null shows the rows without one.
  final String? title;

  /// The section's rows.
  final List<CNSidebarItem> items;

  @override
  bool operator ==(Object other) =>
      other is CNSidebarSection &&
      other.title == title &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(title, Object.hashAll(items));
}

/// A native macOS sidebar that Flutter lays out: sections of rows with
/// symbols or images, badges, and one selected row.
///
/// On macOS it is AppKit's sidebar, SwiftUI's `List` in the sidebar style,
/// in a platform view: Liquid Glass on macOS 26 and later, the vibrant
/// sidebar material before. The rows follow the system's sidebar metrics
/// and the accent colour (or [tint]); arrow keys move the selection once the
/// list has the keyboard focus, and VoiceOver reads each row with its badge.
///
/// Put it where a sidebar belongs, at the leading edge beside the content,
/// for example in a `Row` with a fixed width such as [width]. For a sidebar
/// that is part of the window itself, beside the whole Flutter view, use
/// `CNTabBarNative`, which on macOS turns its tabs into the window's own
/// sidebar.
///
/// iOS has no standalone sidebar control: there the rows are drawn by a
/// [CNTabRail] in its sidebar style (native Liquid Glass on iOS 26 and
/// later, a Cupertino fallback before), without the section headers. Other
/// platforms get the same fallback.
///
/// ```dart
/// CNSidebar(
///   sections: const [
///     CNSidebarSection(items: [
///       CNSidebarItem(title: 'Inbox', sfSymbol: CNSymbol('tray'), badge: '3'),
///       CNSidebarItem(title: 'Sent', sfSymbol: CNSymbol('paperplane')),
///     ]),
///     CNSidebarSection(title: 'Smart Mailboxes', items: [
///       CNSidebarItem(title: 'Today', sfSymbol: CNSymbol('calendar')),
///     ]),
///   ],
///   selectedIndex: _selected,
///   onSelected: (i) => setState(() => _selected = i),
/// )
/// ```
class CNSidebar extends StatefulWidget {
  /// Creates a native sidebar.
  const CNSidebar({
    super.key,
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
    this.tint,
    this.iconsOnly = false,
    this.semanticLabel,
  });

  /// The sections, top to bottom.
  final List<CNSidebarSection> sections;

  /// The selected row, counted across all sections from the top: the first
  /// row of the second section is `sections[0].items.length`. Null or out
  /// of range selects none.
  final int? selectedIndex;

  /// Called with the index of the row the user selects (counted as for
  /// [selectedIndex]). Not called for changes of [selectedIndex].
  final ValueChanged<int> onSelected;

  /// Colour of the icons and of the selected row. Defaults to the system
  /// accent colour on macOS and to the theme's primary colour elsewhere.
  final Color? tint;

  /// Shows only the icons, each row's title as its tooltip and VoiceOver
  /// label: the narrow rail of [CNTabRail] on macOS.
  final bool iconsOnly;

  /// The VoiceOver label of the sidebar as a whole.
  final String? semanticLabel;

  /// A standard sidebar width on macOS.
  static const double width = 220;

  @override
  State<CNSidebar> createState() => _CNSidebarState();
}

class _CNSidebarState extends State<CNSidebar> {
  MethodChannel? _channel;
  Map<String, Object?>? _creationParams;
  int _generation = 0;

  int? _lastIndex;
  Map<String, Object?>? _lastSections;
  Map<String, Object?>? _lastStyle;

  bool get _useMacView =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_useMacView && _creationParams == null) _prepare();
    _syncStyle();
  }

  @override
  void didUpdateWidget(covariant CNSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_useMacView) return;
    if (_channel == null) {
      // Still preparing: start again so the view gets the new rows.
      if (!listEquals(oldWidget.sections, widget.sections)) _prepare();
      return;
    }
    if (widget.selectedIndex != _lastIndex) {
      _lastIndex = widget.selectedIndex;
      _invoke('setSelectedIndex', <String, Object?>{
        'index': widget.selectedIndex,
      });
    }
    if (!listEquals(oldWidget.sections, widget.sections)) {
      _encodeSections().then((sections) {
        if (!mounted || mapEquals(sections, _lastSections)) return;
        _lastSections = sections;
        _invoke('setSections', sections);
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
    'tint': resolveColorToArgb(widget.tint, context),
    'isDark': ThemeHelper.isDark(context),
    'iconsOnly': widget.iconsOnly,
    if (widget.semanticLabel != null) 'semanticLabel': widget.semanticLabel,
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
    final sections = await _encodeSections();
    if (!mounted || generation != _generation) return;
    setState(() {
      _lastSections = sections;
      _lastIndex = widget.selectedIndex;
      _creationParams = <String, Object?>{
        ...sections,
        ..._style(),
        'selectedIndex': widget.selectedIndex,
      };
    });
  }

  Future<Map<String, Object?>> _encodeSections() async {
    Future<Map<String, Object?>?> image(CNImageAsset? asset) async {
      if (asset == null) return null;
      final path = asset.imageData != null
          ? ''
          : await resolveAssetPathForPixelRatio(asset.assetPath);
      final format =
          asset.imageFormat ?? detectImageFormat(path, asset.imageData);
      return <String, Object?>{
        'path': path,
        if (asset.imageData != null) 'data': asset.imageData,
        if (format != null) 'format': format,
      };
    }

    Future<Uint8List?> icon(IconData? data) =>
        data == null ? Future<Uint8List?>.value() : iconDataToImageBytes(data);

    Future<Map<String, Object?>> item(CNSidebarItem e) async {
      // Priority, as in CNTabBar: imageAsset > customIcon > sfSymbol.
      final plainImage = await image(e.imageAsset);
      final activeImage = await image(e.activeImageAsset);
      final plainIcon = e.imageAsset == null ? await icon(e.customIcon) : null;
      final activeIcon = e.activeImageAsset == null
          ? await icon(e.activeCustomIcon)
          : null;
      return <String, Object?>{
        'title': e.title,
        if (e.sfSymbol != null) 'sfSymbol': e.sfSymbol!.name,
        if (e.activeSfSymbol != null) 'activeSfSymbol': e.activeSfSymbol!.name,
        if (plainImage != null) 'image': plainImage,
        if (activeImage != null) 'activeImage': activeImage,
        if (plainIcon != null) 'iconBytes': plainIcon,
        if (activeIcon != null) 'activeIconBytes': activeIcon,
        if (e.badge != null) 'badge': e.badge,
      };
    }

    return <String, Object?>{
      'sections': [
        for (final section in widget.sections)
          <String, Object?>{
            if (section.title != null) 'title': section.title,
            'items': await Future.wait(section.items.map(item)),
          },
      ],
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
    final channel = MethodChannel('CNSidebar_$id');
    _channel = channel;
    _lastStyle = _style();
    channel.setMethodCallHandler((call) async {
      if (call.method == 'valueChanged') {
        final index = ((call.arguments as Map?)?['index'] as num?)?.toInt();
        if (index != null) {
          _lastIndex = index;
          widget.onSelected(index);
        }
      }
    });
    // An index change that landed while the view was being created.
    if (_lastIndex != widget.selectedIndex) {
      _lastIndex = widget.selectedIndex;
      _invoke('setSelectedIndex', <String, Object?>{
        'index': widget.selectedIndex,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_useMacView) return _rail();
    final params = _creationParams;
    if (params == null) return const SizedBox.expand();
    // The rows and the sidebar's label are native accessibility elements.
    return AppKitView(
      viewType: 'CNSidebar',
      creationParams: params,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onCreated,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
      },
    );
  }

  /// iOS and other platforms: a [CNTabRail] in its sidebar style, the rows
  /// of every section one after another.
  Widget _rail() {
    final items = <CNTabBarItem>[
      for (final section in widget.sections)
        for (final e in section.items)
          CNTabBarItem(
            label: e.title,
            icon: e.sfSymbol,
            activeIcon: e.activeSfSymbol,
            customIcon: e.customIcon,
            activeCustomIcon: e.activeCustomIcon,
            imageAsset: e.imageAsset,
            activeImageAsset: e.activeImageAsset,
            badge: e.badge,
          ),
    ];
    final index = widget.selectedIndex;
    return CNTabRail(
      items: items,
      currentIndex: index != null && index >= 0 && index < items.length
          ? index
          : -1,
      onTap: widget.onSelected,
      tint: widget.tint,
      style: widget.iconsOnly ? CNTabRailStyle.rail : CNTabRailStyle.sidebar,
    );
  }
}
