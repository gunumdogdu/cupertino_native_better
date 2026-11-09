import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #134 reproduction: the iOS 26 `CNSearchBar` loses its text after a
/// modal, has no keyboard options, reads its clear button as "Close", and
/// draws its icons at a fixed 16 pt.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/134
/// Reported by @cogwheel0.
///
/// ### The claims
///
/// 1. With `autoHideOnModal: true` (the default) the native view is removed
///    while a modal is up and created again when it closes. The new view is
///    empty and has its initial expanded state, while the app still filters
///    by the old query.
/// 2. No way to turn off capitalization or autocorrection, or to pick the
///    keyboard.
/// 3. VoiceOver reads the clear button as "Close" (the SF Symbol's name).
/// 4. `searchIcon: CNSymbol(size: 22)` is drawn at 16 pt, and the icons
///    don't follow Dynamic Type.
/// 5. Cancel on a bar with `expandable: false` leaves the text in the field.
///
/// ### How this screen proves it
///
/// Two bars: a fixed one (`expandable: false`, a 24 pt magnifying glass) and
/// an expandable one. The status lines show the query each bar last
/// reported through `onChanged`, and the expandable bar's controller state.
///
///  * **Type, then open a dialog and close it** (or AUTO): **bug:** both
///    fields come back empty (and the expandable bar collapsed) while the
///    status still shows the query. **Fixed:** both fields still show their
///    text, and the expandable bar is still open.
///  * **Keyboard:** with *autocorrect* off and capitalization *none*, typing
///    "kite" starts lowercase with no suggestions. *Email* shows the @ key.
///  * **Clear button:** with VoiceOver, the ⓧ in a non-empty field reads
///    "Clear, button" (the bug read "Close").
///  * **Icon size:** the fixed bar's magnifying glass is clearly bigger than
///    the expandable bar's 16 pt one.
///  * **Cancel** on the fixed bar: **fixed:** the field empties and the
///    status shows `""`.
///
/// Needs `CNTabBarRouteObserver()` (the probe entry: `OBSERVER=true`).
class Issue134SearchBarStateTestPage extends StatefulWidget {
  const Issue134SearchBarStateTestPage({super.key, this.autoCycle = false});

  /// Types into both bars, opens and closes a dialog, and prints
  /// `CNB_SHOT <step>`.
  final bool autoCycle;

  @override
  State<Issue134SearchBarStateTestPage> createState() =>
      _Issue134SearchBarStateTestPageState();
}

class _Issue134SearchBarStateTestPageState
    extends State<Issue134SearchBarStateTestPage> {
  final CNSearchBarController _fixed = CNSearchBarController();
  final CNSearchBarController _expandable = CNSearchBarController();
  String _fixedQuery = '';
  String _expandableQuery = '';
  bool _autocorrect = false;
  TextCapitalization _caps = TextCapitalization.none;
  TextInputType _keyboard = TextInputType.text;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    await _fixed.setText('kite');
    await _expandable.expand();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _expandable.setText('owl');
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    debugPrint('CNB_SHOT 134-typed');
    if (!mounted) return;
    _openDialog();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    debugPrint('CNB_SHOT 134-dialog');
    if (!mounted) return;
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    debugPrint('CNB_SHOT 134-after');
  }

  void _openDialog() {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('A modal'),
        content: const Text('The search bars go away under it.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#134: Search bar state'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Fixed (expandable: false, 24 pt icon)'),
            const SizedBox(height: 6),
            CNSearchBar(
              controller: _fixed,
              placeholder: 'Search usernames',
              expandable: false,
              searchIcon: const CNSymbol('magnifyingglass', size: 24),
              autocorrect: _autocorrect,
              textCapitalization: _caps,
              keyboardType: _keyboard,
              onChanged: (t) => setState(() => _fixedQuery = t),
            ),
            const SizedBox(height: 18),
            const Text('Expandable'),
            const SizedBox(height: 6),
            CNSearchBar(
              controller: _expandable,
              placeholder: 'Search',
              onChanged: (t) => setState(() => _expandableQuery = t),
              onExpandStateChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            Text(
              'fixed query: "$_fixedQuery"\n'
              'expandable query: "$_expandableQuery"\n'
              'expandable isExpanded: ${_expandable.isExpanded}',
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
            ),
            const SizedBox(height: 12),
            CupertinoButton.filled(
              onPressed: _openDialog,
              child: const Text('Open a dialog'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Text('autocorrect')),
                CupertinoSwitch(
                  value: _autocorrect,
                  onChanged: (v) => setState(() => _autocorrect = v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CupertinoSlidingSegmentedControl<TextCapitalization>(
              groupValue: _caps,
              onValueChanged: (v) {
                if (v != null) setState(() => _caps = v);
              },
              children: const {
                TextCapitalization.none: Text('none'),
                TextCapitalization.words: Text('words'),
                TextCapitalization.sentences: Text('sentences'),
              },
            ),
            const SizedBox(height: 8),
            CupertinoSlidingSegmentedControl<int>(
              groupValue: _keyboard == TextInputType.emailAddress
                  ? 1
                  : _keyboard == TextInputType.number
                  ? 2
                  : 0,
              onValueChanged: (v) => setState(
                () => _keyboard = switch (v) {
                  1 => TextInputType.emailAddress,
                  2 => TextInputType.number,
                  _ => TextInputType.text,
                },
              ),
              children: const {
                0: Text('text'),
                1: Text('email'),
                2: Text('number'),
              },
            ),
            const SizedBox(height: 18),
            const Text(
              'Bug: after the dialog both fields are empty while the queries '
              'above remain. Fixed: the text is still there.\n'
              'Cancel on the fixed bar empties it (query "").',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
