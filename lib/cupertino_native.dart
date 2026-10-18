/// Native Cupertino widgets for Flutter with Liquid Glass support.
///
/// This library provides native iOS and macOS widgets including buttons,
/// sliders, switches, tab bars, and more. Supports Liquid Glass effects
/// on iOS 26+ and macOS 26+.
///
/// ## Getting Started
///
/// Import this library to access all Cupertino native widgets:
///
/// ```dart
/// import 'package:cupertino_native_better/cupertino_native.dart';
/// ```
///
/// ## Available Components
///
/// - [CNButton] - Native button with multiple styles including glass effects
/// - [CNSlider] - Native slider control
/// - [CNSwitch] - Native toggle switch
/// - [CNSegmentedControl] - Native segmented control
/// - [CNTabBar] - Native tab bar
/// - [CNIcon] - SF Symbols icon renderer
/// - [CNGlassButtonGroup] - Glass button group with Liquid Glass effects
/// - [LiquidGlassContainer] - Container with Liquid Glass background
///
/// {@category Main}
library;

export 'cupertino_native_platform_interface.dart';
export 'cupertino_native_method_channel.dart';
export 'components/action_sheet.dart';
export 'components/slider.dart';
export 'components/switch.dart';
export 'components/segmented_control.dart';
export 'components/icon.dart';
export 'components/tab_bar.dart';
export 'components/popup_menu_button.dart';
export 'components/popup_gesture.dart';
export 'style/sf_symbol.dart';
export 'style/button_style.dart';
export 'style/image_placement.dart';
export 'components/button.dart';
export 'components/glass_button_group.dart';
export 'components/liquid_glass_container.dart';
export 'utils/version_detector.dart';
export 'utils/theme_helper.dart';
export 'style/glass_effect.dart';
export 'utils/transition_observer.dart';

import 'cupertino_native_platform_interface.dart';

/// Top-level facade for simple plugin interactions.
class CupertinoNative {
  /// Returns a user-friendly platform version string supplied by the
  /// platform implementation.
  Future<String?> getPlatformVersion() {
    return CupertinoNativePlatform.instance.getPlatformVersion();
  }
}
