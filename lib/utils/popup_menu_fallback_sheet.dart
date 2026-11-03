import 'package:flutter/cupertino.dart';

import '../components/popup_menu_button.dart';

// The `CupertinoActionSheet` fallback of a popup menu, used where the native
// menu isn't available: by `CNPopupMenuButton`, and by `CNTabBar` for an
// item with `menuItems`.

/// Shows [entries] in a `CupertinoActionSheet` and returns the path to the
/// selected item, opening a further sheet for each nested submenu on the
/// way. Returns null when the user cancels.
///
/// An inline or palette submenu is listed in place, its label above its
/// items, which report the same paths as if it were nested.
Future<List<int>?> showPopupMenuFallbackSheet(
  BuildContext context,
  List<CNPopupMenuEntry> entries, {
  String? title,
}) async {
  final rows = _rows(entries, const []).toList();
  final selected = await showCupertinoModalPopup<List<int>>(
    context: context,
    builder: (ctx) {
      return CupertinoActionSheet(
        title: title != null ? Text(title) : null,
        actions: [
          for (final (path, entry, header) in rows)
            if (header)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  (entry as CNPopupMenuSubmenu).label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(ctx),
                  ),
                ),
              )
            else if (entry case final CNPopupMenuItem item)
              _fallbackAction(
                enabled: item.enabled,
                onPressed: () => Navigator.of(ctx).pop(path),
                isDestructiveAction: item.isDestructive,
                child: _fallbackLabel(ctx, item.label, item.subtitle),
              )
            else if (entry case final CNPopupMenuSubmenu submenu)
              _fallbackAction(
                enabled: submenu.enabled,
                onPressed: () => Navigator.of(ctx).pop(path),
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
  final entry = rows.firstWhere((r) => !r.$3 && _same(r.$1, selected)).$2;
  if (entry is! CNPopupMenuSubmenu) return selected;
  if (!context.mounted) return null;
  final rest = await showPopupMenuFallbackSheet(
    context,
    entry.items,
    title: entry.label,
  );
  return rest == null ? null : [...selected, ...rest];
}

/// The rows of a sheet: each entry with its path, and for an enabled inline
/// or palette submenu a header row followed by its own rows.
Iterable<(List<int>, CNPopupMenuEntry, bool)> _rows(
  List<CNPopupMenuEntry> entries,
  List<int> prefix,
) sync* {
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final path = [...prefix, i];
    if (entry is CNPopupMenuSubmenu &&
        entry.enabled &&
        entry.style != CNPopupMenuSubmenuStyle.nested) {
      if (entry.label.isNotEmpty) yield (path, entry, true);
      yield* _rows(entry.items, path);
    } else {
      yield (path, entry, false);
    }
  }
}

bool _same(List<int> a, List<int> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

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
