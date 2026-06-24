import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Issue #37 reproduction.
///
/// Reporter setup: Material `Scaffold` + `AppBar` (or `SliverAppBar`) with a
/// `CNButton.icon` (a "bell") in the actions, AND a 4-item `CNTabBar`
/// (split: true) at the bottom. While a sheet animates open, the iOS 26
/// Liquid Glass halo of the `CNButton` in the app bar bleeds **through the
/// top of the sheet** as a square — visible for a fraction of a second, then
/// it "fixes" once the transition settles.
///
/// What to look for:
///   - Tap any of the four sheet buttons.
///   - During the open animation, watch the area BELOW the app bar (where
///     the bell icon sits) — a green/glassy rectangle should briefly bleed
///     through the sheet's top edge if the bug reproduces.
///   - Same drill with `SliverAppBar` (toggle below).
///
/// This mirrors the reporter's snippet as closely as possible: same widgets,
/// same flags (`split: true`, `splitSpacing: 0`, `iconSize: 18`, the plus tab
/// with no label, `CNTabBarRouteObserver` registered at the app root), so we
/// can reproduce / verify a fix in isolation.
class Issue37AppBarButtonHaloTest extends StatefulWidget {
  const Issue37AppBarButtonHaloTest({super.key});

  @override
  State<Issue37AppBarButtonHaloTest> createState() =>
      _Issue37AppBarButtonHaloTestState();
}

class _Issue37AppBarButtonHaloTestState
    extends State<Issue37AppBarButtonHaloTest> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  bool _useSliverAppBar = false;

  // ── Sheet openers ──────────────────────────────────────────────────────
  //
  // All three open ABOVE the app bar so the sheet's top edge crosses the bell
  // button vertically during the open animation — that's when the iOS 26
  // Liquid Glass halo of the bell can briefly bleed through the sheet.
  //
  // `showBottomSheet` (the persistent one) is intentionally NOT here: it
  // docks UNDER the app bar by design, so it can't reproduce the halo.

  void _showCupertinoSheet() {
    // Full-screen iOS 26 Cupertino sheet (rootNavigator → above everything).
    Navigator.of(context, rootNavigator: true).push(
      CupertinoSheetRoute<void>(
        builder: (ctx) => _SheetBody(
          title: 'showCupertinoSheet (full)',
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _showFullModalBottomSheet() {
    // Material modal, FULL screen — top edge animates from screen-bottom past
    // the bell on its way to the very top. useRootNavigator + useSafeArea:false
    // + explicit screen height = covers app bar AND status bar.
    final h = MediaQuery.of(context).size.height;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: false,
      builder: (ctx) => _SheetBody(
        title: 'showModalBottomSheet (100%)',
        height: h,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showTallModalBottomSheet() {
    // ~90% height — the top edge lands JUST under the bell when fully open,
    // so you can pause and inspect any static halo bleed after the animation
    // (vs. the full-screen variant where the halo only flashes mid-anim).
    final h = MediaQuery.of(context).size.height;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => _SheetBody(
        title: 'showModalBottomSheet (90%)',
        height: h * 0.9,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  // ── App bar variants ────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('#37 — AppBar'),
      actions: [
        // Reporter's exact widget: glass CNButton.icon('bell') in app bar.
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: CNButton.icon(
            icon: const CNSymbol('bell', size: 20),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      title: const Text('#37 — SliverAppBar'),
      pinned: true,
      floating: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: CNButton.icon(
            icon: const CNSymbol('bell', size: 20),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return CNTabBar(
      items: const [
        CNTabBarItem(
          label: 'Home',
          icon: CNSymbol('house'),
          activeIcon: CNSymbol('house.fill'),
        ),
        CNTabBarItem(
          label: 'Discover',
          icon: CNSymbol('magnifyingglass'),
          activeIcon: CNSymbol('magnifyingglass.fill'),
        ),
        CNTabBarItem(
          label: 'Sales',
          icon: CNSymbol('tag'),
          activeIcon: CNSymbol('tag.fill'),
        ),
        // The plus tab — no label, same icon for active (per reporter).
        CNTabBarItem(
          icon: CNSymbol('plus'),
          activeIcon: CNSymbol('plus'),
        ),
      ],
      iconSize: 18,
      split: true,
      splitSpacing: 0,
      currentIndex: _currentIndex,
      onTap: (i) => setState(() => _currentIndex = i),
    );
  }

  // ── Body content shared by both variants ────────────────────────────────

  List<Widget> _instructions() => const [
        SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Issue #37 repro — what to look for:\n\n'
            '1) HALO BLEED (primary): each sheet below opens ABOVE the app '
            'bar. As the sheet rises, watch the right side where the bell '
            'button sits. If the bug reproduces, a green/glassy rectangle '
            'briefly bleeds through the sheet during the open animation. '
            'The 90% variant lets you observe the top edge AFTER the '
            'animation settles.\n\n'
            '2) TAB BAR LABELS (secondary): close any sheet and look at the '
            'CNTabBar at the bottom. If the labels go blank until you tap '
            'each tab, that\'s a separate bug worth filing.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        SizedBox(height: 16),
      ];

  Widget _sheetButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          CupertinoButton.filled(
            onPressed: _showCupertinoSheet,
            child: const Text('showCupertinoSheet (full)'),
          ),
          CupertinoButton.filled(
            onPressed: _showFullModalBottomSheet,
            child: const Text('showModalBottomSheet (100%)'),
          ),
          CupertinoButton.filled(
            onPressed: _showTallModalBottomSheet,
            child: const Text('showModalBottomSheet (90%)'),
          ),
        ],
      ),
    );
  }

  Widget _appBarToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Expanded(child: Text('Use SliverAppBar variant')),
          Switch(
            value: _useSliverAppBar,
            onChanged: (v) => setState(() => _useSliverAppBar = v),
          ),
        ],
      ),
    );
  }

  // Filler so the SliverAppBar variant has something to scroll behind.
  Widget _filler({required Color color, required int count}) {
    return Container(
      color: color,
      height: 56,
      alignment: Alignment.center,
      child: Text('Row $count', style: const TextStyle(color: Colors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_useSliverAppBar) {
      return Scaffold(
        key: _scaffoldKey,
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverList(
              delegate: SliverChildListDelegate([
                ..._instructions(),
                _appBarToggle(),
                const SizedBox(height: 16),
                _sheetButtons(),
                const SizedBox(height: 16),
                for (var i = 1; i <= 12; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _filler(
                      color: Colors.indigo.shade300,
                      count: i,
                    ),
                  ),
                const SizedBox(height: 32),
              ]),
            ),
          ],
        ),
        bottomNavigationBar: _buildTabBar(),
        extendBody: true,
        resizeToAvoidBottomInset: false,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(),
      body: ListView(
        children: [
          ..._instructions(),
          _appBarToggle(),
          const SizedBox(height: 16),
          _sheetButtons(),
          const SizedBox(height: 24),
          for (var i = 1; i <= 12; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _filler(color: Colors.teal.shade300, count: i),
            ),
          const SizedBox(height: 32),
        ],
      ),
      bottomNavigationBar: _buildTabBar(),
      extendBody: true,
      resizeToAvoidBottomInset: false,
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.onClose,
    this.height = 320,
  });

  final String title;
  final VoidCallback onClose;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Watch the TOP edge of this sheet against the app-bar '
                  'CNButton (bell) above as the sheet animates open. A '
                  'rectangular glass halo briefly bleeding through means #37 '
                  'reproduces.',
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              CupertinoButton.filled(
                onPressed: onClose,
                child: const Text('Close'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
