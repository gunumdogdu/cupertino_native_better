import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;
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
import 'demos/popover.dart';
import 'demos/button.dart';
import 'demos/search_bar.dart';
import 'demos/glass_button_group.dart';
import 'demos/progress_indicator.dart';
import 'demos/pop_up_button.dart';
import 'demos/gauge.dart';
import 'demos/overlay_test.dart';
import 'demos/app_bar.dart';
import 'demos/issues_test.dart';
import 'demos/iphone_duo_demo.dart';
import 'demos/native_tab_bar_demo.dart';
import 'demos/native_sheet_demo.dart';
import 'demos/sidebar_demo.dart';
import 'demos/split_window_demo.dart';
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
import 'demos/tab_bar_demo.dart';
import 'demos/toolbar.dart';
import 'demos/search_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  Color _accentColor = CupertinoColors.systemBlue;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  void _setAccentColor(Color color) {
    setState(() {
      _accentColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      // The banner covers the top-right corner, where the theme toggle sits on
      // macOS and the camera sits on the iPhone Duo outer display (#88).
      debugShowCheckedModeBanner: false,
      // Issue #31 fix: register the observer at the app-level navigator so
      // CNTabBar can detect modals/sheets pushed via the root navigator
      // (default for `showCupertinoSheet`, `showCupertinoModalPopup`, etc.)
      // and auto-hide its native UITabBar to avoid z-order conflicts with
      // Flutter-rendered modal content (e.g. Material TextFields).
      navigatorObservers: [CNTabBarRouteObserver()],
      // Provide Material + Cupertino localizations at the root so demos can
      // freely mix `showModalBottomSheet` (Material) with Cupertino routes
      // without adding the `flutter_localizations` package. Default English
      // strings are sufficient for the demo app.
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      theme: CupertinoThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        primaryColor: _accentColor,
      ),
      home: HomePage(
        isDarkMode: _isDarkMode,
        onToggleTheme: _toggleTheme,
        accentColor: _accentColor,
        onSelectAccentColor: _setAccentColor,
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.accentColor,
    required this.onSelectAccentColor,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final Color accentColor;
  final ValueChanged<Color> onSelectAccentColor;

  static const _systemColors = <MapEntry<String, Color>>[
    MapEntry('Red', CupertinoColors.systemRed),
    MapEntry('Orange', CupertinoColors.systemOrange),
    MapEntry('Yellow', CupertinoColors.systemYellow),
    MapEntry('Green', CupertinoColors.systemGreen),
    MapEntry('Teal', CupertinoColors.systemTeal),
    MapEntry('Blue', CupertinoColors.systemBlue),
    MapEntry('Indigo', CupertinoColors.systemIndigo),
    MapEntry('Purple', CupertinoColors.systemPurple),
    MapEntry('Pink', CupertinoColors.systemPink),
    MapEntry('Gray', CupertinoColors.systemGrey),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        border: null,
        // middle: const Text('Cupertino Native'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CNPopupMenuButton.icon(
              semanticLabel: 'Accent colour',
              buttonIcon: CNSymbol(
                'paintpalette.fill',
                size: 18,
                mode: CNSymbolRenderingMode.multicolor,
              ),
              tint: accentColor,
              items: [
                for (final entry in _systemColors)
                  CNPopupMenuItem(
                    label: entry.key,
                    icon: CNSymbol('circle.fill', size: 18, color: entry.value),
                  ),
              ],
              onSelected: (index) {
                if (index >= 0 && index < _systemColors.length) {
                  onSelectAccentColor(_systemColors[index].value);
                }
              },
            ),
            const SizedBox(width: 8),
            CNButton.icon(
              icon: CNSymbol(isDarkMode ? 'sun.max' : 'moon', size: 18),
              semanticLabel: isDarkMode
                  ? 'Switch to light mode'
                  : 'Switch to dark mode',
              onPressed: onToggleTheme,
            ),
          ],
        ),
      ),
      // SafeArea for the side insets only: on the iPhone Duo outer display the
      // status bar is vertical, on the right edge, and ListView pads only its
      // scroll axis.
      child: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            CupertinoListSection.insetGrouped(
              header: Text('Showcase'),
              children: [
                CupertinoListTile(
                  title: Text('Display & Brightness'),
                  subtitle: Text('Segmented control, slider, switches, menu'),
                  leading: CNIcon(
                    symbol: CNSymbol('sun.max.fill', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => buildShowcaseScene('display'),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Files'),
                  subtitle: Text('Tab bar with search, menu with submenus'),
                  leading: CNIcon(
                    symbol: CNSymbol('folder.fill', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => buildShowcaseScene('files'),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Photos'),
                  subtitle: Text('Liquid Glass buttons over images'),
                  leading: CNIcon(
                    symbol: CNSymbol('photo.fill', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => buildShowcaseScene('photos'),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Account'),
                  subtitle: Text('Native alert and action sheet'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'person.crop.circle.fill',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => buildShowcaseScene('account'),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Music'),
                  subtitle: Text('CNTabBarNative: minimize, accessory, search'),
                  leading: CNIcon(
                    symbol: CNSymbol('music.note', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => buildShowcaseScene('music'),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('iPhone Duo'),
                  subtitle: Text('Vertical bar, sidebar, split at the fold'),
                  leading: CNIcon(
                    symbol: CNSymbol('iphone.gen3', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => buildShowcaseScene('duo'),
                      ),
                    );
                  },
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: Text('Components'),
              children: [
                CupertinoListTile(
                  title: Text('Slider'),
                  leading: CNIcon(
                    symbol: CNSymbol('slider.horizontal.3', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const SliderDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Switch'),
                  leading: CNIcon(
                    symbol: CNSymbol('switch.2', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const SwitchDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Date Picker'),
                  leading: CNIcon(
                    symbol: CNSymbol('calendar', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const DatePickerDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Stepper'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'plus.forwardslash.minus',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const StepperDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Color Well'),
                  leading: CNIcon(
                    symbol: CNSymbol('paintpalette', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const ColorWellDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Page Control'),
                  leading: CNIcon(
                    symbol: CNSymbol('ellipsis', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const PageControlDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Segmented Control'),
                  leading: CNIcon(
                    symbol: CNSymbol('rectangle.split.3x1', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const SegmentedControlDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Icon'),
                  leading: CNIcon(symbol: CNSymbol('app', color: accentColor)),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const IconDemoPage()),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Popup Menu Button'),
                  leading: CNIcon(
                    symbol: CNSymbol('ellipsis.circle', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const PopupMenuButtonDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Action Sheet'),
                  leading: CNIcon(
                    symbol: CNSymbol('square.and.arrow.up', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const ActionSheetDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Context Menu'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'contextualmenu.and.cursorarrow',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const ContextMenuDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Popover'),
                  leading: CNIcon(
                    symbol: CNSymbol('bubble.middle.top', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const PopoverDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Button'),
                  leading: CNIcon(
                    symbol: CNSymbol('hand.tap', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const ButtonDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Glass Button Group'),
                  leading: CNIcon(
                    symbol: CNSymbol('square.on.square', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const GlassButtonGroupDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Search Bar'),
                  leading: CNIcon(
                    symbol: CNSymbol('magnifyingglass', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const SearchBarDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Progress Indicator'),
                  leading: CNIcon(
                    symbol: CNSymbol('progress.indicator', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const ProgressIndicatorDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Pop-Up Button'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'chevron.up.chevron.down',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const PopUpButtonDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Gauge'),
                  leading: CNIcon(
                    symbol: CNSymbol('gauge.with.needle', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const GaugeDemoPage()),
                    );
                  },
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: Text('Navigation'),
              children: [
                CupertinoListTile(
                  title: Text('iPhone Duo'),
                  subtitle: Text('Hinge, vertical bar, fold-aware layouts'),
                  leading: CNIcon(symbol: CNSymbol('book', color: accentColor)),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const IPhoneDuoDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Tab Bar'),
                  subtitle: Text('Badges, tint and font, search tab, items'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'menubar.dock.rectangle',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const TabBarDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Toolbar'),
                  subtitle: Text(
                    'Window toolbar on macOS, bottom toolbar on iOS',
                  ),
                  leading: CNIcon(
                    symbol: CNSymbol('menubar.rectangle', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const ToolbarDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Search Scaffold'),
                  subtitle: Text(
                    'Tabs and search: tab bar on iOS, toolbar on macOS',
                  ),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'magnifyingglass.circle',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const SearchScaffoldDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Native Tab Bar'),
                  subtitle: Text('iOS 26 tab bar, Mac window sidebar'),
                  leading: CNIcon(
                    symbol: CNSymbol('dock.rectangle', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const NativeTabBarDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Native Sheet'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'rectangle.bottomhalf.inset.filled',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const NativeSheetDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Mac Window'),
                  subtitle: Text('Sidebar and inspector around Flutter'),
                  leading: CNIcon(
                    symbol: CNSymbol('rectangle.split.3x1', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const SplitWindowDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Sidebar'),
                  subtitle: Text('CNSidebar, CNTabRail, CNTabScaffold'),
                  leading: CNIcon(
                    symbol: CNSymbol('sidebar.left', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const SidebarDemoPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Glass container'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'rectangle.topthird.inset',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const AppBarDemoPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: Text('Testing'),
              children: [
                CupertinoListTile(
                  title: Text('#2: Modal bottom sheet shadow'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'rectangle.bottomthird.inset.filled',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue2ModalShadowTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#29: Transition Artifact'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'rectangle.on.rectangle',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue29TransitionTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('CNButton modal halo test'),
                  leading: CNIcon(
                    symbol: CNSymbol('square.on.square', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const CNButtonModalHaloTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Glass widgets modal halo test'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'rectangle.stack.fill',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const GlassWidgetsModalHaloTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#36: LiquidGlassContainer behind modal'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'rectangle.fill.on.rectangle.fill',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue36LiquidGlassModalTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#37: AppBar CNButton halo bleed through sheet'),
                  leading: CNIcon(
                    symbol: CNSymbol('bell.badge', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue37AppBarButtonHaloTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#53: CNButton under bottom sheet'),
                  leading: CNIcon(
                    symbol: CNSymbol('square.and.pencil', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue53CNButtonUnderSheetTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#40: CNButton label style'),
                  leading: CNIcon(
                    symbol: CNSymbol('textformat.size', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue40ButtonLabelStyleTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#46: CNToast use_build_context_synchronously'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'exclamationmark.bubble',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue46CNToastContextTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#62 / PR #63: CNTabBar tap gesture arena'),
                  leading: CNIcon(
                    symbol: CNSymbol('hand.tap.fill', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue62TabBarGestureArenaTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#70: CNTabBar backgroundColor'),
                  leading: CNIcon(
                    symbol: CNSymbol('paintpalette', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue70TabBarBackgroundTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#43: Glass interactable under modals'),
                  leading: CNIcon(
                    symbol: CNSymbol('hand.tap', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue43GlassInteractableUnderModalTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#50: GlassButtonGroup dumbbell'),
                  leading: CNIcon(
                    symbol: CNSymbol('capsule', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue50GlassButtonGroupDumbbellTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#60: TabBar labels after pop'),
                  leading: CNIcon(
                    symbol: CNSymbol('textformat.size', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue60TabBarLabelsAfterPopTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#65: Gesture arena, all components'),
                  leading: CNIcon(
                    symbol: CNSymbol('hand.draw', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue65GestureArenaComponentsTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#68: TabBar rapid taps'),
                  leading: CNIcon(
                    symbol: CNSymbol('hand.tap.fill', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue68TabBarRapidTapsTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#76: CNPopupGesture long press'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'contextualmenu.and.cursorarrow',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue76PopupGestureTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#103 / #104: TabBar items change early'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'plus.rectangle.on.rectangle',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue103TabBarItemsChangeTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#105: TabBar dot badge'),
                  leading: CNIcon(
                    symbol: CNSymbol('app.badge', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue105TabBarDotBadgeTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#124: Button halo under dialog'),
                  leading: CNIcon(
                    symbol: CNSymbol('square.dashed', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue124ButtonDialogHaloTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#126: SearchBar controller'),
                  leading: CNIcon(
                    symbol: CNSymbol('magnifyingglass', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue126SearchBarControllerTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#127: Present after popover'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'rectangle.on.rectangle',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue127PopoverPresentAfterTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#128: FloatingIsland resize'),
                  leading: CNIcon(
                    symbol: CNSymbol('capsule', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue128FloatingIslandResizeTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#129: Popover rows'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'list.bullet.rectangle',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue129PopoverRowsTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#130: Icon replace + colour'),
                  leading: CNIcon(
                    symbol: CNSymbol('play.circle', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue130IconReplaceColorTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#131: Split tab action'),
                  leading: CNIcon(
                    symbol: CNSymbol('square.and.pencil', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue131SplitTabActionTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#132: Icon-only tab bar'),
                  leading: CNIcon(
                    symbol: CNSymbol('dock.rectangle', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue132IconOnlyTabBarTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#134: Search bar state'),
                  leading: CNIcon(
                    symbol: CNSymbol('magnifyingglass', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue134SearchBarStateTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#135: Popover gauges, failures'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'gauge.with.dots.needle.33percent',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue135PopoverGaugeFailureTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#136: Tab bar measure, search'),
                  leading: CNIcon(
                    symbol: CNSymbol('ruler', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue136TabBarMeasureSearchTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#137: Slider tap to seek'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'slider.horizontal.below.rectangle',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue137SliderSeekTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#138: Context menu preview'),
                  leading: CNIcon(
                    symbol: CNSymbol('rectangle.stack', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue138ContextMenuPreviewTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#141: Popup menu button'),
                  leading: CNIcon(
                    symbol: CNSymbol('ellipsis.circle', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue141PopupMenuButtonTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#142: Tab bar font, RTL'),
                  leading: CNIcon(
                    symbol: CNSymbol('textformat', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue142TabBarFontRtlTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#143: Segmented font, labels'),
                  leading: CNIcon(
                    symbol: CNSymbol('rectangle.split.3x1', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Issue143SegmentedFontLabelsTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#144: Alert font, RTL'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'exclamationmark.bubble',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue144AlertFontRtlTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('TabBar split: five items'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'circle.righthalf.filled',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const TabBarSplitFiveItemsTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('TabBar item menus'),
                  leading: CNIcon(
                    symbol: CNSymbol('plus.circle', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const TabBarItemMenusTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #64: LiquidGlass safe-area clip'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'rectangle.bottomthird.inset.filled',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Pr64LiquidGlassSafeAreaTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #66: glass imageAsset tint'),
                  leading: CNIcon(
                    symbol: CNSymbol('paintbrush.pointed', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Pr66GlassImageAssetTintTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #67: icon supersampling'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'squareshape.split.2x2',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Pr67IconSupersampleTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #69: LiquidGlass config.effect'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'circle.lefthalf.filled',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Pr69GlassEffectTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #72: LiquidGlass resize'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'arrow.up.left.and.arrow.down.right',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Pr72GlassResizeTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #74: TabBar glass background'),
                  leading: CNIcon(
                    symbol: CNSymbol('dock.rectangle', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Pr74TabBarGlassBackgroundTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #77: LiquidGlass parts'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'capsule.on.rectangle',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Pr77LiquidGlassPartsTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #78: native action sheet'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'list.bullet.rectangle',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Pr78ActionSheetTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #79: native alert'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'exclamationmark.bubble',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Pr79AlertTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #82: TabBar font on first build'),
                  leading: CNIcon(
                    symbol: CNSymbol('textformat', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Pr82TabBarFontFirstBuildTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #84: system brightness'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'circle.lefthalf.filled',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Pr84SystemBrightnessTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #90: TabBar icon precache'),
                  leading: CNIcon(
                    symbol: CNSymbol('timer', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Pr85TabBarIconPrecacheTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #96 / #99: CNIcon taps and placeholder'),
                  leading: CNIcon(
                    symbol: CNSymbol('hand.tap', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Pr96And99IconTapPlaceholderTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #97 / #98: TabBar mount'),
                  leading: CNIcon(
                    symbol: CNSymbol('dock.rectangle', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Pr97And98TabBarMountTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #100: TabBar font at runtime'),
                  leading: CNIcon(
                    symbol: CNSymbol('textformat.size', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Pr100TabBarFontRuntimeTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #94: TabBarNative null accessory'),
                  leading: CNIcon(
                    symbol: CNSymbol('rectangle.dashed', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Pr94TabAccessoryNullTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#86 / PR #91: TabBar selection after sheet'),
                  leading: CNIcon(
                    symbol: CNSymbol('rectangle.stack', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Pr87TabBarSelectionAfterSheetTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#55: PopupMenu isDestructive'),
                  leading: CNIcon(
                    symbol: CNSymbol('trash', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue55PopupMenuDestructiveTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PopupMenu subtitles & submenus'),
                  leading: CNIcon(
                    symbol: CNSymbol('list.bullet.indent', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const PopupMenuSubmenusTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #106: PopupMenu icons after rebuild'),
                  leading: CNIcon(
                    symbol: CNSymbol('arrow.clockwise', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Pr106PopupMenuRebuildTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('PR #42: CNTabBar iconSize (customIcon)'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'arrow.up.left.and.arrow.down.right',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const Pr42TabBarIconSizeCustomIconTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Stack+Positioned tab bar (clean fix attempt)'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'rectangle.bottomthird.inset.filled',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const StackPositionedTabBarTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#33: SVG in CNTabBar'),
                  leading: CNIcon(
                    symbol: CNSymbol('photo.fill', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue33SvgTabBarTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#31: TextField disappear'),
                  leading: CNIcon(
                    symbol: CNSymbol('textformat.abc', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue31TextFieldDisappearTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text(
                    '#31: TextField — NO search variant (hypothesis test)',
                  ),
                  leading: CNIcon(
                    symbol: CNSymbol('textformat', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue31NoSearchTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('CNTabBar split-search clip'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'magnifyingglass.circle',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const TabBarSplitSearchClipTest(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#29: Per-widget halo test'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'square.on.square.dashed',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue29ArtifactTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('#28: Popup Checked State'),
                  leading: CNIcon(
                    symbol: CNSymbol('checkmark.circle', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const Issue28CheckedStateTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Overlay Test'),
                  leading: CNIcon(
                    symbol: CNSymbol('square.stack.3d.up', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const OverlayTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Issues Test'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'exclamationmark.triangle',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const IssuesTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Bottom Nav Test (Simple)'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'rectangle.bottomthird.inset.filled',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const BottomNavTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Bottom Nav Test (IndexedStack)'),
                  leading: CNIcon(
                    symbol: CNSymbol('square.stack.3d.up', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const BottomNavIndexedTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Bottom Nav Test (Custom Icons)'),
                  leading: CNIcon(
                    symbol: CNSymbol('photo.artframe', color: accentColor),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const BottomNavCustomIconsTestPage(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  title: Text('Alert'),
                  leading: CNIcon(
                    symbol: CNSymbol(
                      'exclamationmark.bubble',
                      color: accentColor,
                    ),
                  ),
                  trailing: CupertinoListTileChevron(),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const AlertDemoPage()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
