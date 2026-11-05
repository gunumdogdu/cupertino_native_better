## 2.3.0

> The Mac window goes native, and five new controls. On macOS, `CNTabBarNative` becomes the window's sidebar, `CNNativeSheet` its inspector and the new `CNToolbar` its toolbar, around your unchanged Flutter content. New on both platforms: `CNPopover`, `CNPopUpButton`, `CNGauge`, `CNToolbar` and `CNSidebar`. Fixes #120 and four older bugs. Checked on macOS 27.2 and on the iOS 27 and 26.2 simulators, touches included; code that only runs on macOS 12–26 was reviewed, not run. Compiles with every Xcode from 26.0 on.

### Added

- **`CNPopover`**: a native popover that points at a widget or a rect. `NSPopover` on macOS; a UIKit popover on iPhone and iPad (it stays a popover on iPhone instead of becoming a sheet); Liquid Glass on 26. Its content is native and described by data: a title and message, `CNListItem` rows with a checkmark for choice lists, switches that report changes while it stays open, and default, cancel and destructive buttons. `show` returns the chosen id, or null when it is dismissed; `update` and `dismiss` change or close it. It follows its anchor, closes on navigation and on hot restart, and VoiceOver treats it as modal. Escape and Return work on macOS. Flutter widgets cannot go inside it.
- **`CNPopUpButton`**: the native pop-up button, a value picker that shows the current choice. `NSPopUpButton` on macOS; on iOS 26 a button whose menu selects one item. SF Symbol and image-asset items, dividers, titled sections, disabled items, the `CNButton` styles (glass on macOS 26 and iOS 26), a controlled `value` and the native width.
- **`CNGauge`**: the native gauge, a level indicator on macOS. Capacity, discrete capacity, relevancy and rating on `NSLevelIndicator`; linear and circular SwiftUI `Gauge` styles on both platforms. Warning and critical zones, tick marks (macOS), labels, and an editable star rating that VoiceOver can adjust. A gauge that only shows a value lets taps through to the row under it.
- **`CNToolbar`**: the Apple toolbar. On macOS it puts an `NSToolbar` on the window while the widget is mounted (unified, unified compact or expanded, with the window title and subtitle): buttons with badges and the prominent style on macOS 26, segmented groups, menus, a search field (`NSSearchToolbarItem`), spaces, and the sidebar and inspector toggles while the window has a sidebar or inspector. The widget takes no room; the window keeps its frame and gets its own toolbar back when the widget goes away. On iOS 26 it is a Liquid Glass bottom toolbar with grouped items (toolbar badges need iOS 27). Items update in place.
- **`CNSidebar`**: a native sidebar list in your own layout: SwiftUI `List(.sidebar)` on macOS, on Liquid Glass on 26, with sections, symbols, images, badges and selection. On iOS it draws a `CNTabRail` sidebar.

### macOS — the window

- **`CNTabBarNative`** turns the window into a native split view: the tabs become sidebar rows with symbols, badges and selection, beside your Flutter content, which is moved, not recreated. The search tab is the sidebar's search field, and a tab with a `CNNativeList` shows that list instead of the Flutter content. Same API and callbacks as on iOS; View › Show Sidebar (⌃⌘S) is added. `disable()` gives the window back as it was. `bottomAccessory` and `minimizeBehavior` have no Mac counterpart and are ignored.
- **`CNNativeSheet.show`** opens the window's inspector with the same pages, a segmented page switcher and a close button when `dismissible`; it returns `true` on macOS now. Detents have no Mac meaning. The sidebar and the inspector work together.
- **`CNTabRail` and `CNTabScaffold`** draw a native sidebar on macOS instead of a Flutter one.
- **`CNSearchScaffold`** puts its tabs and its search field in the window toolbar.
- Typing, scrolling, right-clicks and full screen keep working in Flutter content inside the split view, and the window comes back as it was after a hot restart.

### Fixed

- **#120: `CNSegmentedControl` follows a press-and-drag across segments.** Its platform view declared no gesture recognizers, so inside a scrolling list Flutter's gesture arena kept every drag and the control only got taps. Taps and horizontal drags now go to the native control, on iOS and macOS; a vertical drag that starts on it still scrolls the list. Thanks to @LucasLau00 for the report and the fix.
- **`CNTabBarNative`: popping its page in code left the bar on screen.** The bar was presented full screen, which takes the Flutter view out of the window; Flutter then drew no frames, so the page's exit animation never finished and its `dispose` (with its `disable()`) never ran. The bar is now presented over the Flutter view and looks the same. The home indicator now follows your app's setting, as on your Flutter screens (Flutter hides it after a few seconds unless the app sets `SystemUiMode.edgeToEdge`). The bar is marked modal for VoiceOver, so the page under it stays out of reach.
- **iOS `CNSearchScaffold` showed an empty tab bar** on iOS 26 and 27. Its fallback tab bar also shows each item's symbol instead of a placeholder circle. Selecting the search tab in code (`currentIndex`) now opens the search field with the keyboard, as a tap does: UIKit never did this on iOS 26 and not reliably on iOS 27. `CNTabBarSearchController.activateSearch()` brings up the keyboard too.
- **macOS: a popover or toolbar no longer stays on the window after a hot restart.**

### Changed

- `CNTabBarNative.enable(isDark: null)` follows the system appearance on macOS; on iOS it stays light, as before.
- `CNTransitionObserver` is exported from the package library. It was public and documented, but only reachable through its own file.

### Checked

Each new control was checked on macOS 27.2 in light and dark, and on the iOS 27 and iOS 26.2 simulators, with real touches on iOS: popover rows, switches, buttons and outside taps; pop-up selection, press-and-drag and scrolling; the editable rating; toolbar segments, menus and badges; the segmented control's press-and-drag. The Swift code was compiled against the iOS 26.0, 26.1, 26.2, 26.4, 26.5, 27.0 and 27.1 SDKs and the macOS 26.5 and 27.2 SDKs, each with its Xcode's Swift version.

## 2.2.1

> Patch: the iOS part of the package compiles with every Xcode from 26.0 on again (#119). No API changes, no visual changes.

### Fixed — #119 `CNNativeSheet.swift` still failed to build with Xcode 26

2.1.2 moved one cause of the #119 error, but archiving with Xcode 26 then stopped at the sheet's toolbar buttons: "No exact matches in call to static method 'buildExpression'". The buttons were a `ForEach` of toolbar items, and only the iOS 27 SDK (Xcode 27) has a `ForEach` that takes toolbar items. The buttons are now one toolbar item group with the `ForEach` inside it, which every SDK accepts. They share one glass capsule as before: with no, one and two buttons the sheet is pixel-identical to 2.2.0 on the iOS 27 simulator, and with two buttons on iOS 26.2.

### Fixed — `CNTabBarNative` failed to build with Xcode 26.1

The bottom accessory used `tabViewBottomAccessory(isEnabled:)` whenever the compiler was Swift 6.2.1 or newer, but that API first ships in the iOS 26.2 SDK, so Xcode 26.1 stopped with an error. Xcode 26.2 and 26.3, whose compiler reports Swift 6.2, skipped it and showed the empty accessory pill that #93 fixed. The check now asks for the SwiftUI version of the iOS 26.2 SDK instead. Apps built with Xcode 27 are unaffected.

### Checked

The package's iOS Swift code was compiled against the iOS 26.0, 26.1, 26.2, 26.3, 26.4, 26.5, 27.0 and 27.1 SDKs, each with its Xcode's Swift version, and the macOS code against the macOS 26.5 and 27.2 SDKs. All compile. Xcode 16 was never supported (the package uses iOS 26 APIs throughout), and the App Store needs Xcode 26 anyway; the README now says so.

## 2.2.0

> macOS goes native. Every control that has an AppKit counterpart now uses it on every supported macOS (12 and later), not only on macOS 26: buttons, pop-up buttons, sliders, switches, steppers, date pickers, colour wells, segmented controls and the tab bar. Alerts are window sheets, action sheets are menus, search bars are search fields, and image assets and SVGs draw on macOS. New: `CNContextMenu` (right-click on macOS, long press on iOS) and `CNProgressIndicator`. Fixes the macOS hang in #47. Checked on macOS 27.2 and on the iOS 27 and 26.2 simulators; code that only runs on macOS 12–26 was reviewed and forced on macOS 27, not run on those versions.

### Fixed — #47 the example hung on macOS with a debugger attached

Some widgets sent the macOS view a method it did not implement (`setSemanticLabel`, `setInteraction`, `setLabelStyle`, the tab bar's search calls) without awaiting the call. The resulting `MissingPluginException` was uncaught, and a debugger that breaks on uncaught exceptions (the IDE default) paused the UI isolate. On macOS the UI isolate runs on the main thread (merged platform and UI threads), so the whole window stopped with a spinning cursor and no error. With `FLTEnableMergedPlatformUIThread` off the window kept answering but the Flutter content froze, which is why the workaround looked broken. Calls a platform may not implement now treat a missing implementation as "not supported here", the macOS views implement the missing methods, and macOS answers the `beginTransition` / `endTransition` calls `CNTransitionObserver` sends on every route change. A test now checks that every call a widget sends has an answer on macOS.

### macOS — native controls on every macOS

- **`CNButton` and `CNPopupMenuButton`** are AppKit buttons on every macOS. An icon-only button is a circle and a button with a title a capsule; before, every button was drawn as a 44 pt circle with its title spilling out. On macOS 26 the glass styles use the glass bezel, prominent styles `bezelColor` with `tintProminence`, and every style `borderShape` and a `controlSize` that follows the height; `clearGlass` is a borderless button in clear `NSGlassEffectView`. Before macOS 26 they use the push and circular bezels. `labelColor`, font size, family and weight apply. AppKit glass takes its look from the window's appearance, not from what is behind it: over a photo, set `labelColor` and icon colours.
- **`CNSlider`** is an `NSSlider`: tick marks for `numberOfTicks`, `tickValues` and `step`, `neutralValue` on macOS 26, and its colour from the first frame.
- **`CNStepper`, `CNDatePicker`, `CNColorWell`, `CNSegmentedControl`** use their AppKit controls on every macOS, and **`CNSwitch`** a SwiftUI toggle that draws the AppKit switch. `CNSegmentedControl.color` tints the selection and symbol colours apply; `CNDatePicker` compact is the date field with a calendar overlay and wheels the field with a stepper; `CNColorWell` follows `size`.
- **`CNTabBar`** shows each tab's symbol and label, keeps the selected tab readable (it was blue on blue), is no longer clipped at the window's bottom, uses the macOS 27 tabs role (in apps built with the macOS 27 SDK), draws badges, follows item, badge, font and selection changes, and turns a search item into a search tab.
- **`LiquidGlassContainer`** uses `NSGlassEffectView` on macOS 26, with its outline visible (it was clipped), and an `NSVisualEffectView` before 26.
- **Image assets, image bytes, SVGs and custom icons** draw on macOS in `CNIcon`, `CNButton`, `CNPopupMenuButton` (button and items), `CNTabBar` (`imageAsset`, `activeImageAsset`) and `CNGlassButtonGroup`. SVGs are read by `NSImage` (checked on macOS 27.2).
- **Native menus on macOS** (`CNPopupMenuButton`, `CNContextMenu`, `CNActionSheet`) are built the same way: disabled items are greyed out and can no longer be chosen, also inside submenus; destructive items are red; checked items show a checkmark; inline and palette sections end at a separator. Item icons stay visible on macOS 27, which hides them by default, and a single-colour icon with no colour follows the menu's text colour in light and dark. `keepsMenuPresented` has no AppKit equivalent and is ignored on macOS.
- **VoiceOver:** `semanticLabel` reaches VoiceOver on macOS for `CNButton`, `CNPopupMenuButton`, `CNSlider`, `CNSwitch`, `CNSegmentedControl`, `CNStepper`, `CNDatePicker` and `CNColorWell`.

### macOS — dialogs, menus and search

- **`CNAlert`** is a native `NSAlert` shown as a sheet on the window: the default action takes Return, cancel takes Escape, destructive actions are marked, and text fields (secure ones too) sit in the alert. Same API as on iOS.
- **`CNActionSheet`** is an `NSMenu` dropping down from `anchorRect`, or an `NSAlert` sheet without an anchor. Closing it resolves to null.
- **`CNSearchBar`** is a native `NSSearchField` on every macOS (it was a blank area). Escape clears the text, then ends the search and hands the keyboard back to Flutter; an expandable bar behaves like a toolbar search item. New `recentsAutosaveName` keeps recent searches.
- **`CNGlassButtonGroup`** is native Liquid Glass on macOS 26, with badges and menus (it was a blank area). Before 26 it stays a row of native buttons.
- **`CNPopupGesture`** also opens a native menu on a secondary click.
- `CNFloatingIsland` and the experimental `CNGlassCard` spotlight no longer create native views macOS does not have; they draw in Flutter there.

### Added

- **`CNContextMenu`**, a native context menu for any widget. On macOS a right, two-finger or Control-click opens an `NSMenu` at the pointer, also over a background window. On iOS 17.4 and later a long press opens the system menu at the pressed point. Elsewhere it uses the action sheet fallback. It takes the same entries as `CNPopupMenuButton` and reports the chosen path.
- **`CNProgressIndicator`**, a native progress bar or spinner, determinate or indeterminate, with tint and size: SwiftUI's `ProgressView`, which draws `NSProgressIndicator`, on macOS; `UIProgressView` / `UIActivityIndicatorView` on iOS 26 and later; Cupertino and Material fallbacks elsewhere. New enums `CNProgressStyle` and `CNControlSize`.
- **`PlatformVersion.shouldUseNativeControls`**: true on every macOS and on iOS 26 and later, for widgets whose native view is a standard control.
- **`CNSegmentedControl.semanticLabel`**, on iOS too.

### Fixed

- `CNTabBar` did not send a change of an item's `imageAsset`, `activeImageAsset`, image bytes or `customIcon` to the native bar once it was created, and after `setItems` an asset could be swapped for its blurry 1x file. Both are fixed, on iOS and macOS.
- iOS: a raster `imageAsset` in `CNTabBar` was drawn at its pixel size, far larger than the tab; it now fits the item.
- iOS: a PNG or JPG `imageAsset` on a `CNPopupMenuButton` (and wherever a raster asset is loaded with a size) was read at one pixel per point and not fitted, so a @3x icon was drawn three times too large and clipped: the popup's check-circle showed as a blurry zoomed checkmark, and a tinted one showed no icon. Raster assets now use their variant's density and fit the requested size.
- iOS: in debug builds the first SVG an app showed could be missing. SVGKit's device check threw on the first parse, which a warm-up parse raced; the warm-up now runs before any real SVG.
- iOS (#66): uncoloured single-colour image assets on `CNButton` and `CNPopupMenuButton` are now drawn as templates that take the tint or adapt to the glass, as 1.6.0 intended. The check that decides it never ran: Core Graphics rejected the bitmap context it used.
- iOS: `CNButtonConfig.labelFontWeight` was ignored.
- iOS 26/27: a stray outline above the context menu.

### Changed

- The plugin's macOS minimum is 12.0 (it was 11.0; Xcode 27.1 rejects lower deployment targets).

### Example

- Back buttons on macOS for the full-screen pages (Music, Files, iPhone Duo, Native Sheet).
- Captions on the Button page are readable in dark mode.
- New pages: Tab Bar, Search Bar, Glass Button Group, Progress Indicator, Context Menu.
- `lib/mac_page_entry.dart` opens any demo page by name on macOS, for screenshots and checks.

## 2.1.2

> Patch: `CNNativeSheet` failed to compile with some Xcode versions (#119). No API changes.

### Fixed — #119 a build error in `CNNativeSheet.swift`

Building or archiving an app with 2.1.0 or 2.1.1 could stop with "Static method 'buildExpression' requires that 'some ToolbarContent' conform to 'View'" in `CNNativeSheet.swift`, depending on the Xcode version. An availability check sat inside the sheet's toolbar builder, which not every Xcode accepts there. The check now sits outside it, with the same result: on the iOS 27 simulator the sheet is pixel-identical to 2.1.1.

## 2.1.1

> Patch: four fixes contributed by @yagizdo (#115-#118), and a follow-up to #116. Each was reproduced on 2.1.0 and verified with the fix on the iOS 27 simulator; #115, #117 and the #118 alert also on iOS 26.2. The changes below iOS 26 (#116, the #118 segmented control) were verified with the Flutter fallbacks forced on iOS 27 and with widget tests, as no iOS 18 simulator was available. No API changes.

### Fixed — #115 `CNTabBar` dropped split, font and icon size changes made together with a badge

When only the badges changed, the tab bar sent the badges and stopped, so a `split`, `labelFontSize`/`labelFontFamily` or `iconSize` change in the same `setState` never reached the native bar, until a later update that did not also change a badge. Everything changed in one rebuild now goes out together.

### Fixed — #116 the `CNSearchBar` fallback overflowed its parent

Below iOS 26 the fallback bar was as wide as the screen, so in a padded list, column or row it overflowed by the padding, and an expanded bar pushed its Cancel button off screen, where it could not be tapped. The bar now expands into the width its parent gives it, next to Cancel. It also works inside `IntrinsicHeight` and `IntrinsicWidth`. iOS 26 and later are unchanged.

### Fixed — #117 an uncoloured `CNIcon` was black on a dark theme

Without a `color`, the native icon was drawn black whatever the theme, so it almost disappeared on a dark page. That also hit every `CNButton` with an SF Symbol below iOS 26, and the `CNGlassButtonGroup` fallback. It now takes the theme's label colour (black in light, white in dark) and follows theme changes. A given colour, and the hierarchical, palette and multicolour modes, are unchanged.

### Fixed — #118 open modals and pickers follow the system appearance

- **`CNAlert` and `CNActionSheet`** in an app whose theme follows the system kept the old appearance when the system switched while they were open. Under a theme without a brightness they now follow the system; a theme with a brightness still sets theirs.
- **An open colour picker (`CNColorWell`) or compact date popover (`CNDatePicker`)** now switches with the app's brightness too, instead of keeping the one it opened with.
- **The `CNSegmentedControl` fallback** below iOS 26 drew white segments on a dark page. The segments now take the page's background colour.

### Example

- Check pages for #115-#118: `PROBE=pr115` to `pr118`.

## 2.1.0

> A native sheet over the Flutter app: `CNNativeSheet` rests at a few heights, keeps the screen behind it usable, holds a native list and tab bar, and collapses to a glass capsule with only the tab bar.

### Added

- **`CNNativeSheet`: a native sheet over the Flutter app,** drawn by UIKit and SwiftUI (`UISheetPresentationController`). It rests at `CNSheetDetent`s (`collapsed`, `medium`, `large`, a height or a fraction) and can be dragged between them; `collapsed` shrinks a sheet with a tab bar to a glass capsule holding only the tab bar, as Find My's does. Up to `undimmedDetent` the app behind it stays undimmed and keeps taking touches, so a map behind it still pans, and `dismissible: false` keeps it from being dragged closed. On iOS 26 it is Liquid Glass at its partial heights. The content is native: each `CNSheetPage` has a title, buttons beside it (`CNSheetButton`) and a list of `CNListItem`s, and with more than one page a tab bar sits inside the sheet. Checked against Find My's People sheet on iOS 27, at its middle height and collapsed: the title, buttons, rows, separators, capsule and tab bar land within a pixel of Find My's. Flutter widgets cannot be placed inside the sheet, because an iOS app has one Flutter view, and it stays behind. iOS 17 and later.
- **`CNListItem.leadingImage` and `trailingText`,** for a contact photo and a value such as a distance. `CNNativeSheet` rows show them.

### Example

- Native Sheet demo page over a drawn map, and `PROBE=sheet`.

## 2.0.0

> Major: four new native controls (`CNDatePicker`, `CNStepper`, `CNColorWell`, `CNPageControl`), SF Symbol effects in `CNIcon`, clear glass buttons, sliders without a thumb and with tick marks, tab bar items that open a menu (#113, thanks @johan-perso), palettes and inline sections in pop-up menus, and the iOS 27 prominent tab. Three APIs deprecated since 1.3.0 and 1.5.0 are removed, and `CNButtonStyle` gains two values; see "Breaking changes".

### Breaking changes

- **`PlatformVersion.initialize()` is removed.** It has been deprecated since 1.3.0: `PlatformVersion` reads the OS version the first time it is used. Delete the call.
- **`CNTabBarNative.checkIsEnabled()` is removed.** It has been deprecated since 1.5.0. Use the synchronous `CNTabBarNative.isEnabled`.
- **`CNTabBarNative.enable` no longer takes `onSearchSubmitted`, `onSearchCancelled` or `onSearchActiveChanged`.** They have been deprecated and never called since 1.5.0; the search tab reports through `onSearchChanged`. `CNTabBarSearchItem.onSearchActiveChanged` and `CNSearchScaffold.onSearchActiveChanged` are unchanged.
- **`CNButtonStyle` has two new values,** `clearGlass` and `prominentClearGlass`. An exhaustive `switch` over it needs two more cases.

The minimum Flutter and Dart versions do not change.

### Docs — four new showcase screens

The README's "What's new" section shows four new **Showcase** screens of the example app, built only from this package's widgets and recorded on the iOS 27 simulator: a New Event form (date pickers, a stepper, a colour well, pop-up menus), Notes (a "+" tab that opens a menu, and a menu with a formatting palette), a Welcome pager (symbol effects and page dots) and a photo Editor (clear glass buttons and a ticked slider). Run them with `flutter run -t lib/showcase/showcase_app.dart --dart-define=SCENE=event|notes|welcome|editor`.

### Added — `CNDatePicker`

A native date and time picker: `UIDatePicker` on iOS 26+, `NSDatePicker` on macOS 26+. It has `date`, `time`, `dateAndTime` and `yearAndMonth` modes in the `compact`, `inline` and `wheels` styles, with `minimumDate`, `maximumDate`, `minuteInterval`, `tint`, `locale` and `semanticLabel`. The native view reports its size, so the compact pill fits in a `Row` and the inline calendar takes its own height. Its popover opens from the pill and follows the app's theme. A UTC `DateTime` is shown and returned in UTC, a local one in the device's time zone. Below 26 it falls back to `CupertinoDatePicker`, with a pill that opens it in a popup for the compact style.

### Added — `CNStepper`

A native − / + stepper: the system stepper on iOS 26+, an `NSStepper` on macOS 26+, and a Flutter stepper shaped like the iOS 18 one below that. It takes `min`, `max`, `step`, `wraps`, `autorepeat`, `enabled` and a `color`, and VoiceOver reads it as one adjustable element with its `semanticLabel` and value. On iOS 26+ `UIStepper` ignores a tint and has no disabled look, so the native stepper is SwiftUI's, which draws the same control, takes the colour, and dims both buttons while disabled.

### Added — `CNColorWell`

A round colour well: `UIColorWell` on iOS 26+, which opens the system colour picker itself (grid, spectrum, sliders, eyedropper), an `NSColorWell` on macOS 26+, and below that a swatch that opens a sheet of system colours with an opacity slider. It takes `supportsAlpha`, `title`, `supportsEyedropper` (iOS 26) and `enabled`. The picker opens in the app's theme, not the phone's, and VoiceOver reads the well's `semanticLabel` and its colour. `onChanged` always receives an sRGB colour: a Display P3 pick is converted to sRGB and clipped to its gamut.

### Added — `CNPageControl`

Page dots: `UIPageControl` on iOS 26+, and drawn in Flutter with the same geometry on macOS, which has no native page control, and below iOS 26. Pass a PageView's `PageController` as `controller` and the dots follow the PageView, and a tap on them animates it. It takes `backgroundStyle` (automatic, prominent, minimal), `hidesForSinglePage`, `allowsContinuousInteraction`, `enabled` and dot colours. The colours default to the label colours, since UIKit's white dots vanish on a light background.

### Added — SF Symbol effects in `CNIcon`

- **`CNIcon.effect`** runs a `CNSymbolEffect` while it is set: `pulse`, `variableColor`, `scale`, and from iOS 18 / macOS 15 `bounce`, `wiggle`, `breathe` and `rotate`; switching between `drawOff` and `drawOn` (iOS 26 / macOS 26) draws the symbol out and back in. Set it to null to stop.
- **`CNIcon.triggeredEffect`** plays once each time **`effectTrigger`** changes (bounce by default): a bell that bounces on each new message.
- **`CNIcon.replaceTransition`** animates a change of `CNSymbol.name`: `replace`, `downUp`, `upUp`, `offUp`, or `magic` (iOS 18 / macOS 15).
- Effects take a direction, `byLayer` / `wholeSymbol` scope, speed and repeat (`once`, `periodic`, `continuous`). Each needs the OS version that introduced it (iOS 17 / 18 / 26, macOS 14 / 15 / 26); below it, and on other platforms, the icon stays still. Creation params are unchanged when no effect is used.

### Added — clear glass buttons

- **`CNButtonStyle.clearGlass`** and **`.prominentClearGlass`** use `UIButton.Configuration.clearGlass()` / `.prominentClearGlass()` on iOS 26, for buttons over photos and video. With a `glassEffectUnionId` or `glassEffectId` they use `Glass.clear`, tinted for the prominent style. `CNPopupMenuButton` and `CNGlassButtonGroup` take them too. On macOS without those IDs, and below iOS/macOS 26, they look like `glass` / `prominentGlass`.
- The label and icon of a `prominentClearGlass` button are white, as on `prominentGlass`. UIKit's own configuration keeps the dark label colour, which is unreadable on a dark tint. An icon colour overrides the white, and so does `labelColor` on a button without a glass ID.

### Added — thumbless and ticked `CNSlider`

- **`CNSlider.style: CNSliderStyle.thumbless`** draws a media-style slider without a thumb (iOS 26).
- **`numberOfTicks`** or **`tickValues`** draw tick marks, **`allowsTickValuesOnly`** (default true, as in UIKit) snaps to them, and **`neutralValue`** fills the track from a middle value, such as 0 on a -100…100 exposure slider (iOS 26 / macOS 26). Below iOS/macOS 26 the Flutter slider snaps to the same ticks but draws no marks.

### Added — #113 tab bar items that open a menu (thanks @johan-perso)

- **`CNTabBarItem.menuItems`** turns an item into a button that opens a native menu instead of selecting itself, for example a "+" that lets the user pick what to create. It takes the same entries as `CNPopupMenuButton`: items, dividers, subtitles and submenus. The menu opens from a clear button over the item's icon, placed the way the dot badges are found, since a `UITabBarItem` can't carry a menu. The item never gets selected nor calls `onTap`, and its glass still reacts under the finger. Sliding a finger along the bar onto it opens the menu too.
- **`CNTabBar.onMenuSelected(int index, List<int> path)`** gets the item and the path of the chosen entry, as `CNPopupMenuButton.onPathSelected` does.
- Without the iOS 26 native bar (iOS < 26, Android, web), the menu opens as a `CupertinoActionSheet` with a further sheet for each submenu, as `CNPopupMenuButton`'s fallback does. Both now use the same sheet.
- Menu entries show SF Symbols and image assets, not `customIcon`. On the iOS 26 bar with a `searchItem` and on the native macOS bar the item is a plain tab, and the bar is not sent its menus.
- VoiceOver reads each such item once, as the tab it is (the menu button over it is hidden from VoiceOver), and activating it opens the menu.
- `CNPopupMenuButton` and the tab bar now build their menus with the same code (`PopupMenuBuilder.swift`, and `popup_menu_fallback_sheet.dart` for the sheet); `CNPopupMenuButton` behaves as before.

### Added — `CNPopupMenuButton`: palettes, inline sections, items that keep the menu open

- **`CNPopupMenuSubmenu.style`** shows a submenu's items in the parent menu instead of a nested one: `inline` as a section under its label, `palette` as one row of icons (iOS 17+), like the formatting row of a text menu. Their items report the same paths as nested ones. On macOS both are a section with a header; the action sheet fallback lists them in place.
- **`CNPopupMenuSubmenu.elementSize`** (`small`, `medium`, `large`) sets how big its items are (iOS 16+): `small` fits several icons on a row.
- **`CNPopupMenuItem.keepsMenuPresented`** keeps the menu open after the item is chosen (iOS 16+), for actions the user repeats, such as zooming in.
- The same options work in `CNTabBarItem.menuItems`. A menu that uses none of them sends exactly the payload it did before.

### Added — `CNTab.isProminent`, the iOS 27 prominent tab

`CNTabBarNative` can mark one tab as prominent: iOS 27 draws it apart from the others, as a glass circle with its icon at the trailing end of the bar, for the tab users reach for most. A search tab then sits with the other tabs. Below iOS 27, and in apps built with an older SDK, it is a regular tab.

### Fixed

- **Dot badges in right-to-left layouts** were drawn on the mirrored item: the icons are found from left to right, and the first item is the rightmost there.
- **`CNButton` kept its last tint when `tint` was set back to null.** Only non-null tints were sent to the native button, so a button that lost its highlight stayed coloured. It now returns to the colour of a button created without a tint, on iOS and macOS.
- **`CNTab.activeSfSymbol` was never sent to the native tab bar**, so `CNTabBarNative` drew `sfSymbol` on the selected tab too. The selected tab now shows `activeSfSymbol`. The native bar already draws symbols filled, so pick a different symbol rather than the `.fill` one.

### Example

- Showcase scenes `SCENE=event|notes|welcome|editor` (see "Docs" above).
- Date Picker, Stepper, Color Well and Page Control demo pages; symbol effects, clear glass buttons over a photo, and iOS 26 sliders on the icon, button and slider pages.
- Testing screens: `PROBE=datepicker|stepper|colorwell|pagecontrol|controls|symboleffects|clearglass|slider26|tabmenus|prominent|menulayout`. Add `--dart-define=FALLBACK=true` to `stepper|colorwell|pagecontrol|controls` for the Flutter fallbacks.

## 1.9.1

> Patch: six fixes contributed by @yagizdo (#108-#111, #114) and @johan-perso (#112), with review follow-ups, and a fix for a squeezed tab bar on iOS 26. #109, #110, #111 and #112 were reproduced on 1.9.0 and verified with the fix on the iOS 26.2 and iOS 27 simulators. #108 and #114 change only what runs below iOS 26 and were verified by code review and widget tests, as no iOS 18 simulator was available. No API changes.

### Fixed — #108 `CNActionSheet` crashed on a large iPhone in landscape below iOS 26

1.8.3 (#95) set the presentation delegate when the window had a regular width, as on an iPad. A Plus or Pro Max iPhone in landscape has one too, but UIKit still presents the sheet as an alert there, and setting that controller's delegate threw `NSInternalInconsistencyException`. Below iOS 26 the delegate is now set only when the sheet is presented as a popover.

### Fixed — #110 a sheet undid tab bar changes made after the bar appeared

With `autoHideOnModal` (the default), `CNTabBar` removes its native bar while a sheet is up and creates it again when the sheet closes, from the values it was first created with. A badge, label, tint, theme, label font or split layout changed since then came back with its old value. The new bar now gets the current values.

### Fixed — #109 cut or shrunk labels after the tab bar changed width

On iOS 26 and 27 a bar first laid out narrow or invisible, inside `Opacity(0)` or built narrower off screen, kept labels sized for that width: "Favo…", missing labels, or a smaller font. The bar now lays its items out again when its width changes. A bar whose width animates does this on every frame.

### Fixed — #112 the split tab bar with five items, and `splitSpacing`, on iOS 26+

- **A single right item is a circle again with five items**, instead of a narrow pill with its icon and label shrunk. When the two groups are laid out by proportion, the right bar got 1/5 of the width with five items, and iOS 26 draws one item in a bar that narrow as a pill. The right group now gets at least 100 pt, the width it gets with four items on a 402 pt wide phone; two items or more already get enough.
- **`splitSpacing` is the gap between the two glass capsules.** iOS 26 draws each capsule at its content's size and centres it in its bar, leaving about 22 pt of empty bar on each side, so the visible gap was `splitSpacing` plus about 44 pt. The two bars now overlap by that empty part, which holds no item. With the default 12 pt the gap looks like the one in Apple's apps.

### Fixed — `CNTabBar.height` below the bar's own height on iOS 26

On iOS 26 the native bar measures about 97 pt for itself, the top 14 of them room for the selection pill. With a smaller `height`, such as 85, the glass capsule came out short and the labels sat on the icons. On iOS 26 such a bar now keeps its own height at the bottom of the box, its transparent top reaching above it; the space it takes in the layout does not change. Taller heights, and iOS 27, are unchanged.

### Fixed — #111 native widgets and modals follow the app theme

- **`CNSearchBar`, `CNFloatingIsland` and `CNGlassButtonGroup`** read the theme only when they were created. After a switch to dark they stayed light-styled on iOS 27; on iOS 26.2 the glass followed the backdrop, but the search placeholder stayed light. They now switch with the theme, as `CNButton`, `CNSlider` and the other controls already did.
- **`CNActionSheet` and `CNAlert`** opened in the system appearance instead of the app theme, so a light app on a dark phone got a dark sheet. Both now open in the app's brightness.

### Fixed — #114 tab badges below iOS 26

Below iOS 26 `CNTabBar` draws a Flutter fallback, which ignored `CNTabBarItem.badge` and `dotBadge`. Both fallback bars, with and without a `searchItem`, now draw them at the size and place `UITabBarItem` uses on iOS 18, and VoiceOver reads the count as the tab's value. Badges sit on the leading side in right-to-left layouts, keep their size with large text, and appearing or clearing no longer rebuilds the icon. `CNTabRail`'s fallback badge now uses the dark system red in dark mode.

### Example

- Testing screens for #109 / #110 (`PROBE=pr109fade|pr109narrow|pr110`, with `--dart-define=OBSERVER=true` for #110), #111 (`pr111`), #112 (`split5`), the iOS 26 height fix (`overlap`), and issues #60, #68 and #70 (`issue60|issue68|issue70`).

## 1.9.0

> Minor: subtitles and submenus in `CNPopupMenuButton` (#106, thanks @johan-perso), `CNTabBarNative.enable(showCloseButton:)`, fixes from @tgrushka (#94) and @Honahec (#107), and a new pub.dev page with native recordings of every component. Nothing changes for code that does not use the new options; `CNPopupMenuButton.onSelected` becomes nullable (see below).

### Docs — a new pub.dev page

The README opens with recordings of the example app's new **Showcase** screens (Display & Brightness, Files, Photos, Account, Music and iPhone Duo), built only from this package's native widgets and recorded on the iOS 27 simulator, followed by a close-up of each component and a Contributors section. The pubspec screenshots are the new showcase and four of the recordings, 2.5 MB instead of 6.4 MB.

### Added — subtitles and submenus in `CNPopupMenuButton`

- **`CNPopupMenuItem.subtitle`** shows a second line under the label: `UIAction.subtitle` on iOS, `NSMenuItem.subtitle` on macOS 14.4+, a smaller line in the `CupertinoActionSheet` fallback.
- **`CNPopupMenuSubmenu`** opens a nested menu of `items`, which can hold further submenus. It takes the same label, subtitle, icon and `enabled` options as an item. It is a nested `UIMenu` on iOS and an `NSMenuItem.submenu` on macOS; the fallback opens it as a second action sheet. `UIMenu` has no disabled state, so a disabled submenu is shown as a disabled action and cannot be opened.
- **`onPathSelected(List<int> path)`** is called for every selection with the path to the selected item, one index per level, dividers included: `[3]` for `items[3]`, `[2, 1]` for the second entry of the submenu at `items[2]`.
- **`onSelected` is now optional.** It keeps its index, and for an item inside a submenu it gets the index of the top-level submenu it is under, so every selection reaches whichever callback is set. A debug assertion requires at least one of the two callbacks, and another one `onPathSelected` when `items` contain a submenu, since `onSelected` alone cannot tell which of its items was chosen. Its type is now `ValueChanged<int>?`: call sites compile unchanged, but code that calls `button.onSelected(i)` on a `CNPopupMenuButton` needs a `?.` or `!`.

Verified on the simulator (iPhone 17, iOS 26.0) and on macOS 26.2: subtitles, nested submenus, a disabled submenu, and the values both callbacks receive.

The platform channel only gains keys: a level that uses no subtitle and no submenu is encoded to exactly the arrays it was before (covered by a test), and `itemSelected` still carries `index`, now with `path` beside it. Entries are now encoded by one recursive function, `encodePopupMenuEntries`, shared by creation and `setItems`, which also builds each submenu's level.

### Changed — `preserveTopToBottomOrder` uses the system's fixed order on iOS 16+

`preserveTopToBottomOrder` reversed the top-level items itself when the button sat in the lower 60 % of the screen, so that a menu opening upward still read 1, 2, 3 from the top. That reversal cannot reach a submenu: opened from a button at the bottom of the screen, its items showed in reverse. On iOS 16+ the option now sets `preferredMenuElementOrder = .fixed`, which keeps the given order whichever way the menu opens, submenus included; the top level reads the same as before. On iOS 15 the reversal is unchanged.

### Fixed — a `customIcon` after a divider showed another item's icon

The rendered custom icons were collected with one slot per entry, dividers included, but read back with a counter that only counted items. After the first divider every item read the slot before its own: the icon of the previous item, or the divider's empty one. The icons are now looked up by the icon itself (icon, size and colour), which submenus needed anyway, and which also finds them again after a rebuild whose items are new objects.

### Fixed — the `CNPopupMenuButton` fallback ignored `enabled`

The `CupertinoActionSheet` used below iOS 26 and on other platforms reported a disabled item when tapped and opened a disabled submenu. Both are now dimmed and ignore taps.

### Added — `CNTabBarNative.enable(showCloseButton:)`

`showCloseButton: false` hides the close button in each tab's navigation bar, for a root-mode app whose tab bar is the whole app; it then closes only through `disable()`. Defaults to `true`, as before.

### Fixed — #94 `CNTabBarNative` showed an empty accessory pill on iOS 26.1+ (#93)

Since iOS 26.1, `tabViewBottomAccessory` draws its pill even around an empty view, so `bottomAccessory: null` and `setBottomAccessory(null)` left an empty glass pill above the tab bar. The accessory is now disabled when there is none, through the iOS 26.1 `tabViewBottomAccessory(isEnabled:)`; switching it on and off keeps the selected tab. Apps built with Xcode 26.0, whose SDK lacks that call, keep the previous one. Verified on iOS 26.0, 26.2 and 27.0 simulators.

### Fixed — #107 `CNTabBar` resent its items on the first rebuild when `iconSize` was set

The native bar's `iconSize` was not remembered at creation, so the first rebuild after it (a theme change, any parent `setState`) saw a changed size and replaced every tab item of a bar that was already up to date. Bars without `iconSize` were not affected.

### Example

- New Testing screen: *PopupMenu subtitles & submenus*, with nested and disabled submenus, a custom icon after a divider, and a log of both callbacks.
- Testing screens for #94 (*TabBarNative null accessory*, `PROBE=pr94`) and for popup menu icons after a rebuild (`PROBE=pr106`), and widget tests for #107 and the popup menu fixes.

## 1.8.3

> Patch: six fixes contributed by @yagizdo (#95-#100). Each was reproduced on 1.8.2 and verified with the fix on the iOS 27 simulator (#100 also on iOS 26.0 and 26.2), and all six together on an iPhone with iOS 27.2; #95 by code review, as no iOS 18 simulator was available. No API changes.

### Fixed — #98 the tab bar selection jumped through every tab when the bar appeared (#101)

Right after a native `CNTabBar` was created, the label-refresh workaround (#6) selected each tab in turn, yielding to the run loop between them, so the Liquid Glass pill visited every tab — twice — before resting on `currentIndex` (#35, #101). The cycle now runs in one block without animation, so only the final state is drawn, in single and split mode; labels still render. It also no longer turns UIKit animations off app-wide during each cycle. Because a cycle can no longer be interrupted, two cycles can no longer overlap and restore the wrong tab after a sheet closes (#86).

### Fixed — #97 a flat Flutter tab bar flashed before the Liquid Glass bar

On iOS 26 and later every new `CNTabBar` showed the pre-iOS 26 `CupertinoTabBar` fallback for a frame or two (longer in debug builds) while the native bar was prepared. The slot now stays empty, at the bar's height, until the native bar lands. Added on top: if native preparation fails and every retry is used up, the bar shows the fallback after all, so a failure never leaves an app without a tab bar.

### Fixed — #100 `labelFontFamily` and `labelFontSize` on the native bar

The native bar now draws the label font itself: the appearance carries it before the items exist, and a change at runtime sets the items again so their views pick it up. `labelFontSize` without `labelFontFamily` now sizes the system font (SF Medium, SF Semibold in the selection pill), setting both back to null restores the native label, and a taller label moves the icon up by half its extra height and itself down by half, so the two stay clear of each other. This replaces 1.8.2's label override, which is reduced to letting a custom-font title shrink to fit a narrow tab — the lone tab in split mode.

### Fixed — #96 taps on a native `CNIcon` inside a button were lost

`CNIcon` draws SF Symbols in a `UiKitView`, whose recognizer won the gesture arena over an enclosing `CupertinoButton` or `GestureDetector`: the button dimmed but `onPressed` never ran, and only taps on the padding counted. The icon now stays out of the arena while keeping its hit area. This affects the iOS < 26 fallbacks of `CNButton.icon`, `CNPopupMenuButton` and the `CNTabBar` fallback, and any app that puts a `CNIcon` in its own button.

### Fixed — #99 `CNIcon` showed a filled circle before its native view (debug builds)

While `PlatformViewGuard` waits after a cold start or hot restart (debug and profile builds only), `CNIcon` drew a filled circle for SF Symbols and image assets. The slot now stays empty at the icon's size until the native view lands.

### Fixed — #95 `CNActionSheet` crashed on iPhone below iOS 26

Below iOS 26 a compact-width action sheet is presented by a controller that throws when its delegate is set. The delegate is now set only on iOS 26 and later or for popover presentations, and cleared only when it was set.

### Example

- Testing screens for #96 / #99 (`CNIcon` taps and placeholder), #97 / #98 (tab bar mount) and #100 (label font at runtime), and an integration test that taps a `CNIcon` inside a button through the gesture arena. `pr_probe_entry.dart` gains `PROBE=pr86|pr96|pr97|pr100` and `PROBE=tour`, which plays them one after another for a device recording.

## 1.8.2

> Patch: three `CNTabBar` fixes (#82, #103, #104) and one addition (#105, `CNTabBarItem.dotBadge`). Nothing changes for bars that do not use a custom label font, image assets in the fallback, items that change at launch, or dot badges.

### Fixed — #82 `labelFontFamily` had no effect on iOS 26 and 27

Two causes. `CupertinoTabBarPlatformView` built the bar's first `UITabBarAppearance` before reading `labelFontFamily` / `labelFontSize`, so a font passed at creation never reached it (found by @johndavid92 in PR #82). And since iOS 26.2 the Liquid Glass `UITabBar` ignores the `.font` in `titleTextAttributes` altogether, whether set on the appearance or per item (Apple Developer Forums thread 809225, FB21291879). The simulators for iOS 26.0 and 27 ignore it too.

The font is now read before the bars are built, and the bar puts its appearance's font on the tabs' title labels after every layout itself: both copies the Liquid Glass bar keeps of each title, re-measured, and allowed to shrink a little rather than truncate when a custom font is wider than a tab (the lone tab in split mode). Bars without a custom font are not touched.

Verified before and after on the simulator, iOS 27.0 and 26.0, in single and split mode: first appearance, selection changes, `setFont` from a size change, `setFont` sent straight to the native channel, remount, and a sheet round-trip.

### Fixed — #103 the bar could stay on its Flutter fallback when its items changed at launch

`_prepareCreationParams` awaits several times and read `widget.items` again after each await. When an app changed its items in between (a tab added once its data loads), it indexed a list built for the old items past its end; the error was swallowed and nothing prepared the bar again, so it stayed on the Flutter fallback for the session. A smaller window let the native bar appear with the old items. Preparation now uses one snapshot of the items, prepares again when the items change before the native bar exists, and logs and retries a failed preparation twice. Reported from the Kinetrio app.

Verified on the simulator (iOS 27.0, 26.0) by adding a fifth tab after the first frame and 16, 40 and 100 ms later: before, the fallback stuck or the bar kept four tabs; after, five tabs on the native bar every time.

### Fixed — #104 image assets drew black in the fallback

The Flutter fallback passed an `imageAsset` to `CNIcon` without a colour, so template images ignored the bar's active and inactive colours and drew black. They now take those colours, as the native bar tints them; an asset with a `color` of its own keeps it.

### Added — #105 `CNTabBarItem.dotBadge`

`badge: CNTabBarItem.dotBadge` shows a small red dot instead of a count. `UITabBarItem` has no dot badge, and on iOS 26 and 27 a badge keeps one size whatever its text, so `CNTabBar` draws the dot at the top-right of the item's icon itself, in single and split mode, and `CNTabRail` draws it too. The dot views are kept across layouts, so the bar does not lay itself out again on every frame (checked: no layouts while idle). Requested from the Kinetrio app.

### Example

- New Testing screens: *#103 / #104: TabBar items change early* and *#105: TabBar dot badge*; the PR #82 screen gains *Next tab*. `pr_probe_entry.dart` opens them with `PROBE=pr82|issue103|issue105`, and `AUTO=true` steps all three screens through their cases for device screenshots.

## 1.8.1

> Patch: `CNTabRail` (and so `CNTabScaffold`'s rail and sidebar) now draws image assets, and the first SVG image an app loads no longer occasionally fails to draw. No API changes.

### Fixed — `CNTabRail` ignored `imageAsset` / `activeImageAsset`

`CNTabRail` takes the same `CNTabBarItem`s as `CNTabBar`, but drew only SF Symbols and custom icons, so a tab set built from `CNImageAsset`s showed placeholder circles in the rail and the sidebar — including when `CNTabScaffold` moved tabs to the side on iPhone Duo. It now draws image assets (SVG or raster, from an asset path or `imageData`, with resolution variants) in both styles, natively and in the Flutter fallback, with the same priority as `CNTabBar`: `imageAsset` > `customIcon` > `icon`, and `activeImageAsset` for the selected tab when given. As in the system tab bar, icons are tinted and drawn at a fixed size.

### Fixed — the first SVG image could fail to draw

`SVGImageLoader` starts a warm-up parse on a background queue the first time it is used, and SVGKit's parser is not thread-safe. An SVG parsed on the main thread at the same moment could come back empty and fall back to a placeholder. Seen once on the first `imageAsset` of a `CNTabRail`; the same loader serves `CNTabBar`, `CNButton`, `CNIcon` and `CNPopupMenuButton`. SVG parsing is now serialised.

## 1.8.0

> Minor: iPhone Duo support (#102) through four new public APIs — `CNTabScaffold`, `CNTabRail`, `CNFoldable` / `CNFoldableScope` — a new `sidebarOnWideScreens` option on `CNTabBarNative.enable`, and VoiceOver names for native controls (#88) through a new `semanticLabel` on `CNButton`, `CNPopupMenuButton`, `CNSwitch` and `CNSlider`. Nothing changes for apps that do not use them.

### Added — #102 iPhone Duo: tabs that move to the side, and a foldable API

iPhone Duo (iOS 27.1) has an outer display and a larger inner display, and can stand partially open in a book or tabletop pose. On the outer display, and on the inner display in landscape, iOS moves the status bar and the tab bar to a vertical bar on one edge — but only for system containers. See the README's *iPhone Duo (foldable)* section.

- **`CNTabBarNative`** is a system container, so it gets the vertical bar with no code change once the app is built with Xcode 27.1. New `sidebarOnWideScreens: true` turns the tabs into a native sidebar on the open inner display (`.sidebarAdaptable`, with the sidebar as the default placement): beside the content in landscape, behind a sidebar button in portrait.
- **`CNTabScaffold`** brings the same behaviour to `CNTabBar`, which as a standalone bar never turns vertical. It shows a `CNTabBar` at the bottom, swaps it for a `CNTabRail` in the vertical-bar column whenever iOS uses one (moving it clear of the camera region), and with `sidebarOnWideScreens` shows a sidebar on screens at least 600 pt wide. The body stays mounted across every change, so folding never resets the page.
- **`CNTabRail`** is a vertical tab bar taking the same `CNTabBarItem`s: icons in a Liquid Glass capsule (`rail`), or icon-and-label rows in a glass panel (`sidebar`). Badges, custom icons, VoiceOver labels and the selected trait are supported; Cupertino-drawn fallback below iOS 26.
- **`CNFoldable`** reports the hinge (`UIHingeInteraction`: closed / partially open / fully open, and the angle), the physical side of the vertical bar, and the reserved regions — the fold and the camera — in Flutter's logical coordinates. **`CNFoldableScope`** exposes it to `CNFoldable.of(context)` and adds the active fold and the camera to `MediaQuery.displayFeatures`, which Flutter does not populate on iOS itself, so Flutter's dialogs and popups keep clear of the fold.

The iOS 27.1 APIs are compiled only with the iOS 27.1 SDK (`canImport(UIKit, _version: 9127.0.85)`). Built with an older Xcode the package still compiles, `CNFoldable` reports `CNFoldableState.unsupported`, and `CNTabScaffold` keeps a bottom bar.

Requested by @mark8055 (#102). Verified on the iPhone Duo simulator (Xcode 27.1, iOS 27.1, Flutter 3.44.0) in every pose: closed (vertical rail, 0°), open in landscape (vertical rail, 180°) and portrait (bottom bar or sidebar), book pose (a layout split left and right at the fold) and tabletop pose (split above and below it), and a cold start while unfolded.

### Added — #88 VoiceOver names for native controls, and an Accessibility section

- **`semanticLabel`** on `CNButton` (and `CNButton.icon`), `CNPopupMenuButton` (and `.icon`), `CNSwitch` and `CNSlider`: what VoiceOver reads for the native control. Without it, an icon-only button is read by its SF Symbol's built-in name — the example app's theme toggle was announced as "do not disturb", the name of the `moon` symbol — and a switch or slider has no name at all, because a native control cannot merge with the Flutter text beside it. The label is applied natively (the button's, slider's and SwiftUI toggle's accessibility label) and on the Flutter fallbacks.
- **`CNTabRail`** supports the Large Content Viewer, like the system tab bars: its icons keep a fixed size, and with a large text size a long press shows the item enlarged.
- **README *Accessibility* section:** what VoiceOver gets from each native widget, Dynamic Type, the Large Content Viewer, and a Flutter engine limitation that affects VoiceOver touch exploration over scrolling lists (flutter/flutter#194389).

Requested by @tgrushka (#88). Checked through the iOS accessibility tree on the iPhone Duo simulator (iOS 27.1): the names, roles and values of buttons, menus, the slider, switches, the segmented control and the rail, before and after `semanticLabel`.

### Changed — package

- `misc/` (the README's images and videos) and `tool/` (development scripts) are no longer published; the README already loads its media from GitHub. The archive is about 8 MB smaller.
- The pub.dev screenshots open with the iPhone Duo animation.

### Example app

- New *iPhone Duo* page (Navigation): a live hinge gauge, a player that splits at the fold, an even-numbered grid that reflows, and an overlay of the reserved regions.
- The home list now keeps clear of the iPhone Duo outer display's vertical status bar.
- The debug banner is off, so the light/dark toggle in the top-right corner can be tapped on macOS (#88).
- The icon-only buttons in the navigation bar have VoiceOver names.
- The macOS deployment target is 12.0: Xcode 27.1 rejects anything lower.

## 1.7.0

> Minor rather than patch: three new public APIs (`CNActionSheet`, `CNAlert`, `CNTabBar.precacheIcons`), and native widgets under a `CupertinoApp` whose theme leaves `brightness` unset now follow the system brightness instead of coming up light.

### Fixed — #80 Swift Package Manager builds fail on CocoaLumberjack 3.10.0

SVGKit 3.0.0 lets CocoaLumberjack resolve to 3.10.0 (released 2026-09-21), which requires iOS 15, while SVGKit's own target still declares iOS 9 (built as 12.0). Xcode's target-integrity check then rejects every Swift Package Manager build of an app that depends on this package: `The package product 'CocoaLumberjack' requires minimum platform version 15.0 for the iOS platform, but this target supports 12.0`. CocoaPods builds were not affected.

**Fix:** the iOS manifest caps CocoaLumberjack to `3.7.0..<3.10.0` and lists its product on the plugin target, which is what makes Swift Package Manager apply the cap. It can go once SVGKit ships a release with its own cap. An app that already resolved 3.10.0 may need Xcode's *File → Packages → Reset Package Caches* (or a deleted `Package.resolved`) to pick the cap up.

Reported by @dogankarakus, fixed by @yagizdo (PR #83). Verified with a fresh Swift Package Manager app on Flutter 3.44.0: 1.6.0 resolves CocoaLumberjack 3.10.0 and fails to build; this release resolves 3.9.1 and builds.

### Added — #78 `CNActionSheet`, a native action sheet

`CNActionSheet.show` presents a real `UIAlertController` in `.actionSheet` style on every supported iOS version, so the sheet is the system control: destructive red, disabled actions, VoiceOver, Dynamic Type, and the Liquid Glass look on iOS 26. Pass `anchorRect` to anchor it to the control that opened it; from iOS 26 that is how action sheets present on iPhone as well as iPad. Other platforms fall back to `CupertinoActionSheet`. See the README's *Action Sheet* section.

Because it is a UIKit presentation rather than a Flutter route, inline CN widgets on the page stay mounted while it is open. Under a Flutter `CupertinoActionSheet` route, `ModalHideMixin` tears them down and recreates them on dismiss.

Hardened before release:

- **iPad:** an unanchored sheet whose presenter reports compact width (an iPad form sheet, for example) got no popover source, and UIKit throws on that. Whether a synthetic source is needed is now decided by the device and the window, not the presenter.
- A sheet with no `cancelLabel` and no *enabled* action is refused (asserts in debug, resolves to `null` without presenting in release). Below iOS 26 such a sheet cannot be dismissed. Previously only a sheet with no actions at all was refused.

Contributed by @yagizdo (PR #78). Verified on an iPhone (iOS 26.5.2): system look, anchored presentation, inline widgets stay mounted, an outside tap resolves to `null`, and back-to-back, superseding and chained calls all resolve. The unanchored iPad path was checked on an iPad Pro simulator.

### Added — #79 `CNAlert`, a native alert with text fields

`CNAlert.show` presents a `UIAlertController` in `.alert` style: default, cancel and destructive actions, disabled actions, and text fields (secure entry included) whose contents come back in `CNAlertResult.textFields`. Other platforms fall back to `CupertinoAlertDialog`. On iOS a second `show` replaces the alert on screen and resolves the first call to `null`. Configurations UIKit cannot render (no enabled action, two cancel or two default actions) assert in debug. See the README's *Alert* section.

Contributed by @yagizdo (PR #79). Verified on an iPhone (iOS 26.5.2): system look, typed text returned, inline widgets stay mounted, back-to-back and chained calls resolve.

### Added — #73 `CNTabBar.precacheIcons`

A bar whose items use `customIcon` renders those icons to images before its native view can be created, so its first mount showed the Flutter fallback bar for a few frames: a visible flash when the bar appears right after the native splash. `CNTabBar.precacheIcons(items, iconSize: …)` renders them into the existing icon cache ahead of time. Pass the same items and `iconSize` as the bar.

Reported and contributed by @TjarkGomollaDev (PR #90). On an iPhone (iOS 26.5.2, release build), a first mount showed the fallback for 5 frames (113–281 ms); after `precacheIcons` it showed 1 frame (49–50 ms), the same as a mount with cached icons. That last frame stays in every case because the bar builds its creation parameters asynchronously.

### Fixed — #76 `CNPopupGesture` menu invisible until a hot reload, wrong item index

- The menu sat under `Opacity(animation.value)`, which `showGeneralDialog`'s page builder reads once (0.0) and never rebuilds, so the menu stayed invisible until a hot reload. The route's transition already fades it in, so the wrapper is gone.
- Every item reported the same out-of-range index (one shared counter). Each item now reports its own index, dividers excluded.
- SF Symbol icons were drawn as a placeholder circle. They now render through `CNIcon`.

Reported by @dogankarakus. Fixed in PR #89 and verified on an iPhone (iOS 26.5.2).

### Changed — #84 widgets follow the system brightness when the theme sets none

`ThemeHelper` read `Theme.of(context).brightness`, which under a `CupertinoApp` comes from the Cupertino theme with a **light** fallback. An app whose `CupertinoThemeData` leaves `brightness` null, i.e. follows the system, therefore created its native widgets light on a dark device. It now uses `CupertinoTheme.brightnessOf(context)`, which falls back to the platform brightness. `CNSearchBar`, `CNFloatingIsland`, `CNGlassCard` and `CNToast` now take their brightness from `ThemeHelper` too.

Apps that set `brightness` explicitly see no change. An app that left it null and relied on the light result now gets dark widgets on a dark device.

Contributed by @yagizdo (PR #84). Verified on an iPhone (iOS 26.5.2) with the theme set to none, dark and light.

### Known limitations

- iOS 26.2 and later ignore custom tab bar title fonts, so `CNTabBar.labelFontFamily` and `labelFontSize` have no visible effect there (Apple Feedback FB21291879). Verified on iOS 26.5.2, both through `UITabBarAppearance` and per item.

## 1.6.0

> Minor rather than patch because `CNGlassEffect` gains a value (`clear`). That is source-breaking for anyone with an exhaustive `switch` over the enum. 1.5.5 was tagged during development and never published; everything it contained is here.

### Added — #69 `CNGlassEffect.clear`, and `LiquidGlassConfig.effect` is now honoured

`LiquidGlassConfig.effect` was serialised over the channel as `'effect': config.effect.name`, parsed natively, stored, handed to the SwiftUI view and even used as an `.animation(_:value:)` key — and then `glassEffectForConfig()` ignored it and hardcoded `Glass.regular` on both iOS and macOS. `CNGlassEffect.regular` and `CNGlassEffect.prominent` therefore rendered identically, and SwiftUI's third variant, `Glass.clear`, was unreachable.

`clear` matters for glass over imagery: `regular` frosts what is behind it, `clear` lets it through — the treatment Apple's own media controls use over video and artwork.

**Fix:** `CNGlassEffect.clear` is added and both containers honour the value they were already being given.

**`prominent` is unchanged and still falls back to `regular`** — SwiftUI's `Glass` has no prominent counterpart to map onto. The enum value is kept so existing code compiles and so the mapping can be filled in later; it is now documented as a fallback rather than left to be discovered by screenshot. Note also that `clear` barely blurs, so content layered on top of it needs its own contrast handling (a shadow or scrim) in a way `regular` does not.

Reported and fixed by @johndavid92 (PR #69). Verified on an iPhone 16 Pro / iOS 26 simulator with panels of identical size and position over vertical stripes that never vary along y — so every panel sees a pixel-identical backdrop and any difference is the glass alone. RMSE between panel interiors:

| comparison | RMSE |
|---|---|
| before — `regular` vs `prominent` | 0.0010 |
| *noise floor (same panel shifted 1px)* | *0.0027* |
| after — `regular` vs `prominent` | 0.0010 (unchanged) |
| after — `regular` vs `clear` | 0.337 |

Before the fix the two effects differed by less than a one-pixel shift of the same image: peak difference 1/255, zero differing pixels at 2% fuzz. macOS could not be built in the verification environment (pre-existing Swift Package Manager scaffolding issue, unrelated to the change), so the macOS `glassEffectForConfig` body was type-checked against the MacOSX26.0 SDK directly instead.

`CNGlassButtonGroup` still hardcodes `Glass.regular` in `GlassButtonSwiftUI.swift` on both platforms — a separate surface that does not take `CNGlassEffect`, left for a follow-up.

### Fixed — #66 Uncoloured `imageAsset` icons don't adapt to Liquid Glass

An `imageAsset` supplied without an explicit `color` was handed to UIKit as a non-template `UIImage`, so it kept its baked pixels. On an iOS 26 glass button the material resolves its light/dark appearance from the **backdrop**, so a black-baked glyph over a dark backdrop went invisible — and a white-baked one did the same over a light backdrop. `customIcon` and SF Symbols already receive `.alwaysTemplate` and were unaffected, which is what made the inconsistency easy to miss until an app mixed the two.

**Fix:** uncoloured image assets are rendered as templates in `CupertinoButtonPlatformView` and `CupertinoPopupMenuButtonPlatformView`, so the control's tint — and Liquid Glass's automatic foreground adaptation — applies. Explicit `imageAsset.color` values keep their existing baked-tint behaviour.

Templating is gated on the artwork actually being single-colour. `.alwaysTemplate` keeps only the alpha channel: lossless for a black glyph or a grey stroked SVG, but it flattens anything multi-colour to a silhouette. `ImageUtils.isEffectivelyMonochrome(_:)` samples the image on a capped 32×32 grid, compares only near-opaque pixels (so antialiased edges don't read as a second colour) and returns on the first distinct colour — so **multi-colour assets are left exactly as they were**.

Also in this change:

- `GlassButtonSwiftUI.effectiveIconColor` was `tint ?? iconColor`, so a control-level tint overrode an explicit per-icon colour. Now `iconColor ?? tint`.
- The `setButtonIcon` template pass is scoped to image assets. Applied to every icon source it would also template SF Symbols, so a `multicolor`/`palette` symbol without an explicit colour rendered correctly on creation and then flattened after any icon update.

**Behaviour change:** the plain `glass` style no longer sends a forced theme-accent tint from Dart, so the native side can resolve its own foreground. On iOS 26 this is mostly invisible for **icons** — `UIButton.Configuration.glass()` already overrode the image foreground, so a glass SF Symbol rendered as the adaptive system colour rather than the accent even before this release. It *is* visible on glass button **labels**, which now use the system label colour instead of `CupertinoThemeData.primaryColor`. Set `CNButton.tint` explicitly to keep an accent-coloured glass label. `prominentGlass` keeps its accent fallback, and the pre-iOS-26 fallback still reads `primaryColor` from the Cupertino theme.

Reported and fixed by @azharul-islam (PR #66). Reproduced and verified on an iPhone 16 Pro / iOS 26 simulator: over a black backdrop in light mode, a black-baked `imageAsset` was invisible on the glass before the fix and adapts to white after, while a deliberately four-colour asset keeps all four colours.

### Fixed — #67 `customIcon` glyphs pixelated on thin strokes

`iconDataToImageBytes` painted the glyph at 1× `fontSize`, then the "scale to fill" re-blit **upscaled** the cropped ink — icon fonts pad their glyphs inside the em box, so the ink is smaller than the requested `size`. At 1× there is no sub-pixel detail to upscale from, so thin strokes (chevrons, checkmarks, plus signs, outline glyphs) came out with visible staircase edges. Every `customIcon` path in the package routes through this function: `CNButton`, `CNPopupMenuButton`, `CNTabBar`, `CNIcon`, `CNGlassButtonGroup`.

**Fix:** the glyph is rasterised onto a canvas scaled to 2× the device pixel ratio, and the re-blit downscales with `FilterQuality.high` instead of the `Paint()` default of `FilterQuality.none`. Output dimensions are unchanged.

Measured on an iPhone 16 Pro / iOS 26 simulator against a ground-truth render — mean absolute alpha error, chevron at 20 pt, 3× screen:

| | intermediate buffer | MAE |
|---|---|---|
| before | 27k px | 7.00 |
| `FilterQuality` change alone | 27k px | 6.82 |
| **2× canvas + `FilterQuality.high`** | **108k px** | **2.98** |
| 4× linear (font *and* canvas) | 434k px | 1.78 |

The `FilterQuality` change on its own is close to a no-op — the re-blit is only a ~1.1× upscale, so the filter barely matters and it measured *worse* on 5 of 12 glyph/size combinations. The intermediate resolution was the actual problem. The last row is what PR #67 originally proposed; it measures better but is not distinguishable at real icon sizes, and it costs 16× the pixels in a buffer that is walked pixel-by-pixel to find the ink bounds.

Reported and fixed by @azharul-islam (PR #67), refined to 2× on merge.

### Performance — `iconDataToImageBytes` is now memoised

There was no cache on icon rasterisation, and `CNButton` and `CNIcon` build `FutureBuilder(future: iconDataToImageBytes(...))` inside `build()` — so every rebuild re-ran three canvas passes plus a pixel-by-pixel scan of the intermediate buffer.

Results are memoised per (glyph, font, size, colour, device pixel ratio). Futures rather than results are cached, so concurrent callers share one rasterisation; and because `FutureBuilder` only re-subscribes when its future's identity changes, those widgets now keep their snapshot across rebuilds instead of dropping back to a blank placeholder. The map is capped at 256 entries with oldest-first eviction, since `size` is caller-supplied and can be animated. `clearIconImageCache()` is exported for tests and for apps that swap icon fonts at runtime.

### Example app

- New: `Testing → PR #66: glass imageAsset tint` — puts the same artwork through SF Symbol, `customIcon`, uncoloured `imageAsset` and explicitly coloured `imageAsset` on a glass button, over a selectable backdrop (black / white / photo / split) and either brightness. Includes a deliberately four-colour row as the regression check for template flattening, plus popup-menu and button-group rows.
- New: `Testing → PR #67: icon supersampling` — renders the same glyph through the renderer with the supersample factor and `FilterQuality` exposed as separate knobs, blown up nearest-neighbour so real pixels are visible, with mean-alpha-error and intermediate-buffer cost per variant.
- New: `Testing → PR #69: LiquidGlass config.effect` — one panel per `CNGlassEffect.values` over vertical stripes that never vary along y, so every panel sees a pixel-identical backdrop and two panels that render differently can only differ because of the glass. Backdrop switches to a photo for the over-imagery case.
- New: `example/lib/pr_probe_entry.dart` — an alternate entrypoint that boots straight into one test page in one configuration via `--dart-define`, for capturing before/after screenshots without tapping through the demo list.

---

## 1.5.4

### Fixed — #64 `LiquidGlassContainer` glass renders short in the bottom safe area

When a `LiquidGlassContainer`'s frame reached into the bottom safe area — the common "floating bottom panel" layout on home-indicator devices — the native glass stopped short of the frame it was given. Flutter-drawn children stayed in the right place, so they visually spilled outside the glass.

**Cause:** `LiquidGlassContainerPlatformView` hosts the SwiftUI glass in a `UIHostingController`, which propagates the screen's safe area into its SwiftUI content. Where the platform view's frame overlapped the home-indicator inset, the hosted `GeometryReader`/shape was inset by that overlap, so the glass filled only the reduced size.

**Fix:** `self.hostingController.safeAreaRegions = []`, matching the intent of the existing `safeAreaInsets` override in `CupertinoSwitchPlatformView.swift`. `safeAreaRegions` is iOS 16.4+ and the class is already `@available(iOS 26.0, *)`, so no extra availability guard is needed.

Reported and fixed by @fbernack (PR #64), who measured up to **22 pt** short on an iPhone 17 Pro (iOS 26.4 simulator). Independently reproduced and verified on a physical iPhone running **iOS 26.5**: with a 140 pt panel pinned flush to the bottom of a 34 pt inset, the glass fell **~21 pt** short of its frame before the fix and filled it completely after.

macOS is unaffected — `LiquidGlassContainerNSView` uses `NSHostingController`, and macOS windows have no bottom safe-area inset in practice.

### Example app

- New: `Testing → PR #64: LiquidGlass safe-area clip` — a glass panel whose bottom offset, height, and shape (`rect` / `capsule` / `circle`) are adjustable live. A solid red strip fills exactly the safe-area inset (the zone the bug leaves uncovered), a Flutter-drawn magenta outline marks the panel's true frame, and a cyan dashed line marks the safe-area boundary — so "glass short of frame" is directly visible rather than a judgement call. Sliding the bottom offset past the boundary shows whether the glass stays attached to its frame.

---

## 1.5.3

### Fixed — #62 `CNTabBar` taps swallowed by ancestor gesture recognizers

`CNTabBar` stopped responding to taps whenever any ancestor widget held an active gesture recognizer over the same region. The reporter's minimal repro:

```dart
GestureDetector(
  onLongPress: () {},        // any active recognizer is enough
  child: CNTabBar(items: [...], currentIndex: i, onTap: ...),
)
```

Tapping a tab did nothing. In the wild this surfaced via `requests_inspector`, which wraps the whole app in a long-press `GestureDetector` — installing it silently killed the tab bar.

**Cause:** `_buildNativeTabBarPlatformView` constructed the iOS `UiKitView` / macOS `AppKitView` without a `gestureRecognizers` set. With none supplied, the platform view is a passive arena participant and only receives touches if nothing else claims them, so the ancestor won uncontested.

**Fix:** both platform-view branches now pass `Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer())`. `EagerGestureRecognizer.addAllowedPointer` immediately calls `resolve(GestureDisposition.accepted)`, so the platform view claims the pointer on pointer-down and touches forward to the native `UITabBar` regardless of what is competing.

Note the trade-off: gestures made **directly over the tab bar** (long-press, drag) now go to the native bar instead of bubbling to ancestor recognizers. This is the intended behaviour for a tab bar, which is only ever tapped.

Reported and originally patched by @MohamedAboElM3aTy (#62, PR #63). The submitted patch used a bare `TapGestureRecognizer()`, which is a no-op — Flutter's `TapGestureRecognizer.isPointerAllowed` returns `false` when none of `onTapDown`/`onTap`/`onTapUp`/`onTapCancel`/`onTapMove` are set, so the recognizer never enters the arena. Amended to `EagerGestureRecognizer` before merge and verified on-device (iPhone, iOS 26.5).

### Known — same gap remains in other components (#65)

The identical issue affects other platform-view widgets and is tracked in #65. It is **not** a uniform fix, so it was deliberately kept out of this release:

- `button.dart`, `switch.dart`, `slider.dart`, `popup_menu_button.dart` pass a bare `TapGestureRecognizer()` and therefore carry the same latent no-op.
- `segmented_control.dart`, `glass_button_group.dart`, `icon.dart`, `liquid_glass_container.dart`, `floating_island.dart`, `search_bar.dart`, `search_scaffold.dart` pass no `gestureRecognizers` at all.
- Several of those **must not** get a claiming recognizer — `icon.dart` is decorative (it would steal taps from parent widgets), `liquid_glass_container.dart` / `floating_island.dart` / `search_bar.dart` deliberately wrap the platform view in `IgnorePointer` and handle interaction Flutter-side, and `search_scaffold.dart`'s view is `Positioned.fill` behind all Flutter content.
- The button-like components need an *armed* tap recognizer (`TapGestureRecognizer()..onTap = () {}`) rather than an eager one, so drags still fall through to a parent scrollable — `button.dart:654` documents that intent explicitly.

### Example app

- New: `Testing → #62 / PR #63: CNTabBar tap gesture arena` — three switchable scenarios verifying the fix on-device: an ancestor `GestureDetector(onLongPress:)` (the reporter's minimal repro), an ancestor `PageView` (drag-vs-tap competition), and a no-ancestor baseline for regression coverage. Each scenario avoids nesting a `Scrollable` in the gesture region so ancestor gestures resolve deterministically.

---

## 1.5.2

### Fixed — #61 `CNBottomSheet.showCupertino` compile error on Flutter < 3.44

`CNBottomSheet.showCupertino` in v1.5.1 called Flutter's `showCupertinoSheet()` with a `scrollableBuilder:` named parameter. That parameter was only added to `showCupertinoSheet` in Flutter **3.44.0** (via [flutter/flutter#177337](https://github.com/flutter/flutter/pull/177337), 2026-01-23). Anyone consuming the package on stable **3.35 – 3.41.x** — including a substantial share of production Flutter users, FlutterFlow environments, and CI setups — hit a hard compile error:

```
No named parameter with the name 'scrollableBuilder'.
```

Fix: switched to `builder:` (the current API on 3.35 – 3.41; deprecated-but-still-accepted on 3.44+). The lambda didn't use its `ScrollController` anyway, so the swap is behaviour-preserving. Compatible from Flutter 3.35 through today's master.

Thanks @ArkayGit for the clean, precisely-scoped bug report.

### Fixed — #46 `CNToast` queue deadlock after route pop

`CNToast` stored the caller's `BuildContext` on each queued `_ToastEntry` and re-resolved `Overlay.of(entry.context)` inside `_showNext()` — which fires from a `Timer` after each toast's duration. If the caller's widget was disposed while toasts were pending (typical: user shows a toast then taps back), the framework crashed with:

```
Looking up a deactivated widget's ancestor is unsafe.
```

Worse, after the throw, `_isShowing` was left `true` and the queue was **permanently stuck** — every subsequent `CNToast.show/success/error/warning/info` call would silently `_queue.add()` without displaying, until app restart. Only `CNToast.loading()` still worked (it bypasses the queue and inserts into the overlay directly).

Fix (in `lib/components/toast.dart`):

- `_ToastEntry` now stores an `OverlayState` (resolved eagerly at `CNToast.show()` time), not a `BuildContext`. `_showNext()` no longer touches the caller's context and cannot throw on a deactivated widget.
- Added `entry.overlay.mounted` short-circuit and a `try/catch` around `overlay.insert(...)` — if the OverlayState disappears between enqueue and display (extremely rare), the entry is dropped and the queue keeps draining. `_isShowing` is guaranteed to reset.

### Fixed — #46 `CNToast` renders with yellow double-underline under `MaterialApp` (reporter's screenshot)

The same issue also carried a second, unrelated defect surfaced by @macedondev's screenshot: text rendered as **dim red monospace with a yellow double-underline**. That's `MaterialApp._errorTextStyle` (`flutter/lib/src/material/app.dart:45`), Flutter's built-in "your Text has no Material ancestor" debug fallback. `MaterialApp` installs it as the ambient `DefaultTextStyle` at the app root; `_ToastOverlay` renders its `Text` inside an `OverlayEntry` with no `Material` between them, so the fallback style wins. `CupertinoApp` doesn't install `_errorTextStyle`, which is why the maintainer couldn't reproduce the bug locally.

Fix: wrap the toast content in `Material(type: MaterialType.transparency, ...)` inside `_ToastOverlay.build()`, positioned **between `IgnorePointer` and `Align`** so `Positioned` still sees the `Overlay`'s `Stack` as its direct parent (a `Material` between them would break `Positioned`'s parent-data contract and throw `Incorrect use of ParentDataWidget`). Transparent Material paints nothing, so `CupertinoApp` users see no visual change; MaterialApp users get proper text-style resolution and the yellow underlines are gone. Applies to both the queued (`_showNext()`) and direct-insert (`loading()`) toast paths.

Thanks @macedondev for the report.

### Example app

- New: `Testing → #46: CNToast use_build_context_synchronously` — two labeled scenarios. **Bug A** (queue crash on dispose): spam-and-pop button that queues 5 toasts then pops the route ~250ms in, reproducing the "Looking up a deactivated widget's ancestor" crash pre-fix and demonstrating the queue-drains-cleanly behaviour post-fix. **Bug B** (yellow underlines): a route whose body is a nested `MaterialApp` so `CNToast` fires into an overlay with the ambient `_errorTextStyle` — reproduces the reporter's exact rendering. Plus a quick-trigger row for all six `CNToast.*` variants for regression coverage.

---

## 1.5.1

### Fixed — #53 PlatformView z-order bleed under bottom sheets

iOS hybrid composition was reusing the same `PlatformViewContainer` for both a host-page CN-widget and a CN-widget inside a presented sheet, causing the host-page widget's pixels to leak through the sheet's scrim (and vice-versa).

**Fix:** new `ModalHideMixin` (in `lib/utils/modal_hide_mixin.dart`) applied to **all 9** CN widgets that use a PlatformView — `CNButton`, `CNGlassButtonGroup`, `CNSwitch`, `CNSegmentedControl`, `CNPopupMenuButton`, `CNSearchBar`, `CNLiquidGlassContainer`, `CNFloatingIsland`, `CNSlider`. Each widget now destroys its PlatformView (with a same-size placeholder reserving the layout slot) while a sheet covers it, and recreates it when the sheet dismisses.

Each affected widget gained an `autoHideOnModal: bool = true` constructor parameter so users can opt out per-instance.

### New — `CNBottomSheet` + `CNSheetGeometryProbe`

For the modal-hide to be **position-aware** (only widgets actually behind the sheet hide, not the entire host route), the sheet has to publish its rect each frame. Two new public APIs cover this:

- **`CNBottomSheet`** (in `lib/components/bottom_sheet.dart`) — drop-in wrappers that inject the probe automatically:

  ```dart
  CNBottomSheet.show(context: context, builder: (ctx) => MySheet());
  CNBottomSheet.showCupertino(context: context, builder: (ctx) => MySheet());
  CNBottomSheet.showModalPopup(context: context, builder: (ctx) => MySheet());
  ```

- **`CNSheetGeometryProbe`** — wrap your own sheet builder manually if you need to keep using the framework APIs directly:

  ```dart
  showModalBottomSheet(
    context: context,
    builder: (ctx) => CNSheetGeometryProbe(child: MySheet()),
  );
  ```

Without one of these the package falls back to a conservative "hide every CN-widget on this route while any modal is up" behavior — safe, but coarser than needed (an app-bar CN-button could disappear behind a 30%-height sheet).

`CNTabBarRouteObserver` also gained `topModalRect: ValueNotifier<Rect?>` and `publishTopModalRect(Rect?)`, used by the probe.

### Fixed — #55 `CNPopupMenuItem.isDestructive`

`CNPopupMenuItem` gained `isDestructive: bool = false`. When true:

- iOS 14+ adds `UIMenuElement.Attributes.destructive` → the **label** renders in the system destructive red (previously only the icon could be red via `iconColor`).
- iOS 13 legacy fallback uses `UIAlertAction.Style.destructive`.
- iOS < 26 / non-iOS Cupertino fallback uses `CupertinoActionSheetAction(isDestructiveAction: true)`.

Thanks @ashellz for the report.

### Fixed — CNGlassButtonGroup remount blink

`CNGlassButtonGroup`'s `FutureBuilder` returned `SizedBox.shrink()` for one frame between the modal-hide placeholder removal and the platform view actually mounting — text below jumped up then back down on every sheet dismiss. The pending branch now mirrors the placeholder's axis-aware dimensions so the layout slot is held across the swap.

### Fixed — PR #57 macOS `CNSwitch` rendered as a checkbox

The macOS `Toggle` defaulted to a checkbox under recent SDKs. Applied `.toggleStyle(.switch)` to force the switch appearance. iOS unaffected. Thanks @jonathanfristedt.

### Fixed — `MissingPluginException` storm during transitions

`ch.invokeMethod('setTransitioning', …)` calls now use `.catchError((_) {})` to swallow async rejections, and fallback platform-view classes (iOS < 26) register no-op `MethodChannel` handlers so Dart-side calls from `ModalHideMixin` and route-transition containment don't throw.

### Docs

- `pubspec.yaml` `documentation:` now points to https://gunumdogdu.com/docs.
- README documents `CNBottomSheet` / `CNSheetGeometryProbe` usage and the navigatorObserver requirement for modal-hide to work.

### Example app

- New: `Testing → #53: CNButton under bottom sheet` — four sheet-opener variants over a host page full of CN widgets.
- New: `Testing → #55: PopupMenu isDestructive` — text, icon, and mixed menus with destructive items.
- New: `Testing → Glass widgets modal halo test` — all 9 CN widgets behind sheets.
- New: `Testing → CNButton modal halo test` — modal route push/pop animations.
- New: `Testing → #37: CNAppBar button halo test`.

### Known limitations

- `CNGlassButtonGroup` glass merging at default spacing still shows a "dumbbell" between buttons. The single-uniform-pill rewrite hit a SwiftUI hit-testing limitation (`.glassEffect()` intercepts touches at a layer below `.allowsHitTesting(false)`); a UIKit `UIVisualEffectView` rewrite is queued for the next release.

## 1.5.0

### New — CNTabBarNative gains minimize, native lists, accessory & root mode

Building on the existing `CNTabBarNative` (the native iOS 26 Liquid Glass tab bar), this release adds:

- **Minimize-on-scroll** (resolves #32) — `minimizeBehavior:` with `CNTabMinimizeBehavior.{automatic, never, onScrollDown, onScrollUp}`, changeable at runtime via `setMinimizeBehavior(...)`. Requires a tab backed by a `CNNativeList`, since iOS drives the minimize from a real native scroll view.
- **Native list tabs** — `CNTab(nativeList: CNNativeList(items: [CNListItem(...)]))` renders a native scrollable list; `onListItemTap(tabIndex, itemIndex)` reports taps. New `CNNativeList` / `CNListItem` models (now exported from the package).
- **Bottom accessory pill** — `bottomAccessory: CNTabAccessory(...)` floats above the bar and slides inline when it minimizes; `onAccessoryTap` reports taps; show/update/hide at runtime with `setBottomAccessory(...)` (pass `null` to hide).
- **Presentation modes** — `asRoot:` selects modal presentation (default) or root presentation; in root mode a tab with no `nativeList` hosts your real Flutter UI.
- **Search filtering option** — `nativeSearchFilter` (default `true`) filters the search tab's own list locally; set `false` to drive results yourself via `onSearchChanged` + `setItems`.
- **Mutation API** — `setItems(...)` for dynamic/paginated data, plus `onDismissed` (fires when the bar is closed natively, e.g. via the ✕ button).

The native manager was rewritten (`CNNativeTabBar.swift` replaces `CNNativeTabBarManager.swift`) on a stable SwiftUI `TabView` view tree.

### Docs

- Rewrote the README **"Native iOS 26 Tab Bar (CNTabBarNative)"** section: native-takeover mental model, a `CNTabBar` vs `CNTabBarNative` comparison table, presentation modes, and a per-method API reference. Added a preview GIF (minimize + accessory + search).
- Documented that `CNTabBarNative` is a **native takeover, not a Flutter bottom-nav** — for Flutter screens per tab, use `CNTabBar` (clarifies #7).

### Deprecated

- `CNTabBarNative.enable` parameters `onSearchSubmitted`, `onSearchCancelled`, `onSearchActiveChanged` — the search tab now reports through `onSearchChanged`; these are no longer fired and will be removed in a future major release.
- `CNTabBarNative.checkIsEnabled()` — use the synchronous `isEnabled` getter instead.

### Notes

- **#48 (color the unselected tab item):** investigated and intentionally **not** added to `CNTabBar`. iOS 26's Liquid Glass tab bar enforces the system color for unselected items and ignores customization — verified on-device with both the legacy `UITabBar.unselectedItemTintColor` and the modern `UITabBarAppearance` per-state `iconColor` / title `foregroundColor`. The selected `tint` is honored; the unselected state is system-owned, so a public knob would silently no-op on the package's target OS.

## 1.4.6

### Bug Fixes

- **Fixed #39 / merged PR #42** — `CNTabBar.iconSize` is now honored for `customIcon` items (any `IconData` like `CupertinoIcons.house` or `Icons.home`). Previously the custom-icon rasterizer was hardcoded to 25pt regardless of the bar-level `iconSize` or per-item `icon.size`. Bug originally surfaced via #39 (SVG `imageAsset` layout glitch on v1.4.3) and addressed by @Azzeccagarbugli's PR #42, with an extra refinement on top:
  - `lib/components/tab_bar.dart`: `_prepareCreationParams` now passes `widget.iconSize ?? item.icon?.size ?? 25.0` to `iconDataToImageBytes`; same precedence on `activeCustomIcon`; `_buildTabIcon` (Flutter fallback) mirrors the precedence across all icon kinds.
  - `lib/utils/icon_renderer.dart`: full rewrite of `iconDataToImageBytes`. Drops the heavy `RenderRepaintBoundary` + `BuildOwner` setup in favor of a `TextPainter` + canvas + alpha-channel crop approach. **Final step (refinement on top of the PR)**: re-blit the cropped glyph into a square `size × size` canvas with the glyph **scaled to fill**, so custom icons at a given pointSize match SF Symbol's visible ink at the same pointSize (matches SF Symbol's "pointSize is ink size" convention — previously, font em-box padding made customIcon visually smaller than equivalent SF Symbols at the same size).
  - `test/widget_test.dart`: 6 new widget tests verifying the `iconSize > icon.size > 25pt` precedence across SF Symbol / customIcon / imageAsset in the Flutter fallback path.

### New

- **Swift Package Manager support** — fixes #44. The plugin now ships a `Package.swift` manifest for both iOS and macOS targets and is recognized by `pana` as "Swift PM-ready".

  Flutter's SPM rollout is well underway: SPM support landed in Flutter **3.24** (Aug 2024) as opt-in, became the **default for new apps in Flutter 3.44**, and CocoaPods is being phased out — Firebase stops publishing to CocoaPods in **October 2026** and the CocoaPods registry becomes **read-only on December 2, 2026**. Plugins without SPM support already lose pana points and trigger build warnings on modern Flutter versions.

  **Compatibility (no users locked out)**: the plugin's own pubspec constraints stay at `sdk: ^3.9.0` / `flutter: '>=3.3.0'`. The SPM `Package.swift` sits alongside the existing podspec and is only consulted by Flutter 3.24+. Older Flutter consumers continue to resolve the package via CocoaPods exactly as before — the podspec's `source_files` path was updated to point at the new SPM-shaped source directory (`ios/cupertino_native_better/Sources/cupertino_native_better/**`, mirrored on macOS) so both build paths produce the same result.

  | Consumer Flutter | Build path |
  |---|---|
  | 3.3 – 3.23 (pre-SPM) | CocoaPods via podspec. Package.swift ignored. Unchanged from v1.4.5. |
  | 3.24 – 3.43 (SPM opt-in) | CocoaPods by default; SPM if `flutter config --enable-swift-package-manager` is set. Both paths work. |
  | 3.44+ (SPM default) | SPM via `Package.swift`. |

  Thanks to @josec-ecw for the PR.

### Example app

- **Added**: `Testing → PR #42: CNTabBar iconSize (customIcon)` — three side-by-side `CNTabBar`s (SF Symbol / customIcon / SVG imageAsset) with an `iconSize` slider so all three icon kinds can be verified to scale identically. Four Stratis UI Figma SVGs bundled (`camera-01`, `card-add`, `chromecast`, `home-03`) — same source as #39 reporter — for SVG verification.

### Pana

- 160/160 (now includes "**Swift PM-ready**" recognition)

---

## 1.4.5

### Bug Fixes

- **Fixed #35 / #41 (recreate animation on launch + navigation)** — `CNTabBar` no longer plays a visible "morph through every tab" animation on app launch or after navigating away and back.
  - **Launch glitch (#35)**: Swift `refresh` cycles `bar.selectedItem` through every tab to force UITabBar's label layout (workaround for an old "5 items, sporadic missing labels" bug — Issue #6). On iOS 26 with Liquid Glass, that cycling was visible as the selection pill morphing through every tab. The cycle is now wrapped in `UIView.setAnimationsEnabled(false) … true` — labels still render correctly, but the pill no longer animates between items. Tab bar appears instantly with the configured `currentIndex`.
  - **Recreate-on-return (#41 part 1)**: `autoHideOnPageTransition` previously swapped the platform view to a `SizedBox` during route slides, destroying the native `UITabBar`. On return, a fresh view was created and `_onCreated` re-ran `setSelectedIndex` + `refresh` → visible animate-to-index. Fix: when `autoHideOnPageTransition` is on, `CNTabBar.build` now always returns an `IndexedStack` (children: `[SizedBox, UiKitView]`); only the painted index toggles between 0 and 1 across the transition. The `UiKitView`'s element stays mounted in both states, so the native `UITabBar` is preserved across navigation. Bar just appears with the correct index, no animation.

- **Fixed #41 (PlatformViewGuard 500 ms fallback flash on first build)** — non-iOS26 fallback widgets briefly visible during cold start.
  - Cause: `PlatformViewGuard.ensureScheduled` always delayed platform-view creation by 500 ms to give Flutter's `FlutterPlatformViewsController` time to purge stale registrations from a previous Dart isolate after a hot restart. That race only exists in debug; release builds (cold-start, no isolate recycling) were paying the same flash-of-fallback cost for nothing.
  - Fix: `PlatformViewGuard` is now ready immediately in `kReleaseMode`. Native iOS 26 widgets render from the first frame in production; debug-mode hot-restart safety is preserved unchanged.

- **Fixed #36 follow-up** — `LiquidGlassContainer`'s rectangular layer drop shadow leaking past its rounded glass corners while a modal/sheet was presented above (was already targeted in v1.4.4 but only clipped the rectangular layer bounds; rounded clip wasn't applied across all shape configurations correctly). The corner-radius clip in `applyTransitionContainment` now consistently matches `rect` (configured cornerRadius), `capsule` (`min(width, height)/2`), and `circle` (`min(width, height)/2`) — no more square shadow nubs.

### New

- **Fixed #40 (CNButton label customization)** — `CNButtonConfig` now accepts:
  - `labelFontFamily` — custom font family (must be registered in `Info.plist` or as a Flutter font asset).
  - `labelFontSize` — point size override.
  - `labelColor` — explicit foreground color (overrides the `tint`-derived default for non-filled styles, and the system default for filled / borderedProminent / prominentGlass).
  - `labelFontWeight` — Flutter `FontWeight` override.

  Implementation: Swift side applies them via `UIButton.Configuration.titleTextAttributesTransformer`, so the overrides take effect on the native label without losing the iOS 26 Liquid Glass / prominent / tinted button background. Both creation-time (creationParams) and runtime (`setLabelStyle` channel call from `_syncPropsToNativeIfNeeded`) updates are supported. Flutter `FontWeight.value` (0-8) is mapped to `UIFont.Weight`.

  Example:
  ```dart
  CNButton(
    label: '1',
    tint: CupertinoColors.systemOrange,
    onPressed: () {},
    config: const CNButtonConfig(
      style: CNButtonStyle.prominentGlass,
      width: 80, minHeight: 80,
      labelFontSize: 36,
      labelFontWeight: FontWeight.w600,
      labelColor: CupertinoColors.white,
    ),
  )
  ```

### Behavioural details

- `CNTabBar.autoHideOnPageTransition` keeps its default `true`. With the IndexedStack-based hide it's now zero-cost: state is preserved across navigation while still preventing the original page-wide PlatformViewLayer occlusion artifact during route slides.
- Multi-label `CNButton` (e.g. dial-pad style: large number + small letters underneath) is intentionally **not** added to `CNButton`'s API. The same effect composes cleanly via `LiquidGlassContainer` wrapping a `Column` of two Flutter `Text`s — full `TextStyle` freedom on both labels with the native iOS 26 Liquid Glass background. See the closing comment on Issue #40 for a snippet.

### Example app

- **Added**: `Testing → #40: CNButton label style` — interactive screen for verifying the new label-style params (font-size slider, color swatches, font-family segmented control, style picker).

### Pana

- 160/160

---

## 1.4.4

### Bug Fixes

- **Fixed #36** — `LiquidGlassContainer`'s rectangular layer drop shadow leaking past its rounded glass corners while a modal/sheet was presented above. Visible as four square shadow nubs at the card's corners through the modal's scrim, even though the visible glass was rounded.
  - Root cause: `applyTransitionContainment(true)` (added in v1.4.3 for the dynamic halo containment) only set `clipsToBounds = true` on the container's CALayer, which clips to the **rectangular** layer bounds — leaving the four corners outside the rounded glass shape unclipped. The layer's drop shadow rendered into those corners and bled through the modal scrim.
  - Fix: in `LiquidGlassContainerView.swift`, `applyTransitionContainment(true)` now also sets `container.layer.cornerRadius` (and the hosting view's) to match the configured glass shape:
    - `rect` shape → uses the configured `cornerRadius`
    - `capsule` / `circle` → `min(width, height) / 2`
  - The clip is now rounded, matching the visible glass exactly. Reverted to 0 when containment goes inactive so it doesn't affect the at-rest visual.

### Documentation

- **README**: added a prominent "Required Setup: register `CNTabBarRouteObserver`" section directly under Quick Start, documenting:
  - Why the observer is needed (hybrid composition, halo containment, z-order with sheets).
  - Where to register it: `CupertinoApp` / `MaterialApp` / `GoRouter` snippets.
  - What it fixes across all 7 glass widgets, with explicit references to Issues #29, #31, #36.
  - Manual `markAnyModalActive` / `markAnyModalInactive` API for non-route overlays (`Scaffold.showBottomSheet`).
  - Several users reported needing this observer to fix sheet bleed-through; with this section it should now be impossible to miss during initial setup.

### Example app

- **Added**: `Testing → #36: LiquidGlassContainer behind modal` — focused reproduction page for Issue #36. Card-shaped `LiquidGlassContainer` matching the issue reporter's `_AdaptiveGlassContainer` widget exactly (`cornerRadius: 15`, `rect`, `EdgeInsets.all(13)`, no tint), four sheet variants including the reporter's exact `showModalBottomSheet` invocation (rounded top, scaffold-bg, `Clip.antiAlias`, bounce animation, `useRootNavigator: true`), and a `CalendarDatePicker` inside each sheet matching the modal content from the issue's screenshots. White scaffold + black/white pill buttons mirror the reporter's app styling.

### Pana

- 160/160

---

## 1.4.3

### Bug Fixes

- **Fixed #34** — CNButton glass capsule not stretching with its parent frame; icon overflowing a small pill when wrapped in `SizedBox` / `Expanded`. Regression introduced in v1.4.0.
  - Root cause: the v1.4.0 "feat: fixes" commit added always-on `container.clipsToBounds = true` + `uiButton.clipsToBounds = true` (plus layer shadow/background clearing) across every iOS 26 glass widget as part of the #29 halo containment. `UIButton.Configuration.glass()` renders its capsule via an internal background subview whose visual size includes a soft-edge glow extending slightly beyond the button's layer bounds — the always-on clipping was cropping that glow AND preventing the capsule from growing with a stretched frame.
  - Fix: reverted all the always-on clipping across `CNButton`, `CNPopupMenuButton`, `CNFloatingIsland`, `CNGlassButtonGroup`, `LiquidGlassContainer`, `CNSearchBar`. Containers are unclipped at rest, so the glass capsule renders its full soft-edge glow and stretches properly with `SizedBox` / `Expanded` / `Container(width: ...)`.

- **Fixed #29 (fully)** — the original halo-during-route-transition artifact is now resolved via a **dynamic** containment pattern instead of always-on clipping. This also catches the popup/sheet bleed cases that the v1.4.0 fix didn't cover (popup routes, persistent bottom sheets).
  - New native method `setTransitioning(active:)` on `CNButton`, `CNPopupMenuButton`, `CNFloatingIsland`, `CNGlassButtonGroup`, `LiquidGlassContainer`, `CNSearchBar`, and the regular `CNTabBar` variant. When active, it applies the halo-containment clipping + shadow/background clearing; when inactive, it reverts.
  - Dart side listens to two signals and calls `setTransitioning(true)` when either fires:
    1. `ModalRoute.secondaryAnimation` — catches `CupertinoPageRoute` / `MaterialPageRoute` forward/reverse transitions.
    2. A new `CNTabBarRouteObserver.anyModalDepth` counter that tracks any `PopupRoute` / Sheet / Popup / Dialog-named route (`showCupertinoSheet`, `showCupertinoModalPopup`, `showModalBottomSheet`, `DialogRoute`, etc.).
  - For the split-search variant of `CNTabBar` (whose native container is intentionally unclipped so the floating search orb can render above the bar), the auto-hide trigger is broadened to `anyModalDepth` so popups over a search-enabled tab bar no longer leak shadow through the sheet's top edge.

### New

- **`CNTabBarRouteObserver.anyModalDepth`** (read-only `ValueListenable<int>`) — broader counter than the existing `modalDepth`. Tracks every modal-like route (all `PopupRoute`s plus any route whose runtime type contains `Sheet` / `Popup` / `Dialog`). Used internally by the glass widgets for halo-containment activation.

- **`CNTabBarRouteObserver.markAnyModalActive()` / `markAnyModalInactive()`** — public manual API for non-route overlays that `NavigatorObserver` can't see, notably `Scaffold.showBottomSheet` (persistent bottom sheet anchored to `ScaffoldState`, not the Navigator):
  ```dart
  final controller = Scaffold.of(context).showBottomSheet(...);
  CNTabBarRouteObserver.markAnyModalActive();
  controller.closed.whenComplete(CNTabBarRouteObserver.markAnyModalInactive);
  ```

### Example app

- **Added**: `Testing → CNButton modal halo test` — stretched CNButton variants + 4 sheet types (`showCupertinoSheet`, `showCupertinoModalPopup`, `showModalBottomSheet`, `showBottomSheet`) for verifying halo containment across every overlay variant.
- **Added**: `Testing → Glass widgets modal halo test` — same 4-sheet matrix against `CNPopupMenuButton`, `CNGlassButtonGroup`, `LiquidGlassContainer`, `CNSearchBar`, `CNFloatingIsland`.
- **Updated**: `Stack+Positioned tab bar` and `Split-search clip repro` screens now include all 4 sheet types for regression coverage.
- **Added**: `DefaultMaterialLocalizations.delegate` to the root `CupertinoApp` so demos can mix `showModalBottomSheet` (Material) with Cupertino routes without adding `flutter_localizations`.

### Behavioural details

- At rest, glass widgets render the full iOS 26 Liquid Glass capsule (including the soft-edge glow that extends slightly beyond the view's layer bounds) and stretch to fill bounded parent frames. This matches native iOS behaviour.
- During a route transition or while a modal/sheet/popup/dialog is above the widget's route, the native container is clipped and layer shadows are suppressed — the visible change is essentially invisible (the widget's visible frame is unchanged), but Flutter snapshots of the outgoing/incoming page no longer include a halo that extends past the platform-view bounds.
- `CNTabBar` without `searchItem` still uses the narrow Sheet-only `modalDepth` heuristic for its auto-hide (avoids the recreate-and-restore flash on quick action-sheet popups). `CNTabBar` with `searchItem` uses the broader `anyModalDepth` because its container can't be clipped (the floating search orb needs to render above the bar's top edge).

### Pana

- 160/160

---

## 1.4.2

### New

- **`CNTabBarRouteObserver`** — a `NavigatorObserver` that lets `CNTabBar` auto-hide while a full-screen sheet is presented over its route. Resolves Issue #31 (Material `TextField` invisible inside `showCupertinoSheet` when `CNTabBar` is in the bottom nav slot).

  The native `UITabBar` is rendered inside a Flutter `UiKitView`. When a Flutter-rendered sheet route is presented over the same navigator, hybrid composition can leave the tab bar's UIView at a higher z-index than the modal's Flutter content — making `TextField`s inside the sheet invisible and letting the bar bleed through during sheet drags. Auto-hide swaps the platform view for an empty placeholder while the sheet is up, mirroring what iOS does natively when a `UITabBarController` presents a full-screen modal.

  **Setup** (one line per app):
  ```dart
  CupertinoApp(
    navigatorObservers: [CNTabBarRouteObserver()],
    // ...
  )
  ```
  Or `MaterialApp(navigatorObservers: [CNTabBarRouteObserver()], ...)`. Without this observer registered, `CNTabBar` still renders correctly — it just won't auto-hide on top of sheets and you may hit the Issue #31 z-order glitch.

- **`CNTabBar(autoHideOnModal: bool = true)`** — opt-out for the auto-hide behaviour. Default `true`. Set `false` to keep the tab bar visible behind sheets (rare; typically requires a native sheet that won't trigger the z-order issue).

### Bug Fixes

- **Fixed**: tab bar's selected index resetting to 0 after a modal/sheet closed and the platform view was recreated (Issue #2 page repro).
  - Root cause: in `_onCreated` we called `refresh` before `setSelectedIndex`. The native `refresh` method (a workaround for the 5-item-label-rendering bug Issue #6) captures `bar.selectedItem` at start, cycles through items asynchronously, then "restores" the captured value — overriding the `setSelectedIndex(currentIndex)` we sent right after, leaving the bar stuck at the stale `creationParams.selectedIndex = 0`.
  - Fix: swapped the order — `setSelectedIndex` now runs BEFORE `refresh`. Refresh then captures the correct index and restores to it. Applied to both the 50ms and 200ms recreation passes.

### Behavioural details

- Auto-hide is intentionally narrow: it triggers only for routes whose runtime type name contains `Sheet` (`CupertinoSheetRoute`, `ModalBottomSheetRoute`). Action-sheet popups (`CupertinoModalPopupRoute`), dialogs, and regular page pushes do NOT trigger auto-hide. This avoids a visible "platform view recreate + index restore" jump animation on quick popups, while still fixing the z-order issue for full-screen sheets.

### Example app

- **Added**: `Testing → #31: TextField — NO search variant (hypothesis test)` — same flow as the Issue #31 reproduction but with `CNTabBar` configured without `searchItem` and `autoHideOnModal: false`, used to verify the bug isn't search-specific.
- **Added**: registered `CNTabBarRouteObserver()` on the example app's `CupertinoApp` so all demo screens benefit from auto-hide.

### Pana

- 160/160

---

## 1.4.1

### Bug Fixes

- **Fixed**: `CNTabBar` iOS 26 Liquid Glass selection pill was being cropped at its top edge after the v1.4.0 Issue #2 fix.
  - Root cause: v1.4.0 clipped the platform-view container to block the Liquid Glass drop shadow from bleeding over modal bottom sheets. The same clip also cut off the selection pill, which extends ~12–14pt above the bar's top during its morphing animation between tabs.
  - Resolution: the container still clips (shadow containment preserved), but the UITabBar is now positioned 14pt below the container's top edge, and the reported intrinsic height is bar-height + 14pt. The Liquid Glass selection pill — including its morph animation when rapidly switching tabs — renders fully inside the clipped container. Bar's visible position is unchanged at the bottom of the allocated space.
  - Applied to all 5 layout sites: single-bar init, split-bar init, and the equivalent setLayout rebuilds, for both iOS 26+ and iOS < 26 code paths.

### Example app

- **Added**: `Testing → #33: SVG in CNTabBar` — reproduction screen mirroring the SVG-icons-in-CNTabBar pattern reported in Issue #33, including the reporter's `NavBarItem` wrapper, `iconSize: 24`, and `tint` configuration. Local iOS 26 verification shows SVGs render correctly; the screen is published so the reporter (and future users hitting the same symptom) can confirm on their own setup.
- **Added**: `Testing → Stack+Positioned tab bar` — demonstrates the `Stack` + `Positioned(bottom: 0)` layout pattern as an alternative to `Scaffold.bottomNavigationBar` for users who need custom z-order control.
- **Enhanced**: `Testing → CNTabBar split-search clip` — bright teal background and a modal-bottom-sheet trigger button so both the search-orb top-edge clip and the Issue #2 shadow-bleed scenarios can be verified side-by-side on one screen.
- **Bumped**: example app iOS deployment target from 14.0 to 15.0 (required by the plugin's `s.platform = :ios, '15.0'`).

### Known issues

- **iOS simulator (not real device)**: iOS 26 Liquid Glass rendering on the simulator is software-rasterized and has visible differences from real Metal hardware. You may see the Liquid Glass selection pill appear slightly clipped at the top, or a brief rectangular outline around buttons on press. These artifacts **do not appear on real iOS 26 devices**. Always verify Liquid Glass behavior on a real iPhone/iPad before treating a visual quirk as a package bug.

### Pana

- 160/160

---

## 1.4.0

### Bug Fixes

- **Fixed**: `CNTabBar` top-edge shadow bleeding over modals / bottom sheets — the regression of Issue #2 that landed between v1.3.0 and v1.3.8 (Issue #2)
  - Root cause: in v1.3.3 the `clipsToBounds = true` containment from the original v1.3.0 fix was made conditional and disabled on iOS 26+. That removed the only thing keeping the UITabBar's top-edge hairline inside the platform view's bounds.
  - `container.clipsToBounds = true` restored unconditionally on the regular tab-bar platform view (5 sites — single-bar and split-bar in both `init` and `setLayout`)
  - Added `bar.shadowImage = UIImage()` on every `UITabBar` instance as belt-and-suspenders against iOS 26 ignoring the appearance-level shadow override

- **Fixed**: Liquid Glass halo rendering outside platform-view bounds during iOS route transitions — the "placeholder square" reported across CNButton, CNTabBar, and other widgets (Issue #29)
  - Root cause: iOS 26 Liquid Glass effects (`UIButton.Configuration.glass()`, `UITabBar` glass material, `.glassEffect()` SwiftUI modifier) render a translucent halo that extends slightly outside the view's frame. Without containment, that halo became visible during route transitions as a square outline around the widget on the outgoing page.
  - Same containment pattern as Issue #2 applied to: `CNButton`, `CNPopupMenuButton`, `CNSearchBar`, `CNFloatingIsland`, `CNLiquidGlassContainer`
  - `container.clipsToBounds = true`, `container.layer.shadowOpacity = 0`, `container.layer.backgroundColor = clear`, `container.isOpaque = false` plus the same on the inner subview where applicable

- **Fixed**: `CNTabBar` with `searchItem` — the floating Liquid Glass search orb's top edge was being cropped (commented in Issue #31 by @el2zay)
  - The iOS 26+ search-tab-bar variant (`CupertinoTabBarSearchPlatformView`) now leaves its container un-clipped so the search orb can render its top edge correctly. Top-edge hairline is still suppressed via `bar.shadowImage = UIImage()` and `bar.layer.shadowOpacity = 0`, so the original Issue #2 shadow bleed does not return.

- **Fixed**: `CNGlassButtonGroup` badge X-position — the last badge floated near the screen edge instead of sitting on its button when buttons were centered as a tight pill inside a wider container
  - `updateBadgePositions()` now estimates each button's rendered width from icon size + padding + minHeight (capsule width = max(intrinsic, minHeight)), computes the centered-HStack starting offset, and places each badge at the actual button's top-right corner instead of dividing container width evenly across button count.

- **Fixed**: `CNGlassButtonGroup` Auto Layout `_UITemporaryLayoutWidth = 0` warning on initial mount — silenced by lowering hosting-view constraint priorities to `.defaultHigh` so UIKit can break them silently during the brief temp-width=0 phase without logging.

### Test demos added

- `Testing → #2: Modal bottom sheet shadow` — opens a `CupertinoModalPopup` over a `CNTabBar` so the top-edge shadow bleed (or its absence) is easy to inspect
- `Testing → #29: Per-widget halo test` — one slow-transition push per widget so each can be verified in isolation
- `Testing → CNTabBar split-search clip` — `CNTabBar` with a `searchItem` so the floating orb is easy to inspect at the bottom-right
- `Testing → #31: TextField disappear in modal` — Material `Scaffold` + `CNTabBar` (with `searchItem`) in `bottomNavigationBar`, opens a modal sheet with a Material `TextField` and a `CupertinoTextField` for comparison

### Pana

- 160/160

---

## 1.3.9

### New Features

- **Added**: `checked` property on `CNPopupMenuItem` for checkmark/selected state (Issue #28)
  - Native iOS uses `UIAction.state = .on` for native checkmark display
  - Supports single-selection, multi-selection, and mixed checked+disabled states
  - Flutter fallback shows a checkmark icon before the label

### Bug Fixes

- **Fixed**: `PlatformException(recreating_view)` on iOS hot restart (PR #30 by @lucakramberger)
  - New `PlatformViewGuard` utility delays platform view creation during startup
  - `CNTabBar` refactored from nested FutureBuilders to state-managed async pipeline
  - Native `deinit` cleanup added to tab bar platform views

---

## 1.3.8

### Bug Fixes

- **Fixed**: macOS build — resolved 5 compilation errors in native Swift code
  - `badgeCount` parameter missing from `setupSwiftUIButton` method
  - `.clear` color inference on `CALayer.backgroundColor` (now uses `NSColor.clear.cgColor`)
  - `FlutterPlatformView` protocol replaced with `NSView` for LiquidGlassContainer
  - Removed invalid `namespace` argument from `GlassButtonSwiftUI` call
  - `NSButton.title` non-optional handling

---

## 1.3.7

### New Features

- **Added**: Popup menu button support in `CNGlassButtonGroup` via `CNButtonData.popup()` (PR #23 by @byackee)
  - Mix regular icon buttons and popup menu buttons in the same glass button group
  - Native SwiftUI rendering with `UIMenu` support
  - `CNButtonDataPopupItem` model for popup menu items
- **Added**: `labelFontFamily` and `labelFontSize` properties for `CNTabBar` (PR #26, Issue #16 by @byackee)
  - Customize tab bar label font with any registered font family
  - Dynamic font updates via method channel

### Bug Fixes

- **Fixed**: `buttonCustomIconColor` now works on iOS 26 with Liquid Glass rendering (PR #24, Issue #21 by @byackee)
  - Color is now sent to the native side via `capturedButtonIconColor`
  - Native side applies `.withTintColor(.alwaysOriginal)` to preserve custom icon colors
  - Menu item `iconColor` also supported for custom `IconData` icons
- **Fixed**: `CNSwitch` no longer pushed upward by keyboard (PR #25, Issue #4 by @byackee)
  - iOS 16.4+: uses `safeAreaRegions.remove(.keyboard)` official API
  - Pre-iOS 16.4: runtime fix targeting the hosting view's private keyboard notification handler

---

## 1.3.6

### Bug Fixes

- **Fixed**: Horizontal glass button group "waist" effect — reduced toolbar shrinkage between adjacent buttons by enforcing minimum 80pt glass spacing for horizontal groups with 2+ buttons (PR #20 by @byackee)
- **Fixed**: `CNTabBar` now shows a Flutter fallback tab bar while the native view initializes, instead of blank space for ~2 seconds (Issue #5)
- **Fixed**: `CNTabBar` with 5 items no longer has sporadic missing labels — added a second refresh pass for slow-to-initialize native views (Issue #6)

### Improvements

- **Added**: macOS podspec for CocoaPods support (Issue #10)

---

## 1.3.5

### Bug Fixes

- **Fixed**: `CNTabBar` `iconSize` now correctly applies to `CNImageAsset` (SVG/image) icons (Issue #19)
  - Previously, only SF Symbol icons respected the `iconSize` property
  - Image assets loaded via `loadFlutterAsset` and `createImageFromData` now receive the size parameter

---

## 1.3.4

### New Features

- **Added**: `interaction` property for `CNButtonConfig` and `CNButtonDataConfig` (PR #15 by @anirudhrao-github)
  - Allows disabling button touch handling without changing visual appearance
  - When `interaction: false`, button maintains normal look but doesn't respond to touches
  - Useful for conditional interactivity while preserving UI consistency

### Improvements

- **Improved**: `LiquidGlassContainer` layout simplified for better parent alignment control

---

## 1.3.3

### New Features

- **Added**: `customIconSize` property for `CNButtonConfig` and `CNButtonDataConfig` (PR #12 by @anirudhrao-github)
  - Allows customizing the size of custom icons (IconData) in buttons
  - Previously hardcoded to 20.0 points, now configurable

- **Added**: `iconSize` property for `CNTabBar` to control SF Symbol icon sizes
  - Supports dynamic icon sizing with automatic height adjustment
  - Note: Icons above 30pt may have minor visual quirks due to UITabBar constraints

### Bug Fixes

- **Fixed**: `CNGlassButtonGroup` no longer forces equal width on all buttons (PR #12 by @anirudhrao-github)
  - Buttons now use their intrinsic width based on content
  - Label buttons can now be wider than icon-only buttons in the same group
  - Uses SwiftUI `.fixedSize(horizontal: true, vertical: false)` for proper sizing

- **Fixed**: `CNTabBar.onTap` now fires for reselects (Issue #13)
  - Previously, tapping the already-selected tab did not trigger the callback
  - Now all taps fire `onTap`, allowing scroll-to-top or navigation reset on reselect

- **Fixed**: `CNTabBar` icon clipping on iOS 26+ Liquid Glass
  - Disabled `clipsToBounds` on iOS 26+ to allow proper Liquid Glass pill overflow
  - Tab bar height now adjusts dynamically based on icon size

### Improvements

- **Improved**: Initial layout rendering for `CNGlassButtonGroup`
  - Added immediate layout pass after view creation for correct first render

---

## 1.3.2

### New Features

- **Added**: Badge support for `CNGlassButtonGroup` icon buttons (PR #11 by @anirudhrao-github)
  - New `badgeCount` property on `CNButtonData.icon()` for displaying notification badges
  - Badges display as red circles with white text, showing "99+" for counts over 99
  - Uses UIKit overlay on iOS to prevent glass effect sampling artifacts
  - Proper clipping during page transitions

### Improvements

- **Improved**: Added library-level documentation for better API discoverability
  - Enhanced dartdoc comments for `button`, `button_data`, `button_style`, and `cupertino_native` libraries
  - 91.4% API documentation coverage

- **Fixed**: Dart formatting issues for pub.dev compliance
  - Resolved formatting in `button.dart` and `glass_button_group.dart`
  - Achieves 160/160 pana score

---

## 1.3.1

### Bug Fixes

- **Fixed**: Tint color now works correctly when buttons are inside `CNGlassButtonGroup` (PR #8 by @anirudhrao-github)
  - Previously, button tint colors were ignored when placed inside grouped glass buttons
  - Now buttons properly inherit and display their configured tint colors within button groups

---

## 1.3.0

### New Features

- **Added**: `CNTabBarNative` - Native iOS 26 Tab Bar with full UITabBarController integration
  - Uses native `UITabBarController` + `UISearchController` for authentic iOS 26 liquid glass effects
  - `CNTabBarNative.enable()` / `CNTabBarNative.disable()` for app-level tab bar management
  - `CNTab` class for tab configuration with SF Symbols and search tab support
  - Callbacks: `onTabSelected`, `onSearchChanged`, `onSearchSubmitted`, `onSearchCancelled`, `onSearchActiveChanged`
  - Full badge count support and dynamic styling

- **Added**: `CNSearchScaffold` - Native search scaffold controller for standalone search UI

- **Added**: `CNToast` - Toast notification widget with Liquid Glass effects
  - Static methods: `show()`, `success()`, `error()`, `warning()`, `info()`, `loading()`
  - Duration presets: short (2s), medium (3.5s), long (5s)
  - Position options: top, center, bottom
  - Auto-dismiss with queue management
  - `CNLoadingToastHandle` for dismissing loading toasts

- **Added**: `label` property to `CNTabBarSearchItem` for customizing the search tab label
  - Defaults to 'Search' to match iOS native behavior

- **Added**: `preserveTopToBottomOrder` property to `CNPopupMenuButton` (Issue #3)
  - When `true`, menu items maintain top-to-bottom order (1,2,3,4) regardless of menu direction
  - Default `false` preserves native iOS behavior where item 1 stays closest to the button
  - Uses `UIDeferredMenuElement.uncached` for dynamic position detection

### Improvements

- **Enhanced**: `PlatformVersion` now auto-initializes on first access
  - No longer need to call `await PlatformVersion.initialize()` in `main()`
  - Just use `PlatformVersion.isIOS26OrLater` directly
  - Old `initialize()` method kept for backwards compatibility (marked deprecated)

- **Added**: New helper properties to `PlatformVersion`:
  - `isIOS`, `isMacOS`, `isAndroid`, `isApple`
  - `isIOSVersionInRange(min, max)`, `isMacOSVersionInRange(min, max)`

### Bug Fixes

- **Fixed**: `CNPopupMenuButton.icon` now respects the order defined in items (Issue #3)
  - Added `preserveTopToBottomOrder` parameter to control item ordering behavior
  - Native iOS behavior keeps first item closest to button; set `preserveTopToBottomOrder: true` for consistent top-to-bottom order

- **Fixed**: Tab bar shadow artifact appearing over modals and bottom sheets (Issue #2)
  - Changed `configureWithDefaultBackground()` to `configureWithTransparentBackground()`
  - Added explicit shadow removal: `shadowColor = .clear`, `shadowImage = UIImage()`
  - Added `container.clipsToBounds = true` and `layer.shadowOpacity = 0`

- **Fixed**: Search bar keyboard auto-opening behavior (Issue #1)
  - `automaticallyActivatesSearch: false` now properly prevents keyboard from auto-opening
  - This is native iOS behavior - the search bar expands but keyboard only opens on text field tap

---

## 1.2.0

### New Features

- **Added**: iOS 26 Search Tab Feature for CNTabBar with animated Liquid Glass expansion
  - Native `UISearchTab`-style search integration that follows Apple's iOS 26 design
  - Search button expands into a full search bar with smooth spring animation
  - Tabs collapse to icon-only mode when search is active
  - Full Flutter fallback for iOS < 26 with identical behavior

- **Added**: `CNTabBarSearchItem` configuration class for search tab customization
  - `placeholder`: Custom placeholder text for the search field
  - `onSearchChanged`: Callback for live filtering as user types
  - `onSearchSubmit`: Callback when user submits search
  - `onSearchActiveChanged`: Callback for expand/collapse state changes
  - `automaticallyActivatesSearch`: Control keyboard auto-activation behavior

- **Added**: `CNTabBarSearchStyle` for visual customization
  - Icon sizes, colors, and active states
  - Search bar dimensions, padding, and border radius
  - Animation duration control
  - Clear button visibility toggle

- **Added**: `CNTabBarSearchController` for programmatic search control
  - `activateSearch()` / `deactivateSearch()`: Expand/collapse search programmatically
  - `text` property: Get/set search text
  - `clear()`: Clear search text with optional deactivation
  - Listener support for reactive state management

### Improvements

- **Enhanced**: `automaticallyActivatesSearch` now properly controls keyboard behavior
  - When `false`: Search bar expands but keyboard only opens when user taps the text field
  - When `true` (default): Keyboard opens automatically when search expands
  - Mirrors `UISearchTab.automaticallyActivatesSearch` from UIKit

### Bug Fixes

- **Fixed**: `MissingPluginException` errors during hot reload for `setItems` and `refresh` methods
  - Added try-catch error handling to prevent crashes during development
  - Search view now handles all expected method channel calls

---

## 1.1.9

### New Features

- **Added**: Lightweight `setBadges` method for CNTabBar to update badge values without rebuilding the entire tab bar
  - Previously, badge updates required recreating all tab bar items which caused visible flicker
  - New implementation only updates `badgeValue` on existing UITabBarItems for smooth, instant badge changes
  - Automatically detected when only badges changed (not labels, icons, or symbols) and uses fast path

### Improvements

- **Optimized**: CNTabBar now detects badge-only updates in `_syncPropsToNativeIfNeeded()` and calls lightweight native `setBadges` method instead of full `setItems` rebuild
- **Performance**: Badge updates are now instant with no view recreation or animation interruption

---

## 1.1.8

### Fixes

- **Fixed**: Visual update - minor bug fixes and improvements

---

## 1.1.7

### Fixes

- **Fixed**: Split mode tab selection bug where the wrong tab appeared selected on first load
  - **Issue**: When using `split: true` in CNTabBar, the right bar (e.g., Rewards tab) would incorrectly appear selected even when the left bar tab (e.g., Discover) was actually selected
  - **Root Cause**: In the `refresh` method, when restoring selection after cycling through tabs for label rendering, the code was incorrectly setting `right.selectedItem = rightItems.first` when `rightOriginal` was nil
  - **Solution**: Changed to restore the original selection directly (`right.selectedItem = rightOriginal`), which correctly keeps the right bar unselected when a left bar tab is active

- **Fixed**: Added `setSelectedIndex` call after `refresh` in Flutter widget to ensure correct selection state after view initialization

---

## 1.1.6

### Fixes

- **Fixed**: Attempted fix for split mode tab selection (superseded by 1.1.7)

---

## 1.1.5

### Breaking Changes

- **iOS Minimum Version**: Raised iOS deployment target from 13.0 to **15.0**
  - Required for `@FocusState` and other iOS 15+ SwiftUI features
  - Most production apps already target iOS 15+ (released September 2021)

### Fixes

- **Fixed**: Swift compiler error `'FocusState' is only available in iOS 15.0 or newer`
- **Fixed**: Swift compiler error `'self' used before 'super.init' call` in CNSearchBar
- **Fixed**: Pod installation issues when used in projects with iOS 15+ deployment target

---

## 1.1.4

### Fixes

- **Fixed**: Minor internal improvements

---

## 1.1.3

### Fixes

- **Fixed**: Full 50/50 pub.dev static analysis score (160/160 pana points)
- **Fixed**: All remaining lint and formatting issues

---

## 1.1.2

### Fixes

- **Fixed**: Dart formatter compliance

---

## 1.1.1

### Fixes

- **Fixed**: Resolved `use_build_context_synchronously` lint warnings

---

## 1.1.0

### Documentation Overhaul

- **Added**: Complete documentation for all widgets with real iOS 26 screenshots
- **Added**: CNSwitch documentation with controller examples
- **Added**: CNPopupMenuButton documentation with text and icon variants
- **Added**: CNSegmentedControl documentation with SF Symbols support
- **Added**: Button Styles Gallery showcasing multiple button styles
- **Added**: Popup menu opened state preview image
- **Enhanced**: Features table with Controller column
- **Enhanced**: All images now use centered alignment for better presentation

### New Screenshots

- Real iOS 26 Liquid Glass component screenshots (replacing AI-generated placeholders)
- Button styles gallery (4 preview images)
- Switch, Slider, Popup Menu, Segmented Control, Tab Bar previews
- Popup menu opened state preview

### Test Suite Updates

- **Added**: Comprehensive widget tests for CNSearchBar, CNFloatingIsland, CNGlassButtonGroup
- **Added**: Controller tests for CNSearchBarController, CNFloatingIslandController, CNSliderController
- **Added**: Data model tests for CNButtonData, CNButtonDataConfig, CNSymbol, CNImageAsset
- **Updated**: Platform and method channel tests with error handling and null response tests
- **Updated**: Enum tests for all new enums (CNGlassEffect, CNGlassEffectShape, CNSpotlightMode, etc.)
- **Total**: 82 tests covering all major components and APIs

---

## 1.0.6

### Improvements

- **Fixed**: Dart formatting issues to achieve full 50/50 static analysis score on pub.dev
- **Added**: Preview image for pub.dev package page

---

## 1.0.5

### Improvements

#### Static Analysis Cleanup
- **Fixed**: All `use_build_context_synchronously` warnings by capturing context-derived values before async gaps
- **Fixed**: `dangling_library_doc_comments` warning
- **Fixed**: `unnecessary_library_name` and `unnecessary_import` warnings
- **Improved**: Pub points score (static analysis section)

---

## 1.0.4

### Bug Fixes

#### CNButton Tap Detection (iOS < 26 Fallback)
- **Fixed**: Unreliable tap detection in CupertinoButton fallback mode
- **Issue**: Buttons showed press animation but `onPressed` didn't fire consistently
- **Solution**: Added `minSize: 0` to prevent CupertinoButton's internal minimum size from conflicting with SizedBox constraints
- **Added**: Explicit `borderRadius` and `pressedOpacity` for better hit testing and visual feedback

---

## 1.0.3

### Bug Fixes

#### Critical: iOS 18 Crash Fix
- **Fixed**: Reverted GestureDetector overlay that caused crash on iOS 18
- **Error**: `unrecognized selector sent to instance 'onTap:'`
- **Solution**: Removed Stack/GestureDetector approach, kept simple CupertinoButton

#### Icon Button Padding (kept from 1.0.2)
- **Fixed**: Increased default padding for icon buttons from 4 to 8 pixels

---

## 1.0.2 (BROKEN - DO NOT USE)

### Bug Fixes

#### CNButton Tap Detection (iOS < 26 Fallback)
- **BROKEN**: Added GestureDetector overlay that crashed on iOS 18
- Use 1.0.3 instead

#### Icon Button Padding
- **Fixed**: Increased default padding for icon buttons from 4 to 8 pixels
- Icons now have proper breathing room from the button border

---

## 1.0.1

* **Pub Points Improvement**: Addressed static analysis issues to improve package score.
* **Fix**: Resolved `use_build_context_synchronously` warnings across multiple components.
* **Fix**: Replaced deprecated `Color.value` and `withOpacity` usages with modern alternatives.
* **Documentation**: Added missing documentation for public members.

## 1.0.0

**Major Release - Complete iOS Fallback Fixes**

This release addresses critical issues that caused components to malfunction on iOS versions below 26.

### Breaking Changes
- Package renamed from `cupertino_native_plus` to `cupertino_native_better`
- Main import changed to `package:cupertino_native_better/cupertino_native_better.dart`

### Bug Fixes

#### CNButton Label Disappearing (iOS < 26)
- **Fixed**: Buttons with both icon AND label now correctly display both elements in fallback mode
- **Root Cause**: `widget.isIcon` was returning `true` for any button with an icon, even if it also had a label
- **Solution**: Changed fallback check to `widget.isIcon && widget.label == null` to only treat truly icon-only buttons as icon-only

#### CNTabBar Icons Not Showing (iOS < 26)
- **Fixed**: Tab bar icons now render correctly using CNIcon instead of empty placeholder circles
- **Root Cause**: Fallback code only checked for `customIcon`, ignoring SF Symbols (`icon`/`activeIcon`)
- **Solution**: Added `_buildTabIcon()` helper that properly handles all icon types with correct priority

#### CNIcon/CNButton/CNPopupMenuButton Showing "..." (iOS < 26)
- **Fixed**: All CN components now properly render SF Symbols on older iOS versions
- **Root Cause**: Components were checking `shouldUseNativeGlass` (iOS 26+) for SF Symbol support, but SF Symbols work on iOS 13+
- **Solution**: Added new `supportsSFSymbols` getter that always returns true on iOS/macOS

### New Features
- Added `PlatformVersion.supportsSFSymbols` for checking SF Symbol availability (iOS 13+, macOS 11+)
- Comprehensive dartdoc documentation for all public APIs
- Full comparison table with other packages in README

### Documentation
- Complete rewrite of README with feature comparison
- Migration guide from cupertino_native_plus
- Comprehensive code examples for all widgets

---

## 0.0.9

* Package preparation for public release
* Updated repository URLs

## 0.0.8

* Fixed SF Symbol rendering in fallback mode for CNButton
* Fixed SF Symbol rendering in fallback mode for CNPopupMenuButton
* Added proper imports for CNIcon in button and popup components

## 0.0.7

* Added `supportsSFSymbols` getter to PlatformVersion
* SF Symbols now render natively on all iOS versions (13+), not just iOS 26+
* Separated Liquid Glass support (iOS 26+) from SF Symbol support (iOS 13+)

## 0.0.6

* **Dark Mode Support for LiquidGlassContainer**: Added automatic dark mode detection and synchronization for LiquidGlassContainer, ensuring the glass effect correctly adapts to Flutter's theme changes
* **Gesture Detection Fixes**: Fixed gesture handling in LiquidGlassContainer by wrapping platform views in IgnorePointer, preventing the native view from intercepting touch events and allowing child widgets to receive gestures properly
* **Brightness Syncing Improvements**: Enhanced brightness synchronization for icons and other components, ensuring they automatically update when the system theme changes

## 0.0.5

* **Performance Improvements**: Added method channel updates for button groups to prevent full rebuilds and eliminate freezes when updating button parameters
* **Preserved Animations**: Button groups now update smoothly without losing native animations when button properties change (icon, color, image asset, etc.)
* **Efficient Updates**: Implemented granular updates for individual buttons in groups, only updating changed buttons instead of rebuilding the entire group
* **Reactive SwiftUI Updates**: Converted button group SwiftUI views to use ObservableObject pattern for efficient reactive updates
* **Button Parameter Updates**: Individual buttons in groups can now be updated dynamically via method channels without full view rebuilds

## 0.0.4

* **PNG Image Support**: Added full support for PNG images in all components (buttons, icons, popup menus, tab bars, glass button groups)
* **Automatic Asset Resolution**: Implemented automatic asset resolution based on device pixel ratio, similar to Flutter's automatic asset selection. The system now automatically selects the appropriate resolution-specific asset (e.g., `assets/icons/3.0x/checkcircle.png` for @3x devices) or falls back to the closest bigger size
* **ImageUtils Consolidation**: Consolidated all image loading, format detection, scaling, and tinting logic into a shared `ImageUtils.swift` class for better code maintainability and consistency
* **Fixed PNG Rendering**: Fixed PNG image rendering issues in buttons and glass button groups
* **Fixed Image Orientation**: Fixed image flipping issues for both PNG and SVG images when colors are applied
* **Made buttonIcon Optional**: Made `buttonIcon` parameter optional in `CNPopupMenuButton.icon` constructor, allowing developers to use only `buttonImageAsset` or `buttonCustomIcon`
* **Improved Glass Effect Appearance**: Fixed glass effect appearance synchronization with Flutter's theme mode to prevent dark-to-light transitions on initial render
* **Enhanced Image Format Detection**: Improved automatic image format detection from file extensions and magic bytes
* **Better Fallback Handling**: Improved fallback behavior when asset paths fail to load, ensuring images still render from provided image bytes

## 0.0.3

* Updated README to showcase all icon types (SVG assets, custom icons, and SF Symbols)
* Added comprehensive examples for all icon types in Button, Icon, Popup Menu Button, and Tab Bar sections
* Added icon support overview at the beginning of "What's in the package" section
* Clarified that all components support multiple icon types with unified priority system

## 0.0.2

* Updated README with corrected version requirements and improved documentation
* Fixed iOS minimum version requirement (13.0 instead of 14.0)
* Removed incorrect Xcode 26 beta requirement
* Added Contributing and License sections
* Improved package description and introduction

## 0.0.1

* Initial release
* Fixed iOS 26+ version detection using Platform.operatingSystemVersion parsing
* Native Liquid Glass widgets for iOS and macOS
* Support for CNButton, CNIcon, CNSlider, CNSwitch, CNTabBar, CNPopupMenuButton, CNSegmentedControl
* Glass effect unioning for grouped buttons
* LiquidGlassContainer for applying glass effects to any widget
