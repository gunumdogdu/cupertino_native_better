import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issues #167, #168 and #169: `CNPopupMenuButton`.
///
/// * https://github.com/gunumdogdu/cupertino_native_better/issues/167
/// * https://github.com/gunumdogdu/cupertino_native_better/issues/168
/// * https://github.com/gunumdogdu/cupertino_native_better/issues/169
///
/// Reported by @Ashhad08.
///
/// ### #167: right to left
///
/// Open the menu of A (inside `Directionality.rtl`, system language
/// English).
///
///  * **Bug:** titles left-aligned, icons and the checkmark on the left, the
///    submenu chevron pointing right.
///  * **Fixed:** the menu is mirrored: titles right-aligned, icons and the
///    checkmark on the right, the chevron pointing left.
///
/// ### #168: checkedIcon
///
/// Open B and C.
///
///  * **Bug:** (no option) the system checkmark.
///  * **Fixed:** the checked row shows a purple `checkmark.circle.fill`; the
///    other rows' labels stay aligned with it, with or without icons (C).
///
/// ### #169: contentPadding
///
/// The red outline is the button's frame, at the end of a row with 16 pt
/// padding.
///
///  * **Bug:** (no option) "Sort" sits ~12 pt inside its frame.
///  * **Fixed:** with `contentPadding: EdgeInsetsDirectional.zero` the frame
///    ends at the label, so the label lines up with the row's padding.
class Issue167169PopupMenuTestPage extends StatelessWidget {
  const Issue167169PopupMenuTestPage({super.key});

  static const _sorts = [
    CNPopupMenuItem(label: 'Newest', checked: true),
    CNPopupMenuItem(label: 'Price: low to high'),
    CNPopupMenuItem(label: 'Price: high to low'),
  ];

  Widget _row(String title, Widget button) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: CupertinoColors.systemGroupedBackground,
    child: Row(
      children: [
        Expanded(child: Text(title)),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemRed, width: 0.5),
          ),
          child: button,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 13, color: CupertinoColors.systemGrey);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#167 / #168 / #169 Popup'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('A: Directionality.rtl, Arabic', style: label),
            ),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: CNPopupMenuButton(
                    buttonLabel: 'ترتيب',
                    buttonIcon: const CNSymbol('arrow.up.arrow.down'),
                    shrinkWrap: true,
                    items: const [
                      CNPopupMenuItem(
                        label: 'الأحدث',
                        icon: CNSymbol('clock'),
                        checked: true,
                      ),
                      CNPopupMenuItem(
                        label: 'الأقدم',
                        icon: CNSymbol('clock.arrow.circlepath'),
                      ),
                      CNPopupMenuDivider(),
                      CNPopupMenuSubmenu(
                        label: 'السعر',
                        icon: CNSymbol('tag'),
                        items: [
                          CNPopupMenuItem(label: 'من الأقل'),
                          CNPopupMenuItem(label: 'من الأعلى'),
                        ],
                      ),
                    ],
                    onPathSelected: (_) {},
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text('B: checkedIcon, purple, 18 pt', style: label),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CNPopupMenuButton(
                  buttonLabel: 'Newest',
                  shrinkWrap: true,
                  checkedIcon: const CNSymbol(
                    'checkmark.circle.fill',
                    size: 18,
                    color: Color(0xFF990099),
                  ),
                  items: _sorts,
                  onSelected: (_) {},
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text('C: checkedIcon with item icons', style: label),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CNPopupMenuButton(
                  buttonLabel: 'With icons',
                  shrinkWrap: true,
                  checkedIcon: const CNSymbol(
                    'checkmark.circle.fill',
                    color: Color(0xFF990099),
                  ),
                  items: const [
                    CNPopupMenuItem(
                      label: 'Newest',
                      icon: CNSymbol('clock'),
                      checked: true,
                    ),
                    CNPopupMenuItem(
                      label: 'Oldest',
                      icon: CNSymbol('clock.arrow.circlepath'),
                    ),
                    CNPopupMenuItem(
                      label: 'Nearest',
                      icon: CNSymbol('location'),
                    ),
                  ],
                  onSelected: (_) {},
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text('D: contentPadding (red = frame)', style: label),
            ),
            _row(
              'Default insets',
              CNPopupMenuButton(
                buttonLabel: 'Sort',
                shrinkWrap: true,
                items: _sorts,
                onSelected: (_) {},
              ),
            ),
            const SizedBox(height: 12),
            _row(
              'contentPadding: zero',
              CNPopupMenuButton(
                buttonLabel: 'Sort',
                shrinkWrap: true,
                contentPadding: EdgeInsetsDirectional.zero,
                items: _sorts,
                onSelected: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
