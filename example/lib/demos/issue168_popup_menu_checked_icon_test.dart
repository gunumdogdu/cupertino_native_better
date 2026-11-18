import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #168: a custom symbol for the checked item of a
/// `CNPopupMenuButton` menu, and of a `CNPopover` row.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/168
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// `CNPopupMenuItem(checked: true)` always shows the system checkmark. An
/// app that marks the selection with another symbol, such as
/// `checkmark.circle.fill` in its own colour and size, had no way to.
///
/// ### How this screen proves it
///
/// Three sort buttons with the same choices: the system checkmark,
/// `checkedIcon: checkmark.circle.fill` (purple, 18 pt), and items with
/// icons where the checked one shows a per-item `checkedIcon`. **Popover**
/// opens a `CNPopover` whose checked row uses `checkedIcon` too. Pick
/// another sort in a menu and open it again:
///
///  * **Before:** every menu shows the plain system checkmark.
///  * **Now:** the second and third menus mark the choice with their
///    symbol, the titles of every row stay lined up, and VoiceOver reads
///    the checked row as selected.
class Issue168PopupMenuCheckedIconTestPage extends StatefulWidget {
  /// Creates the #168 test page.
  const Issue168PopupMenuCheckedIconTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Prints `CNB_READY 168` once the buttons are up.
  final bool autoCycle;

  @override
  State<Issue168PopupMenuCheckedIconTestPage> createState() =>
      _Issue168PopupMenuCheckedIconTestPageState();
}

class _Issue168PopupMenuCheckedIconTestPageState
    extends State<Issue168PopupMenuCheckedIconTestPage> {
  static const _sorts = ['Newest', 'Price: low to high', 'Price: high to low'];
  static const _icons = ['clock', 'arrow.up', 'arrow.down'];
  int _sort = 0;
  final _popoverKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      Future<void>.delayed(const Duration(seconds: 4), () {
        debugPrint('CNB_READY 168');
      });
      // The popover, once the menus have been looked at.
      Future<void>.delayed(const Duration(seconds: 25), () {
        if (!mounted) return;
        _openPopover();
        Future<void>.delayed(const Duration(seconds: 2), () {
          debugPrint('CNB_SHOT 168-popover');
        });
      });
    }
  }

  Widget _row(String caption, Widget button) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(child: Text(caption)),
          button,
        ],
      ),
    );
  }

  Future<void> _openPopover() async {
    final id = await CNPopover.show(
      context: context,
      anchorKey: _popoverKey,
      content: CNPopoverContent(
        title: 'Sort by',
        rows: [
          for (var i = 0; i < _sorts.length; i++)
            CNPopoverRow(
              id: '$i',
              item: CNListItem(title: _sorts[i]),
              checked: i == _sort,
              checkedIcon: const CNSymbol(
                'checkmark.circle.fill',
                size: 18,
                color: CupertinoColors.systemPurple,
              ),
            ),
        ],
      ),
    );
    if (id != null && mounted) setState(() => _sort = int.parse(id));
  }

  @override
  Widget build(BuildContext context) {
    final caption = TextStyle(
      fontSize: 13,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#168 Checked icon'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text('System checkmark', style: caption),
              _row(
                'Sort',
                CNPopupMenuButton(
                  buttonLabel: _sorts[_sort],
                  shrinkWrap: true,
                  items: [
                    for (var i = 0; i < _sorts.length; i++)
                      CNPopupMenuItem(label: _sorts[i], checked: i == _sort),
                  ],
                  onSelected: (i) => setState(() => _sort = i),
                ),
              ),
              const SizedBox(height: 20),
              Text('checkedIcon: checkmark.circle.fill', style: caption),
              _row(
                'Sort',
                CNPopupMenuButton(
                  buttonLabel: _sorts[_sort],
                  shrinkWrap: true,
                  checkedIcon: const CNSymbol(
                    'checkmark.circle.fill',
                    size: 18,
                    color: CupertinoColors.systemPurple,
                  ),
                  items: [
                    for (var i = 0; i < _sorts.length; i++)
                      CNPopupMenuItem(label: _sorts[i], checked: i == _sort),
                  ],
                  onSelected: (i) => setState(() => _sort = i),
                ),
              ),
              const SizedBox(height: 20),
              Text('Items with icons, per-item checkedIcon', style: caption),
              _row(
                'Sort',
                CNPopupMenuButton(
                  buttonLabel: _sorts[_sort],
                  shrinkWrap: true,
                  items: [
                    for (var i = 0; i < _sorts.length; i++)
                      CNPopupMenuItem(
                        label: _sorts[i],
                        icon: CNSymbol(_icons[i]),
                        checked: i == _sort,
                        checkedIcon: const CNSymbol(
                          'checkmark.seal.fill',
                          color: CupertinoColors.systemGreen,
                        ),
                      ),
                  ],
                  onSelected: (i) => setState(() => _sort = i),
                ),
              ),
              const SizedBox(height: 20),
              Text('CNPopover rows', style: caption),
              _row(
                'Sort',
                CupertinoButton(
                  key: _popoverKey,
                  padding: EdgeInsets.zero,
                  onPressed: _openPopover,
                  child: const Text('Popover'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
