import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #131: a split `CNTabBar` has no item that runs an action without
/// being selected (feature request, iOS 26+).
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/131
/// Reported by @cogwheel0.
///
/// ### The claim
///
/// iOS 26 apps pin a single action, such as Compose, as the right-hand
/// capsule of a split tab bar. With `CNTabBar(split: true, rightCount: 1)`
/// that item is a plain tab: a standalone `UITabBar` selects it before the
/// app hears about the tap, and it has no `shouldSelect`. The app can put
/// the selection back only afterwards.
///
/// ### The fix
///
/// `CNTabBarItem(onPressed: ...)` makes an item an action: a tap calls
/// `onPressed`, never `onTap`, and the item is never selected.
///
/// ### How this screen shows it
///
/// Inbox and Archive are destinations; Compose (the right-hand capsule) is
/// an action. Tap **Compose**.
///
///  * **onPressed (the fix):** Compose is an action item. **Fixed:** the
///    count goes up, Inbox (or Archive) stays selected, no selection
///    highlight grows on Compose, and VoiceOver says "Compose, button".
///  * **onTap, leave it (before):** Compose is a plain tab and `onTap(2)`
///    counts without rebuilding. Compose shows as selected and Inbox loses
///    its selection until something rebuilds the bar.
///  * **onTap, restore (before):** the app rebuilds in `onTap`, which sends
///    the old index back. Compose still grows the Liquid Glass selection
///    for a moment, then the highlight snaps back.
class Issue131SplitTabActionTestPage extends StatefulWidget {
  const Issue131SplitTabActionTestPage({super.key});

  @override
  State<Issue131SplitTabActionTestPage> createState() =>
      _Issue131SplitTabActionTestPageState();
}

class _Issue131SplitTabActionTestPageState
    extends State<Issue131SplitTabActionTestPage> {
  int _tab = 0;

  /// 0: `onPressed` (the fix); 1: `onTap`, leave it; 2: `onTap`, restore.
  int _mode = 0;

  /// Counted outside `setState`, so counting rebuilds only its own text and
  /// never the bar.
  final ValueNotifier<int> _composed = ValueNotifier<int>(0);

  @override
  void dispose() {
    _composed.dispose();
    super.dispose();
  }

  static const List<String> _names = <String>['Inbox', 'Archive'];

  void _onTap(int index) {
    if (index == 2) {
      _composed.value++;
      if (_mode == 2) {
        // Rebuild now, so the bar gets the unchanged index back at once.
        setState(() {});
      }
      return;
    }
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#131: Split tab action'),
      ),
      child: Stack(
        children: <Widget>[
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                CupertinoSlidingSegmentedControl<int>(
                  groupValue: _mode,
                  onValueChanged: (v) {
                    if (v != null) setState(() => _mode = v);
                  },
                  children: const <int, Widget>{
                    0: Text('onPressed'),
                    1: Text('onTap, leave'),
                    2: Text('onTap, restore'),
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Destination: ${_names[_tab]}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<int>(
                  valueListenable: _composed,
                  builder: (context, count, _) =>
                      Text('Compose ran $count times'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Tap Compose (the right-hand capsule).\n\n'
                  'onPressed (the fix): the count goes up, the selection '
                  'never moves and no highlight grows on Compose; VoiceOver '
                  'says "Compose, button".\n'
                  'onTap, leave (before): Compose stays selected and Inbox '
                  'loses its selection.\n'
                  'onTap, restore (before): the selection grows on Compose '
                  'for a moment, then snaps back.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: CNTabBar(
                split: true,
                rightCount: 1,
                items: <CNTabBarItem>[
                  const CNTabBarItem(label: 'Inbox', icon: CNSymbol('tray')),
                  const CNTabBarItem(
                    label: 'Archive',
                    icon: CNSymbol('archivebox'),
                  ),
                  CNTabBarItem(
                    label: 'Compose',
                    icon: const CNSymbol('square.and.pencil'),
                    onPressed: _mode == 0 ? () => _composed.value++ : null,
                  ),
                ],
                currentIndex: _tab,
                onTap: _onTap,
                tint: CupertinoColors.systemBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
