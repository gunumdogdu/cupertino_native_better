import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #167: `CNPopupMenuButton`'s menu stays left to right in an app
/// that switches to Arabic in Dart.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/167
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// Since 2.5.0 the tab bar, segmented control, alert and action sheet take
/// Flutter's `Directionality`, but the popup menu button doesn't: with the
/// system language left in English, its menu keeps titles on the left and
/// icons and checkmarks on the left side.
///
/// ### How this screen proves it
///
/// The same menu twice, with icons, a checked item and a submenu: once left
/// to right, once inside `Directionality(textDirection: rtl)` with Arabic
/// titles. **Switch** flips the second one at run time. Open each menu:
///
///  * **Bug:** the right-to-left menu looks like the left-to-right one,
///    titles aligned left.
///  * **Fixed:** the right-to-left menu is mirrored: titles aligned right,
///    icons, checkmark and submenu arrow on the other side, and it follows
///    **Switch**.
class Issue167PopupMenuRtlTestPage extends StatefulWidget {
  /// Creates the #167 test page.
  const Issue167PopupMenuRtlTestPage({super.key, this.autoCycle = false});

  /// Prints `CNB_READY 167` once both buttons are up.
  final bool autoCycle;

  @override
  State<Issue167PopupMenuRtlTestPage> createState() =>
      _Issue167PopupMenuRtlTestPageState();
}

class _Issue167PopupMenuRtlTestPageState
    extends State<Issue167PopupMenuRtlTestPage> {
  int _sort = 0;
  bool _rtl = true;
  String _last = '—';

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      Future<void>.delayed(const Duration(seconds: 4), () {
        debugPrint('CNB_READY 167');
      });
    }
  }

  List<CNPopupMenuEntry> _items(List<String> t) => [
    CNPopupMenuItem(
      label: t[0],
      icon: const CNSymbol('clock'),
      checked: _sort == 0,
    ),
    CNPopupMenuItem(
      label: t[1],
      icon: const CNSymbol('clock.arrow.circlepath'),
      checked: _sort == 1,
    ),
    const CNPopupMenuDivider(),
    CNPopupMenuSubmenu(
      label: t[2],
      icon: const CNSymbol('arrow.up.arrow.down'),
      items: [
        CNPopupMenuItem(label: t[3]),
        CNPopupMenuItem(label: t[4]),
      ],
    ),
  ];

  Widget _row(String caption, List<String> titles, String label) {
    return Row(
      children: [
        Expanded(child: Text(caption)),
        CNPopupMenuButton(
          buttonLabel: label,
          buttonIcon: const CNSymbol('line.3.horizontal.decrease'),
          shrinkWrap: true,
          items: _items(titles),
          onPathSelected: (path) => setState(() {
            if (path.length == 1 && path.first < 2) _sort = path.first;
            _last = path.join(' › ');
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final caption = TextStyle(
      fontSize: 13,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('#167 Popup menu RTL'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => setState(() => _rtl = !_rtl),
          child: const Text('Switch'),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text('Left to right', style: caption),
              const SizedBox(height: 8),
              _row('Sort', const [
                'Newest',
                'Oldest',
                'More',
                'Price',
                'Distance',
              ], 'Sort'),
              const SizedBox(height: 32),
              Text(
                _rtl ? 'Right to left (Directionality)' : 'Switched back',
                style: caption,
              ),
              const SizedBox(height: 8),
              Directionality(
                textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
                child: _row('ترتيب', const [
                  'الأحدث',
                  'الأقدم',
                  'المزيد',
                  'السعر',
                  'المسافة',
                ], 'ترتيب'),
              ),
              const SizedBox(height: 32),
              Text('Last pick: $_last', style: caption),
            ],
          ),
        ),
      ),
    );
  }
}
