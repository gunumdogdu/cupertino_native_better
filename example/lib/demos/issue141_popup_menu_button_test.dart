import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #141: `CNPopupMenuButton` can't show an icon and a label together,
/// can't style its label, always hides into its menu on iOS 26, and has no
/// open/close callbacks.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/141
/// Reported by @Ashhad08.
///
/// ### The requests and how this screen shows them
///
///  1. **Icon and label together:** "Sort" with a trailing chevron, and
///     "Filter" with a leading symbol above its label (`imagePlacement`).
///  2. **Label font:** "Tajawal Bold" in the pubspec font Tajawal, bold, in
///     orange. The menu's own items stay in the system font (a native menu
///     has no font setting).
///  3. **keepsSourceVisible:** two ••• buttons. Open and close the left one
///     (off): the button disappears into its menu and morphs back when it
///     closes. The right one (on) is left out of the morph: it is there
///     again the moment the menu closes (in a recording, no frames without
///     the button, against six for the left one). The menu opens over the
///     button's place in both.
///  4. **onOpened / onClosed:** the counters go up once each time a menu
///     opens and once when it closes, with or without a choice.
class Issue141PopupMenuButtonTestPage extends StatefulWidget {
  const Issue141PopupMenuButtonTestPage({super.key});

  @override
  State<Issue141PopupMenuButtonTestPage> createState() =>
      _Issue141PopupMenuButtonTestPageState();
}

class _Issue141PopupMenuButtonTestPageState
    extends State<Issue141PopupMenuButtonTestPage> {
  int _opened = 0;
  int _closed = 0;
  String _chosen = '—';

  static const _items = <CNPopupMenuEntry>[
    CNPopupMenuItem(label: 'Newest first', icon: CNSymbol('arrow.down')),
    CNPopupMenuItem(label: 'Oldest first', icon: CNSymbol('arrow.up')),
    CNPopupMenuItem(label: 'Name', icon: CNSymbol('textformat')),
  ];

  void _opens() => setState(() => _opened++);
  void _closes() => setState(() => _closed++);
  void _choose(String button, int i) =>
      setState(() => _chosen = '$button → ${i + 1}');

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#141: Popup menu button'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('1. Icon and label'),
            const SizedBox(height: 8),
            Row(
              children: [
                CNPopupMenuButton(
                  buttonLabel: 'Sort',
                  buttonIcon: const CNSymbol('chevron.down'),
                  imagePlacement: CNImagePlacement.trailing,
                  imagePadding: 4,
                  buttonStyle: CNButtonStyle.glass,
                  shrinkWrap: true,
                  items: _items,
                  onOpened: _opens,
                  onClosed: _closes,
                  onSelected: (i) => _choose('Sort', i),
                ),
                const SizedBox(width: 12),
                CNPopupMenuButton(
                  buttonLabel: 'Filter',
                  buttonIcon: const CNSymbol('line.3.horizontal.decrease'),
                  imagePlacement: CNImagePlacement.top,
                  height: 56,
                  buttonStyle: CNButtonStyle.glass,
                  shrinkWrap: true,
                  items: _items,
                  onOpened: _opens,
                  onClosed: _closes,
                  onSelected: (i) => _choose('Filter', i),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('2. Label font (pubspec Tajawal, bold, orange)'),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CNPopupMenuButton(
                buttonLabel: 'Tajawal Bold',
                labelFontFamily: 'Tajawal',
                labelFontWeight: FontWeight.w700,
                labelFontSize: 18,
                labelColor: CupertinoColors.systemOrange,
                buttonStyle: CNButtonStyle.glass,
                shrinkWrap: true,
                height: 40,
                items: _items,
                onOpened: _opens,
                onClosed: _closes,
                onSelected: (i) => _choose('Tajawal', i),
              ),
            ),
            const SizedBox(height: 20),
            const Text('3. keepsSourceVisible: off · on'),
            const SizedBox(height: 8),
            Row(
              children: [
                CNPopupMenuButton.icon(
                  buttonIcon: const CNSymbol('ellipsis'),
                  items: _items,
                  onOpened: _opens,
                  onClosed: _closes,
                  onSelected: (i) => _choose('off', i),
                ),
                const SizedBox(width: 40),
                CNPopupMenuButton.icon(
                  buttonIcon: const CNSymbol('ellipsis'),
                  keepsSourceVisible: true,
                  items: _items,
                  onOpened: _opens,
                  onClosed: _closes,
                  onSelected: (i) => _choose('on', i),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'opened: $_opened  closed: $_closed  chosen: $_chosen',
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
