import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #100 verification — `labelFontFamily` / `labelFontSize` changed at
/// runtime on the native `CNTabBar`.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/100
/// By @yagizdo.
///
/// ### The claims
///
/// On the iOS 26 and 27 native bar:
///
///  * a font changed at runtime does not reach the labels,
///  * `labelFontSize` without `labelFontFamily` is ignored,
///  * setting both back to null leaves the last custom font on the labels,
///  * a label taller than the native 10 pt one grows up into the icon.
///
/// (A font passed at creation is covered by the PR #82 screen.)
///
/// ### How this screen proves it
///
/// The bar keeps one native view, and *Next* steps its font through: no
/// font, size 15 (system font), Courier 15, Chalkduster 12, then no font
/// again. The strip above draws the expected labels in Flutter.
///
///  * **Bug present:** a step does not change the native labels, size 15
///    stays at the system size, the custom font stays after "no font", or a
///    label overlaps its icon.
///  * **Fixed:** every step matches the strip, "no font" brings back the
///    native label, and labels clear their icons.
///
/// [autoCycle] steps every two seconds, alternating single and split each
/// round.
class Pr100TabBarFontRuntimeTestPage extends StatefulWidget {
  const Pr100TabBarFontRuntimeTestPage({super.key, this.autoCycle = false});

  final bool autoCycle;

  @override
  State<Pr100TabBarFontRuntimeTestPage> createState() =>
      _Pr100TabBarFontRuntimeTestPageState();
}

class _Step {
  const _Step(this.name, this.family, this.size);

  final String name;
  final String? family;
  final double? size;
}

class _Pr100TabBarFontRuntimeTestPageState
    extends State<Pr100TabBarFontRuntimeTestPage> {
  static const List<_Step> _steps = <_Step>[
    _Step('no font', null, null),
    _Step('size 15', null, 15),
    _Step('Courier 15', 'Courier', 15),
    _Step('Chalkduster 12', 'Chalkduster', 12),
  ];

  static const List<CNTabBarItem> _items = <CNTabBarItem>[
    CNTabBarItem(
      label: 'Home',
      icon: CNSymbol('house'),
      activeIcon: CNSymbol('house.fill'),
    ),
    CNTabBarItem(
      label: 'Library',
      icon: CNSymbol('books.vertical'),
      activeIcon: CNSymbol('books.vertical.fill'),
    ),
    CNTabBarItem(
      label: 'Alerts',
      icon: CNSymbol('bell'),
      activeIcon: CNSymbol('bell.fill'),
    ),
    CNTabBarItem(
      label: 'Profile',
      icon: CNSymbol('person'),
      activeIcon: CNSymbol('person.fill'),
    ),
  ];

  int _step = 0;
  int _rounds = 0;
  int _index = 0;
  bool _split = false;
  Timer? _cycle;

  _Step get _current => _steps[_step];

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      _cycle = Timer.periodic(const Duration(seconds: 2), (_) => _next());
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  void _next() {
    setState(() {
      _step = (_step + 1) % _steps.length;
      if (_step == 0 && widget.autoCycle) {
        _rounds++;
        _split = _rounds.isOdd;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final _Step s = _current;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #100 · tab bar font at runtime'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  _controls(),
                  const Spacer(),
                  _reference(s),
                  const SizedBox(height: 130),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: CNTabBar(
                // One native view per layout: only the font changes.
                key: ValueKey<bool>(_split),
                items: _items,
                currentIndex: _index,
                onTap: (int i) => setState(() => _index = i),
                tint: CupertinoColors.systemBlue,
                split: _split,
                labelFontFamily: s.family,
                labelFontSize: s.size,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reference(_Step s) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Text(
            'expected · ${s.name}',
            style: TextStyle(
              fontSize: 11,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              for (final CNTabBarItem item in _items)
                Expanded(
                  child: Text(
                    item.label!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: s.family,
                      fontSize: s.size ?? 10,
                      fontWeight: s.family == null ? FontWeight.w500 : null,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Next steps the font: no font, size 15, Courier 15, Chalkduster '
            '12. Bug: a step that does not reach the native labels, a custom '
            'font left after "no font", or a label in its icon.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          CupertinoSegmentedControl<bool>(
            groupValue: _split,
            onValueChanged: (bool v) => setState(() => _split = v),
            children: const <bool, Widget>{
              false: Text('single', style: TextStyle(fontSize: 12)),
              true: Text('split', style: TextStyle(fontSize: 12)),
            },
          ),
          const SizedBox(height: 10),
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(vertical: 10),
            onPressed: _next,
            child: const Text('Next', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 8),
          Text(
            'step: ${_current.name} · ${_split ? 'split' : 'single'}',
            style: const TextStyle(fontSize: 13, color: CupertinoColors.white),
          ),
        ],
      ),
    );
  }
}
