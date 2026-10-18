import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// PR #82 verification — `CNTabBar` ignores `labelFontFamily` on its first
/// build.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/82
/// Reported by @johndavid92.
///
/// ### The claim
///
/// `labelFontFamily` / `labelFontSize` are sent in the creation params, but
/// `CupertinoTabBarPlatformView.init` reads them *after* the bars and their
/// `UITabBarAppearance` have been built, so `applyLabelFont` returns early
/// and the first appearance carries the system font. The custom font shows
/// only once a later `setFont` call rebuilds the appearance — and Dart sends
/// `setFont` only when the font *changes*, so a bar that keeps the font it
/// was created with never shows it. The PR moves the read to right after
/// `super.init()`.
///
/// ### How this screen proves it
///
/// The bar is created with `labelFontFamily: 'Chalkduster'` from its very
/// first build — a font that ships with iOS and cannot be mistaken for the
/// system font. The strip above the bar draws the same labels in the same
/// font and size **in Flutter**: that is what the bar's labels should look
/// like.
///
/// Judge the **settled** bar. Before the platform view exists `CNTabBar`
/// draws a Flutter fallback that *does* honour the font, so Chalkduster may
/// flash for a frame or two and then flip to the system font; that flip is
/// the bug arriving, not noise.
///
///  * **Bug present:** the settled labels are the plain system font, unlike
///    the reference strip. Tap *Size* — the size change goes through
///    `setFont`, and the labels jump to Chalkduster, which proves the font
///    name is fine and only the creation path loses it. Tap *Remount* (a
///    fresh native view) — system font again. Tap *Size*, then *Sheet* and
///    dismiss it — `CNTabBar` destroys the native view under the sheet and
///    recreates it from its cached creation params, so the font is lost
///    again.
///  * **Bug fixed:** Chalkduster on the settled bar straight after opening
///    the page, after every *Remount*, and after every *Sheet*.
///
/// One thing the PR does not touch, visible only once it is applied: the
/// recreate after *Sheet* uses the params cached at first mount, so a size
/// picked with *Size* afterwards comes back as the creation-time size while
/// the readout still shows the new one. That is the same stale-creation-
/// params gap as Issue #70's colour, not this PR's bug.
///
/// ### Direct setFont (added after the first device run)
///
/// On an iPhone with iOS 26.5.2 the bar's labels never took the font at all —
/// not even after *Size*, which goes through `setFont`. That points either at
/// the Dart sync path or at iOS ignoring the font. The *Direct* buttons send
/// `setFont` straight to the bar's native channel
/// (`CupertinoNativeTabBar_<viewId>`, found through its `RenderUiKitView`;
/// only `invokeMethod` is used), bypassing the plugin's Dart side, with two
/// unrelated fonts:
///
///  * labels change → the plugin's Dart path was dropping the font;
///  * labels still unchanged → iOS ignores `UITabBarAppearance` title fonts
///    on this version, as reported on the Apple developer forums for iOS
///    26.2+ (thread 809225, FB21291879), and PR #82 cannot have a visible
///    effect there.
///
/// `single` and `split` build their bars through separate paths that share
/// `makeAppearance()`. The `searchItem` layout is a different native view
/// with no label-font support at all, so it is not offered here.
class Pr82TabBarFontFirstBuildTestPage extends StatefulWidget {
  const Pr82TabBarFontFirstBuildTestPage({super.key});

  @override
  State<Pr82TabBarFontFirstBuildTestPage> createState() =>
      _Pr82TabBarFontFirstBuildTestPageState();
}

class _Pr82TabBarFontFirstBuildTestPageState
    extends State<Pr82TabBarFontFirstBuildTestPage> {
  static const String _family = 'Chalkduster';

  /// The size every fresh bar is created with, and the one *Size* toggles to.
  /// Far enough apart that a stale size after a sheet is obvious.
  static const double _createdSize = 11;
  static const double _altSize = 15;

  static const List<String> _labels = <String>[
    'Home',
    'Library',
    'Alerts',
    'Profile',
  ];

  static const List<CNTabBarItem> _items = <CNTabBarItem>[
    CNTabBarItem(
      label: 'Home',
      icon: CNSymbol('house'),
      activeIcon: CNSymbol('house.fill'),
    ),
    CNTabBarItem(
      label: 'Library',
      icon: CNSymbol('books.vertical'),
      activeIcon: CNSymbol('books.vertical.fill'),
    ),
    CNTabBarItem(
      label: 'Alerts',
      icon: CNSymbol('bell'),
      activeIcon: CNSymbol('bell.fill'),
    ),
    CNTabBarItem(
      label: 'Profile',
      icon: CNSymbol('person'),
      activeIcon: CNSymbol('person.fill'),
    ),
  ];

  bool _split = false;

  /// Around the bar, so the native view can be found for the direct calls.
  final GlobalKey _barArea = GlobalKey();
  String _direct = '—';
  double _size = _createdSize;
  int _tabIndex = 0;

  /// Part of the bar's key. Bumped by *Remount* and by a layout change, each
  /// of which also resets [_size], so a fresh native view is always created
  /// with [_createdSize]. *Sheet* deliberately does not bump it.
  int _epoch = 1;

  void _remount({bool? split}) {
    setState(() {
      _split = split ?? _split;
      _size = _createdSize;
      _epoch++;
    });
  }

  int? _nativeViewId() {
    final BuildContext? area = _barArea.currentContext;
    if (area is! Element) return null;
    int? id;
    void visit(Element element) {
      if (id != null) return;
      final RenderObject? render = element.renderObject;
      if (render is RenderUiKitView) {
        id = render.viewController.id;
        return;
      }
      element.visitChildElements(visit);
    }

    visit(area);
    return id;
  }

  /// Sends `setFont` straight to the native bar, skipping the plugin's Dart
  /// sync. Only `invokeMethod` — a handler set here would replace CNTabBar's.
  Future<void> _directSetFont(String family, double size) async {
    final int? id = _nativeViewId();
    if (id == null) {
      setState(() => _direct = 'no native view');
      return;
    }
    try {
      await MethodChannel('CupertinoNativeTabBar_$id').invokeMethod<void>(
        'setFont',
        <String, Object>{'labelFontFamily': family, 'labelFontSize': size},
      );
      if (mounted) {
        setState(() => _direct = 'sent $family ${size.toInt()} — look');
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => _direct = 'failed: ${e.code}');
    } on MissingPluginException {
      if (mounted) setState(() => _direct = 'failed: no channel');
    }
  }

  void _toggleSize() {
    setState(() => _size = _size == _createdSize ? _altSize : _createdSize);
  }

  void _showSheet() {
    CNBottomSheet.show<void>(
      context: context,
      builder: (BuildContext ctx) => SizedBox(
        height: 300,
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 16),
              const Text(
                'Sheet round-trip',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'The native tab bar is destroyed while this sheet is up '
                  'and recreated from its cached creation params on Dismiss. '
                  'Check the label font again once it is back.',
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              CupertinoButton.filled(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Dismiss'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #82 · tab bar font'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  _controls(),
                  const Spacer(),
                  _reference(),
                  const SizedBox(height: 130),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(key: _barArea, top: false, child: _tabBar()),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return CNTabBar(
      // A new key per layout / remount forces a fresh native view, so the
      // creation-params path is what gets exercised; Size keeps the key and
      // goes through setFont instead.
      key: ValueKey<String>('${_split ? 'split' : 'single'}#$_epoch'),
      items: _items,
      currentIndex: _tabIndex,
      onTap: (int i) => setState(() => _tabIndex = i),
      tint: CupertinoColors.systemBlue,
      split: _split,
      labelFontFamily: _family,
      labelFontSize: _size,
    );
  }

  /// The same labels in the same font and size, drawn by Flutter.
  Widget _reference() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Text(
            'reference · Flutter text in $_family ${_size.toInt()}',
            style: TextStyle(
              fontSize: 11,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              for (final String label in _labels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _family,
                      fontSize: _size,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
            ],
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
            'Bug: the settled tab labels are the system font, not the '
            'reference font. Size makes it appear; Remount and Sheet lose it '
            'again. Fixed: the reference font from the first settled frame, '
            'after Remount and after Sheet.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CupertinoSegmentedControl<bool>(
              groupValue: _split,
              onValueChanged: (bool v) => _remount(split: v),
              children: const <bool, Widget>{
                false: Text('single', style: TextStyle(fontSize: 12)),
                true: Text('split', style: TextStyle(fontSize: 12)),
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _button('Size', _toggleSize),
              const SizedBox(width: 8),
              _button('Remount', _remount),
              const SizedBox(width: 8),
              _button('Sheet', _showSheet),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _button(
                'Direct Chalkduster 15',
                () => _directSetFont('Chalkduster', 15),
              ),
              const SizedBox(width: 8),
              _button(
                'Direct Courier-Bold 16',
                () => _directSetFont('Courier-Bold', 16),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            '${_split ? 'split' : 'single'} · $_family ${_size.toInt()} · '
            'mount #$_epoch · iOS ${PlatformVersion.iosVersion ?? '?'} · '
            '$backend\ndirect: $_direct',
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

  Widget _button(String label, VoidCallback onPressed) {
    return Expanded(
      child: CupertinoButton.filled(
        padding: const EdgeInsets.symmetric(vertical: 10),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
