import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../components/popup_menu_button.dart';
import 'icon_renderer.dart';
import 'popup_menu_encoder.dart';
import 'popup_menu_fallback_sheet.dart';
import 'theme_helper.dart';

/// Channel owned by `CNContextMenuManager` on the iOS and macOS sides. Like
/// the alert and action sheet channels it carries no platform view: the menu
/// is presented by the window, over everything Flutter draws.
const MethodChannel _channel = MethodChannel('cn_context_menu');

/// Shows [items] as a native menu at [globalPosition] (Flutter's global
/// logical coordinates) and returns the path of the chosen item, or null
/// when the menu was closed without a choice.
///
/// - macOS: an `NSMenu` with its top-left corner at the position, as a
///   context menu opens.
/// - iOS 17.4+: the `UIMenu` a button's menu is, opened from the position.
/// - Elsewhere, below iOS 17.4, or when the native side is missing: the
///   `CupertinoActionSheet` fallback of `CNPopupMenuButton`.
///
/// Used by `CNContextMenu` and by `CNPopupGesture`'s secondary click.
Future<List<int>?> showNativeContextMenu(
  BuildContext context, {
  required List<CNPopupMenuEntry> items,
  required Offset globalPosition,
}) async {
  if (items.isEmpty) return null;
  final platform = defaultTargetPlatform;
  if (platform != TargetPlatform.iOS && platform != TargetPlatform.macOS) {
    return showPopupMenuFallbackSheet(context, items);
  }

  final (iconBytes, assetPaths) = await _menuVisuals(items);
  if (!context.mounted) return null;

  final payload = debugBuildContextMenuPayload(
    items: items,
    position: globalPosition,
    resolveColor: (c) => resolveColorToArgb(c, context),
    isDark: ThemeHelper.themeIsDark(context),
    customIconBytes: iconBytes,
    assetPaths: assetPaths,
  );

  try {
    final path = await _channel.invokeListMethod<int>('show', payload);
    if (path == null || path.isEmpty) return null;
    return path;
  } on PlatformException catch (e) {
    if (e.code == 'unavailable' && context.mounted) {
      // iOS before 17.4 cannot open a menu without a touch on its button.
      return showPopupMenuFallbackSheet(context, items);
    }
    debugPrint(
      '⚠️ [cupertino_native_better] context menu failed: ${e.code} '
      '${e.message ?? ''}',
    );
    return null;
  } on MissingPluginException {
    // No native side (a test without a mock handler, or an older plugin
    // build): the menu is still shown, by the fallback.
    if (!context.mounted) return null;
    return showPopupMenuFallbackSheet(context, items);
  }
}

/// Rendered custom icons and resolved image assets of [items], as
/// CNPopupMenuButton sends them.
Future<(Map<PopupMenuIconKey, Uint8List?>, Map<CNPopupMenuEntry, String>)>
_menuVisuals(List<CNPopupMenuEntry> items) async {
  final iconBytes = <PopupMenuIconKey, Uint8List?>{};
  final assetPaths = Map<CNPopupMenuEntry, String>.identity();
  for (final e in walkPopupMenuEntries(items)) {
    final key = popupMenuIconKey(e);
    if (key != null && !iconBytes.containsKey(key)) {
      iconBytes[key] = await iconDataToImageBytes(
        key.icon,
        size: key.size,
        color: key.color,
      );
    }
    final asset = popupMenuEntryVisual(e)?.imageAsset;
    if (asset != null && asset.assetPath.isNotEmpty) {
      assetPaths[e] = await resolveAssetPathForPixelRatio(asset.assetPath);
    }
  }
  return (iconBytes, assetPaths);
}

/// [items] encoded for a native menu, icons included, or null when
/// [context] is gone by the time the icons are drawn. Used by the
/// `CNContextMenu` preview view, which builds its menu natively.
Future<Map<String, Object?>?> encodeNativeContextMenu(
  BuildContext context,
  List<CNPopupMenuEntry> items,
) async {
  final (iconBytes, assetPaths) = await _menuVisuals(items);
  if (!context.mounted) return null;
  return encodePopupMenuEntries(
    items,
    resolveColor: (c) => resolveColorToArgb(c, context),
    customIconBytes: iconBytes,
    assetPaths: assetPaths,
  );
}

/// Closes a native context menu that is open, which then answers null.
Future<void> dismissNativeContextMenu() async {
  try {
    await _channel.invokeMethod<void>('dismiss');
  } on MissingPluginException {
    // Nothing native to close.
  }
}

/// Builds the method channel payload of [showNativeContextMenu].
///
/// Exposed for tests: the payload is the contract shared with
/// `CNContextMenuManager.swift` on both platforms.
@visibleForTesting
Map<String, Object?> debugBuildContextMenuPayload({
  required List<CNPopupMenuEntry> items,
  required Offset position,
  required int? Function(Color? color) resolveColor,
  bool? isDark,
  Map<PopupMenuIconKey, Uint8List?> customIconBytes = const {},
  Map<CNPopupMenuEntry, String> assetPaths = const {},
}) {
  return <String, Object?>{
    'menu': encodePopupMenuEntries(
      items,
      resolveColor: resolveColor,
      customIconBytes: customIconBytes,
      assetPaths: assetPaths,
    ),
    'x': position.dx,
    'y': position.dy,
    'isDark': ?isDark,
  };
}
