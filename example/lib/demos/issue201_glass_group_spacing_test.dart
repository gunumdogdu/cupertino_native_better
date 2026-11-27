import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #201: `CNGlassButtonGroup.spacingForGlass` is ignored for a
/// horizontal group of 2+ buttons.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/201
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// The native view clamps `spacingForGlass` (the `GlassEffectContainer`
/// blend distance) to at least 80 pt for a horizontal group of 2+ buttons,
/// so two buttons 14 pt apart always merge into one shape, even with
/// `spacingForGlass: 10`.
///
/// ### How this screen proves it
///
/// Six groups of the same two 44 pt icon buttons, one per row, labelled
/// with their `spacing` and `spacingForGlass`:
///
///  * `8 / default` and `8 / 40` (the value the example and many apps pass)
///    and `8 / 80`: merged bars. They show whether 40 looks different from
///    the 80 the clamp gives today.
///  * `14 / 10` and `14 / 0`: the buttons are farther apart than the blend
///    distance, so they should be two capsules.
///  * `4 / 10`: closer than the blend distance, so one shape.
///  * The last row stays mounted while its `spacing` changes: 14, then 4,
///    then 14 again, with `spacingForGlass: 10`. Before, the native group
///    kept the spacing it was created with.
///
/// AUTO prints `CNB_SHOT 201-<step>` with the groups up and after each
/// change of the last row.
class Issue201GlassGroupSpacingTestPage extends StatefulWidget {
  /// Creates the #201 test page.
  const Issue201GlassGroupSpacingTestPage({super.key, this.autoCycle = false});

  /// Changes the last row's spacing, printing `CNB_SHOT`.
  final bool autoCycle;

  @override
  State<Issue201GlassGroupSpacingTestPage> createState() =>
      _Issue201GlassGroupSpacingTestPageState();
}

class _Issue201GlassGroupSpacingTestPageState
    extends State<Issue201GlassGroupSpacingTestPage> {
  static const _rows = <(double, double?)>[
    (8, null),
    (8, 40),
    (8, 80),
    (14, 10),
    (14, 0),
    (4, 10),
  ];

  double _live = 14;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) unawaited(_run());
  }

  Future<void> _run() async {
    Future<void> step(String tag, double live) async {
      setState(() => _live = live);
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      if (mounted) debugPrint('CNB_SHOT 201-$tag');
      await Future<void>.delayed(const Duration(milliseconds: 1000));
    }

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await step('apart', 14);
    await step('closer', 4);
    await step('apart2', 14);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#201 spacingForGlass'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            for (final (spacing, glass) in [..._rows, (_live, 10.0)])
              Container(
                height: 84,
                margin: const EdgeInsets.only(bottom: 8),
                // Stripes behind the glass, so its outline shows.
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFC46B), Color(0xFF6BB8FF)],
                    stops: [0.5, 0.5],
                    tileMode: TileMode.repeated,
                    end: Alignment(-0.9, 0),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Text(
                          'spacing ${spacing.toInt()}\n'
                          'glass ${glass?.toInt() ?? 'default'}',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                    CNGlassButtonGroup(
                      spacing: spacing,
                      spacingForGlass: glass,
                      buttons: [
                        CNButtonData.icon(
                          icon: const CNSymbol('square.and.arrow.up', size: 18),
                          onPressed: () {},
                        ),
                        CNButtonData.icon(
                          icon: const CNSymbol('heart', size: 18),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
