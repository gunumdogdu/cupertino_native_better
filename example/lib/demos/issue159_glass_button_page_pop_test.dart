import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #159 reproduction: a glass `CNButton` in a page's header is flat
/// while a page pushed over it slides off (`Navigator.pop`), and its glass
/// and shadow snap back in one frame when the transition ends: the button
/// blinks every time you come back.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/159
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// While the host route animates, the glass was clipped to its bounds and
/// its shadow cleared (#29), so its glow couldn't draw over the page coming
/// in or going out. That left it flat for the whole transition. Now the
/// glass widgets hide only the part of their glow that the moving page
/// covers, measured after every frame by `CNTabBarRouteObserver`, and keep
/// their full glass everywhere else.
///
/// ### How this screen proves it
///
/// A glass close button in the header, over a striped backdrop. **Push a
/// page** pushes a `CupertinoPageRoute`; its **Pop back** button pops it, or
/// drag it back from the left edge and hold. AUTO pushes and pops twice and
/// prints `CNB_SHOT 159-<step>`.
///
///  * **Bug:** while the page slides off, the close button is a flat disc
///    with no shadow; when the pop ends, its glass and shadow pop back at
///    once.
///  * **Fixed:** the button keeps its glass and shadow while the page slides
///    over it, off it, and while the back gesture holds it; its glow stops
///    at the page's edge.
class Issue159GlassButtonPagePopTestPage extends StatefulWidget {
  const Issue159GlassButtonPagePopTestPage({super.key, this.autoCycle = false});

  /// Pushes and pops the page twice, printing `CNB_SHOT <step>`.
  final bool autoCycle;

  @override
  State<Issue159GlassButtonPagePopTestPage> createState() =>
      _Issue159GlassButtonPagePopTestPageState();
}

class _Issue159GlassButtonPagePopTestPageState
    extends State<Issue159GlassButtonPagePopTestPage> {
  int _closeTaps = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _run();
  }

  Future<void> _run() async {
    Future<void> shot(String tag, int afterMs) async {
      await Future<void>.delayed(Duration(milliseconds: afterMs));
      if (mounted) debugPrint('CNB_SHOT 159-$tag');
    }

    await shot('rest', 4000);
    for (var i = 1; i <= 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      final navigator = Navigator.of(context);
      _push();
      await shot('pushed-$i', 1200);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      navigator.pop();
      await shot('popping-$i', 120);
      await shot('popped-$i', 1200);
    }
    debugPrint('CNB_SHOT 159-done');
  }

  void _push() {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => const _PushedPage()));
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
                    onPressed: _push,
                    child: const Text('Push a page'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '#159 · close taps: $_closeTaps\n'
                    'Push the page, then pop it or drag it back. Bug: the '
                    'close button is flat while the page slides off and '
                    'blinks back. Fixed: it keeps its glass.',
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

class _PushedPage extends StatelessWidget {
  const _PushedPage();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Pushed page')),
      child: Center(
        child: CupertinoButton.filled(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Pop back'),
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
