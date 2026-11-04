import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// A navigation bar with a back button above [child], on macOS only.
///
/// Full-screen pages built for iPhone (the Music and iPhone Duo scenes, the
/// Native Sheet map) have no bar of their own: on iOS the edge swipe takes
/// the user back. A Mac has no edge swipe, so there they get this bar. On
/// every other platform, and on a page that cannot be popped, [child] is
/// returned as it is.
class MacBackBar extends StatelessWidget {
  const MacBackBar({super.key, required this.title, required this.child});

  /// The bar's title.
  final String title;

  /// The page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    if (defaultTargetPlatform != TargetPlatform.macOS || !canPop) return child;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(title)),
      child: SafeArea(
        bottom: false,
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: child,
        ),
      ),
    );
  }
}
