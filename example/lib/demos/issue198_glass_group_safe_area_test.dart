import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Issue #198: a `CNGlassButtonGroup` in the window's safe-area inset is
/// drawn off-centre in its frame.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/198
/// Reported by @LucasLau00.
///
/// ### The claim
///
/// A vertical group in the right safe-area inset (a landscape side strip, or
/// the system strip on iPhone Duo) is drawn to the left of the frame Flutter
/// gives it, after the device rotates. A `CNButton.icon` in an identical
/// 44 pt slot above it stays centred. The button's SwiftUI host has
/// `safeAreaRegions = []` since #184; the group's host doesn't.
///
/// ### How this screen proves it
///
/// The reporter's page: a green strip as wide as the right inset (64 pt
/// without one) holds the button and the group, between two red lines that
/// mark the 44 pt slot. AUTO rotates the app (portrait, landscape left,
/// landscape right, landscape left, portrait, landscape left) and prints
/// `CNB_SHOT 198-<step>` after each.
///
///  * **Before:** on iPhone Duo (iOS 27.1) the group's glass sits 22 pt left
///    of the red lines wherever the right inset is 84 pt, in portrait and
///    landscape left; the button stays between them. iPhone 17 Pro's 62 pt
///    landscape inset (iOS 26.2) didn't show it.
///  * **After:** both stay centred between the lines after every rotation.
class Issue198GlassGroupSafeAreaTestPage extends StatefulWidget {
  /// Creates the #198 test page.
  const Issue198GlassGroupSafeAreaTestPage({super.key, this.autoCycle = false});

  /// Rotates the app through its steps, printing `CNB_SHOT`.
  final bool autoCycle;

  @override
  State<Issue198GlassGroupSafeAreaTestPage> createState() =>
      _Issue198GlassGroupSafeAreaTestPageState();
}

class _Issue198GlassGroupSafeAreaTestPageState
    extends State<Issue198GlassGroupSafeAreaTestPage> {
  static const double _size = 44;
  static const _steps = [
    ('portrait', DeviceOrientation.portraitUp),
    ('left', DeviceOrientation.landscapeLeft),
    ('right', DeviceOrientation.landscapeRight),
    ('left2', DeviceOrientation.landscapeLeft),
    ('portrait2', DeviceOrientation.portraitUp),
    ('left3', DeviceOrientation.landscapeLeft),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) unawaited(_run());
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    for (final (tag, orientation) in _steps) {
      if (!mounted) return;
      await SystemChrome.setPreferredOrientations([orientation]);
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return;
      final inset = MediaQuery.viewPaddingOf(context).right;
      debugPrint('CNB_SHOT 198-$tag inset=$inset');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).right;
    final stripWidth = inset > 0 ? inset : 64.0;
    final line = Container(width: 1, color: const Color(0xFFFF0000));
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#198 Group in the safe-area inset'),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: stripWidth,
          color: const Color(0x4034C759),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: _size,
                      child: CNButton.icon(
                        icon: const CNSymbol('arrow.backward', size: 18),
                        onPressed: () {},
                        config: const CNButtonConfig(
                          style: CNButtonStyle.glass,
                          width: _size,
                          minHeight: _size,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: _size,
                      height: 2 * _size + 3,
                      child: CNGlassButtonGroup(
                        axis: Axis.vertical,
                        spacing: 0,
                        buttons: [
                          for (final symbol in const [
                            'rectangle.compress.vertical',
                            'plus',
                          ])
                            CNButtonData.icon(
                              icon: CNSymbol(symbol, size: 18),
                              onPressed: () {},
                              config: const CNButtonDataConfig(
                                style: CNButtonStyle.glass,
                                width: _size,
                                minHeight: _size,
                                glassEffectUnionId: 'strip',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(left: 0, top: -12, bottom: -12, child: line),
                Positioned(left: _size - 1, top: -12, bottom: -12, child: line),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
