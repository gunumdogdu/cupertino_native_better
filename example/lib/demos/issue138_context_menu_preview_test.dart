import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #138 reproduction: the iOS `CNContextMenu` opens with no lifted
/// preview of the pressed widget.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/138
/// Reported by @cogwheel0.
///
/// ### The claim
///
/// A system context menu lifts a preview of the pressed item above the
/// blurred screen (Photos, Messages, Files). `CNContextMenu` opens a button
/// menu from the pressed point, so the card stays behind the menu.
///
/// ### How this screen proves it
///
/// Two cards, both with the same menu. Long-press each.
///
///  * **showsPreview: false** (the first card, the old behaviour): the menu
///    opens at the finger, the card stays where it is.
///  * **showsPreview: true** (the second card): the card lifts as the menu's
///    preview above the dimmed screen, with rounded 16 pt corners, and
///    settles back when the menu closes. A tap on it still reaches the card
///    (the tap counter goes up).
class Issue138ContextMenuPreviewTestPage extends StatefulWidget {
  const Issue138ContextMenuPreviewTestPage({super.key});

  @override
  State<Issue138ContextMenuPreviewTestPage> createState() =>
      _Issue138ContextMenuPreviewTestPageState();
}

class _Issue138ContextMenuPreviewTestPageState
    extends State<Issue138ContextMenuPreviewTestPage> {
  String _status = '—';
  int _taps = 0;

  static const _items = <CNPopupMenuEntry>[
    CNPopupMenuItem(label: 'Copy', icon: CNSymbol('doc.on.doc')),
    CNPopupMenuItem(label: 'Share', icon: CNSymbol('square.and.arrow.up')),
    CNPopupMenuDivider(),
    CNPopupMenuItem(
      label: 'Delete',
      icon: CNSymbol('trash'),
      isDestructive: true,
    ),
  ];

  Widget _card(String title, Color color) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      alignment: Alignment.bottomLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#138: Context menu preview'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('showsPreview: false'),
            const SizedBox(height: 6),
            CNContextMenu(
              items: _items,
              onSelected: (p) => setState(() => _status = 'plain $p'),
              child: _card('Note without preview', CupertinoColors.systemGrey),
            ),
            const SizedBox(height: 24),
            const Text('showsPreview: true'),
            const SizedBox(height: 6),
            CNContextMenu(
              items: _items,
              showsPreview: true,
              previewCornerRadius: 16,
              onSelected: (p) => setState(() => _status = 'preview $p'),
              // A tap still reaches the child under the native view.
              child: GestureDetector(
                onTap: () => setState(() => _taps++),
                child: _card('Note with preview', CupertinoColors.systemIndigo),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'chosen: $_status   taps on the preview card: $_taps',
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
