import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #132: an icon-only `CNTabBar` has no accessibility names, and
/// `height` is ignored on iOS 26.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/132
/// Reported by @cogwheel0.
///
/// ### The claims
///
/// 1. **No accessibility name.** A tab with an icon and no `label` gets no
///    title and no `accessibilityLabel`, so VoiceOver reads only "Tab, 1 of
///    3". There is no way to name an icon-only tab without showing a title.
/// 2. **`height` ignored on iOS 26.** A bar given a shorter `height` keeps
///    its own height on iOS 26 (`_keepsNativeHeight`), because a squeezed
///    iOS 26 bar put its labels over its icons. An icon-only bar has no
///    labels to collide. iOS 27 honours `height`.
///
/// ### How this screen proves it
///
/// The bar sits at the very bottom, icon-only, `height: 89` as in the report
/// (14 pt room for the selection pill + a 54 pt platter + 21 pt below). Two
/// red lines mark the top of the 89 pt box and where a 54 pt platter would
/// end its top edge (14 pt below it).
///
///  * **Names (any iOS, PNG icons as in the report):** turn on VoiceOver
///    and touch each tab. With *semanticLabel* on (the fix,
///    `CNTabBarItem.semanticLabel`) VoiceOver says "Clock", "Done",
///    "Coins". Off, it is the bar as before: "Tab, 1 of 3" with no name.
///    *SF Symbols* shows whether UIKit names a symbol tab by itself.
///  * **Height (iOS 26 only):** **Bug:** the glass platter starts above the
///    lower red line and is taller (about 61 pt on the iPhone 17 Pro 26.2
///    simulator, against 54 pt on iOS 27). **Fixed:** the platter starts at
///    the lower red line, as it does on iOS 27.
///  * **Labels on** is the control for the height: with labels, iOS 26 keeps
///    its own height on purpose, before and after.
class Issue132IconOnlyTabBarTestPage extends StatefulWidget {
  const Issue132IconOnlyTabBarTestPage({super.key});

  @override
  State<Issue132IconOnlyTabBarTestPage> createState() =>
      _Issue132IconOnlyTabBarTestPageState();
}

class _Issue132IconOnlyTabBarTestPageState
    extends State<Issue132IconOnlyTabBarTestPage> {
  static const double _barHeight = 89;
  static const double _pillRoom = 14;

  int _tab = 0;
  bool _labels = false;

  /// Passes `semanticLabel` (the fix); off shows the bar as before.
  bool _names = true;
  bool _height = true;

  /// PNG images, as in the report: unlike an SF Symbol, a PNG carries no
  /// name UIKit could fall back to.
  bool _png = true;

  CNTabBarItem _item(String label, String png, String symbol) => CNTabBarItem(
    label: _labels ? label : null,
    // The fix: a name for VoiceOver without a visible title.
    semanticLabel: _names ? label : null,
    imageAsset: _png ? CNImageAsset('assets/icons/$png.png', size: 22) : null,
    icon: _png ? null : CNSymbol(symbol),
  );

  @override
  Widget build(BuildContext context) {
    final items = <CNTabBarItem>[
      _item('Clock', 'clock', 'clock'),
      _item('Done', 'checkcircle', 'checkmark.circle'),
      _item('Coins', 'coins', 'dollarsign.circle'),
    ];
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#132: Icon-only tab bar'),
      ),
      child: Stack(
        children: <Widget>[
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                CupertinoSlidingSegmentedControl<bool>(
                  groupValue: _png,
                  onValueChanged: (v) {
                    if (v != null) setState(() => _png = v);
                  },
                  children: const <bool, Widget>{
                    true: Text('PNG icons (report)'),
                    false: Text('SF Symbols'),
                  },
                ),
                const SizedBox(height: 8),
                _Switch(
                  'semanticLabel (the fix)',
                  _names,
                  (v) => setState(() => _names = v),
                ),
                _Switch(
                  'Labels (control)',
                  _labels,
                  (v) => setState(() => _labels = v),
                ),
                _Switch(
                  'height: 89 (else the bar\'s own)',
                  _height,
                  (v) => setState(() => _height = v),
                ),
                const SizedBox(height: 16),
                Text(
                  'iOS ${PlatformVersion.iosVersion} · selected: $_tab',
                  style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Names — turn on VoiceOver and touch each tab.\n'
                  'Bug: "Tab, 1 of 3" with no name. Fixed: "Clock", '
                  '"Done", "Coins".\n\n'
                  'Height (iOS 26, labels off) — Bug: the glass platter '
                  'starts above the lower red line. Fixed: it starts on it, '
                  'as on iOS 27.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          if (_height) ...<Widget>[
            const Positioned(
              left: 0,
              right: 0,
              bottom: _barHeight,
              child: _Guide(),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: _barHeight - _pillRoom,
              child: _Guide(),
            ),
          ],
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CNTabBar(
              height: _height ? _barHeight : null,
              iconSize: 22,
              items: items,
              currentIndex: _tab,
              onTap: (i) => setState(() => _tab = i),
              tint: CupertinoColors.systemBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _Guide extends StatelessWidget {
  const _Guide();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: SizedBox(height: 1, child: ColoredBox(color: Color(0xFFFF2D55))),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch(this.label, this.value, this.onChanged);

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        CupertinoSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}
