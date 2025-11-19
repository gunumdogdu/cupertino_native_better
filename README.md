# cupertino_native_better

Native Liquid Glass widgets for iOS and macOS with pixel-perfect fidelity.

## What's Different?

This is a fixed fork of `cupertino_native_plus` that resolves iOS 26+ version detection issues in release builds.

### The Problem
The original `cupertino_native_plus` package uses platform channels to detect iOS/macOS versions, which fails with "Null check operator used on a null value" in release builds. This causes it to fall back to iOS 15, making `shouldUseNativeGlass` return false even on iOS 26+.

### The Solution
`cupertino_native_better` uses direct parsing of `Platform.operatingSystemVersion` instead of platform channels, which works reliably in both debug and release builds.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  cupertino_native_better:
    git:
      url: https://github.com/yourusername/cupertino_native_better.git
```

## Usage

```dart
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/utils/version_detector.dart';

// Initialize early in your app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlatformVersion.initialize();

  runApp(MyApp());
}

// Use CNButton and other components
CNButton.filled(
  onPressed: () {},
  child: Text('Button'),
)
```

## Changes from cupertino_native_plus

- Fixed iOS 26+ version detection in release builds
- Uses manual version parsing instead of platform channels
- Improved error handling and fallbacks
- Added debug logging for version detection

## Credits

Based on [cupertino_native_plus](https://pub.dev/packages/cupertino_native_plus) by NarekManukyan, which is based on [cupertino_native](https://pub.dev/packages/cupertino_native) by Serverpod.

## License

BSD-3-Clause (same as original package)
