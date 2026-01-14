# FAQ - Common Questions & Solutions

This is the official FAQ for `cupertino_native_better`. Find answers to common questions here!

---

## CNTabBar / Tab Navigation

### Q: How do I implement bottom tab navigation with CNTabBar?

**A:** Here's the simplest pattern:

```dart
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Column(
        children: [
          Expanded(child: _buildCurrentScreen()),
          SafeArea(
            top: false,
            child: CNTabBar(
              items: [
                CNTabBarItem(label: 'Home', icon: CNSymbol('house'), activeIcon: CNSymbol('house.fill')),
                CNTabBarItem(label: 'Profile', icon: CNSymbol('person'), activeIcon: CNSymbol('person.fill')),
              ],
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0: return HomeScreen();
      case 1: return ProfileScreen();
      default: return SizedBox.shrink();
    }
  }
}
```

### Q: Do I need IndexedStack for tab navigation?

**A:** No, `IndexedStack` is optional. Use it only if you need to:
- Preserve scroll positions when switching tabs
- Keep form data intact between tab switches
- Maintain state in StatefulWidgets across tab changes

For simple navigation, a basic `switch` statement works fine.

### Q: onTap doesn't fire when I tap the same tab again (reselect)

**A:** The `onTap` callback fires for ALL taps, including reselects. Check your implementation:

```dart
onTap: (index) {
  final isReselect = index == _currentIndex;
  if (isReselect) {
    // Handle reselect - e.g., scroll to top or pop to root
    print('Reselected tab $index');
  }
  setState(() => _currentIndex = index);
},
```

If this doesn't work, please [open an issue](https://github.com/gunumdogdu/cupertino_native_better/issues) with a minimal reproduction.

### Q: Content is clipped by the tab bar

**A:** Make sure you're using proper SafeArea configuration:

```dart
Column(
  children: [
    Expanded(
      child: SafeArea(
        bottom: false,  // Don't add bottom padding here
        child: YourContent(),
      ),
    ),
    SafeArea(
      top: false,  // Only apply bottom safe area to tab bar
      child: CNTabBar(...),
    ),
  ],
)
```

---

## CNTabBarNative (iOS 26+)

### Q: What's the difference between CNTabBar and CNTabBarNative?

| Feature | CNTabBar | CNTabBarNative |
|---------|----------|----------------|
| Works on | All iOS versions | iOS 26+ only |
| Implementation | Platform view | UITabBarController |
| Glass effects | Yes | Yes (native) |
| Search tab | Yes | Yes (native floating) |

### Q: How do I use CNTabBarNative?

```dart
@override
void initState() {
  super.initState();
  _enableNativeTabBar();
}

Future<void> _enableNativeTabBar() async {
  await CNTabBarNative.enable(
    tabs: [
      CNTab(title: 'Home', sfSymbol: CNSymbol('house.fill')),
      CNTab(title: 'Search', isSearchTab: true),
      CNTab(title: 'Profile', sfSymbol: CNSymbol('person.fill')),
    ],
    selectedIndex: 0,
    onTabSelected: (index) => setState(() => _selectedTab = index),
    onSearchChanged: (query) => print('Search: $query'),
  );
}

@override
void dispose() {
  CNTabBarNative.disable();  // Important!
  super.dispose();
}
```

---

## General

### Q: Why do components look different on older iOS versions?

**A:** This package provides native iOS 26 Liquid Glass effects. On older iOS versions, components automatically fall back to appropriate styling. This is by design to ensure compatibility.

### Q: How do I check if Liquid Glass is available?

```dart
if (PlatformVersion.shouldUseNativeGlass) {
  // iOS 26+ with Liquid Glass
} else {
  // Fallback styling
}
```

---

## Still have questions?

- Check the [example app](https://github.com/gunumdogdu/cupertino_native_better/tree/main/example)
- [Open a discussion](https://github.com/gunumdogdu/cupertino_native_better/discussions)
- [Report a bug](https://github.com/gunumdogdu/cupertino_native_better/issues)
