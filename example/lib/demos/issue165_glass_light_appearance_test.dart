import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #165: keep `LiquidGlassContainer` light over dark content.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/165
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// Liquid Glass turns dark when the content behind it gets dark, and a
/// light-only app wants its floating glass to stay light. The container's
/// brightness sync only follows the app's theme. The request is an opt-in on
/// `LiquidGlassConfig`, such as `appearance: CNGlassAppearance.light`.
///
/// The simulators show three things:
///
///  * The glass takes its light or dark look from its trait.
///    `LiquidGlassConfig.appearance` now fixes that trait: `light`, `dark`,
///    or the app's brightness (`adaptive`, the default).
///  * On iOS 26.0 to 26.2 the system also switches glass that is less than
///    about 65 pt on its shorter side by itself. It turns light glass dark
///    over near-black content and dark glass light over near-white content.
///    No public API stops this. Overriding the trait anywhere (the hosting
///    controller, the effect view, its content view, SwiftUI's
///    `colorScheme`) leaves the switch on. Glass of 66 pt or more doesn't
///    switch.
///  * On iOS 27 the glass keeps its trait's look over any content.
///
/// ### How this screen proves it
///
/// A page scrolls behind floating glass bars: white rows, a 30 % grey
/// section, a black section and a dark gradient. The top row has two 56 pt
/// bars, `adaptive` and `light`. The bottom row has a 56 pt `dark` bar and a
/// 72 pt `adaptive` bar. **Dark app** gives the page a dark theme, so
/// `adaptive` turns dark there and `light` doesn't. AUTO scrolls each
/// section under the bars, in a light and then a dark app, and prints
/// `CNB_SHOT 165-<app>-<section>`.
///
///  * **iOS 27:** `light` stays light over every section, in both apps.
///    `dark` stays dark over the white rows. `adaptive` follows the app.
///  * **iOS 26.0 to 26.2:** in the dark app over the grey section, `light`
///    is light while `adaptive` is dark. That is the option at work. The
///    rest is the system limit. Over the black section and the gradient, the
///    56 pt `light` and `adaptive` bars turn dark whatever their appearance,
///    and over the white rows `dark` turns light. The 72 pt bar never
///    switches with the content: it stays light in the light app and dark in
///    the dark app.
class Issue165GlassLightAppearanceTestPage extends StatefulWidget {
  /// Creates the #165 test page.
  const Issue165GlassLightAppearanceTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Scrolls each section under the glass on its own and prints the steps.
  final bool autoCycle;

  @override
  State<Issue165GlassLightAppearanceTestPage> createState() =>
      _Issue165GlassLightAppearanceTestPageState();
}

/// The sections of the page, top to bottom.
enum _Section { white, grey, black, gradient }

class _Issue165GlassLightAppearanceTestPageState
    extends State<Issue165GlassLightAppearanceTestPage> {
  final _scroll = ScrollController();
  bool _darkApp = false;
  _Section _section = _Section.white;

  /// The OS version as the system reports it, e.g. "26.2".
  static final String _os = () {
    final match = RegExp(
      r'(\d+\.\d+)',
    ).firstMatch(Platform.operatingSystemVersion);
    return match?.group(1) ?? Platform.operatingSystemVersion;
  }();

  /// iOS 26.0 to 26.2, where small glass switches by itself.
  static bool get _switchesBySize =>
      Platform.isIOS && (PlatformVersion.iosVersion ?? 0) == 26;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      Future.delayed(const Duration(seconds: 5), _auto);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double get _sectionHeight => MediaQuery.sizeOf(context).height;

  Future<void> _show(_Section section) async {
    setState(() => _section = section);
    await _scroll.animateTo(
      section.index * _sectionHeight,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _auto() async {
    debugPrint('CNB_165 os=${Platform.operatingSystem} $_os');
    for (final dark in [false, true]) {
      if (!mounted) return;
      setState(() => _darkApp = dark);
      for (final section in _Section.values) {
        if (!mounted) return;
        await _show(section);
        // The system's switch animates in after the content arrives.
        await Future<void>.delayed(const Duration(milliseconds: 3000));
        debugPrint(
          'CNB_SHOT 165-${dark ? 'darkapp' : 'lightapp'}-${section.name}',
        );
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
    }
    await _show(_Section.white);
    debugPrint('CNB_DONE 165');
  }

  String get _expectation {
    if (_switchesBySize) {
      return 'iOS $_os: expect the 56 pt light and adaptive bars to turn dark '
          'over black and the gradient (the system, no API stops it), dark to '
          'turn light over white, and the 72 pt bar to stay light in a light '
          'app.';
    }
    final platform = Platform.isIOS ? 'iOS' : 'macOS';
    return '$platform $_os: expect light to stay light and dark to stay dark '
        'over every section; adaptive follows the app.';
  }

  Widget _sectionView(_Section section) {
    final height = _sectionHeight;
    switch (section) {
      case _Section.white:
        return Container(
          height: height,
          color: CupertinoColors.white,
          child: Column(
            children: [
              for (var i = 0; i < 12; i++)
                Container(
                  height: 56,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E5EA)),
                    ),
                  ),
                  child: Text(
                    'White row $i',
                    style: const TextStyle(color: Color(0xFF000000)),
                  ),
                ),
            ],
          ),
        );
      case _Section.grey:
        return Container(height: height, color: const Color(0xFF4D4D4D));
      case _Section.black:
        return Container(height: height, color: const Color(0xFF000000));
      case _Section.gradient:
        return Container(
          height: height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF33210F), Color(0xFF0D1A33), Color(0xFF4D381F)],
            ),
          ),
        );
    }
  }

  Widget _bar(String label, CNGlassAppearance appearance, double height) {
    final glassDark =
        appearance == CNGlassAppearance.dark ||
        (appearance == CNGlassAppearance.adaptive && _darkApp);
    return Expanded(
      child: LiquidGlassContainer(
        autoHideOnModal: false,
        config: LiquidGlassConfig(
          shape: CNGlassEffectShape.rect,
          cornerRadius: 16,
          appearance: appearance,
        ),
        child: SizedBox(
          height: height,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: glassDark
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFF000000),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top + 44;
    return CupertinoTheme(
      data: CupertinoTheme.of(
        context,
      ).copyWith(brightness: _darkApp ? Brightness.dark : Brightness.light),
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('#165 Glass appearance'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => setState(() => _darkApp = !_darkApp),
            child: Text(_darkApp ? 'Light app' : 'Dark app'),
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scroll,
              child: Column(
                children: [for (final s in _Section.values) _sectionView(s)],
              ),
            ),
            Positioned(
              top: top,
              left: 0,
              right: 0,
              child: ColoredBox(
                color: const Color(0xFFF2F2F7),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Behind: ${_section.name}  ·  '
                        '${_darkApp ? 'dark' : 'light'} app',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF000000),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _expectation,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3C3C43),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (final s in _Section.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                minimumSize: const Size(0, 28),
                                color: s == _section
                                    ? CupertinoColors.activeBlue
                                    : const Color(0xFFD1D1D6),
                                onPressed: () => _show(s),
                                child: Text(
                                  s.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: s == _section
                                        ? const Color(0xFFFFFFFF)
                                        : const Color(0xFF000000),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: bottom + 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _bar('adaptive · 56', CNGlassAppearance.adaptive, 56),
                      const SizedBox(width: 12),
                      _bar('light · 56', CNGlassAppearance.light, 56),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _bar('dark · 56', CNGlassAppearance.dark, 56),
                      const SizedBox(width: 12),
                      _bar('adaptive · 72', CNGlassAppearance.adaptive, 72),
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
