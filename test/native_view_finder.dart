import 'package:cupertino_native_better/utils/reusable_platform_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds the native views on screen: `UiKitView` and `AppKitView`, and the
/// reusable platform view `CNPopupMenuButton` shows its button in (#166).
Finder findNativeView() => find.byWidgetPredicate(
  (w) => w is UiKitView || w is AppKitView || w is ReusableDarwinPlatformView,
  description: 'native view',
);
