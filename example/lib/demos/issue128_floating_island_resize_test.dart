import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #128 reproduction: `CNFloatingIsland` size, corner radius and tint
/// changes after creation never reach the native glass (iOS 26+).
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/128
/// Reported by @cogwheel0.
///
/// ### The claim
///
/// The sizes (`collapsedHeight`, `collapsedWidth`, `expandedHeight`,
/// `expandedWidth`), `cornerRadius` and `tint` go to the native view only in
/// its creation parameters. `didUpdateWidget` forwards `isExpanded` and
/// `animationDuration` and nothing else, so the Liquid Glass keeps the values
/// it was created with while the Flutter content is laid out for the new
/// ones.
///
/// ### How this screen proves it
///
/// The island starts expanded at 140 pt. Its Flutter content is a box with a
/// red outline drawn exactly where the glass should end, labelled with the
/// size the widget was given.
///
///  * **expandedHeight 180**: the red outline grows to 180 pt.
///    **Bug:** the glass stays at 140 pt; the outline runs past its bottom
///    edge. **Fixed:** the glass grows with the outline and ends on it.
///  * **cornerRadius 8** (collapse the island first: the expanded island
///    always uses 24): **Bug:** the collapsed pill stays round.
///    **Fixed:** it gets 8 pt corners.
///  * **Tint orange**: **Bug:** the glass stays untinted. **Fixed:** it
///    turns orange.
///  * **collapsedWidth 240** (collapsed): **Bug:** the pill stays 160 pt
///    wide inside the wider outline. **Fixed:** it widens to the outline.
///  * **Expanded off** (found while checking it): `isExpanded` set by the
///    app does not reach the native view either; only the controller's
///    `expand()`/`collapse()` do. **Bug:** the outline collapses to the
///    pill, the glass stays expanded. **Fixed:** the glass collapses with
///    it.
///  * **Any Expanded flip** (found too): the screen mirrors
///    `onExpandStateChanged` with a plain `setState`. **Bug:** a red screen
///    ("setState() called during build"), as the island reported the
///    change during this page's build. **Fixed:** no error.
///
/// Changing back must work the same way. The glass never blinks: a fix must
/// not recreate the platform view.
///
/// [autoCycle] runs the steps on its own and prints `CNB_SHOT <step>` after
/// each, for simulator screenshots.
class Issue128FloatingIslandResizeTestPage extends StatefulWidget {
  const Issue128FloatingIslandResizeTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Flips the switches one after another, for simulator screenshots.
  final bool autoCycle;

  @override
  State<Issue128FloatingIslandResizeTestPage> createState() =>
      _Issue128FloatingIslandResizeTestPageState();
}

class _Issue128FloatingIslandResizeTestPageState
    extends State<Issue128FloatingIslandResizeTestPage> {
  static const double _expandedWidth = 300;
  static const double _collapsedHeight = 44;

  bool _expanded = true;
  bool _tall = false;
  bool _wide = false;
  bool _square = false;
  bool _tinted = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _runSteps();
  }

  Future<void> _runSteps() async {
    final steps = <(String, VoidCallback)>[
      ('initial', () {}),
      ('tall', () => _tall = true),
      ('tint', () => _tinted = true),
      ('collapsed', () => _expanded = false),
      ('square', () => _square = true),
      ('wide', () => _wide = true),
    ];
    await Future<void>.delayed(const Duration(seconds: 3));
    for (final (name, change) in steps) {
      if (!mounted) return;
      setState(change);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      debugPrint('CNB_SHOT 128-$name');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
  }

  double get _expandedHeight => _tall ? 180 : 140;
  double get _collapsedWidth => _wide ? 240 : 160;

  @override
  Widget build(BuildContext context) {
    final width = _expanded ? _expandedWidth : _collapsedWidth;
    final height = _expanded ? _expandedHeight : _collapsedHeight;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#128: FloatingIsland resize'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: <Widget>[
            Container(
              height: 230,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF1C7ED6), Color(0xFF7048E8)],
                ),
              ),
              child: CNFloatingIsland(
                isExpanded: _expanded,
                collapsedHeight: _collapsedHeight,
                collapsedWidth: _collapsedWidth,
                expandedHeight: _expandedHeight,
                expandedWidth: _expandedWidth,
                cornerRadius: _square ? 8 : null,
                tint: _tinted ? const Color(0xFFFF8A00) : null,
                margin: const EdgeInsets.all(16),
                // Mirrors the island's state with a plain setState, the
                // obvious way to write it. Before the fix this asserted (red
                // screen) when the switch changed isExpanded, as the island
                // reported the change during this page's own build.
                onExpandStateChanged: (expanded) =>
                    setState(() => _expanded = expanded),
                // The content fills the glass exactly, outline included: the
                // collapsed content has no padding, the expanded content sits
                // inside the island's 16 pt padding.
                collapsed: _Outline(
                  width: width,
                  height: height,
                  radius: _square ? 8 : _collapsedHeight / 2,
                  label: '${width.toInt()} × ${height.toInt()}',
                ),
                expanded: _Outline(
                  width: width - 32,
                  height: height - 32,
                  inset: 16,
                  radius: 24,
                  label: '${width.toInt()} × ${height.toInt()}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Switch(
              'Expanded',
              _expanded,
              (v) => setState(() => _expanded = v),
            ),
            _Switch(
              'expandedHeight 180 (else 140)',
              _tall,
              (v) => setState(() => _tall = v),
            ),
            _Switch(
              'collapsedWidth 240 (else 160)',
              _wide,
              (v) => setState(() => _wide = v),
            ),
            _Switch(
              'cornerRadius 8 (else round)',
              _square,
              (v) => setState(() => _square = v),
            ),
            _Switch('Tint orange', _tinted, (v) => setState(() => _tinted = v)),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Bug: the glass keeps the size, corners and tint it was '
                'created with; the red outline (where the glass should end) '
                'runs past it or leaves a gap.\n'
                'Fixed: the glass follows every switch and ends on the red '
                'outline, without blinking.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A red outline the size the glass should be, drawn by Flutter.
class _Outline extends StatelessWidget {
  const _Outline({
    required this.width,
    required this.height,
    required this.label,
    required this.radius,
    this.inset = 0,
  });

  final double width;
  final double height;
  final String label;

  /// The corner radius the glass should have.
  final double radius;

  /// How far the island's own padding moves this box in from the glass edge.
  final double inset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OverflowBox(
        maxWidth: width + inset * 2,
        maxHeight: height + inset * 2,
        child: Container(
          width: width + inset * 2,
          height: height + inset * 2,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFFF2D55), width: 2),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch(this.label, this.value, this.onChanged);

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
