## 1.1.0-prerelease

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
