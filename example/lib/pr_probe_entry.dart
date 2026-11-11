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
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=tabmenus
//     (CNTabBarItem.menuItems; open the menus by hand)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=datepicker \
//     --dart-define=SCENARIO=inline --dart-define=AUTO=true --dart-define=BRIGHTNESS=system
//     (CNDatePicker; SCENARIO: compact | inline | inlineTime | wheels |
//     limits, or leave it out for every section; AUTO moves the value to a
//     new month every 4 s; BRIGHTNESS=system follows
//     `xcrun simctl ui <udid> appearance`; FALLBACK=true draws the Flutter
//     fallback, which iOS 26+ never shows, by claiming to be Android)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=symboleffects
//     (2.0.0: CNIcon symbol effects and replace transitions, on timers)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=clearglass
//     (2.0.0: CNButton clearGlass / prominentClearGlass over a photo)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=slider26
//     (2.0.0: CNSlider thumbless style, ticks and neutral value, on a timer)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=tabbar
//     (CNTabBar badges, tint and font, search tab, changing items;
//     AUTO=true changes them on a timer)
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=stepper
//     (CNStepper; the values and the tint change every 1.5 s. Add
//     --dart-define=FALLBACK=true to draw the Flutter fallbacks instead.)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=colorwell
//     (CNColorWell; the colours change every 1.5 s. FALLBACK=true as above;
//     add --dart-define=SCENARIO=sheet to open the fallback palette sheet.)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=pr115
//     (PRs #115-#118, demos/prs_115_118_test.dart: pr115 tab bar badge with
//     split/font/icon size, pr116 search bar fallback width (FALLBACK=true
//     on iOS 26+), pr117 uncoloured CNIcon on a dark theme, pr118 modals and
//     pickers following the system (BRIGHTNESS=system, SCENARIO=alert opens
//     the alert) and the segmented fallback (FALLBACK=true BRIGHTNESS=dark))
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=sheetdismiss
//     (email 2026-11-04: menus in bottom sheets that do not close on an
//     outside tap; host page with a native tab bar, OBSERVER=true, a
//     floating + menu in sheet 1, "…" menus in the stacked sheet 2)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=sheet
//     (2.1.0: CNNativeSheet over a map-style screen; BG=<image file> and
//     AVATARS=<png>,<png> draw local files for screenshot comparisons;
//     MIDDLE=<points> rests the sheet at that height instead of medium;
//     SMALL=<points> replaces the collapsed height; START=small opens there;
//     ROWS=name|place|distance;... replaces the People rows; SINGLE=true
//     shows the People page alone, without a tab bar)
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=pagecontrol
//     (CNPageControl; the pages turn every 1.5 s. FALLBACK=true as above.)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=controls
//     (CNStepper, CNColorWell and CNPageControl on one screen, changing on
//     a timer.)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=popupbutton
//     (2.3.0: CNPopUpButton; AUTO=true changes every picker's value every
//     2 s and prints `CNB_SHOT cycle<n>` for screenshots; SCROLL=<points>
//     starts the list further down)
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=issue124 \
//     --dart-define=OBSERVER=true
//     (#124: glass CNButton with autoHideOnModal: false under a dialog)
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=issue126
//     (#126 to #132: the same with issue127 ... issue132; one screen each;
//     AUTO=true runs the steps of #126 to #130 and prints `CNB_SHOT <step>`)
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=issue134 \
//     --dart-define=OBSERVER=true
//     (#134 to #138: the same with issue135 ... issue138; AUTO=true runs the
//     steps of #134 to #136 and prints `CNB_SHOT <step>`; #134 needs
//     OBSERVER=true; #140 uses PROBE=issue132)
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=issue141
//     (#141 to #144: the same with issue142 ... issue144; ARABIC=true starts
//     #142 in Arabic; AUTO=true runs #143 and #144 and prints `CNB_SHOT`)
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=issue146
//     (#146 and #147, the latter as issue147; AUTO=true pushes and pops the
//     page over the rail / changes the sort label, printing `CNB_SHOT`)
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=issue149
//     --dart-define=OBSERVER=true
//     (#149; AUTO=true opens and closes each sheet, printing `CNB_SHOT`;
//     #151 is issue151, tapped by hand)
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=issue154
//     (#153 and #154, the former as issue153; AUTO=true flips #153's third
//     row / steps #154's counter and remounts it, printing `CNB_SHOT`)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=gauge
//     (2.3.0: CNGauge; AUTO=true moves the value every 2.5 s through the
//     normal, warning and critical zones and prints `CNB_SHOT gauge<n>`;
//     SCROLL=<points> as above)
//
// PROBE=pr67report additionally dumps the MAE/cost table to the run log.

import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
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
import 'demos/sheet_menus_dismiss_test.dart';
import 'demos/prs_115_118_test.dart';
import 'demos/issue60_tabbar_labels_after_pop_test.dart';
import 'demos/bottom_nav_indexed_test.dart';
import 'demos/issue70_tabbar_background_test.dart';
import 'demos/prs_109_110_tabbar_test.dart';
import 'demos/popup_menu_submenus_test.dart';
import 'demos/tabbar_split_five_items_test.dart';
import 'demos/tabbar_item_menus_test.dart';
import 'demos/native_tab_bar_demo.dart';
import 'demos/popup_menu_button.dart';
import 'demos/pr106_popup_menu_rebuild_test.dart';
import 'demos/date_picker.dart';
import 'demos/upgrades_2_0_probes.dart';
import 'demos/stepper.dart';
import 'demos/color_well.dart';
import 'demos/page_control.dart';
import 'demos/native_sheet_demo.dart';
import 'demos/tab_bar_demo.dart';
import 'demos/pop_up_button.dart';
import 'demos/gauge.dart';
import 'demos/issue124_button_dialog_halo_test.dart';
import 'demos/issue126_search_bar_controller_test.dart';
import 'demos/issue127_popover_present_after_test.dart';
import 'demos/issue128_floating_island_resize_test.dart';
import 'demos/issue129_popover_rows_test.dart';
import 'demos/issue130_icon_replace_color_test.dart';
import 'demos/issue131_split_tab_action_test.dart';
import 'demos/issue132_icon_only_tab_bar_test.dart';
import 'demos/issue134_search_bar_state_test.dart';
import 'demos/issue135_popover_gauge_failure_test.dart';
import 'demos/issue136_tab_bar_measure_search_test.dart';
import 'demos/issue137_slider_seek_test.dart';
import 'demos/issue138_context_menu_preview_test.dart';
import 'demos/issue141_popup_menu_button_test.dart';
import 'demos/issue142_tab_bar_font_rtl_test.dart';
import 'demos/issue143_segmented_font_labels_test.dart';
import 'demos/issue144_alert_font_rtl_test.dart';
import 'demos/issue146_tab_rail_pushed_page_test.dart';
import 'demos/issue147_popup_label_change_test.dart';
import 'demos/issue149_glass_button_under_sheet_test.dart';
import 'demos/issue151_thumbless_slider_seek_test.dart';
import 'demos/issue153_button_label_color_light_dark_test.dart';
import 'demos/issue154_button_label_width_padding_test.dart';

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
const bool _arabic = bool.fromEnvironment('ARABIC');

/// Takes the widgets' Flutter fallbacks on an iOS 26+ simulator.
const bool _fallback = bool.fromEnvironment('FALLBACK');

/// Stamped into the nav bar so a before/after screenshot pair can't be mixed up.
const String _label = String.fromEnvironment('LABEL', defaultValue: '');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (_fallback) debugDefaultTargetPlatformOverride = TargetPlatform.android;
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
        brightness: switch (_brightness) {
          'dark' => Brightness.dark,
          // Follows the device, for light/dark screenshots of one run.
          'system' => null,
          _ => Brightness.light,
        },
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
    if (_probe == 'issue124') {
      return const Issue124ButtonDialogHaloTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue126') {
      return const Issue126SearchBarControllerTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue127') {
      return const Issue127PopoverPresentAfterTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue128') {
      return const Issue128FloatingIslandResizeTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue129') {
      return const Issue129PopoverRowsTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue130') {
      return const Issue130IconReplaceColorTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue131') {
      return const Issue131SplitTabActionTestPage();
    }
    if (_probe == 'issue132') {
      return const Issue132IconOnlyTabBarTestPage();
    }
    if (_probe == 'issue134') {
      return const Issue134SearchBarStateTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue135') {
      return const Issue135PopoverGaugeFailureTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue136') {
      return const Issue136TabBarMeasureSearchTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue137') {
      return const Issue137SliderSeekTestPage();
    }
    if (_probe == 'issue138') {
      return const Issue138ContextMenuPreviewTestPage();
    }
    if (_probe == 'issue141') {
      return const Issue141PopupMenuButtonTestPage();
    }
    if (_probe == 'issue142') {
      return const Issue142TabBarFontRtlTestPage(arabic: _arabic);
    }
    if (_probe == 'issue143') {
      return const Issue143SegmentedFontLabelsTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue144') {
      return const Issue144AlertFontRtlTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue146') {
      return const Issue146TabRailPushedPageTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue147') {
      return const Issue147PopupLabelChangeTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue149') {
      return const Issue149GlassButtonUnderSheetTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue151') {
      return const Issue151ThumblessSliderSeekTestPage();
    }
    if (_probe == 'issue153') {
      return const Issue153ButtonLabelColorLightDarkTestPage(autoCycle: _auto);
    }
    if (_probe == 'issue154') {
      return const Issue154ButtonLabelWidthPaddingTestPage(autoCycle: _auto);
    }
    if (_probe == 'symboleffects') {
      return const SymbolEffectsProbePage();
    }
    if (_probe == 'clearglass') {
      return const ClearGlassProbePage();
    }
    if (_probe == 'slider26') {
      return const Slider26ProbePage();
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
    if (_probe == 'menulayout') {
      return const PopupMenuButtonDemoPage();
    }
    if (_probe == 'prominent') {
      return const NativeTabBarDemoPage(
        autoLaunch: true,
        initialAsRoot: true,
        initialProminent: bool.fromEnvironment('PROMINENT', defaultValue: true),
      );
    }
    if (_probe == 'tabmenus') {
      return const TabBarItemMenusTestPage();
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
    if (_probe == 'pr115') return const Pr115TabBarBadgeSyncPage();
    if (_probe == 'pr116') return const Pr116SearchBarWidthPage();
    if (_probe == 'pr117') return const Pr117IconDefaultColorPage();
    if (_probe == 'pr118') {
      return Pr118ThemeFollowPage(openAlert: _scenario == 'alert');
    }
    if (_probe == 'sheetdismiss') return const SheetMenusDismissTestPage();
    if (_probe == 'pr111') {
      return const Pr111RuntimeThemeTestPage();
    }
    if (_probe == 'datepicker') {
      return const DatePickerDemoPage(
        section: bool.hasEnvironment('SCENARIO') ? _scenario : null,
        autoCycle: _auto,
      );
    }
    if (_probe == 'alert') {
      return AlertDemoPage(autoScenario: _scenario);
    }
    if (_probe == 'tabbar') {
      return const TabBarDemoPage(autoCycle: _auto);
    }
    if (_probe == 'stepper') {
      return const StepperDemoPage(autoCycle: true);
    }
    if (_probe == 'sheet') {
      const bg = String.fromEnvironment('BG');
      const avatars = String.fromEnvironment('AVATARS');
      const middle = String.fromEnvironment('MIDDLE');
      const rows = String.fromEnvironment('ROWS');
      const single = bool.fromEnvironment('SINGLE');
      const small = String.fromEnvironment('SMALL');
      const start = String.fromEnvironment('START');
      return NativeSheetDemoPage(
        autoLaunch: true,
        singlePage: single,
        people: rows.isEmpty
            ? const NativeSheetDemoPage().people
            : [
                for (final row in rows.split(';'))
                  if (row.split('|') case [final a, final b, final c])
                    (a, b, c),
              ],
        smallDetent: small.isEmpty
            ? const NativeSheetDemoPage().smallDetent
            : CNSheetDetent.height(double.parse(small)),
        startSmall: start == 'small',
        middleDetent: middle.isEmpty
            ? CNSheetDetent.medium
            : CNSheetDetent.height(double.parse(middle)),
        backgroundFile: bg.isEmpty ? null : bg,
        avatarFiles: avatars.isEmpty ? const [] : avatars.split(','),
      );
    }
    if (_probe == 'popupbutton') {
      return PopUpButtonDemoPage(
        autoCycle: _auto,
        initialScrollOffset: double.parse(
          const String.fromEnvironment('SCROLL', defaultValue: '0'),
        ),
      );
    }
    if (_probe == 'gauge') {
      return GaugeDemoPage(
        autoCycle: _auto,
        initialScrollOffset: double.parse(
          const String.fromEnvironment('SCROLL', defaultValue: '0'),
        ),
      );
    }
    if (_probe == 'pagecontrol') {
      return const PageControlDemoPage(autoCycle: true);
    }
    if (_probe == 'controls') {
      return const _Controls();
    }
    if (_probe == 'colorwell') {
      return ColorWellDemoPage(
        autoCycle: _scenario != 'sheet' && _scenario != 'still',
        openPicker: _scenario == 'sheet',
      );
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

/// CNStepper, CNColorWell and CNPageControl together, as they might sit in a
/// settings screen, changing on a timer.
class _Controls extends StatefulWidget {
  const _Controls();

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  static const List<Color> _colors = <Color>[
    CupertinoColors.systemIndigo,
    CupertinoColors.systemPink,
    CupertinoColors.systemTeal,
    CupertinoColors.systemOrange,
  ];

  double _size = 14;
  int _color = 0;
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // SCENARIO=still leaves the values to taps.
    if (_scenario == 'still') return;
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      setState(() {
        _size = _size >= 20 ? 12 : _size + 1;
        _color = (_color + 1) % _colors.length;
        _page = (_page + 1) % 4;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _colors[_color];
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Controls')),
      child: SafeArea(
        child: CupertinoListSection.insetGrouped(
          header: const Text('Appearance'),
          footer: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: CNPageControl(
              numberOfPages: 4,
              currentPage: _page,
              currentPageIndicatorColor: color,
              semanticLabel: 'Theme',
              onChanged: (p) => setState(() => _page = p),
            ),
          ),
          children: [
            CupertinoListTile(
              title: const Text('Text Size'),
              additionalInfo: Text('${_size.toInt()} pt'),
              trailing: CNStepper(
                value: _size,
                min: 10,
                max: 24,
                semanticLabel: 'Text size',
                onChanged: (v) => setState(() => _size = v),
              ),
            ),
            CupertinoListTile(
              title: const Text('Accent Color'),
              trailing: CNColorWell(
                color: color,
                title: 'Accent Color',
                semanticLabel: 'Accent color',
                onChanged: (_) {},
              ),
            ),
            CupertinoListTile(
              title: Text(
                'The quick brown fox',
                style: TextStyle(fontSize: _size, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
