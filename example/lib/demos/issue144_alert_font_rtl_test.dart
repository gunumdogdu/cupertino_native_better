import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #144: `CNAlert` and `CNActionSheet` have no font options and stay
/// left to right in a right-to-left app.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/144
/// Reported by @Ashhad08.
///
/// ### The claims
///
/// 1. The title, message and buttons are always in the system font.
/// 2. In an Arabic app the title and message stay left-aligned on iOS 26.
///
/// ### How this screen proves it
///
/// Each button shows the same dialog in Arabic: "Alert" a `CNAlert`, "Sheet"
/// a `CNActionSheet`, both with `fontFamily: 'Tajawal'` and the page's
/// right-to-left `Directionality`. "System" shows the alert as before, for
/// comparison.
///
///  * **Font:** **fixed:** the title, message and both buttons are in
///    Tajawal, the title and the preferred button still bold, and Delete
///    still red. The font stays on while a button is pressed and while the
///    alert closes.
///  * **Right to left:** **fixed:** the title and message align to the
///    right, and the buttons are mirrored (Cancel on the right).
class Issue144AlertFontRtlTestPage extends StatefulWidget {
  const Issue144AlertFontRtlTestPage({super.key, this.autoCycle = false});

  /// Shows the styled alert, then the system one, printing
  /// `CNB_SHOT <step>`.
  final bool autoCycle;

  @override
  State<Issue144AlertFontRtlTestPage> createState() =>
      _Issue144AlertFontRtlTestPageState();
}

class _Issue144AlertFontRtlTestPageState
    extends State<Issue144AlertFontRtlTestPage> {
  String _result = '—';

  /// A context under the page's right-to-left [Directionality], which the
  /// dialogs take their direction from.
  BuildContext? _pageContext;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _run();
  }

  /// A new alert replaces the one on screen, so the steps need no taps.
  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    _alert(styled: true);
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    debugPrint('CNB_SHOT 144-alert');
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    _alert(styled: false);
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    debugPrint('CNB_SHOT 144-system');
  }

  Future<void> _alert({required bool styled}) async {
    final r = await CNAlert.show<String>(
      context: _pageContext ?? context,
      title: 'حذف الملاحظة؟',
      message: 'لا يمكن التراجع عن هذا الإجراء بعد حذف الملاحظة.',
      fontFamily: styled ? 'Tajawal' : null,
      textDirection: styled ? null : TextDirection.ltr,
      actions: const [
        CNAlertAction(label: 'إلغاء', value: 'cancel', isCancel: true),
        CNAlertAction(
          label: 'حذف',
          value: 'delete',
          isDestructive: true,
          isDefault: true,
        ),
      ],
    );
    if (mounted) setState(() => _result = 'alert → ${r?.value}');
  }

  Future<void> _sheet() async {
    final r = await CNActionSheet.show<String>(
      context: _pageContext ?? context,
      title: 'الملاحظة',
      message: 'ماذا تريد أن تفعل بهذه الملاحظة؟',
      fontFamily: 'Tajawal',
      cancelLabel: 'إلغاء',
      actions: const [
        CNActionSheetAction(label: 'مشاركة', value: 'share'),
        CNActionSheetAction(label: 'حذف', value: 'delete', isDestructive: true),
      ],
    );
    if (mounted) setState(() => _result = 'sheet → $r');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Builder(
        builder: (pageContext) {
          _pageContext = pageContext;
          return _page();
        },
      ),
    );
  }

  Widget _page() {
    return Builder(
      builder: (context) => CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('#144: Alert font, RTL'),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CupertinoButton.filled(
                onPressed: () => _alert(styled: true),
                child: const Text('Alert'),
              ),
              const SizedBox(height: 12),
              CupertinoButton.filled(
                onPressed: _sheet,
                child: const Text('Sheet'),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                onPressed: () => _alert(styled: false),
                child: const Text('System (as before)'),
              ),
              const SizedBox(height: 16),
              Text(
                'result: $_result',
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
