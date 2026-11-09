import 'package:flutter/widgets.dart';

/// The text style of one part of a `CNAlert` or `CNActionSheet`: its title,
/// its message or its buttons (#144).
///
/// Every field is optional. A null size or weight keeps the one the system
/// gives that part (the preferred button stays bold), so a style with only a
/// [fontFamily] changes the family alone and the dialog keeps its native
/// proportions. A family declared under `fonts:` in `pubspec.yaml` works as
/// it is: the package registers it with the system the first time.
@immutable
class CNDialogTextStyle {
  /// Creates a dialog text style.
  const CNDialogTextStyle({
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.color,
  });

  /// The font family; null uses the dialog's `fontFamily`, or the system's.
  final String? fontFamily;

  /// The size in points; null keeps the system's.
  final double? fontSize;

  /// The weight; null keeps the system's (the family's nearest face).
  final FontWeight? fontWeight;

  /// The colour; null keeps the system's. A destructive button keeps the
  /// system red.
  final Color? color;

  /// This style for the Flutter fallback dialogs, with [family] when the
  /// style has none.
  TextStyle? toTextStyle(String? family) {
    final f = fontFamily ?? family;
    if (f == null && fontSize == null && fontWeight == null && color == null) {
      return null;
    }
    return TextStyle(
      fontFamily: f,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CNDialogTextStyle &&
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize &&
      other.fontWeight == fontWeight &&
      other.color == color;

  @override
  int get hashCode => Object.hash(fontFamily, fontSize, fontWeight, color);
}
