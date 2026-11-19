import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #179: a right-to-left `CNPopupMenuButton` with an icon and
/// `contentPadding: EdgeInsetsDirectional.zero` (#169) is too narrow for
/// its label, which wraps and, at `height: 22`, is cut.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/179
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// It takes all three together: right to left, an image and zero content
/// insets. The same Arabic label left to right is fine, and so is the same
/// button without an icon or with the style's insets.
///
/// ### How this screen proves it
///
/// The six rows from the issue: shrink-wrapped buttons with a 14 pt
/// `arrow.up.arrow.down`, `imagePadding: 4` and a 16 pt bold label.
///
///  * **Bug:** in rows A and C the label is on two lines (A cut at 22 pt).
///  * **Fixed:** every row shows its label on one line, icon beside it.
///
/// AUTO prints `CNB_READY 179`.
class Issue179PopupMenuRtlZeroPaddingTestPage extends StatelessWidget {
  /// Creates the #179 test page.
  const Issue179PopupMenuRtlZeroPaddingTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Prints `CNB_READY 179` once the rows are up.
  final bool autoCycle;

  static const _arabic = 'سيارات معروضة';

  @override
  Widget build(BuildContext context) {
    if (autoCycle) {
      Future<void>.delayed(const Duration(seconds: 4), () {
        debugPrint('CNB_READY 179');
      });
    }
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#179 RTL, icon, zero padding'),
      ),
      child: SafeArea(
        child: ListView(
          children: const [
            _Row(
              tag: 'A  RTL, Arabic, contentPadding: zero, h22',
              label: _arabic,
              dir: TextDirection.rtl,
              padding: EdgeInsetsDirectional.zero,
            ),
            _Row(
              tag: 'B  RTL, Arabic, contentPadding: null, h22',
              label: _arabic,
              dir: TextDirection.rtl,
              padding: null,
            ),
            _Row(
              tag: 'C  RTL, Arabic, contentPadding: zero, h44',
              label: _arabic,
              dir: TextDirection.rtl,
              padding: EdgeInsetsDirectional.zero,
              height: 44,
            ),
            _Row(
              tag: 'D  RTL, Arabic, contentPadding: zero, no icon, h22',
              label: _arabic,
              dir: TextDirection.rtl,
              padding: EdgeInsetsDirectional.zero,
              icon: false,
            ),
            _Row(
              tag: 'E  LTR, Arabic, contentPadding: zero, h22',
              label: _arabic,
              dir: TextDirection.ltr,
              padding: EdgeInsetsDirectional.zero,
            ),
            _Row(
              tag: 'F  LTR, English, contentPadding: zero, h22',
              label: 'Featured cars',
              dir: TextDirection.ltr,
              padding: EdgeInsetsDirectional.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.tag,
    required this.label,
    required this.dir,
    required this.padding,
    this.height = 22,
    this.icon = true,
  });

  static const _purple = Color(0xFF990099);

  final String tag;
  final String label;
  final TextDirection dir;
  final EdgeInsetsDirectional? padding;
  final double height;
  final bool icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tag,
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: dir,
            child: Row(
              children: [
                const Expanded(
                  child: Text('24,510', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 16),
                CNPopupMenuButton(
                  buttonLabel: label,
                  buttonIcon: icon
                      ? const CNSymbol(
                          'arrow.up.arrow.down',
                          size: 14,
                          color: _purple,
                          mode: CNSymbolRenderingMode.monochrome,
                        )
                      : null,
                  imagePadding: icon ? 4 : null,
                  contentPadding: padding,
                  labelFontSize: 16,
                  labelFontWeight: FontWeight.w700,
                  labelColor: _purple,
                  tint: _purple,
                  height: height,
                  shrinkWrap: true,
                  buttonStyle: CNButtonStyle.plain,
                  items: [
                    CNPopupMenuItem(label: label, checked: true),
                    const CNPopupMenuItem(label: 'Other'),
                  ],
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
