import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #187: `CNButtonConfig.appearance`, the glass look of a `CNButton`.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/187
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// `LiquidGlassConfig.appearance` (#165) fixes a container's glass light or
/// dark, but a glass `CNButton` has no such option: it follows the app's
/// brightness, and over dark content it can turn dark while a light
/// container next to it stays light. The request is the same opt-in on
/// `CNButtonConfig`, with `labelColorLight` / `labelColorDark` (#153)
/// following it, and a check of whether the iOS 26 small-glass limit from
/// #165 applies to buttons.
///
/// ### How this screen proves it
///
/// A page scrolls behind floating glass buttons: white rows, a 30 % grey
/// section, a black section and a dark gradient. Top row: 44 pt buttons
/// with `adaptive`, `light` and `dark`. Bottom row: a `light` icon button,
/// a 72 pt `light` button and a `light` button in a glass effect union (the
/// SwiftUI path). The labels have `labelColorLight` deep blue and
/// `labelColorDark` yellow, so the label shows which look the button has
/// (the union button keeps the system label). **Dark app** gives the page a
/// dark theme. AUTO scrolls each section under the buttons, in a light and
/// then a dark app, and prints `CNB_SHOT 187-<app>-<section>` with each
/// button's rect.
///
///  * **Before:** in the dark app every button is dark, whatever you want.
///  * **With `appearance`:** `light` buttons stay light with a blue label in
///    the dark app, and `dark` stays dark with a yellow label in the light
///    app. `adaptive` follows the app.
///  * **iOS 26.0 to 26.2:** small glass still switches by itself (#165):
///    over black and the gradient a 44 pt `light` button turns dark, and its
///    label turns yellow with it; over white a `dark` button turns light.
///    The 72 pt button doesn't switch (`TALL=64` switches, `TALL=66`
///    doesn't, as for a container).
///  * **iOS 27:** every button keeps its look over every section.
class Issue187ButtonGlassAppearanceTestPage extends StatefulWidget {
  /// Creates the #187 test page.
  const Issue187ButtonGlassAppearanceTestPage({
    super.key,
    this.autoCycle = false,
    this.tallHeight = 72,
  });

  /// Scrolls each section under the buttons and prints the steps.
  final bool autoCycle;

  /// The height of the tall `light` button.
  final double tallHeight;

  @override
  State<Issue187ButtonGlassAppearanceTestPage> createState() =>
      _Issue187ButtonGlassAppearanceTestPageState();
}

enum _Section { white, grey, black, gradient }

class _Issue187ButtonGlassAppearanceTestPageState
    extends State<Issue187ButtonGlassAppearanceTestPage> {
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  bool _darkApp = false;
  _Section _section = _Section.white;

  static const _labelLight = Color(0xFF0040DD);
  static const _labelDark = Color(0xFFFFD60A);

  static final String _os = () {
    final match = RegExp(
      r'(\d+\.\d+)',
    ).firstMatch(Platform.operatingSystemVersion);
    return match?.group(1) ?? Platform.operatingSystemVersion;
  }();

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) Future.delayed(const Duration(seconds: 5), _auto);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _key(String name) => _keys.putIfAbsent(name, GlobalKey.new);

  double get _sectionHeight => MediaQuery.sizeOf(context).height;

  Future<void> _show(_Section section) async {
    setState(() => _section = section);
    await _scroll.animateTo(
      section.index * _sectionHeight,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
    );
  }

  void _printRects() {
    String f(double v) => v.toStringAsFixed(1);
    for (final e in _keys.entries) {
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final r = box.localToGlobal(Offset.zero) & box.size;
      debugPrint(
        'CNB_RECT187 ${e.key} ${f(r.left)} ${f(r.top)} ${f(r.right)} '
        '${f(r.bottom)}',
      );
    }
  }

  Future<void> _auto() async {
    debugPrint('CNB_187 os=${Platform.operatingSystem} $_os');
    _printRects();
    for (final dark in [false, true]) {
      if (!mounted) return;
      setState(() => _darkApp = dark);
      for (final section in _Section.values) {
        if (!mounted) return;
        await _show(section);
        // The system's switch animates in after the content arrives.
        await Future<void>.delayed(const Duration(milliseconds: 3000));
        debugPrint(
          'CNB_SHOT 187-${dark ? 'darkapp' : 'lightapp'}-${section.name}',
        );
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
    }
    await _show(_Section.white);
    debugPrint('CNB_SHOT 187-done');
  }

  Widget _sectionView(_Section section) {
    final height = _sectionHeight;
    return switch (section) {
      _Section.white => Container(
        height: height,
        color: CupertinoColors.white,
        child: Column(
          children: [
            for (var i = 0; i < 14; i++)
              Container(
                height: 56,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA))),
                ),
                child: Text(
                  'White row $i',
                  style: const TextStyle(color: Color(0xFF000000)),
                ),
              ),
          ],
        ),
      ),
      _Section.grey => Container(
        height: height,
        color: const Color(0xFF4D4D4D),
      ),
      _Section.black => Container(
        height: height,
        color: const Color(0xFF000000),
      ),
      _Section.gradient => Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF33210F), Color(0xFF0D1A33), Color(0xFF4D381F)],
          ),
        ),
      ),
    };
  }

  Widget _button(
    String name,
    CNGlassAppearance appearance, {
    double? minHeight,
    bool union = false,
  }) {
    return Expanded(
      child: SizedBox(
        key: _key(name),
        height: minHeight ?? 44,
        child: CNButton(
          label: name,
          autoHideOnModal: false,
          onPressed: () {},
          config: CNButtonConfig(
            style: CNButtonStyle.glass,
            appearance: appearance,
            minHeight: minHeight,
            labelColorLight: _labelLight,
            labelColorDark: _labelDark,
            glassEffectUnionId: union ? 'issue187' : null,
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
          middle: const Text('#187 Button appearance'),
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
                        'iOS $_os · behind: ${_section.name} · '
                        '${_darkApp ? 'dark' : 'light'} app',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF000000),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Blue label = light look, yellow label = dark look.',
                        style: TextStyle(
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
                      _button('adaptive', CNGlassAppearance.adaptive),
                      const SizedBox(width: 10),
                      _button('light', CNGlassAppearance.light),
                      const SizedBox(width: 10),
                      _button('dark', CNGlassAppearance.dark),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        key: _key('icon-light'),
                        width: 44,
                        height: 44,
                        child: CNButton.icon(
                          icon: const CNSymbol('phone.fill'),
                          autoHideOnModal: false,
                          onPressed: () {},
                          config: const CNButtonConfig(
                            style: CNButtonStyle.glass,
                            appearance: CNGlassAppearance.light,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _button(
                        'light ${widget.tallHeight.round()}',
                        CNGlassAppearance.light,
                        minHeight: widget.tallHeight,
                      ),
                      const SizedBox(width: 10),
                      _button(
                        'union light',
                        CNGlassAppearance.light,
                        union: true,
                      ),
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
