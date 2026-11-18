import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #173: `CNSearchBar` doesn't take right to left from Flutter, and
/// has no font options.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/173
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// 1. In an app that switches to Arabic in Dart (the system language stays
///    English), the iOS 26 bar stays left to right inside a right-to-left
///    `Directionality`: magnifying glass on the left, text starting on the
///    left, clear button and Cancel on the right. Now the bar takes the
///    ambient `Directionality` (or its `textDirection`), on iOS, macOS and
///    the bar drawn in Flutter, and a switch reaches a bar on screen.
/// 2. No `labelFontFamily`, `labelFontSize` or `labelFontWeight`, as the
///    other widgets have. Now they set the font of the text, the placeholder
///    and Cancel; a pubspec font (Tajawal here) works, and the size follows
///    Dynamic Type.
///
/// ### How this screen proves it
///
/// The Arabic bars sit in a right-to-left `Directionality` and use Tajawal;
/// the English bars below them are left to right in the system font. The
/// last bar starts left to right in the system font; AUTO switches it to
/// right to left, then to Tajawal 18 Medium, without creating it again.
///
///  * **Bug:** every Arabic bar looks like an English one: glass on the
///    left, placeholder and text on the left, clear button and Cancel on
///    the right, in San Francisco.
///  * **Fixed:** the Arabic bars mirror: magnifying glass on the right,
///    placeholder and text aligned right, clear button and Cancel (إلغاء)
///    on the left, collapsed bar at the right edge, all in Tajawal. The
///    switched bar mirrors in place, its Cancel turns into إلغاء, then it
///    changes font.
///
/// The placeholder is the field's own prompt (the one `placeholderColor`
/// colours): it sits on the right, and so does the caret of the empty
/// field when it is focused. Typed text sits on the right too, Latin text
/// included, in its own bidi order.
///
/// AUTO prints `CNB_SHOT 173-<step>` for rest, expanded, switched, font and
/// focused (the empty Arabic bar, its caret on the right).
class Issue173SearchBarRtlTestPage extends StatefulWidget {
  /// Creates the #173 test page.
  const Issue173SearchBarRtlTestPage({super.key, this.autoCycle = false});

  /// Opens the expandable bars, switches the last bar's direction and font,
  /// and prints `CNB_SHOT` lines.
  final bool autoCycle;

  @override
  State<Issue173SearchBarRtlTestPage> createState() =>
      _Issue173SearchBarRtlTestPageState();
}

class _Issue173SearchBarRtlTestPageState
    extends State<Issue173SearchBarRtlTestPage> {
  final _arabicEmpty = CNSearchBarController();
  final _arabicExpandable = CNSearchBarController();
  final _englishExpandable = CNSearchBarController();
  bool _switchedRtl = false;
  bool _switchedFont = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _auto();
  }

  Future<void> _auto() async {
    await Future<void>.delayed(const Duration(seconds: 5));
    debugPrint('CNB_SHOT 173-rest');
    await Future<void>.delayed(const Duration(seconds: 1));
    await _arabicExpandable.expand();
    await _englishExpandable.expand();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    debugPrint('CNB_SHOT 173-expanded');
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _switchedRtl = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    debugPrint('CNB_SHOT 173-switched');
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _switchedFont = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    debugPrint('CNB_SHOT 173-font');
    await Future<void>.delayed(const Duration(seconds: 1));
    await _arabicEmpty.focus();
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    debugPrint('CNB_SHOT 173-focused');
    await _arabicEmpty.unfocus();
    await Future<void>.delayed(const Duration(seconds: 1));
    debugPrint('CNB_DONE');
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 12, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
    ),
  );

  Widget _header(String text) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 16),
    child: Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const arabicFont = 'Tajawal';
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('#173 Search bar RTL'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => setState(() {
            _switchedRtl = !_switchedRtl;
            _switchedFont = _switchedRtl;
          }),
          child: Text(_switchedRtl ? 'LTR' : 'RTL'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header('العربية، من اليمين إلى اليسار'),
                  _label('فارغ: العنوان النائب على اليمين'),
                  CNSearchBar(
                    controller: _arabicEmpty,
                    expandable: false,
                    showCancelButton: false,
                    placeholder: 'ابحث عن سيارة',
                    labelFontFamily: arabicFont,
                  ),
                  _label('نص عربي، زر المسح وإلغاء على اليسار'),
                  const CNSearchBar(
                    expandable: false,
                    placeholder: 'ابحث عن سيارة',
                    cancelText: 'إلغاء',
                    initialText: 'تويوتا لاند كروزر',
                    labelFontFamily: arabicFont,
                  ),
                  _label('نص لاتيني'),
                  const CNSearchBar(
                    expandable: false,
                    showCancelButton: false,
                    placeholder: 'ابحث عن سيارة',
                    initialText: 'Land Cruiser 300',
                    labelFontFamily: arabicFont,
                  ),
                  _label('قابل للتوسيع'),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: CNSearchBar(
                      controller: _arabicExpandable,
                      placeholder: 'ابحث عن سيارة',
                      cancelText: 'إلغاء',
                      labelFontFamily: arabicFont,
                    ),
                  ),
                ],
              ),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header('English, left to right'),
                  _label('Empty'),
                  const CNSearchBar(
                    expandable: false,
                    showCancelButton: false,
                    placeholder: 'Search cars',
                  ),
                  _label('Text, clear button and Cancel on the right'),
                  const CNSearchBar(
                    expandable: false,
                    placeholder: 'Search cars',
                    initialText: 'Land Cruiser 300',
                  ),
                  _label('Expandable'),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: CNSearchBar(
                      controller: _englishExpandable,
                      placeholder: 'Search cars',
                    ),
                  ),
                  _header('Switched on screen'),
                  _label(
                    '${_switchedRtl ? 'Right to left' : 'Left to right'}, '
                    '${_switchedFont ? 'Tajawal 18 Medium' : 'system font'}',
                  ),
                ],
              ),
            ),
            CNSearchBar(
              expandable: false,
              placeholder: _switchedRtl ? 'ابحث عن سيارة' : 'Search cars',
              cancelText: _switchedRtl ? 'إلغاء' : 'Cancel',
              initialText: 'Hilux',
              textDirection: _switchedRtl
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              labelFontFamily: _switchedFont ? arabicFont : null,
              labelFontSize: _switchedFont ? 18 : null,
              labelFontWeight: _switchedFont ? FontWeight.w500 : null,
            ),
          ],
        ),
      ),
    );
  }
}
