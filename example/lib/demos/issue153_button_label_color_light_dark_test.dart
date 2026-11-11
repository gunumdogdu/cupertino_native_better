import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #153 reproduction: `CNButtonConfig.labelColor` is one colour on
/// light and dark glass.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/153
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// Without `labelColor`, a glass button's label follows the glass: light
/// over dark content, dark over light content. With `labelColor` that one
/// colour is used on both, so a dark colour disappears over dark content
/// and a light one over light content. There is no way to keep the
/// adaptation and still choose the two colours.
///
/// ### How this screen proves it
///
/// The reporter's badges, on a dark row, a light row, and a row that
/// switches between dark and light ("Flip", or every 1.5 s in AUTO). In
/// each row: 1 = no `labelColor`, 2 = dark grey, 3 = white, 4 = dark grey
/// on light glass and white on dark glass (`labelColorLight` /
/// `labelColorDark`).
///
///  * **Bug:** 2 is unreadable on the dark row, 3 on the light row.
///  * **Fixed:** badge 4 (a light and a dark label colour) shows the dark
///    grey on light glass and white on dark glass, switching with the glass
///    like badge 1. The popup menu button (5) does the same.
class Issue153ButtonLabelColorLightDarkTestPage extends StatefulWidget {
  const Issue153ButtonLabelColorLightDarkTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Flips the third row every 1.5 s.
  final bool autoCycle;

  @override
  State<Issue153ButtonLabelColorLightDarkTestPage> createState() =>
      _Issue153ButtonLabelColorLightDarkTestPageState();
}

class _Issue153ButtonLabelColorLightDarkTestPageState
    extends State<Issue153ButtonLabelColorLightDarkTestPage> {
  bool _flipDark = true;
  Timer? _timer;
  int _flips = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        debugPrint('CNB_SHOT flip0');
        _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
          if (!mounted) return;
          _flip();
          _flips++;
          Timer(const Duration(milliseconds: 900), () {
            if (mounted) debugPrint('CNB_SHOT flip$_flips');
          });
          if (_flips >= 4) _timer?.cancel();
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _flip() => setState(() => _flipDark = !_flipDark);

  Widget _row(String title, Color background) {
    final light = background.computeLuminance() > 0.5;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 150,
      color: background,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: light ? CupertinoColors.black : CupertinoColors.white,
                ),
              ),
              const Spacer(),
              // CNPopupMenuButton takes the same pair.
              CNPopupMenuButton(
                buttonLabel: '5 · Sort',
                buttonStyle: CNButtonStyle.glass,
                shrinkWrap: true,
                height: 32,
                labelFontSize: 13,
                labelFontWeight: FontWeight.w600,
                labelColorLight: const Color(0xFF262626),
                labelColorDark: CupertinoColors.white,
                items: const [CNPopupMenuItem(label: 'Newest')],
                onSelected: (_) {},
              ),
            ],
          ),
          const Spacer(),
          const Row(
            children: [
              _Counter(tag: '1'),
              SizedBox(width: 12),
              _Counter(tag: '2', labelColor: Color(0xFF262626)),
              SizedBox(width: 12),
              _Counter(tag: '3', labelColor: CupertinoColors.white),
              SizedBox(width: 12),
              _Counter(
                tag: '4',
                labelColorLight: Color(0xFF262626),
                labelColorDark: CupertinoColors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('#153: Label colour light/dark'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _flip,
          child: const Text('Flip'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            _row('Dark background', const Color(0xFF111111)),
            _row('Light background', const Color(0xFFF2F2F2)),
            _row(
              'Switches (Flip)',
              _flipDark ? const Color(0xFF111111) : const Color(0xFFF2F2F2),
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.tag,
    this.labelColor,
    this.labelColorLight,
    this.labelColorDark,
  });

  final String tag;
  final Color? labelColor;
  final Color? labelColorLight;
  final Color? labelColorDark;

  @override
  Widget build(BuildContext context) {
    return CNButton(
      label: '$tag · 3/12',
      onPressed: () {},
      config: CNButtonConfig(
        style: CNButtonStyle.glass,
        shrinkWrap: true,
        minHeight: 24,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        labelFontSize: 12,
        labelFontWeight: FontWeight.w600,
        labelColor: labelColor,
        labelColorLight: labelColorLight,
        labelColorDark: labelColorDark,
      ),
    );
  }
}
