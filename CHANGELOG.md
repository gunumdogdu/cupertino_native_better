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
