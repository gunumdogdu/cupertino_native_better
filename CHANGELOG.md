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

* Initial release.
