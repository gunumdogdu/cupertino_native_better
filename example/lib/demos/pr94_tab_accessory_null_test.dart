import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #94 — `CNTabBarNative` with `bottomAccessory: null` on iOS 26.1+.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/94
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/93
/// Reported and fixed by @tgrushka.
///
/// ### The claim
///
/// Since iOS 26.1, `tabViewBottomAccessory { EmptyView() }` still draws the
/// accessory: an empty glass pill above the tab bar. iOS 26.1 added
/// `tabViewBottomAccessory(isEnabled:)`, and the PR passes
/// `isEnabled: accessory != nil`.
///
/// ### How this screen proves it
///
/// *Run* presents the native tab bar and steps through five states, three
/// seconds each, then closes it and starts again:
///
///  1. Launched with no accessory, on Feed.
///  2. Accessory "Step 2 · shown".
///  3. Accessory removed.
///  4. Profile selected while the accessory is removed.
///  5. Accessory "Step 5 · back on Profile".
///
///  * **Before (iOS 26.1+):** an empty pill above the tab bar in steps 1, 3
///    and 4.
///  * **After:** no pill in steps 1, 3 and 4, a pill with its text in steps 2
///    and 5, and Profile still selected in step 5 (showing the accessory
///    must not reset the tab to Feed).
///  * iOS 26.0 shows no pill either way: it is the control.
///
/// [autoCycle] runs the steps from the first frame, for screenshots from a
/// simulator or device.
class Pr94TabAccessoryNullTestPage extends StatefulWidget {
  const Pr94TabAccessoryNullTestPage({super.key, this.autoCycle = false});

  final bool autoCycle;

  @override
  State<Pr94TabAccessoryNullTestPage> createState() =>
      _Pr94TabAccessoryNullTestPageState();
}

class _Pr94TabAccessoryNullTestPageState
    extends State<Pr94TabAccessoryNullTestPage> {
  static const _stepLength = Duration(seconds: 3);

  Timer? _timer;
  int _step = 0;
  bool _running = false;

  static const _steps = <String>[
    '1 · launched with no accessory, on Feed',
    '2 · accessory shown',
    '3 · accessory removed',
    '4 · Profile selected, no accessory',
    '5 · accessory back, still on Profile',
  ];

  static List<CNListItem> _rows(String tab) => [
    for (var i = 1; i <= 12; i++)
      CNListItem(
        title: '$tab row $i',
        leadingSymbol: CNSymbol(tab == 'Feed' ? 'list.bullet' : 'person'),
      ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    CNTabBarNative.disable();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _step = 0;
    });
    debugPrint('PR94 step ${_steps[0]}');
    await CNTabBarNative.enable(
      tabs: [
        CNTab(
          title: 'Feed',
          sfSymbol: CNSymbol('list.bullet'),
          nativeList: CNNativeList(items: _rows('Feed')),
        ),
        CNTab(
          title: 'Profile',
          sfSymbol: CNSymbol('person'),
          nativeList: CNNativeList(items: _rows('Profile')),
        ),
      ],
      bottomAccessory: null,
      minimizeBehavior: CNTabMinimizeBehavior.never,
      onTabSelected: (i) => debugPrint('PR94 onTabSelected($i)'),
      onDismissed: () {
        _timer?.cancel();
        if (mounted) setState(() => _running = false);
      },
    );
    _timer?.cancel();
    _timer = Timer.periodic(_stepLength, (_) => _advance());
  }

  Future<void> _advance() async {
    final next = _step + 1;
    if (next == _steps.length) {
      _timer?.cancel();
      await CNTabBarNative.disable();
      if (!mounted) return;
      setState(() => _running = false);
      if (widget.autoCycle) {
        Timer(const Duration(seconds: 2), () {
          if (mounted) _run();
        });
      }
      return;
    }
    setState(() => _step = next);
    debugPrint('PR94 step ${_steps[next]}');
    switch (next) {
      case 1:
        await CNTabBarNative.setBottomAccessory(
          CNTabAccessory(
            text: 'Step 2 · shown',
            sfSymbol: CNSymbol('2.circle'),
          ),
        );
      case 2:
        await CNTabBarNative.setBottomAccessory(null);
      case 3:
        await CNTabBarNative.setSelectedIndex(1);
      case 4:
        await CNTabBarNative.setBottomAccessory(
          CNTabAccessory(
            text: 'Step 5 · back on Profile',
            sfSymbol: CNSymbol('5.circle'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #94 · null accessory'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Run presents the native tab bar and steps through five '
                'states, three seconds each. Steps 1, 3 and 4 have no '
                'accessory: an empty pill above the tab bar there is the '
                'bug. Step 5 must stay on Profile.',
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _steps.length; i++)
                Text(
                  _steps[i],
                  style: TextStyle(
                    fontWeight: _running && i == _step
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: _running ? null : _run,
                child: const Text('Run'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
