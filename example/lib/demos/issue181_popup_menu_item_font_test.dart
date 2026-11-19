import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #181: a font family for `CNPopupMenuButton`'s menu item titles.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/181
/// Reported by @Ashhad08.
///
/// ### The request
///
/// `labelFontFamily` (#141) sets the button's own label, but the menu that
/// opens from it always used the system font, so in an app with its own
/// font the menu looked out of place. `itemLabelFontFamily` sets the font
/// family of the item titles: only the family, so each title keeps the
/// menu's size (Dynamic Type included) and weight, and the rows keep the
/// system's layout.
///
/// ### How this screen proves it
///
/// A left-to-right and a right-to-left button with the same menu: a checked
/// item, an item with a subtitle, a submenu, an inline section with a title
/// and a destructive item. The segmented control picks the item font:
/// system, Tajawal (a pubspec font with Latin and Arabic glyphs, which the
/// plugin registers) or Georgia (built into iOS). Open each menu:
///
///  * **Before:** the titles are always in the system font.
///  * **Now:** item and submenu titles are in the picked family, at the
///    usual size; the subtitle and the section title stay in the system
///    font; the rows, icons and checkmark keep their places, and the right
///    to left menu stays mirrored.
///
/// AUTO prints `CNB_READY 181`; ITEM_FONT=Tajawal|Georgia picks the font.
class Issue181PopupMenuItemFontTestPage extends StatefulWidget {
  /// Creates the #181 test page.
  const Issue181PopupMenuItemFontTestPage({
    super.key,
    this.autoCycle = false,
    this.initialFont = 'Tajawal',
  });

  /// Prints `CNB_READY 181` once the buttons are up.
  final bool autoCycle;

  /// The item font picked at the start: 'system', 'Tajawal' or 'Georgia'.
  final String initialFont;

  @override
  State<Issue181PopupMenuItemFontTestPage> createState() =>
      _Issue181PopupMenuItemFontTestPageState();
}

class _Issue181PopupMenuItemFontTestPageState
    extends State<Issue181PopupMenuItemFontTestPage> {
  static const _fonts = ['system', 'Tajawal', 'Georgia'];
  late String _font = _fonts.contains(widget.initialFont)
      ? widget.initialFont
      : 'Tajawal';
  int _sort = 0;
  String _last = '—';

  String? get _family => _font == 'system' ? null : _font;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      Future<void>.delayed(const Duration(seconds: 4), () {
        debugPrint('CNB_READY 181');
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
      subtitle: t[2],
      icon: const CNSymbol('arrow.up'),
      checked: _sort == 1,
    ),
    CNPopupMenuSubmenu(
      label: t[3],
      icon: const CNSymbol('line.3.horizontal.decrease'),
      items: [
        CNPopupMenuItem(label: t[4]),
        CNPopupMenuItem(label: t[5]),
      ],
    ),
    CNPopupMenuSubmenu(
      label: t[6],
      style: CNPopupMenuSubmenuStyle.inline,
      items: [CNPopupMenuItem(label: t[7], icon: const CNSymbol('star'))],
    ),
    CNPopupMenuItem(
      label: t[8],
      icon: const CNSymbol('trash'),
      isDestructive: true,
    ),
  ];

  static const _english = [
    'Newest',
    'Price: low to high',
    'Subtitle stays system',
    'Filter',
    'Sedan',
    'SUV',
    'Section title',
    'Favourites',
    'Delete',
  ];

  static const _arabic = [
    'الأحدث',
    'السعر: من الأقل إلى الأعلى',
    'العنوان الفرعي بخط النظام',
    'تصفية',
    'سيدان',
    'دفع رباعي',
    'عنوان القسم',
    'المفضلة',
    'حذف',
  ];

  void _select(String tag, List<int> path) {
    setState(() {
      if (path.length == 1 && path.first < 2) _sort = path.first;
      _last = '$tag: ${path.join(' › ')}';
    });
  }

  Widget _row(String caption, String label, List<String> titles, String tag) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              caption,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
          CNPopupMenuButton(
            buttonLabel: label,
            buttonIcon: const CNSymbol('arrow.up.arrow.down', size: 14),
            imagePadding: 4,
            labelFontFamily: _family,
            itemLabelFontFamily: _family,
            shrinkWrap: true,
            buttonStyle: CNButtonStyle.plain,
            items: _items(titles),
            onPathSelected: (path) => _select(tag, path),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#181 Menu item font'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _font,
              children: const {
                'system': Text('System'),
                'Tajawal': Text('Tajawal'),
                'Georgia': Text('Georgia'),
              },
              onValueChanged: (f) {
                if (f != null) setState(() => _font = f);
              },
            ),
            const SizedBox(height: 8),
            _row('Left to right', 'Sort', _english, 'LTR'),
            const SizedBox(height: 120),
            Directionality(
              textDirection: TextDirection.rtl,
              child: _row('Right to left', 'ترتيب', _arabic, 'RTL'),
            ),
            const SizedBox(height: 24),
            Text('Last selected: $_last', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
