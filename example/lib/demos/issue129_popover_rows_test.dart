import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #129: read-only rows for informational popovers (feature request),
/// and separators that miss the text of rows without an icon (bug).
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/129
/// Reported by @cogwheel0.
///
/// ### The claims
///
/// 1. **Request:** every `CNPopoverRow` is a button. A popover that only
///    shows figures (label + `trailingText`) closes when a figure is tapped,
///    and VoiceOver calls each figure "button".
/// 2. **Bug:** when one row has a `leadingSymbol` and another does not, the
///    separators are inset to where the text of the row with the icon
///    starts, but the text of the row without one starts at the edge.
///
/// In the code, every row reserves an icon column (28 pt + 12 pt gap) when
/// any row has an icon, and the separators are inset by that column. A row
/// with no icon builds an empty view for the column, and SwiftUI gives an
/// empty view no frame, so that row's text moves back to the edge.
///
/// ### How this screen proves it
///
///  * **Mixed icons:** three rows; only the middle one has an icon.
///    **Bug:** the top and bottom rows' titles start at the popover's left
///    edge, left of where the separators start. **Fixed:** all three titles
///    start in one column, where the separators start.
///  * **Figures:** a popover of label/value figures, as in the report, with
///    `readOnly: true` (the fix). **Fixed:** tapping a figure does nothing
///    and the popover stays open; VoiceOver reads "Prompt, 1,204" with no
///    "button". (Before, a tap closed the popover and the status showed the
///    figure's id.)
///
/// [autoCycle] opens *Mixed icons* by itself and prints
/// `CNB_SHOT 129-mixed`.
class Issue129PopoverRowsTestPage extends StatefulWidget {
  const Issue129PopoverRowsTestPage({super.key, this.autoCycle = false});

  /// Opens the mixed-icons popover on its own, for simulator runs.
  final bool autoCycle;

  @override
  State<Issue129PopoverRowsTestPage> createState() =>
      _Issue129PopoverRowsTestPageState();
}

class _Issue129PopoverRowsTestPageState
    extends State<Issue129PopoverRowsTestPage> {
  final GlobalKey _mixedKey = GlobalKey();
  final GlobalKey _figuresKey = GlobalKey();
  String _status = 'Open a popover.';

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        _showMixed();
        Future<void>.delayed(
          const Duration(milliseconds: 1500),
          () => debugPrint('CNB_SHOT 129-mixed'),
        );
      });
    }
  }

  Future<void> _showMixed() async {
    final id = await CNPopover.show(
      context: context,
      anchorKey: _mixedKey,
      content: const CNPopoverContent(
        title: 'Mixed icons',
        rows: <CNPopoverRow>[
          CNPopoverRow(
            id: 'plain-1',
            item: CNListItem(title: 'No icon (top)'),
          ),
          CNPopoverRow(
            id: 'icon',
            item: CNListItem(
              title: 'With an icon',
              leadingSymbol: CNSymbol('star'),
            ),
          ),
          CNPopoverRow(
            id: 'plain-2',
            item: CNListItem(title: 'No icon (bottom)'),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _status = 'mixed → ${id ?? 'null'}');
  }

  Future<void> _showFigures() async {
    final id = await CNPopover.show(
      context: context,
      anchorKey: _figuresKey,
      content: const CNPopoverContent(
        title: 'Details',
        rows: <CNPopoverRow>[
          CNPopoverRow(
            id: 'prompt',
            readOnly: true,
            item: CNListItem(title: 'Prompt', trailingText: '1,204'),
          ),
          CNPopoverRow(
            id: 'response',
            readOnly: true,
            item: CNListItem(title: 'Response', trailingText: '318'),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _status = 'figures → ${id ?? 'null'}');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#129: Popover rows'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                CupertinoButton.filled(
                  key: _mixedKey,
                  sizeStyle: CupertinoButtonSize.medium,
                  onPressed: _showMixed,
                  child: const Text('Mixed icons'),
                ),
                const SizedBox(width: 12),
                CupertinoButton.filled(
                  key: _figuresKey,
                  sizeStyle: CupertinoButtonSize.medium,
                  onPressed: _showFigures,
                  child: const Text('Figures'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _status,
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
            ),
            const SizedBox(height: 20),
            const Text(
              'Mixed icons — Bug: the two rows without an icon start their '
              'title at the left edge, left of the separators. Fixed: all '
              'three titles line up where the separators start.\n\n'
              'Figures (readOnly rows) — a tap on a figure does nothing and '
              'the popover stays open; VoiceOver reads "Prompt, 1,204" with '
              'no "button". Close it by tapping outside.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
