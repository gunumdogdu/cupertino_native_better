import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #146 reproduction: a `CNTabRail` stays visible and pressable under
/// a pushed page.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/146
/// Reported by @LucasLau00.
///
/// ### The claim
///
/// When an opaque page is pushed over a page with a rail, the rail's glass
/// is drawn over the incoming page during the slide, a faint outline of its
/// frame stays in its column afterwards, and touches there still press the
/// rail (without calling `onTap`). The rail has neither `ModalHideMixin`
/// nor `HaloContainmentMixin`, which the other glass widgets have.
///
/// ### How this screen proves it
///
/// A `CNTabScaffold` with the rail placement, and a button that pushes a
/// teal full-screen page (or AUTO, which pushes, waits and pops). The tap
/// counter on the rail page counts `onTap`.
///
///  * **During the slide** (`146-sliding`): **bug:** the rail's capsule is
///    drawn over the teal page where they overlap. **Fixed:** the rail is
///    clipped to its own box and slides away under the page.
///  * **After the slide** (`146-pushed`): **bug:** an outline of the rail
///    stays over the teal page, and a tap there animates the rail.
///    **Fixed:** the teal page is clean and a tap there does nothing.
///  * **Back** (`146-back`): the rail is there again and works.
class Issue146TabRailPushedPageTestPage extends StatefulWidget {
  const Issue146TabRailPushedPageTestPage({super.key, this.autoCycle = false});

  /// Pushes the page, waits, pops, and prints `CNB_SHOT <step>`.
  final bool autoCycle;

  @override
  State<Issue146TabRailPushedPageTestPage> createState() =>
      _Issue146TabRailPushedPageTestPageState();
}

class _Issue146TabRailPushedPageTestPageState
    extends State<Issue146TabRailPushedPageTestPage> {
  int _index = 0;
  int _taps = 0;
  NavigatorState? _navigator;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    _push();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    debugPrint('CNB_SHOT 146-sliding');
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    debugPrint('CNB_SHOT 146-pushed');
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    _navigator?.pop();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    debugPrint('CNB_SHOT 146-back');
  }

  void _push() {
    _navigator = Navigator.of(context);
    _navigator!.push(
      CupertinoPageRoute<void>(
        builder: (_) => const CupertinoPageScaffold(
          backgroundColor: CupertinoColors.systemTeal,
          navigationBar: CupertinoNavigationBar(middle: Text('Pushed page')),
          child: Center(
            child: Text(
              'The rail must not show or react here.',
              style: TextStyle(color: CupertinoColors.white, fontSize: 17),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CNTabScaffold(
      placement: CNTabPlacement.rail,
      items: const [
        CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
        CNTabBarItem(label: 'Calendar', icon: CNSymbol('calendar')),
        CNTabBarItem(label: 'Profile', icon: CNSymbol('person')),
      ],
      currentIndex: _index,
      onTap: (i) => setState(() {
        _index = i;
        _taps++;
      }),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '#146 rail · tab $_index · onTap $_taps',
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _push,
                child: const Text('Push a full page'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
