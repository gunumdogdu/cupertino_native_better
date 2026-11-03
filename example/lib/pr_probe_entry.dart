// Headless-ish probe entrypoint for PR verification.
//
// The simulator has no tap automation available here, so instead of driving
// the demo list by hand this entrypoint boots straight into one PR test page
// in one configuration, chosen by --dart-define. Screenshot with
// `xcrun simctl io booted screenshot`.
//
//   flutter run -t lib/pr_probe_entry.dart \
//     --dart-define=PROBE=pr66 --dart-define=BACKDROP=split --dart-define=BRIGHTNESS=light
//
//   flutter run -t lib/pr_probe_entry.dart \
//     --dart-define=PROBE=pr67 --dart-define=ICON=chevron --dart-define=SIZE=20
//
//   flutter run -t lib/pr_probe_entry.dart \
//     --dart-define=PROBE=pr72 --dart-define=SCENARIO=collapse --dart-define=LABEL=before
//   (SCENARIO: resize | collapse | zero | offscreen | detach; the page auto-toggles.)
//
//   flutter run -t lib/pr_probe_entry.dart \
//     --dart-define=PROBE=actionsheet --dart-define=SCENARIO=destructive
//   (SCENARIO: destructive | nocancel | titleonly | disabled | longlist |
//    anchored; the sheet opens itself on the first frame.)
//
//   flutter run -t lib/pr_probe_entry.dart \
//     --dart-define=PROBE=alert --dart-define=SCENARIO=textfield
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=pr82
//     (also pr86, issue103, issue105, pr96, pr97, pr100, and tour, which plays
//     them one after another for a screen recording; --dart-define=AUTO=true steps all three
//     through their cases on their own, for device screenshots)
//   (SCENARIO: twobutton | destructive | threebutton | titleonly | disabled |
//    textfield | secure | twofields | supersede; the alert opens itself on the
//    first frame.)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=submenus
//     (CNPopupMenuButton subtitles and submenus; open the menus by hand)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=split5
//     (CNTabBar split with five items; use the buttons by hand)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=symboleffects
//     (2.0.0: CNIcon symbol effects and replace transitions, on timers)
//
// PROBE=pr67report additionally dumps the MAE/cost table to the run log.

import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;

import 'demos/action_sheet.dart';
import 'demos/pr66_glass_image_asset_tint_test.dart';
import 'demos/pr67_icon_supersample_test.dart';
import 'demos/pr69_glass_effect_test.dart';
import 'demos/pr72_glass_resize_test.dart';
import 'demos/pr82_tabbar_font_first_build_test.dart';
import 'demos/pr87_tabbar_selection_after_sheet_test.dart';
import 'demos/issue103_tabbar_items_change_test.dart';
import 'demos/issue105_tabbar_dot_badge_test.dart';
import 'demos/pr96_99_icon_tap_placeholder_test.dart';
import 'demos/pr97_98_tabbar_mount_test.dart';
import 'demos/pr100_tabbar_font_runtime_test.dart';
import 'demos/pr94_tab_accessory_null_test.dart';
import 'demos/alert.dart';
import 'demos/tabbar_overlap_variants_test.dart';
import 'demos/pr111_runtime_theme_test.dart';
import 'demos/issue60_tabbar_labels_after_pop_test.dart';
import 'demos/bottom_nav_indexed_test.dart';
import 'demos/issue70_tabbar_background_test.dart';
import 'demos/prs_109_110_tabbar_test.dart';
import 'demos/popup_menu_submenus_test.dart';
import 'demos/tabbar_split_five_items_test.dart';
import 'demos/pr106_popup_menu_rebuild_test.dart';
import 'demos/upgrades_2_0_probes.dart';

const String _probe = String.fromEnvironment('PROBE', defaultValue: 'pr67');
const bool _observer = bool.fromEnvironment('OBSERVER');
const String _backdrop = String.fromEnvironment(
  'BACKDROP',
  defaultValue: 'split',
);
const String _brightness = String.fromEnvironment(
  'BRIGHTNESS',
  defaultValue: 'light',
);
const String _icon = String.fromEnvironment('ICON', defaultValue: 'chevron');
const String _size = String.fromEnvironment('SIZE', defaultValue: '20');
const String _accent = String.fromEnvironment('ACCENT', defaultValue: 'blue');
const String _scenario = String.fromEnvironment(
  'SCENARIO',
  defaultValue: 'resize',
);

const bool _auto = bool.fromEnvironment('AUTO');

/// Stamped into the nav bar so a before/after screenshot pair can't be mixed up.
const String _label = String.fromEnvironment('LABEL', defaultValue: '');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (_probe == 'pr67report') {
    WidgetsBinding.instance.addPostFrameCallback((_) => pr67PrintReport());
  }
  runApp(const _ProbeApp());
}

class _ProbeApp extends StatelessWidget {
  const _ProbeApp();

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      navigatorObservers: [if (_observer) CNTabBarRouteObserver()],
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      theme: CupertinoThemeData(
        brightness: _brightness == 'dark' ? Brightness.dark : Brightness.light,
        primaryColor: _accent == 'pink'
            ? CupertinoColors.systemPink
            : CupertinoColors.systemBlue,
      ),
      home: _home(),
    );
  }

  Widget _home() {
    if (_probe.startsWith('pr66')) {
      return Pr66GlassImageAssetTintTestPage(
        initialBackdrop: _backdrop,
        initialBrightness: _brightness,
      );
    }
    if (_probe == 'pr67native') {
      return Pr67NativeStripPage(label: _label);
    }
    if (_probe.startsWith('pr69')) {
      return Pr69GlassEffectTestPage(
        initialBackdrop: _backdrop == 'photo' ? 'photo' : 'stripes',
        initialTinted: _accent == 'pink',
      );
    }
    if (_probe == 'actionsheet') {
      return ActionSheetDemoPage(autoScenario: _scenario);
    }
    if (_probe.startsWith('pr72')) {
      return Pr72GlassResizeTestPage(
        initialScenario: _scenario,
        label: _label,
        autoCycle: true,
      );
    }
    if (_probe == 'symboleffects') {
      return const SymbolEffectsProbePage();
    }
    if (_probe == 'pr106') {
      return const Pr106PopupMenuRebuildTestPage(autoCycle: true);
    }
    if (_probe == 'submenus') {
      return const PopupMenuSubmenusTest();
    }
    if (_probe == 'split5') {
      return const TabBarSplitFiveItemsTestPage();
    }
    if (_probe == 'pr82') {
      return const Pr82TabBarFontFirstBuildTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue103') {
      return const Issue103TabBarItemsChangeTestPage(autoCycle: _auto);
    }
    if (_probe == 'pr86') {
      return const Pr87TabBarSelectionAfterSheetTestPage();
    }
    if (_probe == 'tour') {
      return const _Tour();
    }
    if (_probe == 'pr96') {
      return const Pr96And99IconTapPlaceholderTestPage();
    }
    if (_probe == 'pr97') {
      return const Pr97And98TabBarMountTestPage(autoCycle: _auto);
    }
    if (_probe == 'pr100') {
      return const Pr100TabBarFontRuntimeTestPage(autoCycle: _auto);
    }
    if (_probe == 'pr94') {
      return const Pr94TabAccessoryNullTestPage(autoCycle: true);
    }
    if (_probe == 'issue105') {
      return const Issue105TabBarDotBadgeTestPage(autoCycle: _auto);
    }
    if (_probe.startsWith('pr109') || _probe == 'pr110') {
      return Prs109110TabBarTestPage(
        mode: switch (_probe) {
          'pr109fade' => 'fade',
          'pr109narrow' => 'narrow',
          _ => 'props',
        },
      );
    }
    if (_probe == 'issue70') {
      return const Issue70TabBarBackgroundTestPage();
    }
    if (_probe == 'issue60') {
      return const Issue60TabBarLabelsAfterPopTestPage();
    }
    if (_probe == 'issue68') {
      return const BottomNavIndexedTestPage();
    }
    if (_probe == 'overlap') {
      return const TabBarOverlapVariantsTestPage();
    }
    if (_probe == 'pr111') {
      return const Pr111RuntimeThemeTestPage();
    }
    if (_probe == 'alert') {
      return AlertDemoPage(autoScenario: _scenario);
    }
    return Pr67IconSupersampleTestPage(
      initialIcon: _icon,
      initialSize: double.tryParse(_size),
    );
  }
}

/// Plays the tab bar and icon screens one after another, each stepping
/// through its own cases, so one release build and one screen recording on a
/// device cover them all.
class _Tour extends StatefulWidget {
  const _Tour();

  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> {
  static final List<(Duration, Widget Function())> _stops =
      <(Duration, Widget Function())>[
        (
          const Duration(seconds: 13),
          () => const Pr97And98TabBarMountTestPage(autoCycle: true),
        ),
        (
          const Duration(seconds: 13),
          () => const Issue105TabBarDotBadgeTestPage(autoCycle: true),
        ),
        (
          const Duration(seconds: 11),
          () => const Pr82TabBarFontFirstBuildTestPage(autoCycle: true),
        ),
        (
          const Duration(seconds: 13),
          () => const Issue103TabBarItemsChangeTestPage(autoCycle: true),
        ),
        (
          const Duration(seconds: 21),
          () => const Pr100TabBarFontRuntimeTestPage(autoCycle: true),
        ),
        (
          const Duration(seconds: 6),
          () => const Pr96And99IconTapPlaceholderTestPage(),
        ),
      ];

  int _stop = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    _timer = Timer(_stops[_stop].$1, () {
      if (!mounted || _stop == _stops.length - 1) return;
      setState(() => _stop++);
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: ValueKey<int>(_stop), child: _stops[_stop].$2());
  }
}
