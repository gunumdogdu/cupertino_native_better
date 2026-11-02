import 'package:flutter/cupertino.dart';

import '../components/popup_menu_button.dart';

// The `CupertinoActionSheet` fallback of a popup menu, used where the native
// menu isn't available: by `CNPopupMenuButton`, and by `CNTabBar` for an
// item with `menuItems`.

/// Shows [entries] in a `CupertinoActionSheet` and returns the path to the
/// selected item, opening a further sheet for each submenu on the way.
/// Returns null when the user cancels.
Future<List<int>?> showPopupMenuFallbackSheet(
  BuildContext context,
  List<CNPopupMenuEntry> entries, {
  String? title,
}) async {
  final selected = await showCupertinoModalPopup<int>(
    context: context,
    builder: (ctx) {
      return CupertinoActionSheet(
        title: title != null ? Text(title) : null,
        actions: [
          for (var i = 0; i < entries.length; i++)
            if (entries[i] case final CNPopupMenuItem item)
              _fallbackAction(
                enabled: item.enabled,
                onPressed: () => Navigator.of(ctx).pop(i),
                isDestructiveAction: item.isDestructive,
                child: _fallbackLabel(ctx, item.label, item.subtitle),
              )
            else if (entries[i] case final CNPopupMenuSubmenu submenu)
              _fallbackAction(
                enabled: submenu.enabled,
                onPressed: () => Navigator.of(ctx).pop(i),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: _fallbackLabel(
                        ctx,
                        submenu.label,
                        submenu.subtitle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(CupertinoIcons.chevron_forward, size: 16),
                  ],
                ),
              )
            else
              const SizedBox(height: 8),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          isDefaultAction: true,
          child: const Text('Cancel'),
        ),
      );
    },
  );
  if (selected == null) return null;
  final entry = entries[selected];
  if (entry is! CNPopupMenuSubmenu) return [selected];
  if (!context.mounted) return null;
  final rest = await showPopupMenuFallbackSheet(
    context,
    entry.items,
    title: entry.label,
  );
  return rest == null ? null : [selected, ...rest];
}

/// An action sheet row. `CupertinoActionSheetAction` has no disabled
/// state, so a disabled entry is dimmed and ignores taps.
Widget _fallbackAction({
  required bool enabled,
  required VoidCallback onPressed,
  bool isDestructiveAction = false,
  required Widget child,
}) {
  final action = CupertinoActionSheetAction(
    onPressed: enabled ? onPressed : () {},
    isDestructiveAction: isDestructiveAction,
    child: enabled ? child : Opacity(opacity: 0.4, child: child),
  );
  if (enabled) return action;
  return Semantics(enabled: false, child: IgnorePointer(child: action));
}

/// An action sheet row's label, with the [subtitle] as a smaller second
/// line when there is one.
Widget _fallbackLabel(BuildContext context, String label, String? subtitle) {
  if (subtitle == null || subtitle.isEmpty) return Text(label);
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label),
      Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    ],
  );
}
