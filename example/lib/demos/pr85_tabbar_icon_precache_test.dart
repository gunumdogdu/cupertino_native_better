import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// PR #90 (was #85) / Issue #73 verification — `CNTabBar` shows its Flutter
/// fallback while its custom icons are rendered, most visibly on a first
/// mount.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/90
/// (resubmission of #85)
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/73
/// Reported and contributed by @TjarkGomollaDev.
///
/// ### The claim
///
/// Until its creation params resolve, `CNTabBar.build` returns the Flutter
/// fallback bar. For items with `customIcon` (IconData), resolving them means
/// rasterising every icon (`Canvas.toImage` + `toByteData`, real engine round
/// trips). 1.6.0 already memoises those renders, so a *re*mount is quick —
/// but the first mount of a given icon set starts with an empty cache, which
/// is the flash the reporter sees when a native splash is dismissed. The PR
/// adds `CNTabBar.precacheIcons(items, iconSize: …)` so an app can warm the
/// cache before the bar's first mount.
///
/// ### How this screen proves it
///
/// The bar has five `customIcon` items. Each mount creates a brand-new
/// `CNTabBar` and counts the frames until a `UiKitView` exists in its subtree,
/// i.e. how long the Flutter fallback was on screen:
///
///  * **Cold mount** — uses an icon size never rendered before (one
///    thousandth of a point larger each time, invisible to the eye but a new
///    cache key), so every icon is rasterised from scratch: the #73 case.
///  * **Warm mount** — the same size as the last mount, so every icon comes
///    from the cache: the baseline.
///
///  * **Issue present:** *Cold* takes clearly more frames than *Warm*, and
///    you may catch the fallback bar flashing before the native one.
///  * **What the PR must achieve** — *Precache* (a never-used size, warmed
///    with `CNTabBar.precacheIcons` first, then mounted) must come out the
///    same as *Warm*. PR #85 did on device 2026-10-17: 1 fallback frame /
///    49 ms, same as warm. This button needs the PR's API to compile.
///
/// Each result splits the wait in two:
///
///  * **fallback** — frames drawn before the bar's `UiKitView` existed, i.e.
///    while its creation params (the icon renders) were pending. This is
///    what #73 and #85 are about.
///  * **blank** — frames after that, before the native view was created and
///    rendered (Flutter shows an empty box meanwhile). The same in every
///    mode; precaching cannot touch it.
///
/// *Warm* will not reach zero fallback frames. Even with every icon cached
/// the bar builds its creation params asynchronously, so its first frame is
/// always the fallback; precaching cannot remove that last frame. Compare
/// modes within one build; debug builds are slower across the board, a
/// profile build gives the most realistic numbers.
///
/// This page does not cover a true cold start. `PlatformViewGuard` delays the
/// first native view of every debug or profile run by 500 ms, so that case
/// can only be judged in a release build of an app that mounts the bar at
/// launch.
class Pr85TabBarIconPrecacheTestPage extends StatefulWidget {
  const Pr85TabBarIconPrecacheTestPage({super.key});

  @override
  State<Pr85TabBarIconPrecacheTestPage> createState() =>
      _Pr85TabBarIconPrecacheTestPageState();
}

class _Pr85TabBarIconPrecacheTestPageState
    extends State<Pr85TabBarIconPrecacheTestPage> {
  static const List<CNTabBarItem> _items = <CNTabBarItem>[
    CNTabBarItem(
      label: 'Home',
      customIcon: CupertinoIcons.house,
      activeCustomIcon: CupertinoIcons.house_fill,
    ),
    CNTabBarItem(
      label: 'Library',
      customIcon: CupertinoIcons.book,
      activeCustomIcon: CupertinoIcons.book_fill,
    ),
    CNTabBarItem(
      label: 'Chat',
      customIcon: CupertinoIcons.chat_bubble,
      activeCustomIcon: CupertinoIcons.chat_bubble_fill,
    ),
    CNTabBarItem(
      label: 'Alerts',
      customIcon: CupertinoIcons.bell,
      activeCustomIcon: CupertinoIcons.bell_fill,
    ),
    CNTabBarItem(
      label: 'Profile',
      customIcon: CupertinoIcons.person,
      activeCustomIcon: CupertinoIcons.person_fill,
    ),
  ];

  /// Give up counting after this many frames (about five seconds at 60 Hz).
  static const int _maxFrames = 300;

  /// Base icon size; each cold mount adds one thousandth of a point.
  static const double _baseSize = 24;

  int _coldMounts = 0;
  double _size = _baseSize;
  int _tabIndex = 0;

  /// A fresh key per mount, so every mount is a brand-new `CNTabBar` state.
  GlobalKey _barKey = GlobalKey();
  bool _barVisible = false;

  String? _measuringLabel;
  int _frames = 0;

  /// Frames drawn before the bar's `UiKitView` existed; null until then.
  int? _fallbackFrames;
  final Stopwatch _stopwatch = Stopwatch();
  final List<String> _results = <String>[];

  void _coldMount() {
    _coldMounts++;
    _mount('cold', _baseSize + _coldMounts / 1000);
  }

  /// A never-used size, like a cold mount, but rendered ahead with
  /// `CNTabBar.precacheIcons` before the bar mounts.
  Future<void> _precacheMount() async {
    if (_measuringLabel != null) return;
    _coldMounts++;
    final double size = _baseSize + _coldMounts / 1000;
    setState(() => _measuringLabel = 'precache');
    await CNTabBar.precacheIcons(_items, iconSize: size);
    if (!mounted) return;
    setState(() => _measuringLabel = null);
    _mount('precache', size);
  }

  void _warmMount() {
    if (_coldMounts == 0) {
      // Nothing has been rendered yet, so there is nothing warm to reuse.
      _coldMount();
      return;
    }
    _mount('warm', _size);
  }

  /// Unmounts the bar for one frame, then mounts a new one and counts the
  /// frames until its native view is in the tree.
  void _mount(String label, double size) {
    if (_measuringLabel != null) return;
    setState(() {
      _barVisible = false;
      _measuringLabel = label;
    });
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _size = size;
        _barKey = GlobalKey();
        _barVisible = true;
        _frames = 0;
        _fallbackFrames = null;
      });
      _stopwatch
        ..reset()
        ..start();
      SchedulerBinding.instance.addPostFrameCallback(_countFrame);
    });
  }

  void _countFrame(Duration _) {
    if (!mounted || _measuringLabel == null) return;
    _frames++;
    final BuildContext? barContext = _barKey.currentContext;
    final Element? bar = barContext is Element ? barContext : null;
    if (_fallbackFrames == null &&
        bar != null &&
        _contains(bar, (Element e) => e.widget is UiKitView)) {
      _fallbackFrames = _frames - 1;
    }
    final bool rendered =
        _fallbackFrames != null &&
        bar != null &&
        _contains(bar, (Element e) => e.renderObject is RenderUiKitView);
    if (rendered || _frames >= _maxFrames) {
      _stopwatch.stop();
      final String outcome = rendered
          ? 'fallback ${_fallbackFrames!} · blank '
                '${_frames - 1 - _fallbackFrames!} frames'
          : 'no native view after $_maxFrames frames';
      final String result =
          '${_measuringLabel!.padRight(8)} '
          '${_size.toStringAsFixed(3)} pt  $outcome  '
          '${_stopwatch.elapsedMilliseconds} ms';
      setState(() {
        _results.insert(0, result);
        if (_results.length > 8) _results.removeLast();
        _measuringLabel = null;
      });
      return;
    }
    SchedulerBinding.instance.scheduleFrame();
    SchedulerBinding.instance.addPostFrameCallback(_countFrame);
  }

  static bool _contains(Element root, bool Function(Element) test) {
    bool found = false;
    void visit(Element element) {
      if (found) return;
      if (test(element)) {
        found = true;
        return;
      }
      element.visitChildElements(visit);
    }

    visit(root);
    return found;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #90 · icon precache'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 140),
                child: Column(children: <Widget>[_controls(), _resultsList()]),
              ),
            ),
          ),
          if (_barVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: CNTabBar(
                  key: _barKey,
                  items: _items,
                  currentIndex: _tabIndex,
                  onTap: (int i) => setState(() => _tabIndex = i),
                  tint: CupertinoColors.systemBlue,
                  iconSize: _size,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _controls() {
    final String backend = PlatformVersion.shouldUseNativeGlass
        ? 'native'
        : 'fallback';
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Issue: Cold mounts (icons never rendered) take clearly more '
            'fallback frames than Warm mounts (icons cached). Do a few of '
            'each. Precache must match Warm. Warm is never zero fallback; '
            'blank frames are the same in every mode.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _button('Cold mount', _coldMount),
              const SizedBox(width: 8),
              _button('Warm mount', _warmMount),
              const SizedBox(width: 8),
              _button('Precache', _precacheMount),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_measuringLabel == null ? 'idle' : 'measuring $_measuringLabel…'}'
            ' · ${_items.length} customIcon items · iOS '
            '${PlatformVersion.iosVersion ?? '?'} · $backend',
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.white,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsList() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _results.isEmpty
            ? 'No mounts yet — tap Cold mount, then Warm mount.'
            : _results.join('\n'),
        style: const TextStyle(fontFamily: 'Menlo', fontSize: 12, height: 1.5),
      ),
    );
  }

  Widget _button(String label, VoidCallback onPressed) {
    return Expanded(
      child: CupertinoButton.filled(
        padding: const EdgeInsets.symmetric(vertical: 10),
        onPressed: _measuringLabel == null ? onPressed : null,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
