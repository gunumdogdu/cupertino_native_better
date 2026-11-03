import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #111 — native widgets and modals follow the app theme at runtime.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/111
/// By @yagizdo.
///
/// ### The claim
///
///  * `CNSearchBar`, `CNFloatingIsland` and `CNGlassButtonGroup` read the
///    theme only when they are created: switching the app theme afterwards
///    leaves them light on a dark page (iOS 27) or with a light placeholder
///    (iOS 26.2).
///  * `CNActionSheet` follows the system appearance, not the app theme: a
///    light app on a dark phone gets a dark sheet. 1.9.1 does the same for
///    `CNAlert`.
///
/// ### How this screen proves it
///
/// **Put the phone in Dark Mode first.** The page wraps itself in its own
/// light `CupertinoTheme`. Tap **Dark** to switch the theme without
/// recreating the widgets, **Light** to switch back, and **Sheet** or
/// **Alert** while the theme is light.
///
///  * **Bug present:** after **Dark** the three widgets stay light-styled;
///    the sheet and the alert open dark on the light page.
///  * **Fixed:** the widgets turn dark with the page; the sheet and the
///    alert open light.
class Pr111RuntimeThemeTestPage extends StatefulWidget {
  const Pr111RuntimeThemeTestPage({super.key});

  @override
  State<Pr111RuntimeThemeTestPage> createState() =>
      _Pr111RuntimeThemeTestPageState();
}

class _Pr111RuntimeThemeTestPageState extends State<Pr111RuntimeThemeTestPage> {
  Brightness _brightness = Brightness.light;

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: CupertinoThemeData(brightness: _brightness),
      child: Builder(
        builder: (context) => CupertinoPageScaffold(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('#111 · theme ${_brightness.name}'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CupertinoButton(
                        child: const Text('Light'),
                        onPressed: () =>
                            setState(() => _brightness = Brightness.light),
                      ),
                      CupertinoButton(
                        child: const Text('Dark'),
                        onPressed: () =>
                            setState(() => _brightness = Brightness.dark),
                      ),
                      CupertinoButton(
                        child: const Text('Sheet'),
                        onPressed: () => CNActionSheet.show<int>(
                          context: context,
                          title: 'Action sheet',
                          actions: const [
                            CNActionSheetAction(label: 'One', value: 1),
                            CNActionSheetAction(label: 'Two', value: 2),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        child: const Text('Alert'),
                        onPressed: () => CNAlert.show<int>(
                          context: context,
                          title: 'Alert',
                          actions: const [CNAlertAction(label: 'OK', value: 1)],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const CNSearchBar(placeholder: 'Search'),
                  const SizedBox(height: 24),
                  const Center(
                    child: CNFloatingIsland(collapsed: Text('Island')),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: CNGlassButtonGroup(
                      buttons: [
                        CNButtonData(label: 'One'),
                        CNButtonData(label: 'Two'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
