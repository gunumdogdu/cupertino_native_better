# cupertino_native_better

[![Pub Version](https://img.shields.io/pub/v/cupertino_native_better)](https://pub.dev/packages/cupertino_native_better)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-lightgrey)](https://flutter.dev)

Native iOS 26+ **Liquid Glass** widgets for Flutter with pixel-perfect fidelity. This package renders authentic Apple UI components using native platform views, providing the genuine iOS/macOS look and feel that Flutter's built-in widgets cannot achieve.

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/screenshots/preview.jpg" alt="Preview" width="600"/>
</p>

## Quick Start

No initialization required! Just import and use:

```dart
import 'package:cupertino_native_better/cupertino_native_better.dart';

void main() {
  runApp(MyApp());
}
```

> **Note:** `PlatformVersion` auto-initializes on first access. No need to call `initialize()` anymore!

## Performance Best Practices

### ⚠️ LiquidGlassContainer & Lists

`LiquidGlassContainer` uses a **Platform View** (`UiKitView` / `AppKitView`) under the hood. While powerful, platform views are more expensive than standard Flutter widgets.

*   **DO NOT** use `LiquidGlassContainer` inside long scrolling lists (`ListView.builder`, `GridView`) with many items. This will cause significant performance drops (jank).
*   **DO** use `LiquidGlassContainer` for static elements like Cards, Headers, Navigation Bars, or Floating Action Buttons.

## Why cupertino_native_better?

### Comparison with Other Packages

| Feature | cupertino_native_better | cupertino_native_plus | cupertino_native |
|---------|:-----------------------:|:---------------------:|:----------------:|
| iOS 26+ Liquid Glass | **Yes** | Yes | No |
| Release Build Version Detection | **Fixed** | Broken | N/A |
| SF Symbol Fallback (iOS < 26) | **CNIcon renders natively** | Placeholder icons | N/A |
| Button Label + Icon Fallback | **Both render correctly** | Label disappears | N/A |
| Tab Bar Icon Fallback | **CNIcon renders natively** | Empty circles | N/A |
| Image Asset Support (PNG/SVG) | **Full support** | Partial | No |
| Automatic Asset Resolution | **Yes (1x-4x)** | No | No |
| Dark Mode Sync | **Automatic** | Manual | Manual |
| Glass Effect Unioning | **Yes** | Yes | No |
| macOS Support | **Yes** | Yes | Yes |

### The Problem with Other Packages

**cupertino_native_plus** has a critical bug: it uses platform channels to detect iOS versions, which fails with *"Null check operator used on a null value"* in release builds. This causes:

- `shouldUseNativeGlass` returns `false` even on iOS 26+
- Falls back to old Cupertino widgets incorrectly
- Icons show as "..." or empty circles on iOS 18
- Button labels disappear when buttons have both icon and label

### Our Solution

**cupertino_native_better** fixes all these issues:

```dart
// We parse Platform.operatingSystemVersion directly
// Example: "Version 26.1 (Build 23B82)" -> 26
static int? _getIOSVersionManually() {
  final versionString = Platform.operatingSystemVersion;
  final match = RegExp(r'Version (\d+)\.').firstMatch(versionString);
  return int.tryParse(match?.group(1) ?? '');
}
```

This approach works reliably in **both debug and release builds**.

## Features

### Widgets

| Widget | Description | Controller |
|--------|-------------|:----------:|
| `CNButton` | Native push button with Liquid Glass effects, SF Symbols, and image assets | - |
| `CNButton.icon` | Circular icon-only button variant | - |
| `CNIcon` | Platform-rendered SF Symbols, custom IconData, or image assets | - |
| `CNTabBar` | Native tab bar with split mode for scroll-aware layouts | - |
| `CNSlider` | Native slider with min/max range and step support | `CNSliderController` |
| `CNSwitch` | Native toggle switch with animated state changes | `CNSwitchController` |
| `CNPopupMenuButton` | Native popup menu with dividers, icons, and image assets | - |
| `CNPopupMenuButton.icon` | Circular icon-only popup menu variant | - |
| `CNSegmentedControl` | Native segmented control with SF Symbols support | - |
| `CNGlassButtonGroup` | Grouped buttons with unified glass blending (tint color support) | - |
| `LiquidGlassContainer` | Apply Liquid Glass effects to any Flutter widget | - |
| `CNGlassCard` | **(Experimental)** Pre-styled card with optional breathing glow animation | - |
| `CNTabBarNative` | **iOS 26 Native Tab Bar** with UITabBarController + search | - |
| `CNToast` | Toast notifications with Liquid Glass effects | - |

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

### Tab Bar with Split Mode

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/screenshots/tab_bar_preview.png" width="300" alt="Tab Bar Preview"/>
</p>

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
  split: true, // Separates tabs when scrolling
  rightCount: 1, // Number of tabs pinned to the right
)
```

### Native iOS 26 Tab Bar (CNTabBarNative)

For full iOS 26 liquid glass tab bar experience with native UITabBarController:

```dart
@override
void initState() {
  super.initState();
  CNTabBarNative.enable(
    tabs: [
      CNTab(title: 'Home', sfSymbol: CNSymbol('house.fill')),
      CNTab(title: 'Search', sfSymbol: CNSymbol('magnifyingglass'), isSearchTab: true),
      CNTab(title: 'Profile', sfSymbol: CNSymbol('person.fill')),
    ],
    onTabSelected: (index) => setState(() => _selectedTab = index),
    onSearchChanged: (query) => filterResults(query),
  );
}

@override
void dispose() {
  CNTabBarNative.disable();
  super.dispose();
}
```

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

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  cupertino_native_better: ^1.3.1
```

## Usage

### Basic Button

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/screenshots/button_preview.png" width="300" alt="Button Preview"/>
</p>

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

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/screenshots/button_preview_2.png" width="300" alt="Glass Button Styles"/>
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/screenshots/button_preview_3.png" width="300" alt="Filled Button Styles"/>
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/screenshots/button_preview_4.png" width="300" alt="More Button Styles"/>
</p>

### Icon-Only Button

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/screenshots/icon_button_preview.png" width="300" alt="Icon Button Preview"/>
</p>

```dart
CNButton.icon(
  icon: CNSymbol('plus', size: 24),
  config: CNButtonConfig(style: CNButtonStyle.glass),
  onPressed: () {},
)
```

### Native Icons

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/screenshots/icon_preview.png" width="300" alt="Icon Preview"/>
</p>

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

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/screenshots/slider_preview.jpg" width="300" alt="Slider Preview"/>
</p>

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

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/screenshots/switch_preview.png" width="300" alt="Switch Preview"/>
</p>

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

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/screenshots/popup_menu_preview.png" width="300" alt="Popup Menu Button"/>
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/screenshots/popup_menu_opened_preview.jpg" width="300" alt="Popup Menu Opened"/>
</p>

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

### Segmented Control

<p align="center">
  <img src="https://raw.githubusercontent.com/gunumdogdu/cupertino_native_better/main/misc/screenshots/segmented_control_preview.png" width="300" alt="Segmented Control Preview"/>
</p>

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
   cupertino_native_better: ^1.3.1
   ```

2. Update imports:
   ```dart
   // Before
   import 'package:cupertino_native_plus/cupertino_native_plus.dart';

   // After
   import 'package:cupertino_native_better/cupertino_native_better.dart';
   ```

3. No other code changes needed - API is fully compatible!

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
