// macOS audit entry point (issue #47).
//
// There is no tap automation for macOS apps here, so this entry point boots
// the example's home page and then pushes demo pages by name, the same way a
// tap on the home list does:
//
//   flutter run -d macos -t lib/mac_page_entry.dart --dart-define=PAGE=slider
//   flutter run -d macos -t lib/mac_page_entry.dart --dart-define=PAGES=main
//     (PAGES: a comma list of names, `main` for the Showcase, Components and
//     Navigation sections plus Alert, or `all`; HOLD=<s> per page;
//     BRIGHTNESS=dark; DELAY=<s> before the first push; SCENARIO=<name>
//     for the alert, action_sheet and context_menu pages' autoScenario)
//
// It prints `MACPAGE_PUSH <name>` before each push and `MACPAGE_READY <name>`
// once the page has settled, so a script can screenshot each page. A page
// that hangs the main thread never prints READY.

import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;
import 'package:flutter/services.dart';

import 'main.dart' show HomePage;

import 'demos/slider.dart';
import 'showcase/showcase_app.dart' show buildShowcaseScene;
import 'demos/switch.dart';
import 'demos/date_picker.dart';
import 'demos/stepper.dart';
import 'demos/color_well.dart';
import 'demos/page_control.dart';
import 'demos/segmented_control.dart';
import 'demos/icon.dart';
import 'demos/popup_menu_button.dart';
import 'demos/action_sheet.dart';
import 'demos/context_menu.dart';
import 'demos/button.dart';
import 'demos/overlay_test.dart';
import 'demos/app_bar.dart';
import 'demos/issues_test.dart';
import 'demos/iphone_duo_demo.dart';
import 'demos/native_tab_bar_demo.dart';
import 'demos/native_sheet_demo.dart';
import 'demos/bottom_nav_test.dart';
import 'demos/bottom_nav_indexed_test.dart';
import 'demos/bottom_nav_custom_icons_test.dart';
import 'demos/issue2_modal_shadow_test.dart';
import 'demos/issue28_checked_state_test.dart';
import 'demos/cnbutton_modal_halo_test.dart';
import 'demos/glass_widgets_modal_halo_test.dart';
import 'demos/issue29_artifact_test.dart';
import 'demos/issue29_transition_test.dart';
import 'demos/issue31_no_search_test.dart';
import 'demos/issue31_textfield_disappear_test.dart';
import 'demos/issue36_liquid_glass_modal_test.dart';
import 'demos/issue37_appbar_button_halo_test.dart';
import 'demos/issue53_cnbutton_under_sheet_test.dart';
import 'demos/issue40_button_label_style_test.dart';
import 'demos/issue46_cntoast_context_test.dart';
import 'demos/issue62_tabbar_gesture_arena_test.dart';
import 'demos/issue70_tabbar_background_test.dart';
import 'demos/issue43_glass_interactable_under_modal_test.dart';
import 'demos/issue50_glass_button_group_dumbbell_test.dart';
import 'demos/issue60_tabbar_labels_after_pop_test.dart';
import 'demos/issue65_gesture_arena_components_test.dart';
import 'demos/issue68_tabbar_rapid_taps_test.dart';
import 'demos/issue76_popup_gesture_test.dart';
import 'demos/pr64_liquid_glass_safe_area_test.dart';
import 'demos/pr66_glass_image_asset_tint_test.dart';
import 'demos/pr67_icon_supersample_test.dart';
import 'demos/pr69_glass_effect_test.dart';
import 'demos/pr72_glass_resize_test.dart';
import 'demos/pr74_tabbar_glass_background_test.dart';
import 'demos/pr77_liquid_glass_parts_test.dart';
import 'demos/pr78_action_sheet_test.dart';
import 'demos/pr79_alert_test.dart';
import 'demos/pr82_tabbar_font_first_build_test.dart';
import 'demos/issue103_tabbar_items_change_test.dart';
import 'demos/issue105_tabbar_dot_badge_test.dart';
import 'demos/tabbar_split_five_items_test.dart';
import 'demos/tabbar_item_menus_test.dart';
import 'demos/pr96_99_icon_tap_placeholder_test.dart';
import 'demos/pr97_98_tabbar_mount_test.dart';
import 'demos/pr100_tabbar_font_runtime_test.dart';
import 'demos/pr94_tab_accessory_null_test.dart';
import 'demos/pr84_system_brightness_test.dart';
import 'demos/pr85_tabbar_icon_precache_test.dart';
import 'demos/pr87_tabbar_selection_after_sheet_test.dart';
import 'demos/issue55_popup_menu_destructive_test.dart';
import 'demos/popup_menu_submenus_test.dart';
import 'demos/pr106_popup_menu_rebuild_test.dart';
import 'demos/pr42_tabbar_iconsize_customicon_test.dart';
import 'demos/issue33_svg_tabbar_test.dart';
import 'demos/stack_positioned_tabbar_test.dart';
import 'demos/tabbar_split_search_clip_test.dart';
import 'demos/alert.dart';

const String _page = String.fromEnvironment('PAGE');
const String _pages = String.fromEnvironment('PAGES');
const int _hold = int.fromEnvironment('HOLD', defaultValue: 4);
const int _delay = int.fromEnvironment('DELAY', defaultValue: 3);

/// Opens each page with a synthesized mouse click on its home-list tile
/// (through AppKit, like a real click) instead of a programmatic push.
const bool _tap = bool.fromEnvironment('TAP');

/// Prints `MACPAGE_CLICK <name> <x> <y>` (screen points) and lets an outside
/// tool move the real cursor there and click, then waits for the page.
const bool _realClick = bool.fromEnvironment('REALCLICK');

/// With REALCLICK, clicks the tile's leading CNIcon (an AppKit platform
/// view) instead of its title.
const bool _clickIcon = bool.fromEnvironment('CLICKICON');
const MethodChannel _auditChannel = MethodChannel('cnb_mac_audit');

/// `<width>x<height>` of the window content, e.g. 820x900.
const String _window = String.fromEnvironment('WIN');
/// Passed as `autoScenario` to the pages that take one (alert, action_sheet,
/// context_menu).
const String _scenario = String.fromEnvironment('SCENARIO');
const String _brightness = String.fromEnvironment(
  'BRIGHTNESS',
  defaultValue: 'light',
);

/// Every page of the example's home list, by name.
final Map<String, WidgetBuilder> macPages = <String, WidgetBuilder>{
  // Display & Brightness
  'sc_display': (_) => buildShowcaseScene('display'),
  // Files
  'sc_files': (_) => buildShowcaseScene('files'),
  // Photos
  'sc_photos': (_) => buildShowcaseScene('photos'),
  // Account
  'sc_account': (_) => buildShowcaseScene('account'),
  // Music
  'sc_music': (_) => buildShowcaseScene('music'),
  // iPhone Duo
  'sc_duo': (_) => buildShowcaseScene('duo'),
  // Slider
  'slider': (_) => const SliderDemoPage(),
  // Switch
  'switch': (_) => const SwitchDemoPage(),
  // Date Picker
  'date_picker': (_) => const DatePickerDemoPage(),
  // Stepper
  'stepper': (_) => const StepperDemoPage(),
  // Color Well
  'color_well': (_) => const ColorWellDemoPage(),
  // Page Control
  'page_control': (_) => const PageControlDemoPage(),
  // Segmented Control
  'segmented_control': (_) => const SegmentedControlDemoPage(),
  // Icon
  'icon': (_) => const IconDemoPage(),
  // Popup Menu Button
  'popup_menu_button': (_) => const PopupMenuButtonDemoPage(),
  // Action Sheet
  'action_sheet': (_) => const ActionSheetDemoPage(
    autoScenario: _scenario == '' ? null : _scenario,
  ),
  // Context Menu
  'context_menu': (_) => const ContextMenuDemoPage(
    autoScenario: _scenario == '' ? null : _scenario,
  ),
  // Button
  'button': (_) => const ButtonDemoPage(),
  // iPhone Duo
  'i_phone_duo': (_) => const IPhoneDuoDemoPage(),
  // Native Tab Bar (iOS 26)
  'native_tab_bar': (_) => const NativeTabBarDemoPage(),
  // Native Sheet
  'native_sheet': (_) => const NativeSheetDemoPage(),
  // Glass container
  'app_bar': (_) => const AppBarDemoPage(),
  // #2: Modal bottom sheet shadow
  'issue2_modal_shadow': (_) => const Issue2ModalShadowTest(),
  // #29: Transition Artifact
  'issue29_transition': (_) => const Issue29TransitionTestPage(),
  // CNButton modal halo test
  'c_n_button_modal_halo': (_) => const CNButtonModalHaloTest(),
  // Glass widgets modal halo test
  'glass_widgets_modal_halo': (_) => const GlassWidgetsModalHaloTest(),
  // #36: LiquidGlassContainer behind modal
  'issue36_liquid_glass_modal': (_) => const Issue36LiquidGlassModalTest(),
  // #37: AppBar CNButton halo bleed through sheet
  'issue37_app_bar_button_halo': (_) => const Issue37AppBarButtonHaloTest(),
  // #53: CNButton under bottom sheet
  'issue53_c_n_button_under_sheet': (_) =>
      const Issue53CNButtonUnderSheetTest(),
  // #40: CNButton label style
  'issue40_button_label_style': (_) => const Issue40ButtonLabelStyleTest(),
  // #46: CNToast use_build_context_synchronously
  'issue46_c_n_toast_context': (_) => const Issue46CNToastContextTestPage(),
  // #62 / PR #63: CNTabBar tap gesture arena
  'issue62_tab_bar_gesture_arena': (_) =>
      const Issue62TabBarGestureArenaTestPage(),
  // #70: CNTabBar backgroundColor
  'issue70_tab_bar_background': (_) => const Issue70TabBarBackgroundTestPage(),
  // #43: Glass interactable under modals
  'issue43_glass_interactable_under_modal': (_) =>
      const Issue43GlassInteractableUnderModalTestPage(),
  // #50: GlassButtonGroup dumbbell
  'issue50_glass_button_group_dumbbell': (_) =>
      const Issue50GlassButtonGroupDumbbellTestPage(),
  // #60: TabBar labels after pop
  'issue60_tab_bar_labels_after_pop': (_) =>
      const Issue60TabBarLabelsAfterPopTestPage(),
  // #65: Gesture arena, all components
  'issue65_gesture_arena_components': (_) =>
      const Issue65GestureArenaComponentsTestPage(),
  // #68: TabBar rapid taps
  'issue68_tab_bar_rapid_taps': (_) => const Issue68TabBarRapidTapsTestPage(),
  // #76: CNPopupGesture long press
  'issue76_popup_gesture': (_) => const Issue76PopupGestureTestPage(),
  // #103 / #104: TabBar items change early
  'issue103_tab_bar_items_change': (_) =>
      const Issue103TabBarItemsChangeTestPage(),
  // #105: TabBar dot badge
  'issue105_tab_bar_dot_badge': (_) => const Issue105TabBarDotBadgeTestPage(),
  // TabBar split: five items
  'tab_bar_split_five_items': (_) => const TabBarSplitFiveItemsTestPage(),
  // TabBar item menus
  'tab_bar_item_menus': (_) => const TabBarItemMenusTestPage(),
  // PR #64: LiquidGlass safe-area clip
  'pr64_liquid_glass_safe_area': (_) => const Pr64LiquidGlassSafeAreaTestPage(),
  // PR #66: glass imageAsset tint
  'pr66_glass_image_asset_tint': (_) => const Pr66GlassImageAssetTintTestPage(),
  // PR #67: icon supersampling
  'pr67_icon_supersample': (_) => const Pr67IconSupersampleTestPage(),
  // PR #69: LiquidGlass config.effect
  'pr69_glass_effect': (_) => const Pr69GlassEffectTestPage(),
  // PR #72: LiquidGlass resize
  'pr72_glass_resize': (_) => const Pr72GlassResizeTestPage(),
  // PR #74: TabBar glass background
  'pr74_tab_bar_glass_background': (_) =>
      const Pr74TabBarGlassBackgroundTestPage(),
  // PR #77: LiquidGlass parts
  'pr77_liquid_glass_parts': (_) => const Pr77LiquidGlassPartsTestPage(),
  // PR #78: native action sheet
  'pr78_action_sheet': (_) => const Pr78ActionSheetTestPage(),
  // PR #79: native alert
  'pr79_alert': (_) => const Pr79AlertTestPage(),
  // PR #82: TabBar font on first build
  'pr82_tab_bar_font_first_build': (_) =>
      const Pr82TabBarFontFirstBuildTestPage(),
  // PR #84: system brightness
  'pr84_system_brightness': (_) => const Pr84SystemBrightnessTestPage(),
  // PR #90: TabBar icon precache
  'pr85_tab_bar_icon_precache': (_) => const Pr85TabBarIconPrecacheTestPage(),
  // PR #96 / #99: CNIcon taps and placeholder
  'pr96_and99_icon_tap_placeholder': (_) =>
      const Pr96And99IconTapPlaceholderTestPage(),
  // PR #97 / #98: TabBar mount
  'pr97_and98_tab_bar_mount': (_) => const Pr97And98TabBarMountTestPage(),
  // PR #100: TabBar font at runtime
  'pr100_tab_bar_font_runtime': (_) => const Pr100TabBarFontRuntimeTestPage(),
  // PR #94: TabBarNative null accessory
  'pr94_tab_accessory_null': (_) => const Pr94TabAccessoryNullTestPage(),
  // #86 / PR #91: TabBar selection after sheet
  'pr87_tab_bar_selection_after_sheet': (_) =>
      const Pr87TabBarSelectionAfterSheetTestPage(),
  // #55: PopupMenu isDestructive
  'issue55_popup_menu_destructive': (_) =>
      const Issue55PopupMenuDestructiveTest(),
  // PopupMenu subtitles & submenus
  'popup_menu_submenus': (_) => const PopupMenuSubmenusTest(),
  // PR #106: PopupMenu icons after rebuild
  'pr106_popup_menu_rebuild': (_) => const Pr106PopupMenuRebuildTestPage(),
  // PR #42: CNTabBar iconSize (customIcon)
  'pr42_tab_bar_icon_size_custom_icon': (_) =>
      const Pr42TabBarIconSizeCustomIconTest(),
  // Stack+Positioned tab bar (clean fix attempt)
  'stack_positioned_tab_bar': (_) => const StackPositionedTabBarTest(),
  // #33: SVG in CNTabBar
  'issue33_svg_tab_bar': (_) => const Issue33SvgTabBarTest(),
  // #31: TextField disappear
  'issue31_text_field_disappear': (_) => const Issue31TextFieldDisappearTest(),
  // #31: TextField — NO search variant (hypothesis test)
  'issue31_no_search': (_) => const Issue31NoSearchTest(),
  // CNTabBar split-search clip
  'tab_bar_split_search_clip': (_) => const TabBarSplitSearchClipTest(),
  // #29: Per-widget halo test
  'issue29_artifact': (_) => const Issue29ArtifactTestPage(),
  // #28: Popup Checked State
  'issue28_checked_state': (_) => const Issue28CheckedStateTestPage(),
  // Overlay Test
  'overlay': (_) => const OverlayTestPage(),
  // Issues Test
  'issues': (_) => const IssuesTestPage(),
  // Bottom Nav Test (Simple)
  'bottom_nav': (_) => const BottomNavTestPage(),
  // Bottom Nav Test (IndexedStack)
  'bottom_nav_indexed': (_) => const BottomNavIndexedTestPage(),
  // Bottom Nav Test (Custom Icons)
  'bottom_nav_custom_icons': (_) => const BottomNavCustomIconsTestPage(),
  // Alert
  'alert': (_) => const AlertDemoPage(
    autoScenario: _scenario == '' ? null : _scenario,
  ),
};

/// The Showcase, Components and Navigation sections, plus Alert.
const List<String> macMainPages = <String>[
  'sc_display',
  'sc_files',
  'sc_photos',
  'sc_account',
  'sc_music',
  'sc_duo',
  'slider',
  'switch',
  'date_picker',
  'stepper',
  'color_well',
  'page_control',
  'segmented_control',
  'icon',
  'popup_menu_button',
  'action_sheet',
  'context_menu',
  'button',
  'i_phone_duo',
  'native_tab_bar',
  'native_sheet',
  'app_bar',
  'alert',
];

/// The home-list title of each page and which occurrence of it to tap.
const Map<String, (String, int)> macPageTitles = <String, (String, int)>{
  'sc_display': ('Display & Brightness', 0),
  'sc_files': ('Files', 0),
  'sc_photos': ('Photos', 0),
  'sc_account': ('Account', 0),
  'sc_music': ('Music', 0),
  'sc_duo': ('iPhone Duo', 0),
  'slider': ('Slider', 0),
  'switch': ('Switch', 0),
  'date_picker': ('Date Picker', 0),
  'stepper': ('Stepper', 0),
  'color_well': ('Color Well', 0),
  'page_control': ('Page Control', 0),
  'segmented_control': ('Segmented Control', 0),
  'icon': ('Icon', 0),
  'popup_menu_button': ('Popup Menu Button', 0),
  'action_sheet': ('Action Sheet', 0),
  'context_menu': ('Context Menu', 0),
  'button': ('Button', 0),
  'i_phone_duo': ('iPhone Duo', 1),
  'native_tab_bar': ('Native Tab Bar (iOS 26)', 0),
  'native_sheet': ('Native Sheet', 0),
  'app_bar': ('Glass container', 0),
  'issue2_modal_shadow': ('#2: Modal bottom sheet shadow', 0),
  'issue29_transition': ('#29: Transition Artifact', 0),
  'c_n_button_modal_halo': ('CNButton modal halo test', 0),
  'glass_widgets_modal_halo': ('Glass widgets modal halo test', 0),
  'issue36_liquid_glass_modal': ('#36: LiquidGlassContainer behind modal', 0),
  'issue37_app_bar_button_halo': (
    '#37: AppBar CNButton halo bleed through sheet',
    0,
  ),
  'issue53_c_n_button_under_sheet': ('#53: CNButton under bottom sheet', 0),
  'issue40_button_label_style': ('#40: CNButton label style', 0),
  'issue46_c_n_toast_context': (
    '#46: CNToast use_build_context_synchronously',
    0,
  ),
  'issue62_tab_bar_gesture_arena': (
    '#62 / PR #63: CNTabBar tap gesture arena',
    0,
  ),
  'issue70_tab_bar_background': ('#70: CNTabBar backgroundColor', 0),
  'issue43_glass_interactable_under_modal': (
    '#43: Glass interactable under modals',
    0,
  ),
  'issue50_glass_button_group_dumbbell': ('#50: GlassButtonGroup dumbbell', 0),
  'issue60_tab_bar_labels_after_pop': ('#60: TabBar labels after pop', 0),
  'issue65_gesture_arena_components': ('#65: Gesture arena, all components', 0),
  'issue68_tab_bar_rapid_taps': ('#68: TabBar rapid taps', 0),
  'issue76_popup_gesture': ('#76: CNPopupGesture long press', 0),
  'issue103_tab_bar_items_change': (
    '#103 / #104: TabBar items change early',
    0,
  ),
  'issue105_tab_bar_dot_badge': ('#105: TabBar dot badge', 0),
  'tab_bar_split_five_items': ('TabBar split: five items', 0),
  'tab_bar_item_menus': ('TabBar item menus', 0),
  'pr64_liquid_glass_safe_area': ('PR #64: LiquidGlass safe-area clip', 0),
  'pr66_glass_image_asset_tint': ('PR #66: glass imageAsset tint', 0),
  'pr67_icon_supersample': ('PR #67: icon supersampling', 0),
  'pr69_glass_effect': ('PR #69: LiquidGlass config.effect', 0),
  'pr72_glass_resize': ('PR #72: LiquidGlass resize', 0),
  'pr74_tab_bar_glass_background': ('PR #74: TabBar glass background', 0),
  'pr77_liquid_glass_parts': ('PR #77: LiquidGlass parts', 0),
  'pr78_action_sheet': ('PR #78: native action sheet', 0),
  'pr79_alert': ('PR #79: native alert', 0),
  'pr82_tab_bar_font_first_build': ('PR #82: TabBar font on first build', 0),
  'pr84_system_brightness': ('PR #84: system brightness', 0),
  'pr85_tab_bar_icon_precache': ('PR #90: TabBar icon precache', 0),
  'pr96_and99_icon_tap_placeholder': (
    'PR #96 / #99: CNIcon taps and placeholder',
    0,
  ),
  'pr97_and98_tab_bar_mount': ('PR #97 / #98: TabBar mount', 0),
  'pr100_tab_bar_font_runtime': ('PR #100: TabBar font at runtime', 0),
  'pr94_tab_accessory_null': ('PR #94: TabBarNative null accessory', 0),
  'pr87_tab_bar_selection_after_sheet': (
    '#86 / PR #91: TabBar selection after sheet',
    0,
  ),
  'issue55_popup_menu_destructive': ('#55: PopupMenu isDestructive', 0),
  'popup_menu_submenus': ('PopupMenu subtitles & submenus', 0),
  'pr106_popup_menu_rebuild': ('PR #106: PopupMenu icons after rebuild', 0),
  'pr42_tab_bar_icon_size_custom_icon': (
    'PR #42: CNTabBar iconSize (customIcon)',
    0,
  ),
  'stack_positioned_tab_bar': (
    'Stack+Positioned tab bar (clean fix attempt)',
    0,
  ),
  'issue33_svg_tab_bar': ('#33: SVG in CNTabBar', 0),
  'issue31_text_field_disappear': ('#31: TextField disappear', 0),
  'issue31_no_search': (
    '#31: TextField — NO search variant (hypothesis test)',
    0,
  ),
  'tab_bar_split_search_clip': ('CNTabBar split-search clip', 0),
  'issue29_artifact': ('#29: Per-widget halo test', 0),
  'issue28_checked_state': ('#28: Popup Checked State', 0),
  'overlay': ('Overlay Test', 0),
  'issues': ('Issues Test', 0),
  'bottom_nav': ('Bottom Nav Test (Simple)', 0),
  'bottom_nav_indexed': ('Bottom Nav Test (IndexedStack)', 0),
  'bottom_nav_custom_icons': ('Bottom Nav Test (Custom Icons)', 0),
  'alert': ('Alert', 0),
};

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _MacAuditApp());
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_drive()));
}

List<String> _selectedPages() {
  if (_page.isNotEmpty) return <String>[_page];
  if (_pages == 'main') return macMainPages;
  if (_pages == 'all') return macPages.keys.toList();
  return _pages.split(',').where((p) => p.isNotEmpty).toList();
}

Future<void> _drive() async {
  final pages = _selectedPages();
  if (_window.contains('x')) {
    final parts = _window.split('x').map(double.parse).toList();
    await _auditChannel.invokeMethod<void>('resize', <String, double>{
      'width': parts[0],
      'height': parts[1],
    });
  }
  await Future<void>.delayed(const Duration(seconds: _delay));
  debugPrint('MACPAGE_HOME');
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  for (final name in pages) {
    if (name == 'toggle_theme') {
      await _clickThemeButton();
      continue;
    }
    final builder = macPages[name];
    if (builder == null) {
      debugPrint('MACPAGE_UNKNOWN $name');
      continue;
    }
    if (_realClick) {
      final center = await _tileCenter(name);
      if (center == null) {
        debugPrint('MACPAGE_UNKNOWN $name (tile not found)');
        continue;
      }
      final screen = await _auditChannel.invokeMapMethod<String, double>(
        'toScreen',
        <String, double>{'x': center.dx, 'y': center.dy},
      );
      debugPrint('MACPAGE_PUSH $name');
      debugPrint('MACPAGE_CLICK $name ${screen!['x']} ${screen['y']}');
      await Future<void>.delayed(const Duration(seconds: 2));
    } else if (_tap) {
      final center = await _tileCenter(name);
      if (center == null) {
        debugPrint('MACPAGE_UNKNOWN $name (tile not found)');
        continue;
      }
      debugPrint('MACPAGE_PUSH $name');
      await _auditChannel.invokeMethod<void>('click', <String, double>{
        'x': center.dx,
        'y': center.dy,
      });
    } else {
      debugPrint('MACPAGE_PUSH $name');
      unawaited(
        _navigatorKey.currentState!.push(
          CupertinoPageRoute<void>(builder: builder),
        ),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    debugPrint('MACPAGE_READY $name');
    await Future<void>.delayed(const Duration(seconds: _hold));
    if (pages.length == 1) break;
    _navigatorKey.currentState!.popUntil((route) => route.isFirst);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  }
  debugPrint('MACPAGE_DONE');
}

/// `toggle_theme`: presses the home page's light/dark CNButton (a real click
/// with REALCLICK, an AppKit click with TAP, else its onPressed), which
/// changes the button's icon and semanticLabel.
Future<void> _clickThemeButton() async {
  CNButton? button;
  RenderBox? box;
  void visit(Element e) {
    final w = e.widget;
    if (button == null &&
        w is CNButton &&
        (w.semanticLabel ?? '').startsWith('Switch to')) {
      button = w;
      box = e.findRenderObject() as RenderBox?;
      return;
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  if (button == null || box == null) {
    debugPrint('MACPAGE_UNKNOWN toggle_theme (button not found)');
    return;
  }
  final center = box!.localToGlobal(box!.size.center(Offset.zero));
  debugPrint('MACPAGE_PUSH toggle_theme');
  if (_realClick) {
    final screen = await _auditChannel.invokeMapMethod<String, double>(
      'toScreen',
      <String, double>{'x': center.dx, 'y': center.dy},
    );
    debugPrint('MACPAGE_CLICK toggle_theme ${screen!['x']} ${screen['y']}');
  } else if (_tap) {
    await _auditChannel.invokeMethod<void>('click', <String, double>{
      'x': center.dx,
      'y': center.dy,
    });
  } else {
    button!.onPressed?.call();
  }
  await Future<void>.delayed(const Duration(milliseconds: 2500));
  debugPrint('MACPAGE_READY toggle_theme');
  await Future<void>.delayed(const Duration(seconds: _hold));
}

/// Scrolls the home list until the tile of [name] is built and centred, and
/// returns the centre of its title in global logical coordinates.
Future<Offset?> _tileCenter(String name) async {
  final entry = macPageTitles[name];
  if (entry == null) return null;
  final (title, occurrence) = entry;
  final root = WidgetsBinding.instance.rootElement!;

  Element? findTitle() {
    final hits = <Element>[];
    void visit(Element e) {
      final w = e.widget;
      if (w is Text && w.data == title) hits.add(e);
      e.visitChildren(visit);
    }

    root.visitChildren(visit);
    return hits.length > occurrence ? hits[occurrence] : null;
  }

  ScrollableState? scrollable;
  void visitScrollable(Element e) {
    if (scrollable != null) return;
    if (e is StatefulElement && e.state is ScrollableState) {
      scrollable = e.state as ScrollableState;
      return;
    }
    e.visitChildren(visitScrollable);
  }

  root.visitChildren(visitScrollable);
  final position = scrollable?.position;
  if (position == null) return null;
  position.jumpTo(0);
  await WidgetsBinding.instance.endOfFrame;
  var element = findTitle();
  while (element == null && position.pixels < position.maxScrollExtent) {
    position.jumpTo(
      (position.pixels + 300).clamp(0.0, position.maxScrollExtent),
    );
    await WidgetsBinding.instance.endOfFrame;
    element = findTitle();
  }
  if (element == null) return null;
  await Scrollable.ensureVisible(element, alignment: 0.5);
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(const Duration(milliseconds: 300));
  final box = element.findRenderObject() as RenderBox?;
  if (box == null || !box.attached) return null;
  final center = box.localToGlobal(box.size.center(Offset.zero));
  if (!_clickIcon) return center;
  // CupertinoListTile puts the 28 pt leading icon 16 pt before the title.
  return Offset(box.localToGlobal(Offset.zero).dx - 23, center.dy);
}

class _MacAuditApp extends StatefulWidget {
  const _MacAuditApp();

  @override
  State<_MacAuditApp> createState() => _MacAuditAppState();
}

class _MacAuditAppState extends State<_MacAuditApp> {
  bool dark = _brightness == 'dark';

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [CNTabBarRouteObserver()],
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      theme: CupertinoThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        primaryColor: CupertinoColors.systemBlue,
      ),
      home: HomePage(
        isDarkMode: dark,
        onToggleTheme: () => setState(() => dark = !dark),
        accentColor: CupertinoColors.systemBlue,
        onSelectAccentColor: (_) {},
      ),
    );
  }
}
