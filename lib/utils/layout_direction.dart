import 'package:flutter/widgets.dart';

/// The text direction a native view is laid out in (#142): [explicit], or
/// the ambient [Directionality]. As the `rtl` creation parameter: true or
/// false, or null to leave the system's direction (no [Directionality]).
///
/// UIKit and AppKit lay views out by the app's language, which an app that
/// picks its language in Dart never tells them about, so the native views
/// take Flutter's direction instead.
bool? nativeRtl(BuildContext context, TextDirection? explicit) {
  final direction = explicit ?? Directionality.maybeOf(context);
  if (direction == null) return null;
  return direction == TextDirection.rtl;
}
