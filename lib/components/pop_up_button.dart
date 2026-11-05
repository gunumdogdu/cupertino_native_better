import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/button_style.dart';
import '../style/sf_symbol.dart';
import '../utils/icon_renderer.dart';
import '../utils/modal_hide_mixin.dart';
import '../utils/optional_method_call.dart';
import '../utils/popup_menu_encoder.dart';
import '../utils/theme_helper.dart';
import '../utils/version_detector.dart';
import 'icon.dart';
import 'popup_menu_button.dart';

/// An entry of a [CNPopUpButton] menu: a [CNPopUpButtonItem], a
/// [CNPopUpButtonDivider] or a [CNPopUpButtonSection].
abstract class CNPopUpButtonEntry<T> {
  /// Const constructor for subclasses.
  const CNPopUpButtonEntry();
}

/// A choice of a [CNPopUpButton]: the [value] it stands for and what the
/// menu and the button show for it.
class CNPopUpButtonItem<T> extends CNPopUpButtonEntry<T> {
  /// Creates a choice.
  const CNPopUpButtonItem({
    required this.value,
    required this.label,
    this.icon,
    this.imageAsset,
    this.enabled = true,
  });

  /// The value [CNPopUpButton.onChanged] reports when this item is chosen,
  /// compared with `==` to [CNPopUpButton.value].
  final T value;

  /// The item's title, in the menu and, while it is selected, on the button.
  final String label;

  /// Optional SF Symbol shown before the label. An [imageAsset] takes
  /// precedence.
  ///
  /// On macOS the selected item's image is also shown on the button, as
  /// `NSPopUpButton` does; iOS shows it in the menu only.
  final CNSymbol? icon;

  /// Optional image (SVG, PNG, JPG; a Flutter asset or bytes) shown before
  /// the label, in place of [icon].
  final CNImageAsset? imageAsset;

  /// Whether the item can be chosen. A disabled item is shown dimmed.
  final bool enabled;
}

/// A line between the items of a [CNPopUpButton] menu.
class CNPopUpButtonDivider<T> extends CNPopUpButtonEntry<T> {
  /// Creates a divider.
  const CNPopUpButtonDivider();
}

/// A group of [items] in a [CNPopUpButton] menu, set apart from the other
/// entries, with an optional [title] above them.
///
/// On iOS it is an inline `UIMenu`; on macOS a run of items between
/// separators, under a section header (macOS 14+, a disabled item before).
class CNPopUpButtonSection<T> extends CNPopUpButtonEntry<T> {
  /// Creates a section.
  const CNPopUpButtonSection({this.title, required this.items});

  /// The section's header, or null for none.
  final String? title;

  /// The section's choices.
  final List<CNPopUpButtonItem<T>> items;
}

/// A native pop-up button: a button that shows the current choice and opens
/// a menu of choices when pressed, the standard picker of a value from a
/// short list.
///
/// Unlike [CNPopupMenuButton], which runs an action, a pop-up button selects
/// one of its [items]: the selected item has a checkmark in the menu and its
/// label is the button's title. It is controlled: [onChanged] reports the
/// chosen item's value, and the button shows the new choice once [value]
/// changes to it. If [value] stays the same, the button returns to it.
///
/// ```dart
/// CNPopUpButton<String>(
///   value: _size,
///   items: const [
///     CNPopUpButtonItem(value: 's', label: 'Small'),
///     CNPopUpButtonItem(value: 'm', label: 'Medium'),
///     CNPopUpButtonItem(value: 'l', label: 'Large'),
///   ],
///   onChanged: (v) => setState(() => _size = v),
/// )
/// ```
///
/// | | macOS | iOS 26+ | iOS < 26, other platforms |
/// |---|---|---|---|
/// | control | `NSPopUpButton` | `UIButton` with a `UIMenu`, `changesSelectionAsPrimaryAction` | `CupertinoButton` and a `CupertinoActionSheet` |
/// | width | the widest item, as `NSPopUpButton` sizes itself | the selected title | the selected title |
///
/// The button takes its native width, unless the parent forces one (an
/// `Expanded` or a tight `SizedBox`), and its [height] (see there).
///
/// Use a [CNPopUpButtonItem] whose value stands for "none", such as `null`
/// in a `CNPopUpButton<String?>`, for a "Choose…" placeholder. When no item
/// has [value], the first enabled item is shown as selected.
///
/// VoiceOver reads [semanticLabel] with the selected item's label as the
/// value ("Size, Medium, pop-up button").
class CNPopUpButton<T> extends StatefulWidget {
  /// Creates a native pop-up button.
  const CNPopUpButton({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.buttonStyle,
    this.tint,
    this.height,
    this.semanticLabel,
    this.autoHideOnModal = true,
  });

  /// The menu: choices, dividers and sections, in order.
  final List<CNPopUpButtonEntry<T>> items;

  /// The selected choice: the item whose [CNPopUpButtonItem.value] equals
  /// it.
  final T value;

  /// Called with the value of the item the user chooses. Null disables the
  /// button, as [enabled] false does.
  final ValueChanged<T>? onChanged;

  /// Whether the button can be pressed.
  final bool enabled;

  /// The button's look, as [CNButton]'s. Null is the platform's own
  /// pop-up button: the bordered `NSPopUpButton` on macOS, and on iOS a
  /// plain tinted title with the pop-up indicator, as the system's menu
  /// pickers show.
  ///
  /// | buttonStyle | macOS 26+ | macOS 12–25 | iOS 26+ |
  /// |---|---|---|---|
  /// | null, gray, bordered | bordered pop-up | bordered pop-up | plain (null), gray, bordered |
  /// | plain | borderless pop-up | borderless pop-up | plain |
  /// | glass, clearGlass | pop-up in a regular or clear `NSGlassEffectView` | bordered pop-up | glass, clear glass |
  /// | prominentGlass, prominentClearGlass, filled, borderedProminent | pop-up in an `NSGlassEffectView` tinted with [tint] | bordered pop-up | the same configuration |
  /// | tinted | pop-up in an `NSGlassEffectView` lightly tinted with [tint] | bordered pop-up | tinted |
  ///
  /// `NSPopUpButton` draws its own bezel and ignores the glass bezel and
  /// bezel colours of `NSButton`, so on macOS 26 the glass styles wrap the
  /// borderless pop-up in AppKit's `NSGlassEffectView`, as [CNButton] does
  /// for clear glass.
  final CNButtonStyle? buttonStyle;

  /// Colour of the title (plain, gray, bordered, glass and tinted styles)
  /// or of the button (prominent styles). Null uses the theme's primary
  /// colour where the style is coloured; the default macOS pop-up stays
  /// uncoloured.
  final Color? tint;

  /// Height of the button. Null is the native height: 24 points on macOS (a
  /// regular-size pop-up button) and the height of the configured `UIButton`
  /// on iOS.
  ///
  /// On macOS the `controlSize` follows it: mini below 18 points, small
  /// below 22, regular below 28, large from 28 and extra large from 40
  /// (macOS 26+; large before). A bordered pop-up keeps the bezel height of
  /// its size, centred; a glass capsule fills the height. On iOS the
  /// configuration's `buttonSize` follows it in the same way (mini below
  /// 24 points, small below 30, medium below 40, large from 40), so the
  /// title grows with the button.
  final double? height;

  /// What VoiceOver reads for the button, before the selected item's label.
  final String? semanticLabel;

  /// When true (default), replaces the native view with an empty box of the
  /// same size while a modal sheet covers it (Issue #53). Requires
  /// `CNTabBarRouteObserver()` in the app's `navigatorObservers`.
  final bool autoHideOnModal;

  @override
  State<CNPopUpButton<T>> createState() => _CNPopUpButtonState<T>();
}

/// Height of a macOS pop-up button without a [CNPopUpButton.height]: a
/// regular-size `NSPopUpButton`.
const double _kMacDefaultHeight = 24;

/// What a native iOS button measures until it reports its own height: the
/// plain configuration in English at the default text size.
const double _kIOSEstimatedHeight = 34;

/// How long a finger rests on the button before the touch goes to it as a
/// press, so that the menu opens under the finger and a drag chooses an item.
/// UIKit's scroll views wait as long (`delaysContentTouches`) before they
/// hand a touch to a control; a scroll that starts sooner still scrolls.
const Duration kCNPopUpButtonPressDelay = Duration(milliseconds: 150);

class _CNPopUpButtonState<T> extends State<CNPopUpButton<T>>
    with ModalHideMixin<CNPopUpButton<T>> {
  @override
  bool get autoHideOnModal => widget.autoHideOnModal;

  @override
  MethodChannel? get platformViewChannel => _channel;

  MethodChannel? _channel;
  Size? _nativeSize;

  /// What the native view shows, as last sent (or as created).
  String? _lastItemsSignature;
  List<int>? _lastPath;
  bool? _lastEnabled;
  Map<String, Object?>? _lastStyle;
  bool? _lastIsDark;
  String? _lastSemanticLabel;

  /// Image asset paths resolved for the screen's pixel ratio, by asset path.
  final Map<String, String> _resolvedAssets = {};
  final Set<String> _resolving = {};

  bool get _useNative {
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return apple && PlatformVersion.shouldUseNativeControls;
  }

  bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

  bool get _enabled => widget.enabled && widget.onChanged != null;

  // MARK: Items and selection

  /// The path of the item whose value is [CNPopUpButton.value]: `[i]` for
  /// `items[i]`, `[i, j]` for item `j` of the section at `items[i]`; else
  /// the first enabled item's, as UIKit and AppKit show without a
  /// selection; null for a menu without an enabled item.
  List<int>? get _selectedPath {
    List<int>? firstEnabled;
    for (var i = 0; i < widget.items.length; i++) {
      final e = widget.items[i];
      if (e is CNPopUpButtonItem<T>) {
        if (e.value == widget.value) return [i];
        if (e.enabled) firstEnabled ??= [i];
      } else if (e is CNPopUpButtonSection<T>) {
        for (var j = 0; j < e.items.length; j++) {
          if (e.items[j].value == widget.value) return [i, j];
          if (e.items[j].enabled) firstEnabled ??= [i, j];
        }
      }
    }
    return firstEnabled;
  }

  CNPopUpButtonItem<T>? _itemAt(List<int>? path) {
    if (path == null || path.isEmpty || path.first >= widget.items.length) {
      return null;
    }
    final e = widget.items[path.first];
    if (e is CNPopUpButtonItem<T>) return path.length == 1 ? e : null;
    if (e is CNPopUpButtonSection<T> && path.length == 2) {
      return path[1] < e.items.length ? e.items[path[1]] : null;
    }
    return null;
  }

  CNPopUpButtonItem<T>? get _selectedItem => _itemAt(_selectedPath);

  /// The entries as the shared popup menu encoder takes them: a section is
  /// an inline submenu. Fills [assetPaths] with each entry's resolved image
  /// asset path.
  List<CNPopupMenuEntry> _menuEntries(
    Map<CNPopupMenuEntry, String> assetPaths,
  ) {
    CNPopupMenuItem item(CNPopUpButtonItem<T> i) {
      final entry = CNPopupMenuItem(
        label: i.label,
        icon: i.icon,
        imageAsset: i.imageAsset,
        enabled: i.enabled,
      );
      final path = i.imageAsset?.assetPath;
      if (path != null && path.isNotEmpty) {
        assetPaths[entry] = _resolvedAssets[path] ?? path;
      }
      return entry;
    }

    return [
      for (final e in widget.items)
        if (e is CNPopUpButtonItem<T>)
          item(e)
        else if (e is CNPopUpButtonSection<T>)
          CNPopupMenuSubmenu(
            label: e.title ?? '',
            style: CNPopupMenuSubmenuStyle.inline,
            items: [for (final i in e.items) item(i)],
          )
        else
          const CNPopupMenuDivider(),
    ];
  }

  /// The items as the native view reads them (the popup menu level format,
  /// without checkmarks: the native view marks the selected item).
  Map<String, Object?> _encodedItems(BuildContext context) {
    final assetPaths = Map<CNPopupMenuEntry, String>.identity();
    final entries = _menuEntries(assetPaths);
    return encodePopupMenuEntries(
      entries,
      resolveColor: (c) => resolveColorToArgb(c, context),
      assetPaths: assetPaths,
    );
  }

  /// Everything the encoded items depend on, to tell when to send them
  /// again (the encoded map holds lists, which compare by identity).
  String _itemsSignature(BuildContext context) {
    String symbol(CNSymbol? s) => s == null
        ? ''
        : '${s.name}/${s.size}/${resolveColorToArgb(s.color, context)}/'
              '${s.mode?.name}/'
              '${s.paletteColors?.map((c) => resolveColorToArgb(c, context)).join(',')}';
    String asset(CNImageAsset? a) => a == null
        ? ''
        : '${_resolvedAssets[a.assetPath] ?? a.assetPath}/'
              '${a.imageData == null ? 0 : identityHashCode(a.imageData)}/'
              '${a.imageFormat}/${a.size}/${resolveColorToArgb(a.color, context)}/'
              '${a.mode?.name}';
    String item(CNPopUpButtonItem<T> i) =>
        'i:${i.label}|${symbol(i.icon)}|${asset(i.imageAsset)}|${i.enabled}';
    return [
      for (final e in widget.items)
        if (e is CNPopUpButtonItem<T>)
          item(e)
        else if (e is CNPopUpButtonSection<T>)
          's:${e.title}[${e.items.map(item).join(';')}]'
        else
          'd',
    ].join('\n');
  }

  /// Resolves the items' image asset paths for the screen's pixel ratio and
  /// rebuilds when they arrive.
  void _resolveAssets() {
    final paths = <String>{
      for (final e in widget.items)
        for (final i
            in e is CNPopUpButtonSection<T>
                ? e.items
                : [if (e is CNPopUpButtonItem<T>) e])
          if (i.imageAsset case final a? when a.assetPath.isNotEmpty)
            a.assetPath,
    };
    for (final path in paths) {
      if (_resolvedAssets.containsKey(path) || !_resolving.add(path)) continue;
      resolveAssetPathForPixelRatio(path).then((resolved) {
        _resolving.remove(path);
        if (!mounted) return;
        setState(() => _resolvedAssets[path] = resolved);
      });
    }
  }

  // MARK: Style

  /// The tint sent to the native view. Null keeps the native colour: the
  /// default macOS pop-up, and glass, whose title follows the material.
  Color? get _effectiveTint {
    if (widget.tint != null) return widget.tint;
    final style = widget.buttonStyle;
    if (style == null) {
      return _isMac ? null : ThemeHelper.getPrimaryColor(context);
    }
    if (style == CNButtonStyle.glass || style == CNButtonStyle.clearGlass) {
      return null;
    }
    return ThemeHelper.getPrimaryColor(context);
  }

  Map<String, Object?> _style(BuildContext context) => <String, Object?>{
    'buttonStyle': widget.buttonStyle?.name,
    'tint': resolveColorToArgb(_effectiveTint, context),
    'height': widget.height,
  };

  double get _height {
    final h = widget.height;
    if (h != null) return h;
    if (_isMac) return _kMacDefaultHeight;
    return _nativeSize?.height ?? _kIOSEstimatedHeight;
  }

  /// The button's width until the native view reports it: the title (on
  /// macOS the widest one) and the room the bezel and indicator take.
  double _estimatedWidth(BuildContext context) {
    final labels = _isMac
        ? <String>[
            for (final e in widget.items)
              if (e is CNPopUpButtonItem<T>)
                e.label
              else if (e is CNPopUpButtonSection<T>)
                ...e.items.map((i) => i.label),
          ]
        : <String>[_selectedItem?.label ?? ''];
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: _isMac ? 13 : 17),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return (widest + (_isMac ? 44 : 40)).ceilToDouble();
  }

  // MARK: Lifecycle

  @override
  void initState() {
    super.initState();
    _resolveAssets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncToNative();
  }

  @override
  void didUpdateWidget(covariant CNPopUpButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveAssets();
    _syncToNative();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('CupertinoNativePopUpButton_$id');
    _channel = channel;
    channel.setMethodCallHandler(_onMethodCall);
    _lastItemsSignature = _itemsSignature(context);
    _lastPath = _selectedPath;
    _lastEnabled = _enabled;
    _lastStyle = _style(context);
    _lastIsDark = ThemeHelper.isDark(context);
    _lastSemanticLabel = widget.semanticLabel;
    // The native view may report its size before this handler is set.
    _requestIntrinsicSize();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    final args = call.arguments as Map?;
    switch (call.method) {
      case 'valueChanged':
        final path = (args?['path'] as List?)
            ?.map((step) => (step as num).toInt())
            .toList();
        final item = _itemAt(path);
        if (item == null) return null;
        // The native view shows the choice already.
        _lastPath = path;
        if (item.value != widget.value && _enabled) {
          widget.onChanged?.call(item.value);
        }
        // Back to [value] if the parent kept it.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncToNative();
        });
        WidgetsBinding.instance.scheduleFrame();
      case 'sizeChanged':
        _applyNativeSize(args);
    }
    return null;
  }

  Future<void> _requestIntrinsicSize() async {
    final channel = _channel;
    if (channel == null) return;
    try {
      _applyNativeSize(await channel.invokeMethod<Map>('getIntrinsicSize'));
    } catch (_) {
      // The view is gone; a new one reports its own size.
    }
  }

  void _applyNativeSize(Map? args) {
    final w = (args?['width'] as num?)?.toDouble();
    final h = (args?['height'] as num?)?.toDouble();
    if (w == null || h == null || w <= 0 || h <= 0 || !mounted) return;
    final size = Size(w, h);
    if (size == _nativeSize) return;
    setState(() => _nativeSize = size);
  }

  /// Sends what changed since the last call. A view hidden under a sheet
  /// answers with an error, which is ignored: it is created again with the
  /// current values.
  void _syncToNative() {
    final channel = _channel;
    if (channel == null) return;
    final isDark = ThemeHelper.isDark(context);
    if (_lastIsDark != isDark) {
      _lastIsDark = isDark;
      channel
          .invokeMethod('setBrightness', {'isDark': isDark})
          .catchError((_) {});
    }
    final style = _style(context);
    if (!mapEquals(style, _lastStyle)) {
      _lastStyle = style;
      channel.invokeMethod('setStyle', style).catchError((_) {});
    }
    final signature = _itemsSignature(context);
    final path = _selectedPath;
    if (signature != _lastItemsSignature) {
      _lastItemsSignature = signature;
      _lastPath = path;
      channel
          .invokeMethod('setItems', {
            'items': _encodedItems(context),
            'selectedPath': path,
          })
          .catchError((_) {});
    } else if (!listEquals(path, _lastPath)) {
      _lastPath = path;
      channel
          .invokeMethod('setSelectedPath', {'path': path})
          .catchError((_) {});
    }
    if (_lastEnabled != _enabled) {
      _lastEnabled = _enabled;
      channel
          .invokeMethod('setEnabled', {'enabled': _enabled})
          .catchError((_) {});
    }
    if (_lastSemanticLabel != widget.semanticLabel) {
      _lastSemanticLabel = widget.semanticLabel;
      channel
          .invokeOptionalMethod('setSemanticLabel', {
            'label': widget.semanticLabel,
          })
          .catchError((_) {});
    }
  }

  // MARK: Build

  @override
  Widget build(BuildContext context) {
    if (!_useNative) return _buildFallback(context);

    final height = _height;
    final width = _nativeSize?.width ?? _estimatedWidth(context);
    final hidden = maybeHiddenPlaceholder(height: height, width: width);
    if (hidden != null) return hidden;

    final creationParams = <String, Object?>{
      'items': _encodedItems(context),
      'selectedPath': _selectedPath,
      'enabled': _enabled,
      ..._style(context),
      'semanticLabel': widget.semanticLabel,
      'isDark': ThemeHelper.isDark(context),
    };

    const viewType = 'CupertinoNativePopUpButton';
    final Widget platformView;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      platformView = UiKitView(
        viewType: viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        // In a scrolling parent, a touch that starts to scroll scrolls; a
        // tap opens the menu, and a finger that rests on the button presses
        // it, so the menu opens under the finger and a drag picks an item.
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
          Factory<LongPressGestureRecognizer>(
            () =>
                LongPressGestureRecognizer(duration: kCNPopUpButtonPressDelay),
          ),
        },
      );
    } else {
      // AppKit hit-tests the NSPopUpButton itself: clicks open its menu and
      // scroll events go on to the Flutter view.
      platformView = AppKitView(
        viewType: viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }

    return wrapWithModalInteractionGuard(
      SizedBox(width: width, height: height, child: platformView),
    );
  }

  // MARK: Fallback

  /// iOS below 26 and other platforms: a `CupertinoButton` with the
  /// selected item's label that opens a `CupertinoActionSheet` of the
  /// items, the selected one with a checkmark.
  Widget _buildFallback(BuildContext context) {
    final selected = _selectedItem;
    final enabled = _enabled;
    final color = widget.tint ?? ThemeHelper.getPrimaryColor(context);
    final icon = selected?.icon;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      value: selected?.label,
      // The button below is excluded; this node opens the sheet instead.
      onTap: enabled ? () => _showFallbackSheet(context) : null,
      excludeSemantics: true,
      child: SizedBox(
        height: widget.height ?? 34,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: Size.zero,
          onPressed: enabled ? () => _showFallbackSheet(context) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                CNIcon(symbol: icon, size: 17, color: icon.color ?? color),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  selected?.label ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: enabled ? color : null),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_up_chevron_down,
                size: 14,
                color: enabled ? color : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFallbackSheet(BuildContext context) async {
    final selectedPath = _selectedPath;
    final picked = await showCupertinoModalPopup<List<int>>(
      context: context,
      builder: (ctx) {
        Widget row(CNPopUpButtonItem<T> item, List<int> path) {
          final isSelected = listEquals(path, selectedPath);
          final label = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(CupertinoIcons.checkmark, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(item.label)),
            ],
          );
          final action = CupertinoActionSheetAction(
            isDefaultAction: isSelected,
            onPressed: item.enabled ? () => Navigator.of(ctx).pop(path) : () {},
            child: item.enabled ? label : Opacity(opacity: 0.4, child: label),
          );
          return Semantics(
            selected: isSelected,
            enabled: item.enabled,
            child: item.enabled ? action : IgnorePointer(child: action),
          );
        }

        Widget header(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(ctx),
            ),
          ),
        );

        return CupertinoActionSheet(
          title: widget.semanticLabel == null
              ? null
              : Text(widget.semanticLabel!),
          actions: [
            for (var i = 0; i < widget.items.length; i++)
              if (widget.items[i] case final CNPopUpButtonItem<T> item)
                row(item, [i])
              else if (widget.items[i]
                  case final CNPopUpButtonSection<T> section) ...[
                if (section.title case final title? when title.isNotEmpty)
                  header(title),
                for (var j = 0; j < section.items.length; j++)
                  row(section.items[j], [i, j]),
              ] else
                const SizedBox(height: 8),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );
    final item = _itemAt(picked);
    if (item == null || !mounted || !_enabled) return;
    if (item.value != widget.value) widget.onChanged?.call(item.value);
  }
}
