import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #169: no way to remove `CNPopupMenuButton`'s internal padding.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/169
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// The native button keeps its style's content insets, about 12 pt on each
/// side. A "Sort" button at the end of a list header then sits 12 pt in
/// from the row's 16 pt padding; reducing the row's padding to make up for
/// it moves the button's frame, and the menu the system aligns to it, to
/// the screen edge.
///
/// ### How this screen proves it
///
/// List headers with a 16 pt padding, a red line at that padding on each
/// side. The first header has the default insets, the second
/// `contentPadding: EdgeInsetsDirectional.zero`, the third 4 pt on each
/// side. `CNButton` rows below do the same with
/// `CNButtonConfig.contentPadding`. AUTO prints `CNB_SHOT 169`.
///
///  * **Before:** each label ends about 12 pt left of the red line.
///  * **Now:** with zero padding the label ends on the red line, and the
///    shrink-wrapped button is as wide as its label.
class Issue169ButtonContentPaddingTestPage extends StatelessWidget {
  /// Creates the #169 test page.
  const Issue169ButtonContentPaddingTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Prints `CNB_SHOT 169` once the buttons are up.
  final bool autoCycle;

  static const _items = [
    CNPopupMenuItem(label: 'Newest', checked: true),
    CNPopupMenuItem(label: 'Price: low to high'),
  ];

  Widget _header(String title, EdgeInsetsDirectional? padding) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(child: Text(title)),
          CNPopupMenuButton(
            buttonLabel: 'Sort',
            shrinkWrap: true,
            contentPadding: padding,
            items: _items,
            onSelected: (_) {},
          ),
        ],
      ),
    );
  }

  Widget _buttonRow(String title, EdgeInsetsDirectional? padding) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(child: Text(title)),
          CNButton(
            label: 'Filter',
            onPressed: () {},
            config: CNButtonConfig(
              style: CNButtonStyle.glass,
              shrinkWrap: true,
              contentPadding: padding,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (autoCycle) {
      Future<void>.delayed(const Duration(seconds: 5), () {
        debugPrint('CNB_SHOT 169');
      });
    }
    final caption = TextStyle(
      fontSize: 13,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#169 Content padding'),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // The row padding, on each side.
            for (final side in [true, false])
              Positioned(
                top: 0,
                bottom: 0,
                left: side ? 16 : null,
                right: side ? null : 16,
                child: Container(width: 1, color: CupertinoColors.systemRed),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Text('CNPopupMenuButton', style: caption),
                  _header('Default insets', null),
                  _header('contentPadding: zero', EdgeInsetsDirectional.zero),
                  _header(
                    'contentPadding: 4 on each side',
                    const EdgeInsetsDirectional.symmetric(horizontal: 4),
                  ),
                  const SizedBox(height: 24),
                  Text('CNButton', style: caption),
                  _buttonRow('Default insets', null),
                  _buttonRow(
                    'contentPadding: 6 on each side',
                    const EdgeInsetsDirectional.symmetric(horizontal: 6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
