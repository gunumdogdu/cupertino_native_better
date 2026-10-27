// iPhone Duo probe entrypoint.
//
// The Duo simulator (Xcode 27.1 Device Hub) has no tap automation, so this
// entrypoint boots straight into one screen, chosen by --dart-define, for
// screenshots and screen recordings of the folded and unfolded poses. Fold
// and unfold with the pose buttons below the device bezel in Device Hub.
//
//   flutter run -t lib/duo_probe_entry.dart --dart-define=PAGE=nativeTabBar
//   flutter run -t lib/duo_probe_entry.dart --dart-define=PAGE=nativeTabBar \
//     --dart-define=AS_ROOT=true
//
//   flutter run -t lib/duo_probe_entry.dart --dart-define=PAGE=duo --dart-define=TAB=1
//
// PAGE: home (default, the regular example app) | nativeTabBar | duo
// AS_ROOT: with nativeTabBar, take over the window root so the "Flutter" tab
//   hosts real Flutter content (default false: presented modally).
// TAB: with duo, the showcase tab to open (0 Hinge, 1 Studio, 2 Gallery,
//   3 Options).
// SIDEBAR: start with the sidebar on wide screens on (duo: the showcase
//   option; nativeTabBar: CNTabBarNative's sidebarOnWideScreens).

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;

import 'demos/iphone_duo_demo.dart';
import 'demos/native_tab_bar_demo.dart';
import 'main.dart' as example;

const String _page = String.fromEnvironment('PAGE', defaultValue: 'home');
const bool _asRoot = bool.fromEnvironment('AS_ROOT');
const int _tab = int.fromEnvironment('TAB');
const bool _sidebar = bool.fromEnvironment('SIDEBAR');

void main() {
  if (_page == 'nativeTabBar' || _page == 'duo') {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const _ProbeApp());
    return;
  }
  example.main();
}

class _ProbeApp extends StatelessWidget {
  const _ProbeApp();

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      navigatorObservers: <NavigatorObserver>[CNTabBarRouteObserver()],
      home: _page == 'duo'
          ? const IPhoneDuoDemoPage(initialTab: _tab, initialSidebar: _sidebar)
          : const NativeTabBarDemoPage(
              autoLaunch: true,
              initialAsRoot: _asRoot,
              sidebarOnWideScreens: _sidebar,
            ),
    );
  }
}
