import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../components/popup_menu_button.dart';
import '../style/sf_symbol.dart';
import 'icon_renderer.dart';

/// What a selectable or expandable popup menu entry shows: the fields
/// [CNPopupMenuItem] and [CNPopupMenuSubmenu] have in common.
typedef PopupMenuEntryVisual = ({
  String label,
  String? subtitle,
  CNSymbol? icon,
  IconData? customIcon,
  CNImageAsset? imageAsset,
  Color? iconColor,
  bool enabled,
});

/// The visual fields of [entry], or null for a divider.
PopupMenuEntryVisual? popupMenuEntryVisual(CNPopupMenuEntry entry) {
  if (entry is CNPopupMenuItem) {
    return (
      label: entry.label,
      subtitle: entry.subtitle,
      icon: entry.icon,
      customIcon: entry.customIcon,
      imageAsset: entry.imageAsset,
      iconColor: entry.iconColor,
      enabled: entry.enabled,
    );
  }
  if (entry is CNPopupMenuSubmenu) {
    return (
      label: entry.label,
      subtitle: entry.subtitle,
      icon: entry.icon,
      customIcon: entry.customIcon,
      imageAsset: entry.imageAsset,
      iconColor: entry.iconColor,
      enabled: entry.enabled,
    );
  }
  return null;
}

/// Every entry of [entries] and of their submenus, depth first.
Iterable<CNPopupMenuEntry> walkPopupMenuEntries(
  List<CNPopupMenuEntry> entries,
) sync* {
  for (final e in entries) {
    yield e;
    if (e is CNPopupMenuSubmenu) yield* walkPopupMenuEntries(e.items);
  }
}

/// Encodes popup menu [entries] into the parallel arrays the native popup
/// menu views read.
///
/// Each item, submenu and divider takes one slot in every array, so a slot
/// is addressed by the entry's index in its list, dividers included: the
/// index `onSelected` reports, and each step of an `onPathSelected` path.
///
/// A level with no subtitle and no submenu encodes to exactly the keys it
/// always had. `subtitles`, `isSubmenu` and `submenus` are only added to a
/// level that uses them; `submenus` holds each submenu's own level, encoded
/// the same way, and null for the other slots.
///
/// [customIconBytes] holds the rendered [CNPopupMenuItem.customIcon] of each
/// entry, looked up by the entry itself. [assetPaths] holds the resolved
/// path of each entry's image asset; an entry missing from it uses the raw
/// [CNImageAsset.assetPath].
///
/// `setItems` has never carried the top level's custom icons: the native
/// view keeps the ones it was created with, and a new custom icon recreates
/// the view. Pass [includeCustomIcons] false to encode a top level for it;
/// submenu levels always carry theirs, since `setItems` rebuilds them.
Map<String, Object?> encodePopupMenuEntries(
  List<CNPopupMenuEntry> entries, {
  required int? Function(Color? color) resolveColor,
  Map<CNPopupMenuEntry, Uint8List?> customIconBytes = const {},
  Map<CNPopupMenuEntry, String> assetPaths = const {},
  bool includeCustomIcons = true,
}) {
  final labels = <String>[];
  final symbols = <String>[];
  final customIcons = <Uint8List?>[];
  final customIconColors = <int?>[];
  final imageAssetPaths = <String>[];
  final imageAssetData = <Uint8List?>[];
  final imageAssetFormats = <String>[];
  final isDivider = <bool>[];
  final enabled = <bool>[];
  final checked = <bool>[];
  final isDestructive = <bool>[];
  final sizes = <double?>[];
  final colors = <int?>[];
  final modes = <String?>[];
  final palettes = <List<int?>?>[];
  final gradients = <bool?>[];
  final subtitles = <String>[];
  final isSubmenu = <bool>[];
  final submenus = <Map<String, Object?>?>[];
  var usesSubtitles = false;
  var usesSubmenus = false;

  for (final e in entries) {
    final visual = popupMenuEntryVisual(e);
    if (visual == null) {
      // Only dividers take an empty slot; any other entry type was never
      // sent to the native view.
      if (e is! CNPopupMenuDivider) continue;
      labels.add('');
      symbols.add('');
      customIcons.add(null);
      customIconColors.add(null);
      imageAssetPaths.add('');
      imageAssetData.add(null);
      imageAssetFormats.add('');
      isDivider.add(true);
      enabled.add(false);
      checked.add(false);
      isDestructive.add(false);
      sizes.add(null);
      colors.add(null);
      modes.add(null);
      palettes.add(null);
      gradients.add(null);
      subtitles.add('');
      isSubmenu.add(false);
      submenus.add(null);
      continue;
    }

    final icon = visual.icon;
    final asset = visual.imageAsset;
    labels.add(visual.label);
    symbols.add(icon?.name ?? '');
    customIcons.add(customIconBytes[e]);
    customIconColors.add(resolveColor(visual.iconColor));
    if (asset != null) {
      final path = assetPaths[e] ?? asset.assetPath;
      imageAssetPaths.add(path);
      imageAssetData.add(asset.imageData);
      imageAssetFormats.add(
        asset.imageFormat ?? detectImageFormat(path, asset.imageData) ?? '',
      );
    } else {
      imageAssetPaths.add('');
      imageAssetData.add(null);
      imageAssetFormats.add('');
    }
    isDivider.add(false);
    enabled.add(visual.enabled);
    checked.add(e is CNPopupMenuItem && e.checked);
    isDestructive.add(e is CNPopupMenuItem && e.isDestructive);
    sizes.add(asset?.size ?? icon?.size);
    colors.add(resolveColor(asset?.color ?? icon?.color));
    modes.add(asset?.mode?.name ?? icon?.mode?.name);
    palettes.add(icon?.paletteColors?.map(resolveColor).toList());
    gradients.add(asset?.gradient ?? icon?.gradient);

    final subtitle = visual.subtitle;
    if (subtitle != null && subtitle.isNotEmpty) usesSubtitles = true;
    subtitles.add(subtitle ?? '');
    if (e is CNPopupMenuSubmenu) {
      usesSubmenus = true;
      isSubmenu.add(true);
      submenus.add(
        encodePopupMenuEntries(
          e.items,
          resolveColor: resolveColor,
          customIconBytes: customIconBytes,
          assetPaths: assetPaths,
        ),
      );
    } else {
      isSubmenu.add(false);
      submenus.add(null);
    }
  }

  return {
    'labels': labels,
    'sfSymbols': symbols,
    if (includeCustomIcons) ...{
      'customIconBytes': customIcons,
      'customIconColors': customIconColors,
    },
    'imageAssetPaths': imageAssetPaths,
    'imageAssetData': imageAssetData,
    'imageAssetFormats': imageAssetFormats,
    'isDivider': isDivider,
    'enabled': enabled,
    'checked': checked,
    'isDestructive': isDestructive,
    'sfSymbolSizes': sizes,
    'sfSymbolColors': colors,
    'sfSymbolRenderingModes': modes,
    'sfSymbolPaletteColors': palettes,
    'sfSymbolGradientEnabled': gradients,
    if (usesSubtitles || usesSubmenus) 'subtitles': subtitles,
    if (usesSubmenus) ...{'isSubmenu': isSubmenu, 'submenus': submenus},
  };
}
