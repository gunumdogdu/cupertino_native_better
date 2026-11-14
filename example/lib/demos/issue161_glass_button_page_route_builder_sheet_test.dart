import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #161 reproduction: on a page hosted in a `PageRouteBuilder`, a
/// glass `CNButton` showed a square box around its glass while a sheet
/// package's sheet was open or held mid-drag.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/161
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// A page in a `PageRouteBuilder` transitions with any page route pushed over
/// it, and a sheet package's sheet route is a page route. So the sheet moved
/// the page's secondary animation as a page pushed over it does, and the
/// glass widgets took the sheet route's whole box (the whole screen) for
/// what covers them: their glow was cut all round, which left a box. Now a
/// sheet route the page transitions with counts as a modal, measured as its
/// sheet. `showCupertinoSheet` moves every page's secondary animation, so it
/// takes the same path.
///
/// A sheet route that is a page route is also offstage for the first frame
/// of its push, laid out open. That frame no longer counts as the open sheet
/// covering the widgets, which cut their glow for a frame or more as the
/// sheet came up, on any page.
///
/// ### How this screen proves it
///
/// **Open the page** pushes a page in a `PageRouteBuilder`, with glass
/// buttons in its header over a striped backdrop. From there, **Sheet
/// route** opens a sheet built like a sheet package's (a page route that
/// follows a drag on its grabber; drag it down and hold), and
/// **showCupertinoSheet** opens Flutter's. AUTO does both and prints
/// `CNB_SHOT 161-<step>`.
///
///  * **Bug:** while the sheet is held down part-way, a grey square shows
///    around each glass button, and the glow outside it is gone.
///  * **Fixed:** the buttons keep their glass and shadow; only the part of
///    the glow under the sheet is hidden.
class Issue161GlassButtonPageRouteBuilderSheetTestPage extends StatefulWidget {
  const Issue161GlassButtonPageRouteBuilderSheetTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Opens the page, then each sheet, printing `CNB_SHOT <step>`.
  final bool autoCycle;

  @override
  State<Issue161GlassButtonPageRouteBuilderSheetTestPage> createState() =>
      _Issue161GlassButtonPageRouteBuilderSheetTestPageState();
}

class _Issue161GlassButtonPageRouteBuilderSheetTestPageState
    extends State<Issue161GlassButtonPageRouteBuilderSheetTestPage> {
  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(auto: true));
    }
  }

  void _open({bool auto = false}) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => _HostPage(autoCycle: auto),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#161 PageRouteBuilder'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'The bug needs the page to be hosted in a PageRouteBuilder. '
                'Open it, then open a sheet and drag it down and hold. Bug: '
                'a square box around the glass buttons. Fixed: they keep '
                'their glass and shadow.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _open,
                child: const Text('Open the page'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HostPage extends StatefulWidget {
  const _HostPage({required this.autoCycle});

  final bool autoCycle;

  @override
  State<_HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<_HostPage> {
  int _heartTaps = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _run();
  }

  Future<void> _run() async {
    Future<void> shot(String tag, int afterMs) async {
      await Future<void>.delayed(Duration(milliseconds: afterMs));
      if (mounted) debugPrint('CNB_SHOT 161-$tag');
    }

    await shot('rest', 3000);
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final route = _SheetRoute();
    navigator.push(route);
    await shot('sheet-open', 1500);
    // A finger holding the sheet part-way down.
    for (final value in <double>[0.8, 0.6, 0.45]) {
      for (var i = 1; i <= 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        route.dragTo(route.value + (value - route.value) * i / 10);
      }
      await shot('sheet-held-${(value * 100).round()}', 1500);
    }
    route.release();
    await shot('sheet-released', 1200);
    navigator.pop();
    await shot('sheet-closed', 1200);
    if (!mounted) return;
    _showCupertinoSheet();
    await shot('cupertino-sheet-open', 1500);
    navigator.pop();
    await shot('cupertino-sheet-closed', 1200);
    debugPrint('CNB_SHOT 161-done');
  }

  void _showCupertinoSheet() {
    showCupertinoSheet<void>(
      context: context,
      scrollableBuilder: (context, _) => CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('showCupertinoSheet'),
        ),
        child: Center(
          child: CupertinoButton.filled(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        autoHideOnModal: false,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      CNButton.icon(
                        icon: const CNSymbol('heart', size: 17),
                        semanticLabel: 'Favourite',
                        autoHideOnModal: false,
                        onPressed: () => setState(() => _heartTaps++),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: CupertinoButton.filled(
                    onPressed: () => Navigator.of(context).push(_SheetRoute()),
                    child: const Text('Sheet route (drag it and hold)'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: CupertinoButton.filled(
                    onPressed: _showCupertinoSheet,
                    child: const Text('showCupertinoSheet'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '#161 · heart taps: $_heartTaps\n'
                    'This page is in a PageRouteBuilder. Bug: a square box '
                    'around the glass buttons while a sheet is held down. '
                    'Fixed: they keep their glass.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: CupertinoColors.white,
                    ),
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

/// A sheet built like a sheet package's (`modal_bottom_sheet`): a page
/// route whose page is the whole screen, with its sheet at the bottom
/// following a drag on its grabber, which sets the route's animation value
/// directly.
class _SheetRoute extends PageRoute<void> {
  _SheetRoute();

  /// How far up the sheet is: 1 open, 0 closed.
  double get value => controller!.value;

  /// Moves the sheet as a finger dragging it does.
  void dragTo(double value) => controller!.value = value.clamp(0.0, 1.0);

  /// Lets go: it springs back up.
  void release() => controller!.forward();

  @override
  Color? get barrierColor => const Color(0x33000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final height = MediaQuery.sizeOf(context).height * 0.6;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(animation),
        child: GestureDetector(
          onVerticalDragUpdate: (d) =>
              dragTo(controller!.value - d.primaryDelta! / height),
          onVerticalDragEnd: (_) {
            if (controller!.value < 0.4) {
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
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
                const Text(
                  'Drag down and hold',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
