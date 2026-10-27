import 'dart:math' as math;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals;

/// iPhone Duo showcase (issue #102).
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/102
///
/// One page that reacts to every pose of a foldable iPhone, built only from
/// this package's public API:
///
///  * [CNTabScaffold] puts the tabs where the system would: a bottom
///    [CNTabBar] on the inner display in portrait, a [CNTabRail] in the
///    vertical-bar column on the outer display and in landscape, and — with
///    the *Sidebar* option — a sidebar on the open inner display.
///  * [CNFoldableScope] / [CNFoldable] supply the hinge angle and status, the
///    vertical-bar side and the fold and camera regions.
///  * **Hinge** draws the device opening at the live angle.
///  * **Studio** splits at the fold: artwork above and controls below in the
///    tabletop pose, a list beside a detail in the book pose.
///  * **Gallery** is an even-numbered grid that reflows when unfolded.
///  * **Options** overlays the reserved regions and switches the sidebar.
///
/// On anything but an iPhone Duo running iOS 27.1 the page still works: the
/// readouts say so and the scaffold keeps a bottom tab bar.
class IPhoneDuoDemoPage extends StatelessWidget {
  const IPhoneDuoDemoPage({
    super.key,
    this.initialTab = 0,
    this.initialSidebar = false,
  });

  /// Tab to open on. Used by `lib/duo_probe_entry.dart` for recordings.
  final int initialTab;

  /// Starting value of the *Sidebar on wide screens* option.
  final bool initialSidebar;

  @override
  Widget build(BuildContext context) {
    return CNFoldableScope(
      child: _DuoShowcase(
        initialTab: initialTab,
        initialSidebar: initialSidebar,
      ),
    );
  }
}

class _DuoShowcase extends StatefulWidget {
  const _DuoShowcase({required this.initialTab, required this.initialSidebar});

  final int initialTab;
  final bool initialSidebar;

  @override
  State<_DuoShowcase> createState() => _DuoShowcaseState();
}

class _DuoShowcaseState extends State<_DuoShowcase> {
  late int _tab = widget.initialTab;
  bool _showRegions = false;
  late bool _sidebar = widget.initialSidebar;
  int _accent = 0;

  static const List<Color> _accents = <Color>[
    CupertinoColors.systemIndigo,
    CupertinoColors.systemPink,
    CupertinoColors.systemTeal,
    CupertinoColors.systemOrange,
  ];

  static const List<CNTabBarItem> _items = <CNTabBarItem>[
    CNTabBarItem(
      label: 'Hinge',
      icon: CNSymbol('book'),
      activeIcon: CNSymbol('book.fill'),
    ),
    CNTabBarItem(
      label: 'Studio',
      icon: CNSymbol('music.note.list'),
      activeIcon: CNSymbol('music.note.list'),
      badge: '2',
    ),
    CNTabBarItem(
      label: 'Gallery',
      icon: CNSymbol('square.grid.2x2'),
      activeIcon: CNSymbol('square.grid.2x2.fill'),
    ),
    CNTabBarItem(
      label: 'Options',
      icon: CNSymbol('slider.horizontal.3'),
      activeIcon: CNSymbol('slider.horizontal.3'),
    ),
  ];

  Color get _tint => _accents[_accent];

  @override
  Widget build(BuildContext context) {
    final foldable = CNFoldable.of(context);
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(primaryColor: _tint),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CNTabScaffold(
              items: _items,
              currentIndex: _tab,
              onTap: (i) => setState(() => _tab = i),
              tint: _tint,
              sidebarOnWideScreens: _sidebar,
              backgroundColor: CupertinoColors.systemGroupedBackground
                  .resolveFrom(context),
              body: IndexedStack(
                index: _tab,
                children: <Widget>[
                  _HingePage(foldable: foldable, tint: _tint),
                  _StudioPage(foldable: foldable, tint: _tint),
                  _GalleryPage(tint: _tint),
                  _OptionsPage(
                    showRegions: _showRegions,
                    sidebar: _sidebar,
                    accent: _accent,
                    accents: _accents,
                    onShowRegions: (v) => setState(() => _showRegions = v),
                    onSidebar: (v) => setState(() => _sidebar = v),
                    onAccent: (i) => setState(() => _accent = i),
                  ),
                ],
              ),
            ),
          ),
          if (_showRegions)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _RegionsPainter(foldable.regions, _tint),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

String _poseName(CNFoldableState s) {
  final hinge = s.hinge;
  if (hinge == null) return s.isSupported ? 'No hinge' : 'Not available';
  switch (hinge.status) {
    case CNHingeStatus.closed:
      return 'Closed';
    case CNHingeStatus.fullyOpen:
      return 'Open';
    case CNHingeStatus.partiallyOpen:
      final fold = s.activeFold;
      if (fold == null) return 'Partially open';
      return fold.isHorizontal ? 'Tabletop' : 'Book';
    case CNHingeStatus.unknown:
      return 'Unknown';
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            // Large titles stay large but cap their growth, like iOS large
            // titles, so they do not break mid-word at accessibility sizes.
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.5),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout(this.symbol, this.label, this.value, this.tint);

  final String symbol;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          CNIcon(symbol: CNSymbol(symbol, size: 18, color: tint), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 16,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hinge
// ---------------------------------------------------------------------------

class _HingePage extends StatelessWidget {
  const _HingePage({required this.foldable, required this.tint});

  final CNFoldableState foldable;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final hinge = foldable.hinge;
    final fold = foldable.regions
        .where((r) => r.kind == CNReservedRegionKind.division)
        .firstOrNull;
    final camera = foldable.regions
        .where((r) => r.kind == CNReservedRegionKind.occlusion)
        .firstOrNull;

    String rect(Rect r) =>
        '${r.width.round()}×${r.height.round()} at '
        '${r.left.round()},${r.top.round()}';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: <Widget>[
          const _PageTitle('Hinge', 'Live from UIHingeInteraction'),
          _Card(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
            child: Column(
              children: <Widget>[
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: hinge?.angle ?? math.pi),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (context, angle, _) => SizedBox(
                    height: 150,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _HingePainter(
                        angle: angle,
                        tint: tint,
                        track: CupertinoColors.systemFill.resolveFrom(context),
                        ink: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  hinge == null ? '—' : '${hinge.degrees.round()}°',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                Text(
                  _poseName(foldable),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: tint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: <Widget>[
                _Readout(
                  'sidebar.right',
                  'Vertical bar',
                  switch (foldable.verticalBarSide) {
                    CNVerticalBarSide.none => 'None',
                    CNVerticalBarSide.left => 'Left edge',
                    CNVerticalBarSide.right => 'Right edge',
                  },
                  tint,
                ),
                _Readout(
                  'line.diagonal',
                  'Fold',
                  fold == null
                      ? 'None'
                      : '${fold.isActive ? 'Active' : 'Inactive'} · '
                            '${rect(fold.frame)}',
                  tint,
                ),
                _Readout(
                  'camera',
                  'Camera',
                  camera == null ? 'None' : rect(camera.frame),
                  tint,
                ),
                _Readout(
                  'rectangle.dashed',
                  'Screen',
                  '${MediaQuery.sizeOf(context).width.round()}×'
                      '${MediaQuery.sizeOf(context).height.round()} pt',
                  tint,
                ),
              ],
            ),
          ),
          if (!foldable.isSupported) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Foldable APIs need iOS 27.1 and a build with Xcode 27.1. '
              'Run this page on the iPhone Duo simulator.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A side view of the device: one panel fixed, the other opened by [angle]
/// around the hinge, over a 0–180° track.
class _HingePainter extends CustomPainter {
  _HingePainter({
    required this.angle,
    required this.tint,
    required this.track,
    required this.ink,
  });

  final double angle;
  final Color tint;
  final Color track;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final hinge = Offset(size.width / 2, size.height - 12);
    final length = math.min(size.width / 2 - 24, size.height - 30);
    final arcRect = Rect.fromCircle(center: hinge, radius: length * 0.62);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, math.pi, math.pi, false, trackPaint);

    final progress = Paint()
      ..color = tint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, math.pi, angle.clamp(0, math.pi), false, progress);

    final panel = Paint()
      ..color = ink
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    // Fixed panel lies flat to the left; the moving panel opens clockwise
    // from it by `angle` (0 = on top of it, π = flat to the right).
    canvas.drawLine(hinge, hinge + Offset(-length, 0), panel);
    // Direction π + angle: up over the top as it opens, flat right at π.
    final a = angle.clamp(0, math.pi).toDouble();
    canvas.drawLine(
      hinge,
      hinge + Offset(-math.cos(a) * length, -math.sin(a) * length),
      panel..color = tint,
    );
    canvas.drawCircle(hinge, 7, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_HingePainter old) =>
      old.angle != angle ||
      old.tint != tint ||
      old.track != track ||
      old.ink != ink;
}

// ---------------------------------------------------------------------------
// Studio — splits at the fold
// ---------------------------------------------------------------------------

class _StudioPage extends StatefulWidget {
  const _StudioPage({required this.foldable, required this.tint});

  final CNFoldableState foldable;
  final Color tint;

  @override
  State<_StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<_StudioPage> {
  double _progress = 0.38;
  bool _playing = true;
  int _mode = 0;
  int _track = 0;

  static const List<(String, String, List<Color>)> _tracks =
      <(String, String, List<Color>)>[
        (
          'Glass Horizon',
          'Liquid Ensemble',
          <Color>[Color(0xFF5B5BD6), Color(0xFFE05297)],
        ),
        (
          'Fold Lines',
          'The Hinges',
          <Color>[Color(0xFF0E9F9F), Color(0xFF3B6FE0)],
        ),
        (
          'Two Screens',
          'Duo Session',
          <Color>[Color(0xFFF08A24), Color(0xFFD9365E)],
        ),
        (
          'Vertical Bar',
          'Status Line',
          <Color>[Color(0xFF7A3FE0), Color(0xFF1FA2C9)],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final fold = widget.foldable.activeFold;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The fold is in the Flutter view's coordinates. CNTabScaffold pins
        // the body to the top and right edges, so the only offset is a
        // sidebar's width on the left: the view's width minus the body's.
        final view = View.of(context);
        final viewWidth = view.physicalSize.width / view.devicePixelRatio;
        final origin = Offset(viewWidth - MediaQuery.sizeOf(context).width, 0);
        var local = fold?.frame.shift(-origin);
        // While the device rotates, the fold can briefly arrive in the old
        // orientation's coordinates. Split only when it lies inside the page,
        // with room on both sides.
        if (local != null) {
          final page = Offset.zero & constraints.biggest;
          final room = fold!.isHorizontal
              ? local.top >= 120 && local.bottom <= page.bottom - 120
              : local.left >= 160 && local.right <= page.right - 160;
          if (!room) local = null;
        }

        if (local != null && fold!.isHorizontal) {
          // Tabletop: watch above the fold, control below it.
          return Column(
            children: <Widget>[
              SizedBox(
                height: local.top,
                child: SafeArea(bottom: false, child: _artwork(compact: true)),
              ),
              SizedBox(height: local.height),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 12),
                    child: _controls(),
                  ),
                ),
              ),
            ],
          );
        }
        if (local != null && !fold!.isHorizontal) {
          // Book: list on the left page, the track on the right page.
          return Row(
            children: <Widget>[
              SizedBox(
                width: local.left,
                child: SafeArea(right: false, child: _trackList()),
              ),
              SizedBox(width: local.width),
              Expanded(
                child: SafeArea(
                  left: false,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      _artwork(compact: false),
                      const SizedBox(height: 16),
                      _controls(),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: <Widget>[
              const _PageTitle('Studio', 'Splits at the fold'),
              _artwork(compact: false),
              const SizedBox(height: 16),
              _controls(),
              const SizedBox(height: 16),
              _Card(padding: EdgeInsets.zero, child: _trackList(shrink: true)),
            ],
          ),
        );
      },
    );
  }

  Widget _artwork({required bool compact}) {
    final (title, artist, colors) = _tracks[_track];
    return Padding(
      padding: EdgeInsets.all(compact ? 16 : 0),
      child: AspectRatio(
        aspectRatio: compact ? 16 / 9 : 1.25,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: LiquidGlassContainer(
                  config: const LiquidGlassConfig(
                    effect: CNGlassEffect.regular,
                    shape: CNGlassEffectShape.rect,
                    cornerRadius: 20,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.white,
                          ),
                        ),
                        Text(
                          artist,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xDDFFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CNSlider(
            value: _progress,
            semanticLabel: 'Playback position',
            onChanged: (v) => setState(() => _progress = v),
            color: widget.tint,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CNButton.icon(
                icon: const CNSymbol('backward.fill', size: 20),
                semanticLabel: 'Previous track',
                onPressed: () => setState(
                  () => _track = (_track + _tracks.length - 1) % _tracks.length,
                ),
              ),
              const SizedBox(width: 18),
              CNButton.icon(
                icon: CNSymbol(_playing ? 'pause.fill' : 'play.fill', size: 26),
                semanticLabel: _playing ? 'Pause' : 'Play',
                config: const CNButtonConfig(
                  style: CNButtonStyle.prominentGlass,
                ),
                tint: widget.tint,
                onPressed: () => setState(() => _playing = !_playing),
              ),
              const SizedBox(width: 18),
              CNButton.icon(
                icon: const CNSymbol('forward.fill', size: 20),
                semanticLabel: 'Next track',
                onPressed: () =>
                    setState(() => _track = (_track + 1) % _tracks.length),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CNSegmentedControl(
            labels: const <String>['Lyrics', 'Queue', 'Devices'],
            selectedIndex: _mode,
            onValueChanged: (i) => setState(() => _mode = i),
          ),
        ],
      ),
    );
  }

  Widget _trackList({bool shrink = false}) {
    return ListView.builder(
      shrinkWrap: shrink,
      physics: shrink ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.symmetric(vertical: shrink ? 6 : 16),
      itemCount: _tracks.length,
      itemBuilder: (context, i) {
        final (title, artist, colors) = _tracks[i];
        final selected = i == _track;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _track = i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: colors),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? widget.tint
                              : CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                      Text(
                        artist,
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Gallery — an even grid that reflows
// ---------------------------------------------------------------------------

class _GalleryPage extends StatelessWidget {
  const _GalleryPage({required this.tint});

  final Color tint;

  static const List<List<Color>> _palette = <List<Color>>[
    <Color>[Color(0xFF5B5BD6), Color(0xFF8E6CF0)],
    <Color>[Color(0xFFE05297), Color(0xFFF59E6C)],
    <Color>[Color(0xFF0E9F9F), Color(0xFF5BD6A6)],
    <Color>[Color(0xFF3B6FE0), Color(0xFF63B3F2)],
    <Color>[Color(0xFFF08A24), Color(0xFFF7C948)],
    <Color>[Color(0xFF7A3FE0), Color(0xFFE05297)],
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Even column counts, so a centred fold always falls between columns.
          final columns = constraints.maxWidth >= 600 ? 4 : 2;
          return CustomScrollView(
            slivers: <Widget>[
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _PageTitle('Gallery', 'An even grid that reflows'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid.builder(
                  itemCount: 24,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemBuilder: (context, i) {
                    final colors = _palette[i % _palette.length];
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colors,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '#${i + 1}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Options
// ---------------------------------------------------------------------------

class _OptionsPage extends StatelessWidget {
  const _OptionsPage({
    required this.showRegions,
    required this.sidebar,
    required this.accent,
    required this.accents,
    required this.onShowRegions,
    required this.onSidebar,
    required this.onAccent,
  });

  final bool showRegions;
  final bool sidebar;
  final int accent;
  final List<Color> accents;
  final ValueChanged<bool> onShowRegions;
  final ValueChanged<bool> onSidebar;
  final ValueChanged<int> onAccent;

  @override
  Widget build(BuildContext context) {
    Widget row(String title, String detail, bool value, ValueChanged<bool> f) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CNSwitch(value: value, semanticLabel: title, onChanged: f),
          ],
        ),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: <Widget>[
          const _PageTitle('Options', 'Showcase settings'),
          _Card(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: <Widget>[
                row(
                  'Show reserved regions',
                  'Outline the fold and the camera',
                  showRegions,
                  onShowRegions,
                ),
                row(
                  'Sidebar on wide screens',
                  'Open inner display in portrait',
                  sidebar,
                  onSidebar,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                for (var i = 0; i < accents.length; i++)
                  GestureDetector(
                    onTap: () => onAccent(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accents[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i == accent
                              ? CupertinoColors.label.resolveFrom(context)
                              : const Color(0x00000000),
                          width: 3,
                        ),
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

/// Outlines the fold (accent, dashed when inactive) and the camera (orange).
class _RegionsPainter extends CustomPainter {
  _RegionsPainter(this.regions, this.tint);

  final List<CNReservedRegion> regions;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in regions) {
      final fold = r.kind == CNReservedRegionKind.division;
      final color = fold ? tint : CupertinoColors.systemOrange;
      final rect = r.frame.width < 2 || r.frame.height < 2
          ? r.frame.inflate(1)
          : r.frame;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = color.withValues(alpha: r.isActive ? 0.28 : 0.10),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.isActive ? 2.5 : 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RegionsPainter old) =>
      !listEquals(old.regions, regions) || old.tint != tint;
}
