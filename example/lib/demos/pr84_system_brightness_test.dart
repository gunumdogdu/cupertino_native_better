import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #84 verification — native widgets are created light on a dark system
/// when the Cupertino theme sets no brightness.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/84
/// Reported by @yagizdo.
///
/// ### The claim
///
/// `ThemeHelper.getBrightness` treats a null `CupertinoThemeData.brightness`
/// as `Brightness.light`. A `CupertinoApp` that sets no brightness follows
/// the system — Flutter's own Cupertino widgets go dark on a dark phone — but
/// every CN widget is created with `isDark: false`, so its native view gets
/// `overrideUserInterfaceStyle = .light`. The reporter sees glass buttons
/// appear light and fade to dark on every launch; `setBrightness` never
/// fires, because Dart never sees a dark theme. The PR makes `getBrightness`
/// return `CupertinoTheme.brightnessOf(context)`, which falls back to the
/// platform brightness.
///
/// ### How this screen proves it
///
/// **Put the phone in Dark Mode first.** The example app's root
/// `CupertinoApp` always sets a brightness, so this page wraps itself in its
/// own `CupertinoTheme`, switched by the segmented control:
///
///  * `none` — `CupertinoThemeData()` with no brightness: the bug case.
///  * `dark` — explicit `Brightness.dark`: the **control**, i.e. what the
///    native widgets look like when they are told the truth.
///  * `light` — explicit `Brightness.light`: must stay light before and
///    after the fix (an explicit theme wins over the system).
///
/// Each row shows a Flutter Cupertino widget next to its CN counterpart.
/// Changing mode or tapping *Remount* recreates every native view, so the
/// creation-time `isDark` is what is exercised. The readout prints the three
/// values involved; `ThemeHelper.isDark` is what the CN widgets act on.
///
///  * **Bug present** (Dark Mode, `none`): the readout says `theme null ·
///    platform dark · ThemeHelper.isDark false`. The page and the Flutter
///    column are dark, but the native column does **not** match what it
///    looks like in `dark`: the segmented control, switch and slider keep
///    their light-mode colours, the glass buttons come up light and drift
///    toward dark after each *Remount*, and *Menu* opens a **light** menu.
///    The menu is the least timing-dependent of these.
///  * **Bug fixed:** in `none` the readout says `ThemeHelper.isDark true`,
///    the native column is indistinguishable from `dark`, nothing fades on
///    *Remount*, and *Menu* opens dark. `light` still gives light native
///    widgets.
///
/// With the phone in Light Mode `none` and `light` are identical and the
/// page proves nothing; the banner says so.
///
/// Not the same as the reporter's video: that is a cold launch, where the
/// launch screen is also in play. This page replays only the creation of
/// the native views.
///
/// Not covered here: `CNToast`. It builds under the root overlay, outside
/// this page's theme, so its half of the bug (white text on a white toast in
/// a dark-system app with no brightness) cannot show in the example app.
///
/// Once the PR is applied, one more check: with the page open in `none`,
/// flip the phone's appearance from Control Center. Every native widget here
/// should follow live; on `main` the native column stays light.
class Pr84SystemBrightnessTestPage extends StatefulWidget {
  const Pr84SystemBrightnessTestPage({super.key});

  @override
  State<Pr84SystemBrightnessTestPage> createState() =>
      _Pr84SystemBrightnessTestPageState();
}

enum _ThemeMode { none, dark, light }

class _Pr84SystemBrightnessTestPageState
    extends State<Pr84SystemBrightnessTestPage> {
  _ThemeMode _mode = _ThemeMode.none;

  /// Part of every native widget's key; bumped by *Remount* and by a mode
  /// change so each native view is created afresh.
  int _epoch = 1;

  int _segment = 0;
  bool _switch = false;
  double _slider = 0.4;
  String _lastMenu = '—';

  CupertinoThemeData get _theme {
    switch (_mode) {
      case _ThemeMode.none:
        return const CupertinoThemeData();
      case _ThemeMode.dark:
        return const CupertinoThemeData(brightness: Brightness.dark);
      case _ThemeMode.light:
        return const CupertinoThemeData(brightness: Brightness.light);
    }
  }

  Key _key(String name) => ValueKey<String>('${_mode.name}#$_epoch-$name');

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: _theme,
      // The Builder's context is below the page-local theme, so everything
      // under it — Flutter and CN alike — reads that theme.
      child: Builder(builder: _page),
    );
  }

  Widget _page(BuildContext context) {
    final bool platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #84 · system brightness'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _controls(context),
            if (!platformDark) ...<Widget>[
              const SizedBox(height: 12),
              _lightModeBanner(),
            ],
            const SizedBox(height: 20),
            _header(context),
            _row(
              context,
              'Button',
              CupertinoButton.tinted(
                padding: const EdgeInsets.symmetric(vertical: 10),
                onPressed: () {},
                child: const Text('Flutter'),
              ),
              CNButton(key: _key('button'), label: 'Glass', onPressed: () {}),
            ),
            _row(
              context,
              'Icon',
              Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  CupertinoIcons.heart_fill,
                  size: 28,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: CNButton.icon(
                  key: _key('icon'),
                  icon: const CNSymbol('heart.fill'),
                  onPressed: () {},
                ),
              ),
            ),
            _row(
              context,
              'Segments',
              CupertinoSlidingSegmentedControl<int>(
                groupValue: _segment,
                onValueChanged: (int? v) => setState(() => _segment = v ?? 0),
                children: const <int, Widget>{0: Text('One'), 1: Text('Two')},
              ),
              CNSegmentedControl(
                key: _key('segments'),
                labels: const <String>['One', 'Two'],
                selectedIndex: _segment,
                onValueChanged: (int i) => setState(() => _segment = i),
              ),
            ),
            _row(
              context,
              'Switch',
              Align(
                alignment: Alignment.centerLeft,
                child: CupertinoSwitch(
                  value: _switch,
                  onChanged: (bool v) => setState(() => _switch = v),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: CNSwitch(
                  key: _key('switch'),
                  value: _switch,
                  onChanged: (bool v) => setState(() => _switch = v),
                ),
              ),
            ),
            _row(
              context,
              'Slider',
              CupertinoSlider(
                value: _slider,
                onChanged: (double v) => setState(() => _slider = v),
              ),
              CNSlider(
                key: _key('slider'),
                value: _slider,
                onChanged: (double v) => setState(() => _slider = v),
              ),
            ),
            _row(
              context,
              'Menu',
              Text(
                'last: $_lastMenu',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: CNPopupMenuButton(
                  key: _key('menu'),
                  buttonLabel: 'Menu',
                  buttonStyle: CNButtonStyle.glass,
                  items: const <CNPopupMenuEntry>[
                    CNPopupMenuItem(
                      label: 'Copy',
                      icon: CNSymbol('doc.on.doc'),
                    ),
                    CNPopupMenuItem(
                      label: 'Share',
                      icon: CNSymbol('square.and.arrow.up'),
                    ),
                    CNPopupMenuItem(
                      label: 'Delete',
                      icon: CNSymbol('trash'),
                      isDestructive: true,
                    ),
                  ],
                  onSelected: (int i) => setState(
                    () => _lastMenu = const <String>[
                      'Copy',
                      'Share',
                      'Delete',
                    ][i],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(BuildContext context) {
    final Brightness? themeBrightness = CupertinoTheme.of(context).brightness;
    final Brightness platform = MediaQuery.platformBrightnessOf(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Phone in Dark Mode. Bug: in none, Menu opens light, the '
            'segmented control has black labels on a light track and the '
            'off switch is light grey — unlike in dark. Fixed: none and '
            'dark look the same.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: CupertinoSegmentedControl<_ThemeMode>(
                  groupValue: _mode,
                  onValueChanged: (_ThemeMode v) => setState(() {
                    _mode = v;
                    _epoch++;
                  }),
                  children: <_ThemeMode, Widget>{
                    for (final _ThemeMode m in _ThemeMode.values)
                      m: Text(m.name, style: const TextStyle(fontSize: 12)),
                  },
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                onPressed: () => setState(() => _epoch++),
                child: const Text('Remount', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'theme ${themeBrightness?.name ?? 'null'} · '
            'platform ${platform.name} · '
            'ThemeHelper.isDark ${ThemeHelper.isDark(context)} · '
            'mount #$_epoch',
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

  Widget _lightModeBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemOrange.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'The phone is in Light Mode, so none and light are identical and '
        'this page cannot show the bug. Switch to Dark Mode (Settings → '
        'Display & Brightness) and come back.',
        style: TextStyle(fontSize: 13, height: 1.35),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 84),
          Expanded(child: Text('Flutter', style: style)),
          const SizedBox(width: 12),
          Expanded(child: Text('native CN', style: style)),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    Widget flutter,
    Widget native,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
          Expanded(child: flutter),
          const SizedBox(width: 12),
          Expanded(child: native),
        ],
      ),
    );
  }
}
