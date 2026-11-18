import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter/services.dart';

/// Issue #170: the iOS 26 `CNSearchBar` has no Liquid Glass shadow, and no
/// way to open with text in it.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/170
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// 1. The bar's glass casts no shadow, so on a white page the capsule
///    nearly disappears. A plain SwiftUI view with the same
///    `.glassEffect(.regular, in: .capsule)` has the soft shadow. The glass
///    sat in a background clipped to the capsule (`.clipShape`), and the
///    platform view in a capsule `ClipRRect`: both cut the shadow away. Now
///    the glass is applied to the bar with no clip, and the platform view is
///    not clipped, so the shadow draws past the bar's box. The box keeps its
///    size. `showShadow: false` keeps the flat capsule.
/// 2. There is no `initialText`, and `CNSearchBarController.setText` does
///    nothing until the native view exists. Now `initialText` opens the bar
///    with text without calling `onChanged`, and a `setText` made before the
///    view exists is applied once it does (and reported, as `setText` is).
///
/// ### How this screen proves it
///
/// A white page, as in the report. In debug builds on iOS, rows B and D are
/// search bars written in plain SwiftUI in the example's Runner (no plugin
/// code): B applies the glass to the bar with no clip, D clips it as
/// `CNSearchBar` did. They have none of the plugin's halo containment, so
/// B's shadow shows over a page pushed over this one; `CNSearchBar`'s
/// doesn't.
///
///  * **Shadow. Bug:** A is flat and looks like D. **Fixed:** A has the same
///    soft shadow as B, and C (`showShadow: false`) looks like D. The
///    collapsed bar E casts it too.
///  * **Initial text. Bug:** no `initialText` (the screen would not build).
///    **Fixed:** F shows "Toyota Land Cruiser" and its `onChanged` count
///    stays 0; G opens with "Hilux" when it expands.
///  * **Queued setText. Bug:** H, mounted with `setText('Land Cruiser 300')`
///    in the same frame, stays empty. **Fixed:** H shows the text, and its
///    `onChanged` ran once with it.
///
/// AUTO prints `CNB_STATE` lines (the Flutter size of A and C, the
/// `onChanged` calls) and `CNB_SHOT 170-<step>` for rest, queued and
/// expanded, then pushes a page over the bars in slow motion (push, popped):
/// the glass under a moving page must show no box.
class Issue170SearchBarGlassShadowTestPage extends StatefulWidget {
  /// Creates the #170 test page.
  const Issue170SearchBarGlassShadowTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Mounts H, opens G and prints the state and `CNB_SHOT` lines.
  final bool autoCycle;

  @override
  State<Issue170SearchBarGlassShadowTestPage> createState() =>
      _Issue170SearchBarGlassShadowTestPageState();
}

class _Issue170SearchBarGlassShadowTestPageState
    extends State<Issue170SearchBarGlassShadowTestPage> {
  final _shadowKey = GlobalKey();
  final _flatKey = GlobalKey();
  final _expandable = CNSearchBarController();
  final _queued = CNSearchBarController();
  final _initialCalls = <String>[];
  final _queuedCalls = <String>[];
  bool _queuedMounted = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _auto();
  }

  Future<void> _auto() async {
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    debugPrint(
      'CNB_STATE 170 A=${_sizeOf(_shadowKey)} C=${_sizeOf(_flatKey)} '
      'F.onChanged=${_initialCalls.length}',
    );
    debugPrint('CNB_SHOT 170-rest');
    await Future<void>.delayed(const Duration(seconds: 1));
    _mountQueued();
    // The text is applied once H's native view exists, which takes longer
    // on a busy machine: wait for it, 10 s at most.
    for (var i = 0; i < 50 && _queuedCalls.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    debugPrint('CNB_STATE 170 H.onChanged=$_queuedCalls');
    debugPrint('CNB_SHOT 170-queued');
    await Future<void>.delayed(const Duration(seconds: 1));
    await _expandable.expand();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    debugPrint(
      'CNB_STATE 170 F.onChanged=${_initialCalls.length} '
      'A=${_sizeOf(_shadowKey)}',
    );
    debugPrint('CNB_SHOT 170-expanded');
    await _pushOverInSlowMotion();
    debugPrint('CNB_DONE');
  }

  /// Pushes a page over this one in slow motion and shoots it part-way:
  /// the glass under a moving page, which without `CNTabBarRouteObserver`
  /// is clipped to its bounds (no box may show at the capsules' corners).
  Future<void> _pushOverInSlowMotion() async {
    timeDilation = 10;
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const CupertinoPageScaffold(
          backgroundColor: CupertinoColors.systemGroupedBackground,
          child: Center(child: Text('Pushed page')),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    debugPrint('CNB_SHOT 170-push');
    await Future<void>.delayed(const Duration(seconds: 6));
    timeDilation = 1;
    if (mounted) Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(seconds: 1));
    debugPrint('CNB_SHOT 170-popped');
  }

  String _sizeOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return '?';
    return '${box.size.width.toStringAsFixed(1)}x'
        '${box.size.height.toStringAsFixed(1)}';
  }

  /// Mounts H and sets its text in the same frame, before its native view
  /// exists.
  void _mountQueued() {
    setState(() {
      _queuedMounted = !_queuedMounted;
      _queuedCalls.clear();
    });
    if (_queuedMounted) _queued.setText('Land Cruiser 300');
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
    ),
  );

  Widget _reference({required bool clipped}) => SizedBox(
    height: 36,
    child: UiKitView(
      viewType: 'CNBReferenceSearchBar',
      creationParams: <String, Object>{'clipped': clipped},
      creationParamsCodec: const StandardMessageCodec(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final reference = kDebugMode && defaultTargetPlatform == TargetPlatform.iOS;
    const status = TextStyle(fontSize: 13, color: CupertinoColors.black);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('#170 Search bar shadow'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _mountQueued,
          child: Text(_queuedMounted ? 'Remove H' : 'Mount H'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            _label('A. CNSearchBar (fixed: soft shadow, like B)'),
            CNSearchBar(
              key: _shadowKey,
              expandable: false,
              showCancelButton: false,
            ),
            if (reference) ...[
              _label('B. SwiftUI reference: glass on the bar, no clip'),
              _reference(clipped: false),
            ],
            _label('C. CNSearchBar(showShadow: false), like D'),
            CNSearchBar(
              key: _flatKey,
              expandable: false,
              showCancelButton: false,
              showShadow: false,
            ),
            if (reference) ...[
              _label('D. SwiftUI reference: glass background + clipShape'),
              _reference(clipped: true),
            ],
            _label('E. Expandable, collapsed'),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: CNSearchBar(),
            ),
            _label('F. initialText: "Toyota Land Cruiser"'),
            CNSearchBar(
              expandable: false,
              showCancelButton: false,
              initialText: 'Toyota Land Cruiser',
              onChanged: (t) => setState(() => _initialCalls.add(t)),
            ),
            const SizedBox(height: 6),
            Text(
              'F onChanged calls: ${_initialCalls.length} '
              '(fixed: 0 until you type)',
              style: status,
            ),
            _label('G. Expandable, initialText: "Hilux"'),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CNSearchBar(
                controller: _expandable,
                initialText: 'Hilux',
                showCancelButton: false,
              ),
            ),
            _label('H. setText right after it is built'),
            if (_queuedMounted)
              CNSearchBar(
                controller: _queued,
                expandable: false,
                showCancelButton: false,
                onChanged: (t) => setState(() => _queuedCalls.add(t)),
              )
            else
              const SizedBox(
                height: 36,
                child: Center(child: Text('Tap "Mount H"')),
              ),
            const SizedBox(height: 6),
            Text(
              'H onChanged: $_queuedCalls (fixed: [Land Cruiser 300])',
              style: status,
            ),
          ],
        ),
      ),
    );
  }
}
