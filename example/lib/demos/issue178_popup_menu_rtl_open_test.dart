import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #178: a right-to-left `CNPopupMenuButton` menu opens left to right,
/// then jumps to right to left when the open animation ends.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/178
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// Since 2.8.0 (#167) the menu of a button under a right-to-left
/// `Directionality` is mirrored, with the system language left in English.
/// But it is mirrored only once the open animation has ended: for the whole
/// animation (about 0.8 s) the titles, icons and checkmark are on the left,
/// then they jump to the right. `textDirection: rtl` on the button does the
/// same.
///
/// ### How this screen proves it
///
/// The page is right to left. Button **A** takes it from `Directionality`,
/// button **B** from `textDirection`. Open each menu and watch it grow:
///
///  * **Bug:** the rows grow left to right (titles on the left), then jump.
///  * **Fixed:** the rows are right to left (titles and checkmark on the
///    right) from the first frame, with no jump.
///
/// **New button** adds a third right-to-left button after a menu has been
/// opened: its icon must stay on the right of its title, like A's, so
/// opening a menu doesn't change how views made later are laid out.
///
/// AUTO prints `CNB_READY 178`.
class Issue178PopupMenuRtlOpenTestPage extends StatefulWidget {
  /// Creates the #178 test page.
  const Issue178PopupMenuRtlOpenTestPage({super.key, this.autoCycle = false});

  /// Prints `CNB_READY 178` once the buttons are up.
  final bool autoCycle;

  @override
  State<Issue178PopupMenuRtlOpenTestPage> createState() =>
      _Issue178PopupMenuRtlOpenTestPageState();
}

class _Issue178PopupMenuRtlOpenTestPageState
    extends State<Issue178PopupMenuRtlOpenTestPage> {
  int _sort = 0;
  bool _showNew = false;
  String _last = '—';

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      Future<void>.delayed(const Duration(seconds: 4), () {
        debugPrint('CNB_READY 178');
      });
    }
  }

  List<CNPopupMenuEntry> get _items => [
    CNPopupMenuItem(
      label: 'الأحدث',
      icon: const CNSymbol('clock'),
      checked: _sort == 0,
    ),
    CNPopupMenuItem(
      label: 'السعر: من الأقل إلى الأعلى',
      icon: const CNSymbol('arrow.up'),
      checked: _sort == 1,
    ),
    CNPopupMenuItem(
      label: 'السعر: من الأعلى إلى الأقل',
      icon: const CNSymbol('arrow.down'),
      checked: _sort == 2,
    ),
    const CNPopupMenuItem(
      label: 'حذف',
      icon: CNSymbol('trash'),
      isDestructive: true,
    ),
  ];

  void _select(String tag, int i) {
    setState(() {
      if (i < 3) _sort = i;
      _last = '$tag: $i';
    });
  }

  Widget _row(String tag, String caption, Widget button) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          button,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('#178 RTL menu, first frame'),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _row(
                'A',
                'Directionality (no textDirection)',
                CNPopupMenuButton.icon(
                  buttonCustomIcon: CupertinoIcons.ellipsis_circle,
                  preserveTopToBottomOrder: true,
                  buttonStyle: CNButtonStyle.plain,
                  items: _items,
                  onSelected: (i) => _select('A', i),
                ),
              ),
              const SizedBox(height: 180),
              _row(
                'B',
                'textDirection: TextDirection.rtl',
                CNPopupMenuButton.icon(
                  buttonCustomIcon: CupertinoIcons.ellipsis_circle,
                  preserveTopToBottomOrder: true,
                  buttonStyle: CNButtonStyle.plain,
                  textDirection: TextDirection.rtl,
                  items: _items,
                  onSelected: (i) => _select('B', i),
                ),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: () => setState(() => _showNew = !_showNew),
                child: Text(_showNew ? 'Remove new button' : 'New button'),
              ),
              const SizedBox(height: 12),
              if (_showNew)
                _row(
                  'C',
                  'Made after a menu opened: icon right of the title',
                  CNPopupMenuButton(
                    buttonLabel: 'ترتيب',
                    buttonIcon: const CNSymbol('arrow.up.arrow.down', size: 14),
                    imagePadding: 4,
                    shrinkWrap: true,
                    buttonStyle: CNButtonStyle.plain,
                    items: _items,
                    onSelected: (i) => _select('C', i),
                  ),
                ),
              const SizedBox(height: 12),
              Text('Last selected: $_last', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
