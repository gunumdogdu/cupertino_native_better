import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #156 reproduction: a glass `CNButton` with `autoHideOnModal: false`
/// is flat for as long as a sheet from a sheet package is open, and its
/// shadow drops out while a dialog fades in or out.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/156
/// Reported by @Ashhad08.
///
/// ### The claims
///
///  1. Sheet packages wrap their sheet in a full-screen `OverlayPortal` (a
///     status bar tap handler) and drag detector. `CNTabBarRouteObserver`
///     didn't know those paint only their child, so it measured the sheet
///     as the whole screen, and the button stayed contained.
///  2. A dialog far from the button still clips the glass while it fades.
///  3. A sheet that scales the page under it (as `CupertinoScaffold` does)
///     left the glass flat while the page moved, and for as long as a
///     finger held the sheet mid-drag (2.7.1). The flattening hid a box
///     around the glow: `CNButton` sat in a `ClipRect` its own size, which
///     the engine turns into a mask at the view's bounds under a scaled
///     page. The clip is gone, so the glass needs no flattening.
///
/// ### How this screen proves it
///
/// A glass close button in the header, over a striped backdrop. **Sheet**
/// opens a route built like a sheet package's (OverlayPortal and drag
/// detector around a sheet that stops well below the header). **Dialog**
/// opens a `showCupertinoDialog` with a list on the left, away from the
/// button. **Scaling sheet** opens a sheet that scales the page down as it
/// comes; drag its grabber down and hold. AUTO opens each in turn, drags the
/// scaling sheet half way and holds it, and prints `CNB_SHOT 156-<step>`.
///
///  * **Bug:** under the sheet the button is a flat disc (no rim or shadow)
///    until the sheet is closed; while the dialog fades the shadow drops out;
///    while the scaling sheet is held mid-drag the button is flat.
///  * **Fixed:** the button keeps its full glass under the sheets, while the
///    dialog fades in and out, and while the page scales or the sheet is
///    held, dimmed like the rest of the page, with no box around its glow.
class Issue156GlassButtonPackageSheetTestPage extends StatefulWidget {
  const Issue156GlassButtonPackageSheetTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Opens and closes the sheet and the dialog, printing `CNB_SHOT <step>`.
  final bool autoCycle;

  @override
  State<Issue156GlassButtonPackageSheetTestPage> createState() =>
      _Issue156GlassButtonPackageSheetTestPageState();
}

class _Issue156GlassButtonPackageSheetTestPageState
    extends State<Issue156GlassButtonPackageSheetTestPage> {
  int _closeTaps = 0;

  /// The page's scale, driven by the scaling sheet's animation.
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  _ScalingSheetRoute? _scaling;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _run();
  }

  Future<void> _run() async {
    Future<void> shot(String tag, int afterMs) async {
      await Future<void>.delayed(Duration(milliseconds: afterMs));
      if (mounted) debugPrint('CNB_SHOT 156-$tag');
    }

    await shot('rest', 4000);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    _openSheet();
    await shot('sheet-up', 1500);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    Navigator.of(context).pop();
    await shot('sheet-closed', 1600);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _openDialog();
    await shot('dialog-up', 1500);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    Navigator.of(context).pop();
    await shot('dialog-closed', 1600);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _openScalingSheet();
    await shot('scale-up', 1500);
    // Drag it half way down, as a finger would, and hold.
    for (var v = 1.0; v > 0.55; v -= 0.02) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      _scaling?.dragTo(v);
    }
    await shot('scale-held', 1500);
    _scaling?.release();
    await shot('scale-released', 1500);
    if (!mounted) return;
    Navigator.of(context).pop();
    await shot('scale-closed', 1600);
    debugPrint('CNB_SHOT 156-done');
  }

  void _openSheet() {
    Navigator.of(context).push(_PackageStyleSheetRoute());
  }

  void _openScalingSheet() {
    final route = _ScalingSheetRoute(_progress);
    _scaling = route;
    Navigator.of(context).push(route);
  }

  void _openDialog() {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Stack(
        children: [
          Positioned(
            left: 24,
            top: 180,
            width: 180,
            height: 360,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: CupertinoListSection(
                topMargin: 0,
                children: [
                  for (var year = 2027; year >= 2021; year--)
                    CupertinoListTile(
                      title: Text('$year'),
                      onTap: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _progress,
      builder: (context, progress, child) => ColoredBox(
        color: const Color(0xFF000000),
        child: Transform.scale(
          scale: 1 - progress / 10,
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12 * progress),
            child: child,
          ),
        ),
      ),
      child: _page(context),
    );
  }

  Widget _page(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          const Positioned.fill(child: _Stripes()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      CNButton.icon(
                        icon: const CNSymbol('chevron.left', size: 17),
                        semanticLabel: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      CNButton.icon(
                        icon: const CNSymbol('xmark', size: 17),
                        semanticLabel: 'Close',
                        autoHideOnModal: false,
                        onPressed: () => setState(() => _closeTaps++),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: CupertinoButton.filled(
                    onPressed: _openSheet,
                    child: const Text('Sheet (package style)'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: CupertinoButton.filled(
                    onPressed: _openDialog,
                    child: const Text('Dialog away from the button'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: CupertinoButton.filled(
                    onPressed: _openScalingSheet,
                    child: const Text('Scaling sheet (drag and hold it)'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '#156 · close taps: $_closeTaps\n'
                    'The close button has autoHideOnModal: false. Bug: it is '
                    'flat while the sheet is up. Fixed: it keeps its glass.',
                    style: _caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A sheet route built like the sheet packages build theirs: a full-screen
/// `OverlayPortal` and drag detector around a sheet that covers the bottom
/// 70% of the screen.
class _PackageStyleSheetRoute extends PopupRoute<void> {
  final OverlayPortalController _portal = OverlayPortalController();

  @override
  Color? get barrierColor => const Color(0x66000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: child,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final height = MediaQuery.sizeOf(context).height * 0.7;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (_) => const SizedBox.shrink(),
      child: GestureDetector(
        onVerticalDragUpdate: (_) {},
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Text(
              'Package-style sheet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sheet that scales the page under it down as it comes and goes, and
/// follows a drag on its grabber, as `CupertinoScaffold` sheets do: the drag
/// sets the route's animation value directly.
class _ScalingSheetRoute extends PopupRoute<void> {
  _ScalingSheetRoute(this.progress);

  final ValueNotifier<double> progress;

  @override
  Color? get barrierColor => const Color(0x33000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  TickerFuture didPush() {
    animation!.addListener(_follow);
    return super.didPush();
  }

  void _follow() => progress.value = animation!.value;

  @override
  void dispose() {
    animation?.removeListener(_follow);
    progress.value = 0;
    super.dispose();
  }

  /// Moves the sheet as a finger dragging it does.
  void dragTo(double value) => controller!.value = value.clamp(0.0, 1.0);

  /// Lets go: it springs back up.
  void release() => controller!.forward();

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final height = MediaQuery.sizeOf(context).height * 0.85;
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onVerticalDragUpdate: (d) =>
            dragTo(controller!.value - d.primaryDelta! / height),
        onVerticalDragEnd: (_) {
          if (controller!.value < 0.5) {
            Navigator.of(context).pop();
          } else {
            release();
          }
        },
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey3.resolveFrom(context),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Drag down and hold',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label.resolveFrom(context),
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _caption = TextStyle(
  fontSize: 14,
  height: 1.4,
  color: CupertinoColors.white,
);

/// Diagonal stripes, so the glass's refraction and rim are easy to see.
class _Stripes extends StatelessWidget {
  const _Stripes();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment(-0.82, -0.86),
          tileMode: TileMode.repeated,
          colors: [
            Color(0xFF1F6FEB),
            Color(0xFF1F6FEB),
            Color(0xFFF4A261),
            Color(0xFFF4A261),
          ],
          stops: [0, 0.5, 0.5, 1],
        ),
      ),
    );
  }
}
