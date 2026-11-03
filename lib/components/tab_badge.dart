import 'package:flutter/cupertino.dart';

// The badges the CNTabBar and CNTabRail fallbacks draw for
// CNTabBarItem.badge. Not exported.

/// [CNTabBarItem.dotBadge]: a dot without a count.
class TabBadgeDot extends StatelessWidget {
  /// Creates the dot.
  const TabBadgeDot({super.key});

  /// Diameter, as `CNDotTabBar` and `CNTabRailView` draw it natively.
  static const double size = 9;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.resolveFrom(context),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A red capsule with the badge text. The defaults match `CNTabRailView`'s
/// native badge.
class TabBadge extends StatelessWidget {
  /// Creates a badge showing [text].
  const TabBadge(
    this.text, {
    super.key,
    this.height = 17,
    this.fontSize = 11,
    this.fontWeight = FontWeight.w700,
    this.padding = 5,
  });

  /// The badge text.
  final String text;

  /// Height, and the width of a one-character badge.
  final double height;

  /// Font size of [text].
  final double fontSize;

  /// Font weight of [text].
  final FontWeight fontWeight;

  /// Horizontal padding when [text] is longer than one character.
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: height, minHeight: height),
      padding: EdgeInsets.symmetric(horizontal: text.length > 1 ? padding : 0),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.resolveFrom(context),
        borderRadius: BorderRadius.all(Radius.circular(height / 2)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: CupertinoColors.white,
        ),
      ),
    );
  }
}
