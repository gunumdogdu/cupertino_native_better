import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'capture_stage.dart';

class StageSpec {
  const StageSpec({required this.kind, required this.loopMs, required this.build});
  final String kind;   // 'static' | 'animated'
  final int loopMs;
  final Widget Function() build;
}

final Map<String, StageSpec> kStages = {
  'cn-button': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'cn-button',
      size: const Size(220, 80),
      child: CNButton(
        label: 'Get Started',
        icon: const CNSymbol('arrow.right', size: 18),
        config: const CNButtonConfig(style: CNButtonStyle.filled),
        onPressed: () {},
      ),
    ),
  ),
  'cn-button-icon': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'cn-button-icon',
      size: const Size(120, 80),
      child: CNButton.icon(
        icon: const CNSymbol('square.and.arrow.up', size: 20),
        onPressed: () {},
      ),
    ),
  ),
  'cn-icon': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'cn-icon',
      size: const Size(96, 80),
      child: const CNIcon(
        symbol: CNSymbol('star.fill'),
        size: 32,
        color: CupertinoColors.systemYellow,
      ),
    ),
  ),
  'liquid-glass-container': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'liquid-glass-container',
      size: const Size(240, 140),
      background: const Color(0xFF3A5BA0),
      child: LiquidGlassContainer(
        config: const LiquidGlassConfig(
          shape: CNGlassEffectShape.rect,
          cornerRadius: 20,
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Liquid Glass',
            style: TextStyle(color: CupertinoColors.white),
          ),
        ),
      ),
    ),
  ),
  'cn-glass-button-group': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'cn-glass-button-group',
      size: const Size(240, 90),
      background: const Color(0xFF3A5BA0),
      child: CNGlassButtonGroup.fromWidgets(
        buttonWidgets: [
          CNButton.icon(
            icon: const CNSymbol('plus', size: 18),
            onPressed: () {},
          ),
          CNButton.icon(
            icon: const CNSymbol('minus', size: 18),
            onPressed: () {},
          ),
          CNButton.icon(
            icon: const CNSymbol('square.and.arrow.up', size: 18),
            onPressed: () {},
          ),
        ],
      ),
    ),
  ),
  'cn-glass-card': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'cn-glass-card',
      size: const Size(260, 160),
      background: const Color(0xFF2A2440),
      child: const CNGlassCard(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Glass Card',
            style: TextStyle(color: CupertinoColors.white),
          ),
        ),
      ),
    ),
  ),
  'cn-switch': StageSpec(
    kind: 'animated',
    loopMs: 2400,
    build: () => const _SwitchLoop(),
  ),
  'cn-slider': StageSpec(
    kind: 'animated',
    loopMs: 2600,
    build: () => const _SliderLoop(),
  ),
  'cn-segmented-control': StageSpec(
    kind: 'animated',
    loopMs: 3000,
    build: () => const _SegmentedLoop(),
  ),
  'cn-tab-bar': StageSpec(
    kind: 'animated',
    loopMs: 3000,
    build: () => const _TabBarLoop(),
  ),
  'cn-popup-menu-button': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'cn-popup-menu-button',
      size: const Size(180, 80),
      child: CNPopupMenuButton(
        buttonLabel: 'Options',
        buttonStyle: CNButtonStyle.glass,
        items: const [
          CNPopupMenuItem(label: 'Edit', icon: CNSymbol('pencil')),
          CNPopupMenuItem(label: 'Share', icon: CNSymbol('square.and.arrow.up')),
          CNPopupMenuItem(label: 'Delete', icon: CNSymbol('trash')),
        ],
        onSelected: (_) {},
      ),
    ),
  ),
  'cn-search-bar': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'cn-search-bar',
      size: const Size(320, 72),
      // CNSearchBar sizes its expanded field to MediaQuery width, so constrain
      // the reported width to keep the rendered bar inside the stage crop.
      child: Builder(
        builder: (ctx) {
          final mq = MediaQuery.of(ctx);
          return MediaQuery(
            data: mq.copyWith(size: const Size(296, 72)),
            child: const CNSearchBar(
              expandable: false,
              placeholder: 'Search',
              showCancelButton: false,
            ),
          );
        },
      ),
    ),
  ),
  'cn-floating-island': StageSpec(
    kind: 'animated',
    loopMs: 3400,
    build: () => const _FloatingIslandLoop(),
  ),
  // CNTabBarNative is a native iOS 26 take-over presented OVER the Flutter app,
  // not a measurable Flutter widget. The stage enables the native bar, cycles
  // the selected tab, and prints a HARDCODED rect covering the bottom native
  // tab-bar region so the driver crops to it.
  'cn-tab-bar-native': StageSpec(
    kind: 'animated',
    loopMs: 3000,
    build: () => const _NativeTabBarLoop(),
  ),
  // The live CNToast.show overlay anchors to the top of the screen (outside
  // the centered stage rect), so it can't be cropped tightly. Fall back to a
  // static render of the exact toast surface (white pill + check + label),
  // matching _ToastOverlay's non-glass styling.
  'cn-toast': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'cn-toast',
      size: const Size(300, 96),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.checkmark_circle_fill,
                color: CupertinoColors.systemGreen, size: 22),
            SizedBox(width: 12),
            Text('Saved to library',
                style: TextStyle(
                    color: CupertinoColors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    ),
  ),
};

class _SwitchLoop extends StatefulWidget {
  const _SwitchLoop();
  @override
  State<_SwitchLoop> createState() => _SwitchLoopState();
}

class _SwitchLoopState extends State<_SwitchLoop> {
  bool _v = false;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (mounted) setState(() => _v = !_v);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CaptureStage(
    id: 'cn-switch',
    size: const Size(120, 80),
    animMs: 2400,
    child: CNSwitch(value: _v, onChanged: (x) => setState(() => _v = x)),
  );
}

class _SliderLoop extends StatefulWidget {
  const _SliderLoop();
  @override
  State<_SliderLoop> createState() => _SliderLoopState();
}

class _SliderLoopState extends State<_SliderLoop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CaptureStage(
    id: 'cn-slider',
    size: const Size(240, 80),
    animMs: 2600,
    child: CNSlider(
      value: _ctrl.value,
      onChanged: (_) {},
      color: CupertinoColors.systemBlue,
    ),
  );
}

class _SegmentedLoop extends StatefulWidget {
  const _SegmentedLoop();
  @override
  State<_SegmentedLoop> createState() => _SegmentedLoopState();
}

class _SegmentedLoopState extends State<_SegmentedLoop> {
  int _i = 0;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (mounted) setState(() => _i = (_i + 1) % 3);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CaptureStage(
    id: 'cn-segmented-control',
    size: const Size(280, 72),
    animMs: 3000,
    child: CNSegmentedControl(
      labels: const ['Day', 'Week', 'Month'],
      selectedIndex: _i,
      shrinkWrap: true,
      onValueChanged: (v) => setState(() => _i = v),
    ),
  );
}

class _TabBarLoop extends StatefulWidget {
  const _TabBarLoop();
  @override
  State<_TabBarLoop> createState() => _TabBarLoopState();
}

class _TabBarLoopState extends State<_TabBarLoop> {
  int _i = 0;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (mounted) setState(() => _i = (_i + 1) % 3);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CaptureStage(
    id: 'cn-tab-bar',
    // Taller stage so the native UITabBar has room to lay the label BELOW the
    // icon without clipping (the old 340x100 squeezed both into one row).
    size: const Size(360, 130),
    animMs: 3000,
    child: CNTabBar(
      items: const [
        CNTabBarItem(label: 'Home', icon: CNSymbol('house.fill')),
        CNTabBarItem(label: 'Search', icon: CNSymbol('magnifyingglass')),
        CNTabBarItem(label: 'Profile', icon: CNSymbol('person.fill')),
      ],
      currentIndex: _i,
      onTap: (v) => setState(() => _i = v),
      // Let the native iOS 26 tab bar use its INTRINSIC height: it stacks the
      // icon above the label automatically at that height. Forcing a larger
      // `height` makes the native bar vertically center icon+label into the
      // same band, which is what caused them to overlap. The taller stage
      // (360x130) just guarantees the intrinsic bar isn't clipped by the crop.
    ),
  );
}

class _NativeTabBarLoop extends StatefulWidget {
  const _NativeTabBarLoop();
  @override
  State<_NativeTabBarLoop> createState() => _NativeTabBarLoopState();
}

class _NativeTabBarLoopState extends State<_NativeTabBarLoop> {
  // HEADLINE FEATURE: the native iOS 26 SEARCH of CNTabBarNative. We present a
  // search tab (isSearchTab:true + a nativeList) with nativeSearchFilter:true,
  // select it, then on a loop activate the search field and type a query so the
  // native list visibly FILTERS live.
  //
  // On iOS 26 the tab-bar search FIELD renders as a pill at the BOTTOM of the
  // screen (where the typed text + clear button appear) and the filtered rows
  // render above it under a large "Search" title. So the crop must be TALL: it
  // spans from just above the result rows down THROUGH the bottom search pill,
  // capturing BOTH the search field and the live-filtering list.
  //
  // Hardcoded pixel rect (3x) on the iPhone 17 Pro (1206x2622), measured
  // empirically from a full screenshot (tool writes <id>_full.png mid-capture).
  // Width 1146 → encoder scales to 480 wide; height 2180 → 913 tall after the
  // min(480,iw) scale. Result GIF is 480x913, ~160KB (< 700KB), fps 18.
  static const int _rectL = 30;
  static const int _rectT = 360;
  static const int _rectW = 1146;
  static const int _rectH = 2180;
  static const int _animMs = 4000;

  // The recognizable list contents. "Da" → Daydream, Daylight (clear filter).
  static const List<CNListItem> _items = [
    CNListItem(title: 'Daydream', subtitle: 'Wallows', leadingSymbol: CNSymbol('music.note')),
    CNListItem(title: 'Daylight', subtitle: 'David Kushner', leadingSymbol: CNSymbol('music.note')),
    CNListItem(title: 'Nightfall', subtitle: 'Halsey', leadingSymbol: CNSymbol('music.note')),
    CNListItem(title: 'Sunset', subtitle: 'The Midnight', leadingSymbol: CNSymbol('music.note')),
    CNListItem(title: 'Echoes', subtitle: 'Pink Floyd', leadingSymbol: CNSymbol('music.note')),
    CNListItem(title: 'Wallows', subtitle: 'Wallows', leadingSymbol: CNSymbol('music.note')),
    CNListItem(title: 'Drive', subtitle: 'Clairo', leadingSymbol: CNSymbol('music.note')),
    CNListItem(title: 'Ocean', subtitle: 'Lady Wray', leadingSymbol: CNSymbol('music.note')),
  ];

  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await CNTabBarNative.enable(
        tabs: const [
          CNTab(title: 'Library', sfSymbol: CNSymbol('music.note.list')),
          CNTab(title: 'Radio', sfSymbol: CNSymbol('dot.radiowaves.left.and.right')),
          // The search tab — isSearchTab:true + a nativeList that the native
          // search field filters live when nativeSearchFilter is true.
          CNTab(
            title: 'Search',
            isSearchTab: true,
            nativeList: CNNativeList(items: _items),
          ),
        ],
        // Select the search tab so the search field is the focus.
        selectedIndex: 2,
        nativeSearchFilter: true,
        minimizeBehavior: CNTabMinimizeBehavior.never,
        tintColor: CupertinoColors.systemPink,
        asRoot: true,
      );
      // Let the native bar settle, then announce the hardcoded crop rect.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      debugPrint(
        'CN_CAPTURE_READY id=cn-tab-bar-native '
        'rect=$_rectL,$_rectT,$_rectW,$_rectH dpr=3.0 anim_ms=$_animMs',
      );
      _runLoop();
    });
  }

  // One ~4s pass: open the native search, type a query so the list filters
  // down to the matches, then clear and close. Repeats for the capture window.
  Future<void> _runLoop() async {
    if (_disposed || !mounted) return;
    await CNTabBarNative.activateSearch();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await CNTabBarNative.setSearchText('Da');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await CNTabBarNative.setSearchText('Day');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await CNTabBarNative.setSearchText('');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await CNTabBarNative.deactivateSearch();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!_disposed && mounted) _runLoop();
  }

  @override
  void dispose() {
    _disposed = true;
    CNTabBarNative.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Covered by the native take-over; just a neutral backdrop.
    return Container(color: const Color(0xFFF2F2F7));
  }
}

class _FloatingIslandLoop extends StatefulWidget {
  const _FloatingIslandLoop();
  @override
  State<_FloatingIslandLoop> createState() => _FloatingIslandLoopState();
}

class _FloatingIslandLoopState extends State<_FloatingIslandLoop>
    with SingleTickerProviderStateMixin {
  // The CNFloatingIsland renders its native glass via a SwiftUI VStack pinned
  // to the TOP of (and centered within) its platform-view frame — it does NOT
  // lay itself out inside the measured CaptureStage RenderBox. So we bypass the
  // stage's auto-rect and announce a HARDCODED pixel rect (3x, iPhone 17 Pro,
  // 1206x2622) covering the EXPANDED island.
  //
  // CHANGE: we no longer morph collapse<->expand (that left a big empty dark
  // box below the collapsed pill, since the rect was sized for the expanded
  // card). The island now stays EXPANDED the whole time (isExpanded:true and
  // the controller is never driven). Internal motion comes from a row of
  // "equalizer" bars beside the music note (a Flutter AnimationController),
  // so the card is full and clearly alive with NO empty band.
  static const double _stageW = 300; // logical pts, centered on screen
  static const int _expandedW = 260; // expanded island width in logical pts
  static const int _expandedH = 88; // expanded island height in logical pts
  // Inner content height = expandedH minus the package's EdgeInsets.all(16).
  static const double _innerH = 56;

  // Hardcoded crop rect in device px (3x), MEASURED empirically from a full
  // screenshot (tool/capture_docs.sh writes <id>_full.png mid-capture). The
  // island is a FIXED expanded size now (260x92 logical = 780x276 px), so the
  // rect tightly bounds it. The card is centered horizontally and pinned to
  // the top of its platform-view frame. Measured: L≈205 T≈891 on the
  // 1206x2622 device. We pad a touch so all four corners + glass shadow are
  // inside the frame with no empty band.
  static const int _rectL = 188;
  static const int _rectT = 895;
  static const int _rectW = 804;
  static const int _rectH = 300;
  static const int _animMs = 2400;

  late final AnimationController _eq;

  @override
  void initState() {
    super.initState();
    _eq = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _animMs),
    )..repeat();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        debugPrint(
          'CN_CAPTURE_READY id=cn-floating-island '
          'rect=$_rectL,$_rectT,$_rectW,$_rectH dpr=3.0 anim_ms=$_animMs',
        );
      });
    });
  }

  @override
  void dispose() {
    _eq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Full-screen neutral backdrop with the island stage centered horizontally
    // and offset from the top so the hardcoded rect lands on it. We do NOT use
    // CaptureStage here (it would print an auto-rect we don't want).
    return Container(
      color: const Color(0xFF2A2440),
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 300),
        child: SizedBox(
          width: _stageW,
          height: 160,
          child: CNFloatingIsland(
            // Stay expanded the whole capture — no collapse morph, no empty
            // box. The controller is intentionally NOT driven.
            isExpanded: true,
            position: CNFloatingIslandPosition.top,
            collapsedWidth: _expandedW.toDouble(),
            collapsedHeight: 56,
            expandedWidth: _expandedW.toDouble(),
            expandedHeight: _expandedH.toDouble(),
            margin: EdgeInsets.zero,
            // Required, but never shown (isExpanded:true and we never collapse).
            collapsed: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.music_note,
                    color: CupertinoColors.white, size: 18),
                SizedBox(width: 8),
                Text('Now Playing',
                    style:
                        TextStyle(color: CupertinoColors.white, fontSize: 14)),
              ],
            ),
            // Fixed-height box matching the card's inner area, with the row
            // centered inside it, so the content vertically fills the card and
            // leaves NO empty band (rather than top-anchoring).
            expanded: SizedBox(
              height: _innerH,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.music_note_2,
                        color: CupertinoColors.white, size: 30),
                    const SizedBox(width: 14),
                    _Equalizer(controller: _eq),
                    const SizedBox(width: 16),
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daydream',
                            style: TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text('Wallows',
                            style: TextStyle(
                                color: CupertinoColors.systemGrey3,
                                fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of equalizer bars that bob up and down on a continuous loop, giving
/// the (fixed-size) expanded floating island subtle internal motion without
/// any collapse/expand morph.
class _Equalizer extends StatelessWidget {
  const _Equalizer({required this.controller});
  final AnimationController controller;

  static const List<double> _phases = [0.0, 0.33, 0.66, 0.15];
  static const double _maxH = 28;
  static const double _minH = 6;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < _phases.length; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              _bar(_phases[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _bar(double phase) {
    // 0..1 triangle wave so bars rise and fall smoothly.
    final t = (controller.value + phase) % 1.0;
    final wave = t < 0.5 ? t * 2 : (1 - t) * 2;
    final h = _minH + (_maxH - _minH) * wave;
    return Container(
      width: 4,
      height: h,
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
