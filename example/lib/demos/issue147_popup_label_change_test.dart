import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #147 reproduction: changing a `CNPopupMenuButton`'s `buttonLabel`
/// recreates the native button, so it blinks out and its row jumps.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/147
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// The platform view's key holds `buttonLabel` and every item label, so a
/// new label disposes of the native button and creates another, although
/// `setButtonTitle` and `setItems` can update it in place. For a frame the
/// button is gone and the row lays out without it ("Save" jumps right), and
/// the new button then goes through three widths.
///
/// ### How this screen proves it
///
/// The reporter's results header: "1,234 results", "Save", and a sort
/// button showing the chosen sort. The sort changes every 1.5 s (AUTO) or
/// from the menu. The line under it lists every x position "Save" takes,
/// frame by frame.
///
///  * **Bug:** on each change "Save" jumps to the right edge (the button is
///    gone for a frame) and back, through intermediate widths.
///  * **Fixed:** "Save" moves once per change, by the width difference
///    between the old and the new label.
class Issue147PopupLabelChangeTestPage extends StatefulWidget {
  const Issue147PopupLabelChangeTestPage({super.key, this.autoCycle = false});

  /// Changes the sort every 1.5 s and prints `CNB_SHOT <step>` and the
  /// positions "Save" took.
  final bool autoCycle;

  @override
  State<Issue147PopupLabelChangeTestPage> createState() =>
      _Issue147PopupLabelChangeTestPageState();
}

const _sorts = ['Newest', 'Oldest', 'Price (high)', 'Price (low)', 'Name'];

class _Issue147PopupLabelChangeTestPageState
    extends State<Issue147PopupLabelChangeTestPage> {
  final GlobalKey _saveKey = GlobalKey();
  int _selected = 0;
  double? _saveX;
  final List<String> _positions = <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_track);
    if (widget.autoCycle) _run();
  }

  /// Records every distinct x position of "Save", frame by frame.
  void _track(Duration _) {
    if (!mounted) return;
    final box = _saveKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final x = box.localToGlobal(Offset.zero).dx;
      if (x != _saveX) {
        _saveX = x;
        _positions.add(x.toStringAsFixed(0));
        if (_positions.length > 40) _positions.removeAt(0);
        setState(() {});
      }
    }
    WidgetsBinding.instance.addPostFrameCallback(_track);
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 4));
    for (var i = 1; i <= 4; i++) {
      if (!mounted) return;
      setState(() => _selected = i % _sorts.length);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
    debugPrint('CNB_147 save x positions: ${_positions.join(' ')}');
    debugPrint('CNB_SHOT 147-done');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#147: Popup label change'),
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '1,234 results',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Text(
                    'Save',
                    key: _saveKey,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.systemIndigo,
                    ),
                  ),
                  const SizedBox(width: 16),
                  CNPopupMenuButton(
                    buttonLabel: _sorts[_selected],
                    buttonCustomIcon: CupertinoIcons.arrow_up_arrow_down,
                    buttonCustomIconColor: CupertinoColors.systemIndigo,
                    imagePadding: 4,
                    labelFontSize: 16,
                    labelFontWeight: FontWeight.w700,
                    labelColor: CupertinoColors.systemIndigo,
                    height: 24,
                    shrinkWrap: true,
                    buttonStyle: CNButtonStyle.plain,
                    keepsSourceVisible: true,
                    autoHideOnModal: false,
                    items: [
                      for (var i = 0; i < _sorts.length; i++)
                        CNPopupMenuItem(
                          label: _sorts[i],
                          checked: i == _selected,
                        ),
                    ],
                    onSelected: (i) => setState(() => _selected = i),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '"Save" x: ${_positions.join(' ')}',
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Bug: "Save" jumps right and back on every change (the '
                'button is recreated). Fixed: it moves once, by the width '
                'difference of the labels.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
