import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/button_style.dart';
import '../style/image_placement.dart';
import '../style/sf_symbol.dart';
import '../utils/icon_renderer.dart';
import '../utils/modal_hide_mixin.dart';
import '../utils/popup_menu_encoder.dart';
import '../utils/popup_menu_fallback_sheet.dart';
import '../utils/theme_helper.dart';
import '../utils/version_detector.dart';
import '../utils/optional_method_call.dart';
import 'icon.dart';

/// Base type for entries in a [CNPopupMenuButton] menu.
abstract class CNPopupMenuEntry {
  /// Const constructor for subclasses.
  const CNPopupMenuEntry();
}

/// A selectable item in a popup menu.
class CNPopupMenuItem extends CNPopupMenuEntry {
  /// Creates a selectable popup menu item.
  const CNPopupMenuItem({
    required this.label,
    this.subtitle,
    this.icon,
    this.customIcon,
    this.imageAsset,
    this.iconColor,
    this.enabled = true,
    this.checked = false,
    this.isDestructive = false,
    this.keepsMenuPresented = false,
  });

  /// Display label for the item.
  final String label;

  /// Optional second line shown under the [label].
  ///
  /// `UIAction.subtitle` on iOS, `NSMenuItem.subtitle` on macOS 14.4+, and a
  /// smaller second line in the `CupertinoActionSheet` fallback.
  final String? subtitle;

  /// Optional SF Symbol shown before the label.
  /// Priority: [imageAsset] > [customIcon] > [icon]
  final CNSymbol? icon;

  /// Optional custom icon from CupertinoIcons, Icons, or any IconData.
  /// If provided, this takes precedence over [icon] but not [imageAsset].
  final IconData? customIcon;

  /// Optional image asset (SVG, PNG, etc.) shown before the label.
  /// If provided, this takes precedence over [icon] and [customIcon].
  final CNImageAsset? imageAsset;

  /// Optional color for custom icons. This applies a tint color to the custom icon.
  /// For SF Symbols, use the [icon]'s color parameter instead.
  final Color? iconColor;

  /// Whether the item can be selected.
  final bool enabled;

  /// Whether the item shows a checkmark (selected/active state).
  final bool checked;

  /// Marks the item as destructive (e.g. "Delete", "Logout", "Remove").
  ///
  /// On iOS 14+ this applies `UIMenuElement.Attributes.destructive` so the
  /// LABEL renders in the system red destructive color (not just the icon).
  /// On iOS < 26 fallback (CupertinoActionSheet) the entry uses
  /// `isDestructiveAction: true`. On iOS 13 legacy UIAlertController fallback
  /// the action uses `.destructive` style. On macOS, which has no destructive
  /// menu item style, the label and an icon without its own colour are drawn
  /// in the system red.
  final bool isDestructive;

  /// Whether the menu stays open after this item is chosen, for an action
  /// the user repeats, such as zooming in (iOS 16+). The item's callback runs
  /// each time; the menu shows the items it opened with until it closes.
  /// Ignored on macOS and in the action sheet fallback.
  final bool keepsMenuPresented;
}

/// A visual divider between popup menu items.
class CNPopupMenuDivider extends CNPopupMenuEntry {
  /// Creates a visual divider between items.
  const CNPopupMenuDivider();
}

/// How a [CNPopupMenuSubmenu] shows its items.
enum CNPopupMenuSubmenuStyle {
  /// A row that opens a nested menu. The default.
  nested,

  /// The items in the parent menu, as a section under the submenu's label.
  inline,

  /// The items in the parent menu, as one row of icons (iOS 17+), as the
  /// formatting row at the top of a text menu. Give each item an icon. On
  /// iOS 16 and macOS it is shown as [inline].
  palette,
}

/// The size of the items of a [CNPopupMenuSubmenu] (iOS 16+). Smaller sizes
/// fit several items on one row; [CNPopupMenuElementSize.small] shows their
/// icons only.
enum CNPopupMenuElementSize {
  /// The size the system picks. The default.
  automatic,

  /// Icons only, several to a row.
  small,

  /// Icon over label, several to a row.
  medium,

  /// A full row per item.
  large,
}

/// An entry that opens a nested menu of [items], or shows them in place
/// (see [style]).
///
/// On iOS it is a `UIMenu` nested in the button's menu, on macOS an
/// `NSMenuItem` with a submenu, and in the `CupertinoActionSheet` fallback a
/// row that opens a second sheet. Submenus can contain submenus.
///
/// Selecting an item inside it calls [CNPopupMenuButton.onPathSelected] with
/// the item's full path, and [CNPopupMenuButton.onSelected] with the index of
/// the top-level entry the item is under.
class CNPopupMenuSubmenu extends CNPopupMenuEntry {
  /// Creates an entry that opens a nested menu.
  const CNPopupMenuSubmenu({
    required this.label,
    required this.items,
    this.subtitle,
    this.icon,
    this.customIcon,
    this.imageAsset,
    this.iconColor,
    this.enabled = true,
    this.style = CNPopupMenuSubmenuStyle.nested,
    this.elementSize = CNPopupMenuElementSize.automatic,
  });

  /// Display label for the submenu entry, also used as the nested menu's
  /// title.
  final String label;

  /// Entries of the nested menu: items, dividers and further submenus.
  final List<CNPopupMenuEntry> items;

  /// Optional second line shown under the [label].
  ///
  /// `UIMenu.subtitle` on iOS, `NSMenuItem.subtitle` on macOS 14.4+, and a
  /// smaller second line in the `CupertinoActionSheet` fallback.
  final String? subtitle;

  /// Optional SF Symbol shown before the label.
  /// Priority: [imageAsset] > [customIcon] > [icon]
  final CNSymbol? icon;

  /// Optional custom icon from CupertinoIcons, Icons, or any IconData.
  /// If provided, this takes precedence over [icon] but not [imageAsset].
  final IconData? customIcon;

  /// Optional image asset (SVG, PNG, etc.) shown before the label.
  /// If provided, this takes precedence over [icon] and [customIcon].
  final CNImageAsset? imageAsset;

  /// Optional color for custom icons. This applies a tint color to the custom icon.
  /// For SF Symbols, use the [icon]'s color parameter instead.
  final Color? iconColor;

  /// Whether the nested menu can be opened. A disabled submenu is shown
  /// greyed out, like a disabled item.
  final bool enabled;

  /// Whether the items open as a nested menu, or show in the parent menu as
  /// a section or a row of icons. Inline and palette items report the same
  /// paths as nested ones. In the action sheet fallback they are listed in
  /// place under the label.
  final CNPopupMenuSubmenuStyle style;

  /// The size of the items (iOS 16+), mostly for [CNPopupMenuSubmenuStyle.inline]
  /// sections. Ignored on macOS and in the action sheet fallback.
  final CNPopupMenuElementSize elementSize;
}

// Reusable style enum for buttons across widgets (popup menu, future CNButton, ...)

/// A Cupertino-native popup menu button.
///
/// On iOS/macOS this embeds a native popup button and shows a native menu.
class CNPopupMenuButton extends StatefulWidget {
  /// Creates a text-labeled popup menu button.
  ///
  /// Give it a [buttonIcon], [buttonCustomIcon] or [buttonImageAsset] as
  /// well to show the icon next to the label, placed by [imagePlacement]
  /// (#141).
  const CNPopupMenuButton({
    super.key,
    required this.buttonLabel,
    required this.items,
    this.onSelected,
    this.onPathSelected,
    this.tint,
    this.height = 32.0,
    this.shrinkWrap = false,
    this.buttonStyle = CNButtonStyle.plain,
    this.preserveTopToBottomOrder = false,
    this.autoHideOnModal = true,
    this.semanticLabel,
    this.buttonIcon,
    this.buttonCustomIcon,
    this.buttonCustomIconColor,
    this.buttonImageAsset,
    this.imagePlacement = CNImagePlacement.leading,
    this.imagePadding,
    this.labelFontFamily,
    this.labelFontSize,
    this.labelFontWeight,
    this.labelColor,
    this.keepsSourceVisible = false,
    this.onOpened,
    this.onClosed,
  }) : width = null,
       round = false,
       assert(
         onSelected != null || onPathSelected != null,
         'CNPopupMenuButton needs onSelected or onPathSelected.',
       );

  /// Creates a round, icon-only popup menu button.
  CNPopupMenuButton.icon({
    super.key,
    this.buttonIcon,
    this.buttonCustomIcon,
    this.buttonCustomIconColor,
    this.buttonImageAsset,
    required this.items,
    this.onSelected,
    this.onPathSelected,
    this.tint,
    double size = 44.0, // button diameter (width = height)
    this.buttonStyle = CNButtonStyle.glass,
    this.preserveTopToBottomOrder = false,
    this.autoHideOnModal = true,
    this.semanticLabel,
    this.keepsSourceVisible = false,
    this.onOpened,
    this.onClosed,
  }) : buttonLabel = null,
       imagePlacement = CNImagePlacement.leading,
       imagePadding = null,
       labelFontFamily = null,
       labelFontSize = null,
       labelFontWeight = null,
       labelColor = null,
       round = true,
       width = size,
       height = size,
       shrinkWrap = false,
       super() {
    assert(
      buttonIcon != null ||
          buttonCustomIcon != null ||
          buttonImageAsset != null,
      'At least one of buttonIcon, buttonCustomIcon, or buttonImageAsset must be provided',
    );
    assert(
      onSelected != null || onPathSelected != null,
      'CNPopupMenuButton.icon needs onSelected or onPathSelected.',
    );
  }

  /// Text for the button (null for the round icon button).
  final String? buttonLabel; // null in icon mode
  /// Icon for the button: the round button's icon, or shown next to
  /// [buttonLabel].
  /// Priority: [buttonImageAsset] > [buttonCustomIcon] > [buttonIcon]
  final CNSymbol? buttonIcon;

  /// Optional custom icon from CupertinoIcons, Icons, or any IconData for the button.
  /// If provided, this takes precedence over [buttonIcon] but not [buttonImageAsset].
  final IconData? buttonCustomIcon;

  /// Optional color for the [buttonCustomIcon].
  ///
  /// When provided, the custom icon is rendered with this color.
  /// Defaults to white when not specified (suitable for glass-style buttons).
  /// Has no effect on [buttonIcon] (SF Symbol) or [buttonImageAsset].
  final Color? buttonCustomIconColor;

  /// Optional image asset (SVG, PNG, etc.) for the button icon.
  /// If provided, this takes precedence over [buttonIcon] and [buttonCustomIcon].
  final CNImageAsset? buttonImageAsset;
  // Fixed size (width = height) when in icon mode.
  /// Fixed width in icon mode; otherwise computed/intrinsic.
  final double? width;

  /// Whether this is the round icon variant.
  final bool round; // internal: text=false, icon=true

  /// Where the icon goes relative to [buttonLabel] when the button has both
  /// (iOS 15+; on macOS the button's image position).
  final CNImagePlacement imagePlacement;

  /// The gap between the icon and [buttonLabel], in points. Null keeps the
  /// system's.
  final double? imagePadding;

  /// The font family of [buttonLabel], e.g. a font declared under `fonts:`
  /// in `pubspec.yaml`, which the package registers with the system the
  /// first time it is used. Null keeps the system font. The menu's own item
  /// titles always use the system font: a native menu has no font setting.
  final String? labelFontFamily;

  /// The size of [buttonLabel], in points. Null keeps the system's.
  final double? labelFontSize;

  /// The weight of [buttonLabel], also applied with [labelFontFamily] (the
  /// family's nearest face).
  final FontWeight? labelFontWeight;

  /// The colour of [buttonLabel]. Null keeps the button style's.
  final Color? labelColor;

  /// iOS 26+: whether the button is left out of the menu's morph.
  ///
  /// By default the system morphs the button into its menu: the button
  /// disappears as the menu grows out of it and morphs back in when the
  /// menu closes. With this on, the menu grows out of a clear stand-in at
  /// the button's place instead, so the button is never hidden by the morph
  /// and is simply there again the moment the menu closes. The menu still
  /// opens at the button's place, so while it is up it covers the part of
  /// the button under it. macOS menus never hide their button.
  final bool keepsSourceVisible;

  /// Called each time the menu is about to show, as
  /// `PopupMenuButton.onOpened` is.
  final VoidCallback? onOpened;

  /// Called each time the menu has closed, whether or not an item was
  /// chosen. A choice is reported to [onSelected] / [onPathSelected] as
  /// well, around the same moment.
  final VoidCallback? onClosed;

  /// Entries that populate the popup menu.
  final List<CNPopupMenuEntry> items;

  /// Called with the index in [items] of the selected entry, dividers
  /// included.
  ///
  /// For an item inside a [CNPopupMenuSubmenu], the index is the one of the
  /// top-level entry it is under, so `items[index]` can be a
  /// [CNPopupMenuSubmenu]. Use [onPathSelected] to know which item was
  /// selected in a submenu.
  ///
  /// At least one of [onSelected] and [onPathSelected] must be set. When
  /// both are, both are called for every selection.
  final ValueChanged<int>? onSelected;

  /// Called with the path to the selected item, for every selection.
  ///
  /// Each step is an index in a list of entries, dividers included: `[3]`
  /// is `items[3]`, and `[2, 1]` the second entry of the submenu at
  /// `items[2]`. A path always ends on a [CNPopupMenuItem].
  ///
  /// Required when [items] contain a [CNPopupMenuSubmenu].
  final ValueChanged<List<int>>? onPathSelected;

  /// Tint color for the control.
  final Color? tint;

  /// Control height; icon mode uses diameter semantics.
  final double height;

  /// If true, sizes the control to its intrinsic width.
  final bool shrinkWrap;

  /// Visual style to apply to the button.
  final CNButtonStyle buttonStyle;

  /// When true, items maintain top-to-bottom order even when menu opens upward.
  ///
  /// By default (false), iOS native behavior keeps the first item closest to
  /// the button. When the menu opens upward, this means item 1 appears at the
  /// bottom. Set to true to always display items 1,2,3,4 from top to bottom.
  ///
  /// On iOS 16+ this uses the system's fixed menu order
  /// (`preferredMenuElementOrder = .fixed`), which also keeps the order of
  /// submenus. On iOS 15 the top-level items are reversed when the button is
  /// in the lower part of the screen; submenus keep the system order there.
  final bool preserveTopToBottomOrder;

  /// When true (default), destroys the native popup menu's PlatformView while a
  /// modal sheet is presented above this widget's host route. Fixes the
  /// iOS hybrid-composition z-order bleed (Issue #53) where a host-page
  /// CN-widget's pixels leak through a sheet that also contains a CN-widget.
  /// Requires `CNTabBarRouteObserver()` to be registered in the app's
  /// `navigatorObservers`. No effect on iOS < 26 / non-iOS (Flutter fallback).
  ///
  /// When false, the native view stays while a modal (a dialog, popup or
  /// sheet) is up, and its Liquid Glass glow is clipped to the view's bounds
  /// from the modal's push until its exit animation ends, so no box shows
  /// around it through the modal's barrier (Issue #124).
  final bool autoHideOnModal;

  /// What VoiceOver reads for the button.
  ///
  /// Without it, VoiceOver reads [buttonLabel], or for an icon-only button
  /// the SF Symbol's built-in name — which describes the picture, not the
  /// action (`paintpalette.fill` is read as "Paint palette, filled"). Set it
  /// on every icon-only button.
  final String? semanticLabel;

  /// Whether this is the round, icon-only variant ([CNPopupMenuButton.icon]).
  bool get isIconButton => round;

  /// Whether the button shows an icon, alone or next to its label.
  bool get _hasButtonImage =>
      buttonIcon != null ||
      buttonCustomIcon != null ||
      buttonImageAsset != null;

  @override
  State<CNPopupMenuButton> createState() => _CNPopupMenuButtonState();
}

class _CNPopupMenuButtonState extends State<CNPopupMenuButton>
    with
        ModalHideMixin<CNPopupMenuButton>,
        HaloContainmentMixin<CNPopupMenuButton> {
  @override
  bool get autoHideOnModal => widget.autoHideOnModal;

  @override
  MethodChannel? get platformViewChannel => _channel;

  MethodChannel? _channel;
  bool? _lastIsDark;
  int? _lastTint;
  String? _lastTitle;
  String? _lastSemanticLabel;
  String? _lastIconName;
  double? _lastIconSize;
  int? _lastIconColor;
  double? _intrinsicWidth;
  CNButtonStyle? _lastStyle;
  Offset? _downPosition;
  bool _pressed = false;

  /// Rendered custom icons of the menu entries, by [popupMenuIconKey], from
  /// the last [_renderCustomIcons]. `setItems` sends the submenus' ones again.
  Map<PopupMenuIconKey, Uint8List?> _menuIconBytes = {};

  // Halo containment (Issues #29 and #124) is driven by
  // HaloContainmentMixin.

  bool get _isDark => ThemeHelper.isDark(context);
  // Regular and clear glass resolve their content foreground from the
  // material's automatic appearance, so no accent fallback is applied.
  Color? get _effectiveTint {
    final tint = widget.tint;
    if (tint != null ||
        (widget.buttonStyle != CNButtonStyle.glass &&
            widget.buttonStyle != CNButtonStyle.clearGlass)) {
      return tint ?? ThemeHelper.getPrimaryColor(context);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _debugCheckSubmenuCallback();
  }

  @override
  void didUpdateWidget(covariant CNPopupMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _debugCheckSubmenuCallback();
    _syncPropsToNativeIfNeeded();
  }

  // The constructors cannot walk `items` (they are const), so the submenu
  // check runs here.
  void _debugCheckSubmenuCallback() {
    assert(
      widget.onPathSelected != null ||
          !widget.items.any((e) => e is CNPopupMenuSubmenu),
      'CNPopupMenuButton has a CNPopupMenuSubmenu but no onPathSelected: '
      'onSelected only reports the index of the submenu, not which of its '
      'items was selected.',
    );
  }

  /// Reports a selection at [path] to the callbacks that are set.
  void _dispatchSelection(List<int> path) {
    if (path.isEmpty) return;
    widget.onSelected?.call(path.first);
    widget.onPathSelected?.call(List<int>.unmodifiable(path));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  /// Returns a hide-placeholder wrapped in a LayoutBuilder that reproduces
  /// the live build's width formula, or null when the widget should render
  /// normally. Mirrors the width logic in [_buildNativePopupMenu]'s
  /// LayoutBuilder so the slot has identical dimensions whether or not the
  /// native platform view is currently mounted (prevents surrounding text
  /// from creeping into the slot during the hide/show transition).
  /// The width the live button takes under [constraints], as
  /// [_buildNativePopupMenu] lays it out; null fills the bounded width.
  double? _liveWidth(BoxConstraints constraints) {
    if (widget.isIconButton) return widget.width ?? widget.height;
    final preferIntrinsic = widget.shrinkWrap || !constraints.hasBoundedWidth;
    return preferIntrinsic ? (_intrinsicWidth ?? 80.0) : null;
  }

  /// What shows while the native button is prepared: the size the live
  /// button will take, so the row around it doesn't jump (#147).
  Widget _loadingPlaceholder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _liveWidth(constraints);
        return SizedBox(
          height: widget.height,
          width:
              width ?? (constraints.hasBoundedWidth ? constraints.maxWidth : 0),
        );
      },
    );
  }

  Widget? _maybeHiddenWithLiveDimensions() {
    // Probe with widget-level dimensions: if not hidden, return null so the
    // caller proceeds with the normal build.
    final probe = maybeHiddenPlaceholder(
      height: widget.height,
      width: widget.width,
    );
    if (probe == null) return null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedWidth = constraints.hasBoundedWidth;
        final preferIntrinsic = widget.shrinkWrap || !hasBoundedWidth;
        double? width;
        if (widget.isIconButton) {
          // Fixed circle size for icon buttons (matches live build).
          width = widget.width ?? widget.height;
        } else if (preferIntrinsic) {
          // Match the live build's intrinsic-width fallback (80.0).
          width = _intrinsicWidth ?? 80.0;
        } else if (hasBoundedWidth && constraints.maxWidth.isFinite) {
          // Live build passes null width so SizedBox fills the parent's
          // bounded width. Mirror that explicitly so the placeholder reserves
          // the same footprint instead of collapsing to 0.
          width = constraints.maxWidth;
        }
        return maybeHiddenPlaceholder(height: widget.height, width: width) ??
            SizedBox(height: widget.height, width: width);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if we should use native platform view
    final isIOSOrMacOS =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    // An NSButton and NSMenu on every macOS, a UIButton menu on iOS 26+.
    final shouldUseNative =
        isIOSOrMacOS && PlatformVersion.shouldUseNativeControls;

    // Fallback to Flutter widgets for non-iOS/macOS or iOS < 26
    if (!shouldUseNative) {
      // For both non-iOS/macOS and iOS < 26, use CupertinoActionSheet
      return _buildCupertinoFallback(context);
    }

    // Issue #53 fix: when a modal is presented above our host route, destroy
    // the native popup menu's PlatformView so it's removed from the shared
    // iOS PlatformView container.
    //
    // Compute the placeholder width using the SAME formula the live build
    // uses inside its LayoutBuilder so the surrounding layout does not
    // reflow during hide/show (text creeping into the gap, etc.).
    final hiddenWrapper = _maybeHiddenWithLiveDimensions();
    if (hiddenWrapper != null) return hiddenWrapper;

    // Priority: imageAsset > customIcon > icon

    // Check if we need to render custom icons or image assets
    final hasCustomButtonIcon = widget.buttonCustomIcon != null;
    final hasButtonImageAsset = widget.buttonImageAsset != null;
    final hasCustomMenuIcons = walkPopupMenuEntries(
      widget.items,
    ).any((e) => popupMenuEntryVisual(e)?.customIcon != null);
    final hasMenuImageAssets = walkPopupMenuEntries(
      widget.items,
    ).any((e) => popupMenuEntryVisual(e)?.imageAsset != null);

    if (hasCustomButtonIcon ||
        hasCustomMenuIcons ||
        hasButtonImageAsset ||
        hasMenuImageAssets) {
      // Create a key that changes when button or menu icons change
      final buttonIconKey =
          '${widget.buttonImageAsset?.assetPath}_${widget.buttonImageAsset?.imageData?.length ?? 0}_${widget.buttonCustomIcon?.hashCode ?? 0}_${widget.buttonCustomIconColor?.toARGB32() ?? 0}';
      final menuIconsKey = walkPopupMenuEntries(widget.items)
          .map((e) {
            final v = popupMenuEntryVisual(e);
            if (v != null) {
              return '${v.imageAsset?.assetPath}_${v.imageAsset?.imageData?.length ?? 0}_${v.customIcon?.hashCode ?? 0}_${v.iconColor?.toARGB32() ?? 0}';
            }
            return '';
          })
          .join('|');
      return FutureBuilder<Map<String, dynamic>>(
        key: ValueKey('popupMenu_icons_$buttonIconKey|$menuIconsKey'),
        future: _renderCustomIcons(context),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _loadingPlaceholder();
          }
          return FutureBuilder<Widget>(
            future: _buildNativePopupMenu(
              context,
              customIconData: snapshot.data,
            ),
            builder: (context, widgetSnapshot) {
              if (!widgetSnapshot.hasData) {
                return _loadingPlaceholder();
              }
              return widgetSnapshot.data!;
            },
          );
        },
      );
    }

    return FutureBuilder<Widget>(
      future: _buildNativePopupMenu(context, customIconData: null),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _loadingPlaceholder();
        }
        return snapshot.data!;
      },
    );
  }

  Future<Map<String, dynamic>> _renderCustomIcons(BuildContext context) async {
    Uint8List? buttonIconBytes;
    // By icon rather than by position, so that dividers and submenus cannot
    // shift an icon onto another entry, and the icons of the previous build
    // still match while this one renders.
    final menuIconBytes = <PopupMenuIconKey, Uint8List?>{};

    // Handle button icon - imageAsset takes precedence over customIcon
    if (widget.buttonImageAsset != null) {
      // ImageAsset doesn't need async rendering, it's already data
      buttonIconBytes = null; // Will be handled in _buildNativePopupMenu
    } else if (widget.buttonCustomIcon != null) {
      buttonIconBytes = await iconDataToImageBytes(
        widget.buttonCustomIcon!,
        size: widget.buttonIcon?.size ?? 20.0,
        color: widget.buttonCustomIconColor ?? CupertinoColors.white,
      );
    }

    // Handle menu item icons - imageAsset takes precedence over customIcon
    // (an image asset doesn't need async rendering, it's already data)
    for (final e in walkPopupMenuEntries(widget.items)) {
      final key = popupMenuIconKey(e);
      if (key == null || menuIconBytes.containsKey(key)) continue;
      menuIconBytes[key] = await iconDataToImageBytes(
        key.icon,
        size: key.size,
        color: key.color,
      );
    }
    _menuIconBytes = menuIconBytes;

    return {'buttonIconBytes': buttonIconBytes, 'menuIconBytes': menuIconBytes};
  }

  Future<Widget> _buildNativePopupMenu(
    BuildContext context, {
    Map<String, dynamic>? customIconData,
  }) async {
    const viewType = 'CupertinoNativePopupMenuButton';

    // Capture all context-derived values before any async operations
    final capturedIsDark = _isDark;
    final capturedStyle = encodeStyle(context, tint: _effectiveTint);
    final capturedButtonIconColor = resolveColorToArgb(
      widget.buttonImageAsset?.color ??
          widget.buttonCustomIconColor ??
          widget.buttonIcon?.color,
      context,
    );
    final capturedLabelColor = resolveColorToArgb(widget.labelColor, context);
    final capturedButtonPaletteColors = widget.buttonIcon?.paletteColors
        ?.map((c) => resolveColorToArgb(c, context))
        .toList();
    // Resolve button image asset path if present
    String? resolvedButtonAssetPath;
    if (widget.buttonImageAsset != null &&
        widget.buttonImageAsset!.assetPath.isNotEmpty) {
      resolvedButtonAssetPath = await resolveAssetPathForPixelRatio(
        widget.buttonImageAsset!.assetPath,
      );
    }
    if (!mounted) return const SizedBox();

    // Resolve menu image assets concurrently, submenus included
    final menuAssetPaths = Map<CNPopupMenuEntry, String>.identity();
    await Future.wait(
      walkPopupMenuEntries(widget.items).map((e) async {
        final asset = popupMenuEntryVisual(e)?.imageAsset;
        if (asset != null) {
          menuAssetPaths[e] = await resolveAssetPathForPixelRatio(
            asset.assetPath,
          );
        }
      }),
    );
    if (!mounted) return const SizedBox();

    final buttonIconBytes = customIconData?['buttonIconBytes'] as Uint8List?;
    final menuIconBytes =
        customIconData?['menuIconBytes'] as Map<PopupMenuIconKey, Uint8List?>?;

    // Flatten entries into parallel arrays for the platform view.
    final menu = encodePopupMenuEntries(
      widget.items,
      resolveColor: (c) => resolveColorToArgb(c, context),
      customIconBytes: menuIconBytes ?? const {},
      assetPaths: menuAssetPaths,
    );

    final creationParams = <String, dynamic>{
      if (widget.buttonLabel != null) 'buttonTitle': widget.buttonLabel,
      if (widget.semanticLabel != null) 'semanticLabel': widget.semanticLabel,
      if (buttonIconBytes != null) 'buttonCustomIconBytes': buttonIconBytes,
      if (widget.buttonImageAsset != null) ...{
        // Use resolved asset path
        if (resolvedButtonAssetPath != null)
          'buttonAssetPath': resolvedButtonAssetPath,
        if (widget.buttonImageAsset!.imageData != null)
          'buttonImageData': widget.buttonImageAsset!.imageData,
        // Auto-detect format if not provided (use resolved path)
        'buttonImageFormat':
            widget.buttonImageAsset!.imageFormat ??
            detectImageFormat(
              resolvedButtonAssetPath ?? widget.buttonImageAsset!.assetPath,
              widget.buttonImageAsset!.imageData,
            ),
      },
      if (widget.buttonIcon != null) 'buttonIconName': widget.buttonIcon!.name,
      // Next to a label, an SF Symbol at the default size takes the label's
      // size, as UIKit sizes a titled button's symbol.
      'buttonIconSize': ?(widget.isIconButton
          ? widget.buttonImageAsset?.size ?? widget.buttonIcon?.size ?? 20.0
          : widget.buttonImageAsset?.size ??
                (widget.buttonIcon?.size == 24.0
                    ? null
                    : widget.buttonIcon?.size)),
      if (capturedButtonIconColor != null)
        'buttonIconColor': capturedButtonIconColor,
      if (widget.isIconButton) 'round': true,
      'height': widget.height,
      'buttonStyle': widget.buttonStyle.name,
      ...menu,
      'isDark': capturedIsDark,
      'style': capturedStyle,
      if (widget.buttonIcon?.mode != null)
        'buttonIconRenderingMode': widget.buttonIcon!.mode!.name,
      if (capturedButtonPaletteColors != null)
        'buttonIconPaletteColors': capturedButtonPaletteColors,
      if (widget.buttonIcon?.gradient != null)
        'buttonIconGradientEnabled': widget.buttonIcon!.gradient,
      'preserveTopToBottomOrder': widget.preserveTopToBottomOrder,
      if (widget.buttonLabel != null && widget._hasButtonImage) ...{
        'imagePlacement': widget.imagePlacement.name,
        if (widget.imagePadding != null) 'imagePadding': widget.imagePadding,
      },
      if (widget.labelFontFamily != null)
        'labelFontFamily': widget.labelFontFamily,
      if (widget.labelFontSize != null) 'labelFontSize': widget.labelFontSize,
      if (widget.labelFontWeight != null)
        'labelFontWeight': widget.labelFontWeight!.value,
      'labelColor': ?capturedLabelColor,
      if (widget.keepsSourceVisible) 'keepsSourceVisible': true,
    };

    // Create a comprehensive key that includes all parameters affecting platform view creation
    // The labels are left out: `setButtonTitle` and `setItems` change them
    // in place. With them in the key, a new label created the native button
    // again, so it vanished for a frame and its row jumped (#147). Icons
    // stay in: `setItems` doesn't carry the menu's custom icons.
    final buttonIconKey =
        '${widget.round}_${widget.buttonIcon?.name}_${widget.buttonImageAsset?.assetPath}_${widget.buttonImageAsset?.imageData?.length ?? 0}_${widget.buttonCustomIcon?.hashCode ?? 0}';
    final itemsKey = walkPopupMenuEntries(widget.items)
        .map((e) {
          final v = popupMenuEntryVisual(e);
          if (v != null) {
            return '${v.icon?.name}_${v.imageAsset?.assetPath}_${v.imageAsset?.imageData?.length ?? 0}_${v.customIcon?.hashCode ?? 0}';
          }
          return 'divider';
        })
        .join('|');
    final viewKey = ValueKey(
      'popupMenu_'
      '$buttonIconKey|'
      '$itemsKey|'
      '${widget.buttonStyle.name}_'
      '${widget.height}_'
      '${widget.width}_'
      '${widget.tint?.toARGB32()}_'
      '${widget.buttonCustomIconColor?.toARGB32()}_'
      '${widget.imagePlacement.name}_${widget.imagePadding}_'
      '${widget.labelFontFamily}_${widget.labelFontSize}_'
      '${widget.labelFontWeight?.value}_${widget.labelColor?.toARGB32()}_'
      '${widget.keepsSourceVisible}_'
      '$_isDark',
    );

    final platformView = defaultTargetPlatform == TargetPlatform.iOS
        ? UiKitView(
            key: viewKey,
            viewType: viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
            },
          )
        : AppKitView(
            key: viewKey,
            viewType: viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
            },
          );

    return wrapWithModalInteractionGuard(
      LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedWidth = constraints.hasBoundedWidth;
          // If shrinkWrap or width is unbounded (e.g. inside a Row), prefer intrinsic width.
          final preferIntrinsic = widget.shrinkWrap || !hasBoundedWidth;
          double? width;
          if (widget.isIconButton) {
            // Fixed circle size for icon buttons
            width = widget.width ?? widget.height;
          } else if (preferIntrinsic) {
            width = _intrinsicWidth ?? 80.0;
          }
          return Listener(
            onPointerDown: (e) {
              _downPosition = e.position;
              _setPressed(true);
            },
            onPointerMove: (e) {
              final start = _downPosition;
              if (start != null && _pressed) {
                final moved = (e.position - start).distance;
                if (moved > kTouchSlop) {
                  _setPressed(false);
                }
              }
            },
            onPointerUp: (_) {
              _setPressed(false);
              _downPosition = null;
            },
            onPointerCancel: (_) {
              _setPressed(false);
              _downPosition = null;
            },
            child: ClipRect(
              child: SizedBox(
                height: widget.height,
                width: width,
                child: platformView,
              ),
            ),
          );
        },
      ),
    );
  }

  void _onCreated(int id) {
    final ch = MethodChannel('CupertinoNativePopupMenuButton_$id');
    _channel = ch;
    ch.setMethodCallHandler(_onMethodCall);
    resetHaloContainment();
    _lastTint = resolveColorToArgb(_effectiveTint, context);
    _lastIsDark = _isDark;
    _lastTitle = widget.buttonLabel;
    _lastSemanticLabel = widget.semanticLabel;
    _lastIconName = widget.buttonIcon?.name;
    _lastIconSize = widget.buttonIcon?.size;
    _lastIconColor = resolveColorToArgb(widget.buttonIcon?.color, context);
    _lastStyle = widget.buttonStyle;
    if (!widget.isIconButton) {
      _requestIntrinsicSize();
    }
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'menuOpened') {
      widget.onOpened?.call();
    } else if (call.method == 'menuClosed') {
      widget.onClosed?.call();
    } else if (call.method == 'itemSelected') {
      final args = call.arguments as Map?;
      final idx = (args?['index'] as num?)?.toInt();
      final path = (args?['path'] as List?)
          ?.map((step) => (step as num).toInt())
          .toList();
      _dispatchSelection(path ?? [?idx]);
    }
    return null;
  }

  Future<void> _requestIntrinsicSize() async {
    final ch = _channel;
    if (ch == null) return;
    try {
      final size = await ch.invokeMethod<Map>('getIntrinsicSize');
      final w = (size?['width'] as num?)?.toDouble();
      if (w != null && mounted) {
        setState(() => _intrinsicWidth = w);
      }
    } catch (_) {}
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    // Prepare popup items upfront to avoid using BuildContext after awaits.
    // Image asset paths are sent unresolved, as `setItems` always did.
    final updItems = encodePopupMenuEntries(
      widget.items,
      resolveColor: (c) => resolveColorToArgb(c, context),
      customIconBytes: _menuIconBytes,
      includeCustomIcons: false,
    );
    // Capture context-dependent values before any awaits
    final tint = resolveColorToArgb(_effectiveTint, context);
    final preIconName = widget.buttonIcon?.name;
    final preIconSize = widget.buttonIcon?.size;
    final preIconColor = resolveColorToArgb(widget.buttonIcon?.color, context);
    if (_lastTint != tint && tint != null) {
      await ch.invokeMethod('setStyle', {'tint': tint});
      _lastTint = tint;
    }
    if (_lastStyle != widget.buttonStyle) {
      await ch.invokeMethod('setStyle', {
        'buttonStyle': widget.buttonStyle.name,
      });
      _lastStyle = widget.buttonStyle;
    }
    if (_lastTitle != widget.buttonLabel && widget.buttonLabel != null) {
      await ch.invokeMethod('setButtonTitle', {'title': widget.buttonLabel});
      _lastTitle = widget.buttonLabel;
      _requestIntrinsicSize();
    }

    if (widget._hasButtonImage) {
      final iconName = preIconName;
      final iconSize = preIconSize;
      final iconColor = preIconColor;
      final updates = <String, dynamic>{};

      // Handle button imageAsset (takes precedence over SF Symbol)
      if (widget.buttonImageAsset != null) {
        // Resolve asset path based on device pixel ratio
        final resolvedAssetPath = await resolveAssetPathForPixelRatio(
          widget.buttonImageAsset!.assetPath,
        );
        updates['buttonAssetPath'] = resolvedAssetPath;
        updates['buttonImageData'] = widget.buttonImageAsset!.imageData;
        // Auto-detect format if not provided (use resolved path)
        updates['buttonImageFormat'] =
            widget.buttonImageAsset!.imageFormat ??
            detectImageFormat(
              resolvedAssetPath,
              widget.buttonImageAsset!.imageData,
            );
        updates['buttonIconSize'] = widget.buttonImageAsset!.size;
        if (widget.buttonImageAsset!.color != null) {
          if (mounted) {
            updates['buttonIconColor'] = resolveColorToArgb(
              widget.buttonImageAsset!.color,
              context,
            );
          }
        }
        if (widget.buttonImageAsset!.mode != null) {
          updates['buttonIconRenderingMode'] =
              widget.buttonImageAsset!.mode!.name;
        }
        if (widget.buttonImageAsset!.gradient != null) {
          updates['buttonIconGradientEnabled'] =
              widget.buttonImageAsset!.gradient;
        }
      } else {
        // Fallback to SF Symbol
        if (_lastIconName != iconName && iconName != null) {
          updates['buttonIconName'] = iconName;
          _lastIconName = iconName;
        }
        if (_lastIconSize != iconSize && iconSize != null) {
          updates['buttonIconSize'] = iconSize;
          _lastIconSize = iconSize;
        }
        if (_lastIconColor != iconColor && iconColor != null) {
          updates['buttonIconColor'] = iconColor;
          _lastIconColor = iconColor;
        }
        if (widget.buttonIcon?.mode != null) {
          updates['buttonIconRenderingMode'] = widget.buttonIcon!.mode!.name;
        }
        if (widget.buttonIcon?.paletteColors != null) {
          updates['buttonIconPaletteColors'] = widget.buttonIcon!.paletteColors!
              .map((c) => resolveColorToArgb(c, context))
              .toList();
        }
        if (widget.buttonIcon?.gradient != null) {
          updates['buttonIconGradientEnabled'] = widget.buttonIcon!.gradient;
        }
      }

      if (updates.isNotEmpty) {
        await ch.invokeMethod('setButtonIcon', updates);
      }
    }

    await ch.invokeMethod('setItems', updItems);

    if (_lastSemanticLabel != widget.semanticLabel) {
      _lastSemanticLabel = widget.semanticLabel;
      await ch.invokeOptionalMethod('setSemanticLabel', {
        'label': widget.semanticLabel,
      });
    }
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    // Capture values before awaiting
    final isDark = _isDark;
    final tint = resolveColorToArgb(_effectiveTint, context);
    if (_lastIsDark != isDark) {
      await ch.invokeMethod('setBrightness', {'isDark': isDark});
      _lastIsDark = isDark;
    }
    if (_lastTint != tint && tint != null) {
      await ch.invokeMethod('setStyle', {'tint': tint});
      _lastTint = tint;
    }
  }

  Future<void> _setPressed(bool pressed) async {
    final ch = _channel;
    if (ch == null) return;
    if (_pressed == pressed) return;
    _pressed = pressed;
    try {
      await ch.invokeMethod('setPressed', {'pressed': pressed});
    } catch (_) {}
  }

  Widget _buildCupertinoFallback(BuildContext context) {
    // For iOS < 26 and non-iOS/macOS, use CupertinoActionSheet
    final label = widget.semanticLabel;
    if (label != null) {
      return Semantics(
        label: label,
        button: true,
        excludeSemantics: true,
        child: _buildCupertinoFallbackButton(context),
      );
    }
    return _buildCupertinoFallbackButton(context);
  }

  Widget _buildCupertinoFallbackButton(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: widget.isIconButton && widget.round
          ? (widget.width ?? widget.height)
          : null,
      child: CupertinoButton(
        padding: widget.isIconButton
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onPressed: () async {
          widget.onOpened?.call();
          final path = await showPopupMenuFallbackSheet(
            context,
            widget.items,
            title: widget.buttonLabel,
          );
          widget.onClosed?.call();
          if (path != null) _dispatchSelection(path);
        },
        child: widget.isIconButton
            ? (widget.buttonIcon != null
                  ? CNIcon(
                      symbol: widget.buttonIcon,
                      size: widget.buttonIcon!.size,
                      color: widget.buttonIcon!.color,
                    )
                  : const SizedBox.shrink())
            : _fallbackLabel(),
      ),
    );
  }

  /// The fallback's label, with the icon next to it and the label style.
  Widget _fallbackLabel() {
    final text = Text(
      widget.buttonLabel ?? '',
      style: TextStyle(
        fontFamily: widget.labelFontFamily,
        fontSize: widget.labelFontSize,
        fontWeight: widget.labelFontWeight,
        color: widget.labelColor,
      ),
    );
    final symbol = widget.buttonIcon;
    if (symbol == null) return text;
    final icon = CNIcon(symbol: symbol, size: symbol.size, color: symbol.color);
    final gap = widget.imagePadding ?? 6;
    final vertical =
        widget.imagePlacement == CNImagePlacement.top ||
        widget.imagePlacement == CNImagePlacement.bottom;
    final first =
        widget.imagePlacement == CNImagePlacement.leading ||
        widget.imagePlacement == CNImagePlacement.top;
    final children = first
        ? <Widget>[icon, SizedBox(width: gap, height: gap), text]
        : <Widget>[text, SizedBox(width: gap, height: gap), icon];
    return vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: children)
        : Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
