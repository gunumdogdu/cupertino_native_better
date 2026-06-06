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
    size: const Size(340, 100),
    animMs: 3000,
    child: CNTabBar(
      items: const [
        CNTabBarItem(label: 'Home', icon: CNSymbol('house.fill')),
        CNTabBarItem(label: 'Search', icon: CNSymbol('magnifyingglass')),
        CNTabBarItem(label: 'Profile', icon: CNSymbol('person.fill')),
      ],
      currentIndex: _i,
      onTap: (v) => setState(() => _i = v),
    ),
  );
}

class _NativeTabBarLoop extends StatefulWidget {
  const _NativeTabBarLoop();
  @override
  State<_NativeTabBarLoop> createState() => _NativeTabBarLoopState();
}

class _NativeTabBarLoopState extends State<_NativeTabBarLoop> {
  // Hardcoded pixel rect (3x) covering the bottom native tab-bar region on the
  // iPhone 17 Pro (1206x2622). Measured empirically from a full screenshot.
  static const int _rectL = 60;
  static const int _rectT = 2330;
  static const int _rectW = 1086;
  static const int _rectH = 260;
  static const int _animMs = 3000;

  Timer? _t;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await CNTabBarNative.enable(
        tabs: [
          CNTab(title: 'Home', sfSymbol: CNSymbol('house.fill')),
          CNTab(title: 'Search', sfSymbol: CNSymbol('magnifyingglass')),
          CNTab(title: 'Favorites', sfSymbol: CNSymbol('heart.fill')),
          CNTab(title: 'Profile', sfSymbol: CNSymbol('person.fill')),
        ],
        minimizeBehavior: CNTabMinimizeBehavior.never,
        tintColor: CupertinoColors.systemBlue,
        asRoot: true,
      );
      // Let the native bar settle, then announce a hardcoded crop rect.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      debugPrint(
        'CN_CAPTURE_READY id=cn-tab-bar-native '
        'rect=$_rectL,$_rectT,$_rectW,$_rectH dpr=3.0 anim_ms=$_animMs',
      );
      _t = Timer.periodic(const Duration(milliseconds: 900), (_) {
        _i = (_i + 1) % 4;
        CNTabBarNative.setSelectedIndex(_i);
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
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

class _FloatingIslandLoopState extends State<_FloatingIslandLoop> {
  final CNFloatingIslandController _c = CNFloatingIslandController();
  Timer? _t;
  bool _expanded = false;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 1700), (_) {
      _expanded = !_expanded;
      if (_expanded) {
        _c.expand();
      } else {
        _c.collapse();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CaptureStage(
    id: 'cn-floating-island',
    size: const Size(300, 170),
    animMs: 3400,
    background: const Color(0xFF2A2440),
    child: CNFloatingIsland(
      controller: _c,
      position: CNFloatingIslandPosition.top,
      collapsedWidth: 180,
      expandedWidth: 260,
      expandedHeight: 120,
      margin: const EdgeInsets.all(8),
      collapsed: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.music_note, color: CupertinoColors.white, size: 18),
          SizedBox(width: 8),
          Text('Now Playing',
              style: TextStyle(color: CupertinoColors.white, fontSize: 14)),
        ],
      ),
      expanded: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.music_note_2,
              color: CupertinoColors.white, size: 28),
          SizedBox(height: 8),
          Text('Daydream',
              style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Wallows',
              style: TextStyle(
                  color: CupertinoColors.systemGrey3, fontSize: 13)),
        ],
      ),
    ),
  );
}
