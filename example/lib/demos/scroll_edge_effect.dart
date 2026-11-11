import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// CNScrollEdgeEffect: the iOS 26 scroll edge effect over a Flutter list,
/// at the top (under the status bar) and the bottom (under the floating
/// controls and the home indicator), soft or hard, and off for comparison.
///
/// The list runs under both edges. At rest at the top, the top effect is
/// gone, as in a native scroll view; scrolled, the rows under the status bar
/// are softened.
class ScrollEdgeEffectDemoPage extends StatefulWidget {
  const ScrollEdgeEffectDemoPage({super.key, this.autoCycle = false});

  /// Steps through rest, scrolled, hard and off, printing `CNB_SHOT <step>`.
  final bool autoCycle;

  @override
  State<ScrollEdgeEffectDemoPage> createState() =>
      _ScrollEdgeEffectDemoPageState();
}

const _tiles = [
  ('Ember', Color(0xFFE4572E), Color(0xFFFFC914)),
  ('Lagoon', Color(0xFF17BEBB), Color(0xFF2E86AB)),
  ('Orchid', Color(0xFF9B5DE5), Color(0xFFF15BB5)),
  ('Moss', Color(0xFF4F772D), Color(0xFF90A955)),
  ('Dusk', Color(0xFF22223B), Color(0xFF9A8C98)),
  ('Citrus', Color(0xFFF9C80E), Color(0xFFF86624)),
  ('Glacier', Color(0xFFCAF0F8), Color(0xFF0077B6)),
  ('Plum', Color(0xFF5F0F40), Color(0xFFE36414)),
];

class _ScrollEdgeEffectDemoPageState extends State<ScrollEdgeEffectDemoPage> {
  final ScrollController _controller = ScrollController();
  CNScrollEdgeStyle _style = CNScrollEdgeStyle.soft;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _run();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    Future<void> step(String tag, FutureOr<void> Function() action) async {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) debugPrint('CNB_SHOT $tag');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await step('rest', () {});
    await step('scrolled', () => _controller.jumpTo(260));
    await step('hard', () => setState(() => _style = CNScrollEdgeStyle.hard));
    await step('off', () => setState(() => _enabled = false));
    await step('end', () {
      setState(() {
        _enabled = true;
        _style = CNScrollEdgeStyle.soft;
      });
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          _TileList(
            controller: _controller,
            padding: EdgeInsets.fromLTRB(
              16,
              padding.top + 56,
              16,
              padding.bottom + 80,
            ),
          ),
          if (_enabled) ...[
            CNScrollEdgeEffect(
              edge: CNScrollEdge.top,
              height: padding.top + 44,
              style: _style,
              controller: _controller,
            ),
            CNScrollEdgeEffect(
              edge: CNScrollEdge.bottom,
              height: padding.bottom + 64,
              style: _style,
              controller: _controller,
            ),
          ],
          Positioned(
            left: 16,
            top: padding.top + 2,
            child: CNButton.icon(
              icon: const CNSymbol('chevron.left'),
              semanticLabel: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: padding.bottom + 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CNButton(
                  label: _style == CNScrollEdgeStyle.soft ? 'Soft' : 'Hard',
                  config: const CNButtonConfig(shrinkWrap: true),
                  onPressed: () => setState(
                    () => _style = _style == CNScrollEdgeStyle.soft
                        ? CNScrollEdgeStyle.hard
                        : CNScrollEdgeStyle.soft,
                  ),
                ),
                const SizedBox(width: 12),
                CNButton(
                  label: _enabled ? 'Effect on' : 'Effect off',
                  config: const CNButtonConfig(shrinkWrap: true),
                  onPressed: () => setState(() => _enabled = !_enabled),
                ),
                const SizedBox(width: 12),
                CNButton(
                  label: 'Tabs',
                  config: const CNButtonConfig(shrinkWrap: true),
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const ScrollEdgeEffectTabsDemoPage(),
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

class _TileList extends StatelessWidget {
  const _TileList({this.controller, required this.padding});

  final ScrollController? controller;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: 24,
      itemBuilder: (_, i) {
        final (name, a, b) = _tiles[i % _tiles.length];
        return Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(colors: [a, b]),
          ),
          alignment: Alignment.bottomLeft,
          child: Text(
            '$name ${i + 1}\nA gradient tile with text to soften',
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}

/// [CNTabScaffold] with `bottomScrollEdgeEffect: true`: the tiles scroll
/// under the tab bar and get the system scroll edge effect behind it. No
/// controller: the scaffold follows the body's scroll view.
class ScrollEdgeEffectTabsDemoPage extends StatefulWidget {
  const ScrollEdgeEffectTabsDemoPage({
    super.key,
    this.autoCycle = false,
    this.effect = true,
  });

  /// Whether the scaffold has its bottom scroll edge effect.
  final bool effect;

  /// Prints `CNB_SHOT tabs-rest`, scrolls, prints `CNB_SHOT tabs-scrolled`,
  /// scrolls to the end and prints `CNB_SHOT tabs-end`.
  final bool autoCycle;

  @override
  State<ScrollEdgeEffectTabsDemoPage> createState() =>
      _ScrollEdgeEffectTabsDemoPageState();
}

class _ScrollEdgeEffectTabsDemoPageState
    extends State<ScrollEdgeEffectTabsDemoPage> {
  int _tab = 0;
  final ScrollController _auto = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _run();
  }

  @override
  void dispose() {
    _auto.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    Future<void> shot(String tag) async {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) debugPrint('CNB_SHOT $tag');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }

    await Future<void>.delayed(const Duration(seconds: 2));
    await shot('tabs-scrolled');
    if (!mounted) return;
    _auto.jumpTo(_auto.position.maxScrollExtent);
    await shot('tabs-end');
  }

  @override
  Widget build(BuildContext context) {
    return CNTabScaffold(
      bottomScrollEdgeEffect: widget.effect,
      currentIndex: _tab,
      onTap: (i) => setState(() => _tab = i),
      items: const [
        CNTabBarItem(label: 'Tiles', icon: CNSymbol('square.grid.2x2')),
        CNTabBarItem(label: 'Back', icon: CNSymbol('chevron.left')),
      ],
      body: Builder(
        builder: (context) {
          if (_tab == 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).maybePop();
            });
          }
          final padding = MediaQuery.paddingOf(context);
          return _TileList(
            controller: widget.autoCycle ? _auto : null,
            padding: EdgeInsets.fromLTRB(
              16,
              padding.top + 16,
              16,
              padding.bottom + 16,
            ),
          );
        },
      ),
    );
  }
}
