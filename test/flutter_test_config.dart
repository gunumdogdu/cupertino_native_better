import 'dart:async';

import 'package:cupertino_native_better/utils/reusable_platform_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file: native views kept for reuse by one test
/// (#166) must not be picked up by the next.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(ReusablePlatformViews.debugReset);
  await testMain();
}
