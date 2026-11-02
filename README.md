<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/banner.png" width="100%" alt="cupertino_native_better: iOS 26, iOS 27 and iPhone Duo. The real iOS controls, in Flutter.">
</p>

<p align="center">
  <strong>The real iOS&nbsp;26 and iOS&nbsp;27 controls, in Flutter.</strong><br>
  Liquid Glass tab bars, buttons, menus, sliders, switches, alerts and sheets, drawn by UIKit and SwiftUI themselves.
</p>

<p align="center">
  <a href="https://pub.dev/packages/cupertino_native_better"><img src="https://img.shields.io/pub/v/cupertino_native_better?color=0A84FF" alt="pub version"></a>
  <a href="https://pub.dev/packages/cupertino_native_better/score"><img src="https://img.shields.io/pub/points/cupertino_native_better?color=34C759" alt="pub points"></a>
  <a href="https://github.com/gunumdogdu/cupertino_native_better/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-8E8E93" alt="MIT license"></a>
  <a href="https://gunumdogdu.com/docs"><img src="https://img.shields.io/badge/docs-gunumdogdu.com-5E5CE6" alt="Documentation"></a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/scene_display.gif" width="250" alt="A Display and Brightness page built from the native segmented control, slider, switches and pop-up menu, switching to dark mode">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/scene_files.gif" width="250" alt="A Files app on the native tab bar, with a pop-up menu that opens a Sort By submenu">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/scene_music.gif" width="250" alt="A Music app on CNTabBarNative: the tab bar minimizes on scroll and the now-playing accessory moves inline">
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/scene_photos.gif" width="250" alt="A Photos viewer: Liquid Glass buttons and a glass button group over two images, tinting themselves as you swipe">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/scene_account.gif" width="250" alt="An account page opening the native alert and the native action sheet">
</p>

<p align="center"><sub>Every screen on this page is the example app, recorded on the iOS&nbsp;27 simulator. Nothing is mocked up.</sub></p>

## Why it looks right

- **Apple's own controls.** Each widget is a native UIKit or SwiftUI view, so the Liquid Glass, the animations, the menus and the haptics are the system's, and they keep up with every iOS release.
- **Liquid Glass everywhere it belongs.** Tab bars that minimize on scroll, glass buttons and button groups that blend, slider thumbs that turn to glass under your finger, menus with submenus, alerts and anchored action sheets.
- **iPhone Duo ready.** Tabs move to the vertical bar when folded and to a sidebar when open, and layouts can split at the hinge.
- **Light and dark for free.** Every control follows the app's brightness.
- **Runs everywhere else, too.** Below iOS&nbsp;26 and on Android and the web, each widget falls back to its Cupertino counterpart, so one codebase covers every platform.
- **Accessible.** Native controls carry their VoiceOver names, values and traits.

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/light_dark.png" width="520" alt="The Display and Brightness page in light and in dark mode">
</p>

## What's new in 1.9.0

- **Subtitles and submenus in `CNPopupMenuButton`**, nested as deep as you like, with `onPathSelected` reporting the full path. Thanks [@johan-perso](https://github.com/johan-perso).
- **`CNTabBarNative` no longer shows an empty accessory pill on iOS&nbsp;26.1+** when `bottomAccessory` is null. Thanks [@tgrushka](https://github.com/tgrushka).
- **`CNTabBarNative.enable(showCloseButton: false)`** for root-mode apps whose tab bar is the whole app.
- **`CNTabBar` no longer rebuilds its items on the first rebuild** when `iconSize` is set. Thanks [@Honahec](https://github.com/Honahec).

The full list is in the [changelog](https://pub.dev/packages/cupertino_native_better/changelog).

## Installation

```yaml
dependencies:
  cupertino_native_better: ^1.9.0
```

Liquid Glass needs iOS&nbsp;26 or macOS&nbsp;26; earlier versions get the Cupertino fallbacks. The iOS deployment target is 15.0.

## Quick start

```dart
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

void main() => runApp(
  CupertinoApp(
    // Keeps Liquid Glass views below sheets and dialogs. Required.
    navigatorObservers: [CNTabBarRouteObserver()],
    home: const HomePage(),
  ),
);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _wifi = true;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CNButton(
              label: 'Get Started',
              config: const CNButtonConfig(style: CNButtonStyle.prominentGlass),
              onPressed: () {},
            ),
            CNSwitch(value: _wifi, onChanged: (v) => setState(() => _wifi = v)),
          ],
        ),
      ),
    );
  }
}
```

### Required Setup: register `CNTabBarRouteObserver`

iOS 26 Liquid Glass widgets are native `UIView`s composited under Flutter via hybrid composition. Without coordination, their drop shadow / soft-edge halo can bleed through any sheet or popup pushed over the page, and `CNTabBar` can render above modal content (e.g. making a `TextField` inside a sheet invisible).

`cupertino_native_better` ships a single `NavigatorObserver` that fixes this for the entire app. **Register it once** on your root navigator:

```dart
CupertinoApp(
  navigatorObservers: [CNTabBarRouteObserver()],
  // ...
)
// or
MaterialApp(
  navigatorObservers: [CNTabBarRouteObserver()],
  // ...
)
// GoRouter:
GoRouter(
  observers: [CNTabBarRouteObserver()],
  routes: [...],
)
```

With this single line:

- `CNTabBar` auto-hides while a full-screen sheet is on top (fixes Issue #31 z-order conflicts with Material `TextField`s).
- Every glass widget (`CNButton`, `CNPopupMenuButton`, `CNFloatingIsland`, `CNGlassButtonGroup`, `LiquidGlassContainer`, `CNSearchBar`, split-search `CNTabBar`) clamps its halo while a modal/sheet/popup/dialog is presented above — no glass border bleeding through the modal scrim (Issues #29, #36).

For non-route overlays that the observer can't see (notably `Scaffold.showBottomSheet` — anchored to `ScaffoldState`, not pushed onto the Navigator), pair the show/close with the manual API:

```dart
final controller = Scaffold.of(context).showBottomSheet(...);
CNTabBarRouteObserver.markAnyModalActive();
controller.closed.whenComplete(CNTabBarRouteObserver.markAnyModalInactive);
```

> Without the observer registered, widgets still render fine — but the dynamic z-order/halo containment never engages, and you may see glass bleeding through modals.

### Recommended Setup: present bottom sheets via `CNBottomSheet`

Adding to the observer above, **v1.5.1** adds a second piece of the modal-coordination story to fix the PlatformView z-order bleed between CN-widgets on the host page and CN-widgets *inside* a presented sheet (Issue #53).

When a bottom sheet covers a CN-widget, the package now destroys the host-page widget's PlatformView (with a same-size placeholder reserving the layout slot) while the sheet is up, then recreates it on dismiss. For this to be **position-aware** — only the widgets actually behind the sheet hide, not the entire route — the sheet has to publish its on-screen rect each frame.

**Option A — drop-in wrappers (recommended):**

```dart
CNBottomSheet.show(context: context, builder: (ctx) => MySheet());
CNBottomSheet.showCupertino(context: context, builder: (ctx) => MySheet());
CNBottomSheet.showModalPopup(context: context, builder: (ctx) => MySheet());
```

`CNBottomSheet` mirrors Flutter's standard sheet APIs and injects a `CNSheetGeometryProbe` automatically.

**Option B — wrap your own sheet manually:**

```dart
showModalBottomSheet(
  context: context,
  builder: (ctx) => CNSheetGeometryProbe(child: MySheet()),
);
```

Wrap the builder's root child in `CNSheetGeometryProbe` if you need to keep using the framework's `showModalBottomSheet` / `showCupertinoModalPopup` directly (e.g. for advanced configuration not yet exposed on `CNBottomSheet`).

Without one of these, the package falls back to a conservative "hide every CN-widget on this route while any modal is up" behavior — safe, but coarser than needed (e.g. an app-bar CN-button could disappear behind a 30%-height sheet).

Each affected widget also has an `autoHideOnModal: bool = true` constructor parameter so you can opt out per-instance if you ever need the old behavior.

## Components

### Slider, switch and segmented control

The system's own controls, so the slider thumb turns to glass while you drag it and the switch stretches as it flips.

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/slider.gif" width="420" alt="A native slider: the thumb turns to Liquid Glass while it is dragged"><br>
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/switch.gif" width="420" alt="A native switch flipping on"><br>
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/segmented_control.gif" width="420" alt="A native segmented control selecting Dark, which switches the page to dark mode">
</p>

```dart
CNSlider(value: _brightness, onChanged: (v) => setState(() => _brightness = v))

CNSwitch(value: _trueTone, onChanged: (v) => setState(() => _trueTone = v))

CNSegmentedControl(
  labels: const ['Light', 'Dark', 'Automatic'],
  selectedIndex: _appearance,
  onValueChanged: (i) => setState(() => _appearance = i),
)
```

### Pop-up menus with subtitles and submenus

A real `UIMenu`: subtitles, checkmarks, SF Symbols, destructive items and submenus nested as deep as you need.

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/popup_menu.gif" width="300" alt="A native pop-up menu opening a Sort By submenu and re-sorting the list by name">
</p>

```dart
CNPopupMenuButton.icon(
  buttonIcon: const CNSymbol('ellipsis'),
  items: [
    const CNPopupMenuItem(label: 'New Folder', icon: CNSymbol('folder.badge.plus')),
    const CNPopupMenuDivider(),
    CNPopupMenuSubmenu(
      label: 'Sort By',
      subtitle: 'Date',
      icon: const CNSymbol('arrow.up.arrow.down'),
      items: [
        for (final name in ['Name', 'Kind', 'Date', 'Size'])
          CNPopupMenuItem(label: name, checked: name == 'Date'),
      ],
    ),
  ],
  onPathSelected: (path) {}, // [2, 0] = Sort By › Name
)
```

### Tab bar

`CNTabBar` is a native `UITabBar` for your own layout, with badges, image assets, a split mode and a separate search tab.

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/tab_bar.gif" width="420" alt="The native tab bar switching between Recents, Shared and Browse">
</p>

```dart
CNTabBar(
  items: const [
    CNTabBarItem(label: 'Recents', icon: CNSymbol('clock'), activeIcon: CNSymbol('clock.fill')),
    CNTabBarItem(label: 'Shared', icon: CNSymbol('folder.badge.person.crop')),
    CNTabBarItem(label: 'Browse', icon: CNSymbol('folder'), activeIcon: CNSymbol('folder.fill')),
  ],
  currentIndex: _tab,
  onTap: (i) => setState(() => _tab = i),
  searchItem: const CNTabBarSearchItem(placeholder: 'Search'),
)
```

### Native tab bar with minimize on scroll

`CNTabBarNative` presents a SwiftUI `TabView`: the bar minimizes while you scroll, a bottom accessory rides above it, and the search tab is the system's.

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/native_tab_bar.gif" width="420" alt="The native TabView: the tab bar minimizes on scroll, the now-playing accessory moves inline, then Library and Search open">
</p>

```dart
await CNTabBarNative.enable(
  asRoot: true,
  showCloseButton: false,
  bottomAccessory: const CNTabAccessory(text: 'Morning Run Mix', sfSymbol: CNSymbol('play.fill')),
  tabs: [
    CNTab(title: 'Home', sfSymbol: const CNSymbol('house.fill'), nativeList: homeList),
    CNTab(title: 'Library', sfSymbol: const CNSymbol('square.stack.fill'), badgeCount: 3, nativeList: libraryList),
    CNTab(title: 'Search', isSearchTab: true, nativeList: searchList),
  ],
);
```

### Buttons and Liquid Glass

Glass and prominent glass buttons, icon buttons with badges, and `CNGlassButtonGroup`, whose buttons share one piece of glass. The glass picks up the colour of whatever is behind it.

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/glass_buttons.gif" width="420" alt="Liquid Glass buttons and a glass button group over a photo, tinting themselves as the photo changes">
</p>

```dart
CNButton.icon(icon: const CNSymbol('square.and.arrow.up'), onPressed: share)

CNGlassButtonGroup(
  buttons: [
    CNButtonData.icon(icon: const CNSymbol('heart'), onPressed: like,
        config: const CNButtonDataConfig(glassEffectUnionId: 'actions')),
    CNButtonData.icon(icon: const CNSymbol('info.circle'), onPressed: info,
        config: const CNButtonDataConfig(glassEffectUnionId: 'actions')),
  ],
)
```

### Alerts and action sheets

`UIAlertController`, with text fields, cancel and destructive actions. On iOS&nbsp;26 an action sheet anchors to the control that opened it.

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/alert.gif" width="330" alt="A native alert with Cancel and a destructive Sign Out action">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/action_sheet.gif" width="330" alt="A native action sheet anchored to the Delete Account row">
</p>

```dart
final result = await CNAlert.show<String>(
  context: context,
  title: 'Sign Out?',
  actions: const [
    CNAlertAction(label: 'Cancel', isCancel: true),
    CNAlertAction(label: 'Sign Out', value: 'out', isDestructive: true),
  ],
);
```

### iPhone Duo

`CNTabScaffold` puts the tabs where the system would: in the vertical bar when the device is closed, in a sidebar when it is open. `CNFoldable` reports the hinge, so a layout can split exactly at the fold.

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/iphone_duo.gif" width="600" alt="iPhone Duo: tabs in the vertical bar when closed, then the device opens and, half folded, the list and the selected file split at the hinge">
</p>

```dart
CNFoldableScope(
  child: CNTabScaffold(
    items: tabs,
    currentIndex: _tab,
    onTap: (i) => setState(() => _tab = i),
    sidebarOnWideScreens: true,
    body: page,
  ),
)
```

### And more

| Widget | What it is |
|---|---|
| `CNIcon` | SF Symbols drawn by the system, in every rendering mode, plus your own image assets and `IconData` |
| `CNSearchBar` | An expanding native search field |
| `CNToast` | Toasts on Liquid Glass, with success, error, warning, info and loading styles |
| `CNFloatingIsland` | A glass island that expands into more content |
| `CNBottomSheet` | Sheets that keep the glass behind them where it belongs |
| `LiquidGlassContainer` | Liquid Glass behind any Flutter widget |
| `CNTabRail` | A vertical glass tab rail or sidebar |
| `CNGlassCard` | An experimental glass card with an optional breathing glow |

Open the example app's **Showcase** section to try every screen above on your own device.

## Guides

### Widgets

| Widget | Description | Controller |
|--------|-------------|:----------:|
| `CNButton` | Native push button with Liquid Glass effects, SF Symbols, and image assets | - |
| `CNButton.icon` | Circular icon-only button variant | - |
| `CNIcon` | Platform-rendered SF Symbols, custom IconData, or image assets | - |
| `CNTabBar` | Native tab bar with split mode for scroll-aware layouts | - |
| `CNTabRail` | Vertical tab bar (glass rail or sidebar) for the side of the screen | - |
| `CNTabScaffold` | Tab layout that moves the tabs to the side on iPhone Duo, like the system | - |
| `CNFoldable` | iPhone Duo hinge (status + angle), vertical-bar side, fold and camera regions | - |
| `CNSlider` | Native slider with min/max range and step support | `CNSliderController` |
| `CNSwitch` | Native toggle switch with animated state changes | `CNSwitchController` |
| `CNPopupMenuButton` | Native popup menu with dividers, icons, image assets, subtitles and submenus | - |
| `CNPopupMenuButton.icon` | Circular icon-only popup menu variant | - |
| `CNActionSheet` | Native `UIAlertController` action sheet with destructive styling | - |
| `CNAlert` | Native `UIAlertController` alert with text fields and destructive styling | - |
| `CNSegmentedControl` | Native segmented control with SF Symbols support | - |
| `CNGlassButtonGroup` | Grouped buttons with unified glass blending (tint color support) | - |
| `LiquidGlassContainer` | Apply Liquid Glass effects to any Flutter widget | - |
| `CNGlassCard` | **(Experimental)** Pre-styled card with optional breathing glow animation | - |
| `CNTabBarNative` | **iOS 26 Native Tab Bar** with UITabBarController + search | - |
| `CNToast` | Toast notifications with Liquid Glass effects | - |

### Tab Bar with Split Mode

```dart
CNTabBar(
  items: [
    CNTabBarItem(
      label: 'Home',
      icon: CNSymbol('house'),
      activeIcon: CNSymbol('house.fill'),
    ),
    CNTabBarItem(
      label: 'Profile',
      icon: CNSymbol('person.crop.circle'),
      activeIcon: CNSymbol('person.crop.circle.fill'),
    ),
  ],
  currentIndex: _selectedIndex,
  onTap: (index) => setState(() => _selectedIndex = index),
  iconSize: 25, // Optional: customize icon size (default ~25pt)
  split: true, // Separates tabs when scrolling
  rightCount: 1, // Number of tabs pinned to the right
)
```

#### Precaching `customIcon` items

Items that use `customIcon` (an `IconData`) are rendered to images before the
native bar can be created, so the first mount of a bar shows its Flutter
fallback for a few frames. When a bar appears right after launch, warm the
cache first with the same items and `iconSize` the bar will use:

```dart
await CNTabBar.precacheIcons(items, iconSize: 25);
```

A bar mounted afterwards skips the fallback. SF Symbol and `imageAsset` items
need no precaching.

#### Badges, dots and label fonts

```dart
CNTabBar(
  items: const [
    CNTabBarItem(label: 'Inbox', icon: CNSymbol('tray'), badge: '3'),
    // A small red dot instead of a count, e.g. for "something new".
    CNTabBarItem(label: 'Feed', icon: CNSymbol('sparkles'), badge: CNTabBarItem.dotBadge),
  ],
  currentIndex: _selectedIndex,
  onTap: (index) => setState(() => _selectedIndex = index),
  labelFontFamily: 'Avenir Next', // any font registered with iOS
  labelFontSize: 11,
)
```

`UITabBarItem` has no dot badge, so `CNTabBar` and `CNTabRail` draw
`CNTabBarItem.dotBadge` themselves. VoiceOver reads nothing for a dot, so if
it matters, say what is new in the tab's label. `labelFontFamily` and
`labelFontSize` apply to the native bar, at creation and when they change;
`labelFontSize` alone sizes the system font, and setting both back to null
restores the native label (1.8.3). A taller label moves the icon up to keep
clear of it, and a title wider than a narrow tab (the lone tab in split mode)
shrinks to fit.

#### Items that open a menu

`menuItems` turns an item into a button that opens a native menu instead of
selecting itself, for example a "+" that lets the user pick what to create.
It takes the same entries as `CNPopupMenuButton`, with subtitles and
submenus, and the chosen entry goes to `onMenuSelected` with its path.

```dart
CNTabBar(
  split: true,
  rightCount: 1,
  items: [
    const CNTabBarItem(label: 'Home', icon: CNSymbol('house.fill')),
    const CNTabBarItem(label: 'Library', icon: CNSymbol('books.vertical.fill')),
    const CNTabBarItem(label: 'Profile', icon: CNSymbol('person.fill')),
    CNTabBarItem(
      icon: const CNSymbol('plus'),
      menuItems: const [
        CNPopupMenuItem(label: 'New note', subtitle: 'Text, lists and photos'),
        CNPopupMenuItem(label: 'New folder'),
        CNPopupMenuDivider(),
        CNPopupMenuSubmenu(label: 'Import', items: [
          CNPopupMenuItem(label: 'Photo'),
          CNPopupMenuItem(label: 'File'),
        ]),
      ],
    ),
  ],
  currentIndex: _selectedIndex,
  onTap: (index) => setState(() => _selectedIndex = index),
  // index 3, path [3, 1] for Import > File.
  onMenuSelected: (index, path) => openCreatePage(path),
)
```

An item with a menu never gets selected nor calls `onTap`, and its glass
still reacts under the finger. Sliding a finger along the bar onto it opens
the menu too. Menu entries show SF Symbols and image
assets, not `customIcon`. On the Flutter fallback (iOS < 26, Android, web),
the menu opens as a `CupertinoActionSheet`, as `CNPopupMenuButton`'s does.
On the iOS 26 bar with a `searchItem`, and on the native macOS bar, the item
is a plain tab.

### Native iOS 26 Tab Bar (CNTabBarNative)

> **`CNTabBarNative` is not a Flutter widget — it is a full native takeover.**
> Calling `CNTabBarNative.enable(...)` presents a real iOS 26 Liquid Glass tab bar
> (a SwiftUI `TabView` over a `UITabBarController`) **on top of / in place of** your
> Flutter app. You don't put it in your widget tree and there is **no `currentIndex` /
> `onTap` contract** — you drive it with static methods and react to callbacks.
>
> **iOS 26+ only.** On older iOS, other platforms, or the web, `enable()` is a silent
> no-op (nothing appears). If you need a tab bar that works everywhere and lives inside
> your Flutter tree, use [`CNTabBar`](#tab-bar-with-split-mode) instead.

#### `CNTabBar` vs `CNTabBarNative` — pick the right one

| | **`CNTabBar`** (widget) | **`CNTabBarNative`** (native takeover) |
|---|---|---|
| Where it lives | In your Flutter widget tree | Presented natively over/instead of your app |
| Each tab's content | **Your Flutter screens** (you own navigation) | Native scrolling lists, a native search tab, and/or **one** root-mode Flutter surface |
| Platforms | iOS (Liquid Glass on 26) + graceful Flutter fallback elsewhere | **iOS 26 only** (no-op otherwise) |
| Minimize-on-scroll (shrink) | ✗ | ✅ (`minimizeBehavior`) |
| Apple-Music-style search tab | Split-search variant (`searchItem`) | ✅ Dedicated `Tab(role: .search)` |
| Bottom accessory pill | ✗ | ✅ (`bottomAccessory`) |
| Best for | **A normal app** — Flutter screens per tab | Showcasing iOS 26 native chrome: minimize, native search, accessory |

> ⚠️ **Do _not_** use `CNTabBarNative` as a drop-in for a Flutter bottom nav — e.g.
> calling `enable()` in `initState` and driving an `IndexedStack` /
> `Scaffold.bottomNavigationBar` from `onTabSelected` → `setState`. That creates **two
> sources of truth** for the selected tab (the native bar _and_ your Flutter state),
> which causes the "have to tap twice" behavior and screen rebuilds. For Flutter screens
> per tab, use **`CNTabBar`**.

#### Two presentation modes

`CNTabBarNative` can present in one of two ways, controlled by `asRoot`:

- **Modal (default, `asRoot: false`)** — presented full-screen over your app. Tabs that
  have a `nativeList` show native lists; tabs **without** a list show a placeholder
  (Flutter content requires root mode). Dismiss with `disable()` or the ✕ button.
- **Root (`asRoot: true`)** — replaces the app's root view controller (primary
  navigation). A tab **without** a `nativeList` then hosts your **real Flutter UI**
  (the package re-parents your existing `FlutterViewController` into that tab). This is
  how you mix native list/search tabs with **one** live Flutter "home" surface.

#### Minimal example (modal, native lists + search + minimize)

```dart
await CNTabBarNative.enable(
  tabs: [
    // A tab with a nativeList renders a native scrollable list — and is what
    // lets the bar minimize on scroll (iOS needs a real native scroll view).
    CNTab(
      title: 'Feed',
      sfSymbol: CNSymbol('list.bullet'),
      nativeList: CNNativeList(items: [
        for (var i = 1; i <= 50; i++)
          CNListItem(
            title: 'Post #$i',
            subtitle: 'Row $i',
            leadingSymbol: CNSymbol('photo'),
            showChevron: true,
          ),
      ]),
    ),
    CNTab(
      title: 'Profile',
      sfSymbol: CNSymbol('person'),
      badgeCount: 3,
      nativeList: CNNativeList(items: profileItems),
    ),
    // Apple-Music-style search tab: its OWN screen with its OWN list + search field.
    CNTab(
      title: 'Search',
      isSearchTab: true,
      nativeList: CNNativeList(items: searchableItems),
    ),
  ],
  minimizeBehavior: CNTabMinimizeBehavior.onScrollDown, // shrink on scroll down
  bottomAccessory: CNTabAccessory(
    text: 'Now Playing',
    sfSymbol: CNSymbol('music.note'),
  ),
  tintColor: CupertinoColors.systemBlue,
  isDark: false,
  // Callbacks
  onTabSelected: (i) => debugPrint('tab $i'),
  onListItemTap: (tabIndex, itemIndex) => debugPrint('row $itemIndex in tab $tabIndex'),
  onSearchChanged: (query) => debugPrint('search: $query'),
  onAccessoryTap: () => debugPrint('accessory tapped'),
  onDismissed: () => debugPrint('bar closed (✕ or disable())'),
);

// Later, when leaving the experience:
await CNTabBarNative.disable();
```

#### Tabs — `CNTab`

```dart
CNTab(
  title: 'Feed',                       // shown under the icon
  sfSymbol: CNSymbol('list.bullet'),   // the tab icon (SF Symbol)
  badgeCount: 3,                       // optional red badge
  isSearchTab: false,                  // mark exactly one tab as the search tab
  nativeList: CNNativeList(items: [...]), // optional native list content
)
```

- A tab **with `nativeList`** → a native scrollable list (`CNListItem`s). Required for
  minimize-on-scroll.
- A tab **with `isSearchTab: true`** → the detached iOS 26 search button that morphs into
  a search field (Apple Music style). It is its own destination with its own list.
- A tab with **neither** → hosts your Flutter content in root mode, or a placeholder in
  modal mode.

#### Minimize-on-scroll

```dart
minimizeBehavior: CNTabMinimizeBehavior.onScrollDown,
```

| Value | Behavior |
|---|---|
| `automatic` | System default for the context |
| `never` | Bar stays fully expanded |
| `onScrollDown` | Minimize when scrolling **down**, expand on scroll up |
| `onScrollUp` | Minimize when scrolling **up**, expand on scroll down |

Requires at least one tab backed by a `CNNativeList` (iPhone) — a Flutter list cannot
drive the native minimize. Change it at runtime with `setMinimizeBehavior(...)` (e.g. set
`.never` to keep the bar expanded on a particular screen).

#### Search tab

The search tab is a **separate destination** (not an in-place filter of another tab).
Two ways to populate results:

- **`nativeSearchFilter: true`** (default) — iOS filters the search tab's own
  `nativeList` for you, locally, as the user types.
- **`nativeSearchFilter: false`** — you drive it: listen to `onSearchChanged(query)`, run
  your own search (a backend, or across your own data), and push results into the search
  tab with `setItems(tabIndex: searchTabIndex, items: results)`.

Programmatic helpers: `setSearchText(text)`, `activateSearch()` (select the search tab),
`deactivateSearch()` (clear the query).

#### Bottom accessory pill

A pill that floats above the bar and slides **inline** into it when the bar minimizes.

```dart
bottomAccessory: CNTabAccessory(text: 'Now Playing', sfSymbol: CNSymbol('music.note')),
// ...
onAccessoryTap: () { /* tapped */ },
```

Show / update / hide it after `enable()` with `setBottomAccessory(accessory)` — pass
`null` to hide (e.g. hide it on a specific tab from inside `onTabSelected`).

#### API reference

| Method | What it does |
|---|---|
| `enable({tabs, selectedIndex, minimizeBehavior, bottomAccessory, tintColor, isDark, asRoot, nativeSearchFilter, ...callbacks})` | Present the native tab bar. No-op below iOS 26. |
| `disable()` | Dismiss the bar and return to your app. |
| `isEnabled` | `bool` — whether the bar is currently presented. |
| `setItems({tabIndex, items})` | Replace a tab's native list (async data, pagination, live updates). |
| `setSelectedIndex(index)` | Programmatically select a tab. |
| `setBadgeCounts(List<int?>)` | Per-tab badges (`null`/`0` clears). |
| `setBottomAccessory(accessory?)` | Show / update / hide the accessory (`null` hides). |
| `setStyle({tintColor})` | Update the selected-tab tint. |
| `setBrightness({isDark})` | Switch light/dark appearance. |
| `setMinimizeBehavior(behavior)` | Change when the bar minimizes. |
| `setSearchText(text)` / `activateSearch()` / `deactivateSearch()` | Drive the search tab. |

**Callbacks** (all optional): `onTabSelected(int index)`, `onListItemTap(int tabIndex,
int itemIndex)`, `onSearchChanged(String query)`, `onAccessoryTap()`, `onDismissed()`
(fired when the bar is closed natively via ✕ — reset your own state here).

### Tab Bar with iOS 26 Search Tab

The `CNTabBar` supports iOS 26's native search tab feature with animated expansion:

```dart
CNTabBar(
  items: [
    CNTabBarItem(
      label: 'Overview',
      icon: CNSymbol('square.grid.2x2.fill'),
    ),
    CNTabBarItem(
      label: 'Projects',
      icon: CNSymbol('folder'),
      activeIcon: CNSymbol('folder.fill'),
    ),
  ],
  currentIndex: _index,
  onTap: (i) => setState(() => _index = i),
  // iOS 26 Search Tab Feature
  searchItem: CNTabBarSearchItem(
    placeholder: 'Find customer',
    // Control keyboard auto-activation
    automaticallyActivatesSearch: false, // Keyboard only opens on text field tap
    onSearchChanged: (query) {
      // Live filtering as user types
    },
    onSearchSubmit: (query) {
      // Handle search submission
    },
    onSearchActiveChanged: (isActive) {
      // React to search expand/collapse
    },
    style: const CNTabBarSearchStyle(
      iconSize: 20,
      buttonSize: 44,
      searchBarHeight: 44,
      animationDuration: Duration(milliseconds: 400),
      showClearButton: true,
    ),
  ),
  searchController: _searchController, // Optional programmatic control
)
```

#### automaticallyActivatesSearch

Controls whether the keyboard opens automatically when the search tab expands:

- `true` (default): Tapping the search button expands the bar AND opens the keyboard
- `false`: Tapping the search button only expands the bar; keyboard opens when user taps the text field

This mirrors `UISearchTab.automaticallyActivatesSearch` from UIKit.

### iPhone Duo (foldable)

iPhone Duo folds. Closed, it uses its outer display; open, its larger inner display; partially open, it stands in a *book* pose (fold top to bottom) or a *tabletop* pose (fold left to right). On the outer display, and on the inner display in landscape, iOS 27.1 moves the status bar and the tab bar to a **vertical bar** on one edge.

**`CNTabBarNative`** gets the vertical bar automatically once your app is built with Xcode 27.1. Add `sidebarOnWideScreens: true` to turn the tabs into a native sidebar on the open inner display: beside the content in landscape, behind a sidebar button in portrait.

```dart
CNTabBarNative.enable(
  tabs: [...],
  sidebarOnWideScreens: true,
);
```

**`CNTabScaffold`** does the same for `CNTabBar`, which as a standalone bar never turns vertical on its own. It shows a `CNTabBar` at the bottom, swaps it for a `CNTabRail` in the vertical-bar column whenever iOS uses one, and can show a sidebar on wide screens. The body stays mounted, so folding never resets your page:

```dart
CNFoldableScope( // once, above the app
  child: CNTabScaffold(
    items: const [
      CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
      CNTabBarItem(label: 'Library', icon: CNSymbol('books.vertical')),
    ],
    currentIndex: index,
    onTap: (i) => setState(() => index = i),
    sidebarOnWideScreens: true,
    body: pages[index],
  ),
)
```

**`CNFoldable`** reports the hinge, the vertical bar and the screen's reserved regions. `CNFoldableScope` also adds the fold and the camera to `MediaQuery.displayFeatures`, so Flutter's own dialogs and popups keep clear of the fold when the device is partially open:

```dart
final duo = CNFoldable.of(context);

duo.hinge?.status;     // CNHingeStatus.closed / partiallyOpen / fullyOpen
duo.hinge?.degrees;    // 0 (shut) … 180 (flat)
duo.verticalBarSide;   // CNVerticalBarSide.none / left / right
duo.activeFold?.frame; // where the fold is, in logical pixels
```

Use the hinge angle for effects and the status and regions for layout, as Apple recommends. The *iPhone Duo* page of the example app splits a player at the fold (artwork above it in the tabletop pose, a list beside it in the book pose) and reflows an even-numbered grid.

> **Requirements:** iOS 27.1 and Xcode 27.1 (the iOS 27.1 SDK). Built with an older Xcode the package still compiles; `CNFoldable` then reports `CNFoldableState.unsupported` and `CNTabScaffold` keeps a bottom bar.
>
> **Your own layouts:** on the outer display the vertical status bar adds a safe-area inset on one side. `ListView` pads only along its scroll axis, so wrap content in `SafeArea(top: false, bottom: false, …)` (or use `CNTabScaffold`'s body) to keep it clear.
>
> **Simulator:** Xcode 27.1 replaces Simulator with Device Hub. The *Closed*, *Partially Open* and *Open* pose buttons sit below the device; hold Option and drag the slider for any angle.

### Accessibility

The widgets that render natively are real UIKit and SwiftUI controls, so VoiceOver, Voice Control and Switch Control see the system's own controls rather than an imitation. Checked through the iOS accessibility tree (iPhone Duo simulator, iOS 27.1):

| Widget | What VoiceOver gets |
|--------|---------------------|
| `CNButton`, `CNButton.icon` | A button, named by its title or `semanticLabel` |
| `CNPopupMenuButton` | A button that opens the system menu |
| `CNSlider` | An adjustable slider with its value; swipe up or down to change it |
| `CNSwitch` | A switch with its on/off state |
| `CNSegmentedControl` | A group of segments, each with its title |
| `CNTabRail` | A button per tab, with its badge as the value and the selected state |
| `CNTabBarNative`, `CNAlert`, `CNActionSheet` | System controllers, presented by iOS |

**Name every icon-only control.** Without a name, an icon-only button is read by its SF Symbol's built-in name, which describes the picture rather than the action (`moon` is read as "do not disturb"), and a switch or slider has no name at all: a native control cannot merge with the Flutter text next to it. Pass `semanticLabel`:

```dart
CNButton.icon(
  icon: const CNSymbol('moon'),
  semanticLabel: 'Switch to dark mode',
  onPressed: toggleTheme,
)

CNSwitch(value: wifi, semanticLabel: 'Wi-Fi', onChanged: setWifi)
CNSlider(value: volume, semanticLabel: 'Volume', onChanged: setVolume)
```

**Dynamic Type.** Button titles follow the system text size. Tab bars, the tab rail and segmented controls keep a fixed size, as they do throughout iOS, and offer the **Large Content Viewer** instead: with a large text size, long-press an item to see it enlarged. `CNTabBar` and `CNTabBarNative` are system tab bars, and `CNTabRail` adopts the viewer as well.

> **Known Flutter limitation ([flutter/flutter#194389](https://github.com/flutter/flutter/issues/194389)):** VoiceOver *touch exploration* — moving a finger over the screen to find an element — does not reach a native control that shares its area with a scrolling Flutter list, because Flutter's accessibility hit test returns the list first. That covers controls placed inside a `ListView`, and a `CNTabBar` or `CNTabScaffold` bar floating over scrolling content. `CNTabBarNative` is not affected: its tab bar is a real `UITabBarController` outside Flutter's view. Where touch exploration of the tab bar matters, prefer `CNTabBarNative`.

### Icon Support

All widgets support three icon types with unified priority:

1. **Image Assets** (highest priority) - PNG, SVG, JPG with automatic resolution selection
2. **Custom Icons** - Any `IconData` (CupertinoIcons, Icons, custom)
3. **SF Symbols** - Native Apple SF Symbols with rendering modes

```dart
// SF Symbol
CNButton(
  label: 'Settings',
  icon: CNSymbol('gear', size: 20),
  onPressed: () {},
)

// Custom Icon
CNButton(
  label: 'Home',
  customIcon: CupertinoIcons.home,
  onPressed: () {},
)

// Image Asset
CNButton(
  label: 'Custom',
  imageAsset: CNImageAsset('assets/icons/custom.png', size: 20),
  onPressed: () {},
)
```

### Button Styles

```dart
CNButtonStyle.plain           // Minimal, text-only
CNButtonStyle.gray            // Subtle gray background
CNButtonStyle.tinted          // Tinted text
CNButtonStyle.bordered        // Bordered outline
CNButtonStyle.borderedProminent // Accent-colored border
CNButtonStyle.filled          // Solid filled background
CNButtonStyle.glass           // Liquid Glass effect (iOS 26+)
CNButtonStyle.prominentGlass  // Prominent glass effect (iOS 26+)
```

### Glass Effect Unioning

Multiple buttons can share a unified glass effect:

```dart
Row(
  children: [
    CNButton(
      label: 'Left',
      config: CNButtonConfig(
        style: CNButtonStyle.glass,
        glassEffectUnionId: 'toolbar',
      ),
      onPressed: () {},
    ),
    CNButton(
      label: 'Right',
      config: CNButtonConfig(
        style: CNButtonStyle.glass,
        glassEffectUnionId: 'toolbar',
      ),
      onPressed: () {},
    ),
  ],
)
```

## Usage

### Basic Button

```dart
CNButton(
  label: 'Get Started',
  icon: CNSymbol('arrow.right', size: 18),
  config: CNButtonConfig(
    style: CNButtonStyle.filled,
    imagePlacement: CNImagePlacement.trailing,
  ),
  onPressed: () {
    // Handle tap
  },
)
```

### Button Styles Gallery

### Icon-Only Button

```dart
CNButton.icon(
  icon: CNSymbol('plus', size: 24),
  config: CNButtonConfig(style: CNButtonStyle.glass),
  onPressed: () {},
)
```

### Native Icons

```dart
CNIcon(
  symbol: CNSymbol(
    'star.fill',
    size: 32,
    color: Colors.amber,
    mode: CNSymbolRenderingMode.multicolor,
  ),
)
```

### Slider with Controller

```dart
final controller = CNSliderController();

CNSlider(
  value: 0.5,
  min: 0,
  max: 1,
  controller: controller,
  onChanged: (value) {
    print('Value: $value');
  },
)

// Programmatic update
controller.setValue(0.75);
```

### Switch with Controller

```dart
final controller = CNSwitchController();

CNSwitch(
  value: _isEnabled,
  onChanged: (value) {
    setState(() => _isEnabled = value);
  },
  controller: controller,
  color: Colors.green, // Optional tint color
)

// Programmatic control
controller.setValue(true, animated: true);
controller.setEnabled(false); // Disable interaction
```

### Popup Menu Button

```dart
// Text-labeled popup menu
CNPopupMenuButton(
  buttonLabel: 'Options',
  buttonStyle: CNButtonStyle.glass,
  items: [
    CNPopupMenuItem(
      label: 'Edit',
      icon: CNSymbol('pencil'),
    ),
    CNPopupMenuItem(
      label: 'Share',
      icon: CNSymbol('square.and.arrow.up'),
    ),
    const CNPopupMenuDivider(), // Visual separator
    CNPopupMenuItem(
      label: 'Delete',
      icon: CNSymbol('trash', color: Colors.red),
      enabled: true,
    ),
  ],
  onSelected: (index) {
    print('Selected item at index: $index');
  },
)

// Icon-only popup menu (circular glass button)
CNPopupMenuButton.icon(
  buttonIcon: CNSymbol('ellipsis.circle', size: 24),
  buttonStyle: CNButtonStyle.glass,
  items: [
    CNPopupMenuItem(label: 'Option 1', icon: CNSymbol('star')),
    CNPopupMenuItem(label: 'Option 2', icon: CNSymbol('heart')),
  ],
  onSelected: (index) {},
)
```

#### Subtitles and submenus

`subtitle` adds a second line under an item's label. `CNPopupMenuSubmenu` opens a nested menu, and can itself contain submenus. On iOS they are the system's `UIAction.subtitle` and nested `UIMenu`; on macOS `NSMenuItem.subtitle` (macOS 14.4+) and `NSMenuItem.submenu`; the `CupertinoActionSheet` fallback shows the subtitle as a smaller line and opens each submenu as a second sheet.

```dart
CNPopupMenuButton(
  buttonLabel: 'Actions',
  items: const [
    CNPopupMenuItem(label: 'Rename', subtitle: 'Also renames the file'),
    CNPopupMenuDivider(),
    CNPopupMenuSubmenu(
      label: 'Export',
      subtitle: '3 formats',
      icon: CNSymbol('square.and.arrow.up'),
      items: [
        CNPopupMenuItem(label: 'PDF'),
        CNPopupMenuSubmenu(
          label: 'Spreadsheet',
          items: [
            CNPopupMenuItem(label: 'CSV'),
            CNPopupMenuItem(label: 'Numbers'),
          ],
        ),
      ],
    ),
  ],
  onPathSelected: (path) {
    // [0]       → Rename
    // [2, 0]    → Export › PDF
    // [2, 1, 0] → Export › Spreadsheet › CSV
  },
)
```

`onPathSelected` is called for every selection with the path to the selected item: one index per level, dividers included, as in `onSelected`. `onSelected` still gets an index in `items`; for an item inside a submenu, that is the index of the top-level submenu it is under. At least one of the two callbacks is required, and `onPathSelected` is required as soon as `items` contain a submenu. When both are set, both are called.

### Action Sheet

An imperative API, like `CNToast.show`. On iOS it presents a real
`UIAlertController` in `.actionSheet` style, so the sheet is the system
control — system destructive red, VoiceOver, Dynamic Type, and on iOS 26 the
Liquid Glass appearance, which the system applies with no opt-in. Because the
appearance comes from the OS, the native path is used on **every** supported
iOS version instead of being gated on iOS 26. Other platforms fall back to
`CupertinoActionSheet`.

```dart
final choice = await CNActionSheet.show<String>(
  context: context,
  title: 'Delete photo?',
  message: 'This cannot be undone.',
  actions: const [
    CNActionSheetAction(
      label: 'Delete',
      value: 'delete',
      isDestructive: true,
    ),
    CNActionSheetAction(label: 'Duplicate', value: 'duplicate'),
    CNActionSheetAction(label: 'Export as PDF', value: 'pdf', enabled: false),
  ],
  cancelLabel: 'Cancel',
);

if (choice == 'delete') _deletePhoto();
```

`show` resolves to the selected action's `value`, or `null` when the sheet is
cancelled or dismissed.

#### Anchoring — read this before shipping

Starting in iOS 26 an action sheet anchors to the view it came from **on iPhone
as well as iPad**, appearing directly over that view instead of sliding up from
the bottom ([WWDC25](https://developer.apple.com/forums/thread/803824)). Pass
`anchorRect` — the global rect of the widget that triggered the sheet — to get
that presentation and its transition:

```dart
final box = _buttonKey.currentContext!.findRenderObject()! as RenderBox;

await CNActionSheet.show<String>(
  context: context,
  anchorRect: box.localToGlobal(Offset.zero) & box.size,
  actions: const [
    CNActionSheetAction(label: 'Share', value: 'share'),
    CNActionSheetAction(label: 'Remove', value: 'remove', isDestructive: true),
  ],
);
```

Omitting `anchorRect` is still valid — the system centres the sheet. Two things
to know about that path:

- On iOS 26 a centred sheet groups the cancel button with the actions (side by
  side when there is only one action), rather than the detached bottom row
  older iOS used.
- Below iOS 26 UIKit adds no cancel button of its own, so the sheet shows
  exactly the actions you passed. Without a `cancelLabel` the only way out is to
  pick one, so pass one unless forcing a choice is what you want.

What `anchorRect` itself does depends on the presentation the OS picks:

- On iPad, and on iPhone from iOS 26, the sheet is a popover: it drops the
  cancel button and is dismissed by tapping outside, so passing `cancelLabel`
  alongside `anchorRect` is harmless — it simply does not render.
- On iPhone below iOS 26 `anchorRect` does not turn the sheet into a popover.
  It still slides up from the bottom, still renders `cancelLabel` and still has
  no outside-tap dismissal, so pass one.

#### Content guidance

Apple's [HIG](https://developer.apple.com/design/human-interface-guidelines/action-sheets)
puts destructive choices at the top and caps the sheet at four buttons including
cancel. `CNActionSheet` preserves the order you pass — reordering would silently
break the index-to-`value` mapping — so put the destructive action first
yourself.

#### No per-action icons

`UIAlertAction` exposes no public image property, so `CNActionSheetAction` has
no icon field. The `setValue(_:forKey: "image")` workaround seen in the wild is
KVC against an undeclared private property: it risks App Store rejection and
breaks silently across iOS releases. Use [`CNPopupMenuButton`](#popup-menu-button)
when you need icons — its `UIMenu` path has a public image API.

### Alert

An imperative API like `CNActionSheet.show`. On iOS it presents a real
`UIAlertController` in `.alert` style — system typography, the destructive
red, VoiceOver, Dynamic Type, and on iOS 26 the Liquid Glass appearance — on
every supported iOS version. Other platforms fall back to
`CupertinoAlertDialog`.

```dart
final result = await CNAlert.show<String>(
  context: context,
  title: 'Delete photo?',
  message: 'This cannot be undone.',
  actions: const [
    CNAlertAction(label: 'Cancel', isCancel: true),
    CNAlertAction(label: 'Delete', value: 'delete', isDestructive: true),
  ],
);

if (result?.value == 'delete') _deletePhoto();
```

Text fields come back in `CNAlertResult.textFields`, in order:

```dart
final result = await CNAlert.show<String>(
  context: context,
  title: 'Rename',
  textFields: const [
    CNAlertTextField(placeholder: 'Name', initialText: 'Untitled'),
  ],
  actions: const [
    CNAlertAction(label: 'Cancel', isCancel: true),
    CNAlertAction(label: 'Save', value: 'save', isDefault: true),
  ],
);

if (result?.value == 'save') rename(result!.textFields.first);
```

`show` resolves to a `CNAlertResult` for every button press, cancel included,
and to `null` when no answer was produced — for example when, on iOS, a
second `CNAlert.show` replaced this alert. Things to know:

- An alert cannot be dismissed by tapping outside, so pass at least one
  enabled action. A call with none asserts in debug and resolves to `null`
  without presenting in release.
- At most one action may be `isCancel` and at most one `isDefault`; UIKit
  cannot render more.
- `UIAlertController` has no public API for custom content or action icons,
  so `CNAlert` offers neither.

### Segmented Control

```dart
// Text-only segments
CNSegmentedControl(
  labels: ['Day', 'Week', 'Month', 'Year'],
  selectedIndex: _selectedIndex,
  onValueChanged: (index) {
    setState(() => _selectedIndex = index);
  },
  color: Colors.blue, // Optional tint color
)

// Segments with SF Symbols
CNSegmentedControl(
  labels: ['List', 'Grid', 'Gallery'],
  sfSymbols: [
    CNSymbol('list.bullet'),
    CNSymbol('square.grid.2x2'),
    CNSymbol('photo.on.rectangle'),
  ],
  selectedIndex: _viewMode,
  onValueChanged: (index) {
    setState(() => _viewMode = index);
  },
  shrinkWrap: true, // Size to content
)
```

### Liquid Glass Container

```dart
LiquidGlassContainer(
  config: LiquidGlassConfig(
    effect: CNGlassEffect.regular,
    shape: CNGlassEffectShape.rect,
    cornerRadius: 16,
    interactive: true,
  ),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Text('Glass Effect'),
  ),
)

// Or use the extension
Text('Glass Effect')
  .liquidGlass(cornerRadius: 16)
```

### Experimental: Glass Card

```dart
CNGlassCard(
  child: Text("Hello"),
  breathing: true, // Optional subtle glow animation
)
```

## Performance Best Practices

### ⚠️ LiquidGlassContainer & Lists

`LiquidGlassContainer` uses a **Platform View** (`UiKitView` / `AppKitView`) under the hood. While powerful, platform views are more expensive than standard Flutter widgets.

*   **DO NOT** use `LiquidGlassContainer` inside long scrolling lists (`ListView.builder`, `GridView`) with many items. This will cause significant performance drops (jank).
*   **DO** use `LiquidGlassContainer` for static elements like Cards, Headers, Navigation Bars, or Floating Action Buttons.

## Platform Fallbacks

| Platform | Liquid Glass | SF Symbols | Other Widgets |
|----------|:------------:|:----------:|:-------------:|
| iOS 26+ | Native | Native | Native |
| iOS 13-25 | CupertinoButton | Native via CNIcon | CupertinoWidgets |
| macOS 26+ | Native | Native | Native |
| macOS 11-25 | CupertinoButton | Native via CNIcon | CupertinoWidgets |
| Android/Web/etc | Material fallback | Flutter Icon | Material fallback |

## Version Detection

Check platform capabilities:

```dart
// Check if Liquid Glass is available
if (PlatformVersion.shouldUseNativeGlass) {
  // iOS 26+ or macOS 26+
}

// Check if SF Symbols are available (iOS 13+, macOS 11+)
if (PlatformVersion.supportsSFSymbols) {
  // Use CNIcon for native rendering
}

// Get specific version
print('iOS version: ${PlatformVersion.iosVersion}');
print('macOS version: ${PlatformVersion.macOSVersion}');
```

## Requirements

- **Flutter**: >= 3.3.0
- **Dart SDK**: >= 3.9.0
- **iOS**: >= 15.0 (Liquid Glass requires iOS 26+)
- **macOS**: >= 11.0 (Liquid Glass requires macOS 26+)

## Migration from cupertino_native_plus

1. Update your `pubspec.yaml`:
   ```yaml
   # Before
   cupertino_native_plus: ^x.x.x

   # After
   cupertino_native_better: ^1.9.0
   ```

2. Update imports:
   ```dart
   // Before
   import 'package:cupertino_native_plus/cupertino_native_plus.dart';

   // After
   import 'package:cupertino_native_better/cupertino_native_better.dart';
   ```

3. No other code changes needed - API is fully compatible!

## Contributors

<p align="center">
  <a href="https://github.com/gunumdogdu" title="Emir Gunumdogdu"><img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/contributors/gunumdogdu.png" width="104" height="104" alt="Emir Gunumdogdu"></a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://github.com/yagizdo" title="Yılmaz Yağız Dokumacı"><img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/contributors/yagizdo.png" width="104" height="104" alt="Yılmaz Yağız Dokumacı"></a>
</p>

<p align="center">
  <strong><a href="https://github.com/gunumdogdu">Emir Gunumdogdu</a></strong> created and maintains the package.<br>
  <strong><a href="https://github.com/yagizdo">Yılmaz Yağız Dokumacı</a></strong> has merged 10 pull requests, among them the native <code>CNActionSheet</code> and <code>CNAlert</code>,
  Swift Package Manager builds, system brightness, the tab bar's native label fonts, and a long run of tab bar and icon fixes.
</p>

<p align="center">
  <a href="https://github.com/anirudhrao-github" title="anirudhrao-github"><img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/contributors/anirudhrao-github.png" width="56" height="56" alt="anirudhrao-github"></a>
  <a href="https://github.com/azharul-islam" title="Azharul Islam"><img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/contributors/azharul-islam.png" width="56" height="56" alt="Azharul Islam"></a>
  <a href="https://github.com/Azzeccagarbugli" title="Francesco Coppola"><img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/contributors/Azzeccagarbugli.png" width="56" height="56" alt="Francesco Coppola"></a>
  <a href="https://github.com/Honahec" title="Hao Chen"><img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/contributors/Honahec.png" width="56" height="56" alt="Hao Chen"></a>
  <a href="https://github.com/MohamedAboElM3aTy" title="Mohamed Abo El Maaty Zaky"><img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/contributors/MohamedAboElM3aTy.png" width="56" height="56" alt="Mohamed Abo El Maaty Zaky"></a>
  <a href="https://github.com/TjarkGomollaDev" title="Tjark"><img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/contributors/TjarkGomollaDev.png" width="56" height="56" alt="Tjark"></a>
  <a href="https://github.com/fbernack" title="Franz Bernack"><img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/contributors/fbernack.png" width="56" height="56" alt="Franz Bernack"></a>
  <a href="https://github.com/johan-perso" title="Johan"><img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/contributors/johan-perso.png" width="56" height="56" alt="Johan"></a>
  <a href="https://github.com/johndavid92" title="VishalKevadiya"><img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/contributors/johndavid92.png" width="56" height="56" alt="VishalKevadiya"></a>
  <a href="https://github.com/jonathanfristedt" title="Jonathan Fristedt"><img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/contributors/jonathanfristedt.png" width="56" height="56" alt="Jonathan Fristedt"></a>
  <a href="https://github.com/josec-ecw" title="José Cano"><img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/contributors/josec-ecw.png" width="56" height="56" alt="José Cano"></a>
  <a href="https://github.com/tgrushka" title="Tom Grushka"><img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/readme/contributors/tgrushka.png" width="56" height="56" alt="Tom Grushka"></a>
</p>

<p align="center">Thank you to everyone who has made this package better.</p>

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Credits

This package is based on:
- [cupertino_native_plus](https://pub.dev/packages/cupertino_native_plus) by NarekManukyan
- [cupertino_native](https://pub.dev/packages/cupertino_native) by Serverpod

## License

MIT License - see [LICENSE](LICENSE) for details.
