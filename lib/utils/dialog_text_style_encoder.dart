import 'package:flutter/widgets.dart';

import '../channel/params.dart';
import '../style/dialog_text_style.dart';

/// [style] without its colour, for a destructive button, which keeps the
/// system red.
TextStyle? dialogStyleWithoutColor(TextStyle? style) => style == null
    ? null
    : TextStyle(
        fontFamily: style.fontFamily,
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
      );

/// The `textStyle` of a dialog's show payload, or null for the system look.
Map<String, Object?>? encodeDialogTextStyle(
  BuildContext context, {
  String? fontFamily,
  CNDialogTextStyle? title,
  CNDialogTextStyle? message,
  CNDialogTextStyle? action,
}) {
  Map<String, Object?>? part(CNDialogTextStyle? style) {
    if (style == null) return null;
    final map = <String, Object?>{
      'fontFamily': ?style.fontFamily,
      'fontSize': ?style.fontSize,
      'fontWeight': ?style.fontWeight?.value,
      'color': ?resolveColorToArgb(style.color, context),
    };
    return map.isEmpty ? null : map;
  }

  final encoded = <String, Object?>{
    'fontFamily': ?fontFamily,
    'title': ?part(title),
    'message': ?part(message),
    'action': ?part(action),
  };
  return encoded.isEmpty ? null : encoded;
}
