import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #50 reproduction — `CNGlassButtonGroup` glass pinches into a
/// "dumbbell" between its buttons.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/50
/// Reported by @enmanuelmag.
///
/// ### The claim
///
/// A `CNGlassButtonGroup` of a popup button and an icon button — the
/// reporter's exact group, mirrored in `_group`: `CNButtonData.popup` with
/// two items ('Lista' / 'Calendar') whose icon follows the selection, then
/// `CNButtonData.icon` with `magnifyingglass`, everything else at its
/// default — does not render as one uniform capsule. The glass is thinner
/// in the middle than at the ends: a pinched waist between the buttons, so
/// each button's cap "pushes" the outline beyond the group's glass. The
/// reporter adds that reducing the icon size does not help.
///
/// This is a **documented known limitation** (CHANGELOG 1.5.1, *Known
/// limitations*), still unfixed on `main`: `GlassButtonGroupSwiftUI` lays the
/// buttons out in an `HStack(spacing:)` inside
/// `GlassEffectContainer(spacing: max(spacingForGlass, 80))`, and every
/// `GlassButtonSwiftUI` applies its **own** `.glassEffect(in: Capsule())`.
/// The container morphs two separate capsules together, and the bridge it
/// grows between them is narrower than the capsules — the waist. A single
/// outer glass gave the right pill but `.glassEffect` swallowed every tap,
/// so it was reverted; a UIKit `UIVisualEffectView` rewrite is queued. This
/// screen therefore doubles as the regression check for that rewrite —
/// including taps, since hit-testing is what sank the last attempt.
///
/// ### How this screen proves it
///
/// Fixed geometry in the body, with every glass shape exactly 44 pt tall:
///
///  * **group** — the reporter's group in a 180 pt slot. The native side
///    insets its content 3 pt from the top and 6 pt from the right (badge
///    room), so the slot is placed to put the group's centre on the page's
///    centre line, and its capsule spans y = 25…69 of the stage.
///  * **control** — directly below, a `LiquidGlassContainer` capsule
///    (`CNGlassEffect.regular`, the same `Glass.regular` the buttons use),
///    44 pt tall and about as wide as the group (`2 × (1.2 × icon + 24) +
///    spacing`; the group's real width is decided natively by glyph widths,
///    so the ends need not line up — only the **edges** are being compared).
///  * **rails** — magenta lines drawn in Flutter 2 pt above and below each
///    capsule's expected top and bottom edge. Along the straight section of
///    a uniform capsule the gap to each rail is constant. Turn them off
///    (`none`) before zooming into a screenshot to read the rim itself.
///
/// The same group is also in the navigation bar (trailing, 140 pt slot),
/// because that is where the reporter uses it — but the toolbar is 44 pt
/// tall while the group asks for 47 (44 + the 3 pt badge inset), so that
/// instance is squeezed and may look flat-cut at the bottom. That would be a
/// separate defect, not #50; judge the waist on the body group.
///
/// Backdrops: `dark` (the reporter's screenshot is dark glass on near-black),
/// `light`, and `photo` (`assets/home.jpg`). The page theme follows the
/// backdrop, so the native glass is created light on `light` and dark
/// otherwise, and the icons are black or white like the reporter's
/// `AppColors.foreground`.
///
/// Judge with the reporter's defaults (`defaults` at the start of the
/// readout), rails on, then take a screenshot and zoom in: in the reporter's
/// screenshot the waist is only about a point per side at this height.
///
///  * **Bug present:** the group's glass narrows between the two buttons —
///    its top and bottom edges dip toward each other mid-group, so the gap
///    to the rails is wider there than over each button, and the rim kinks
///    where the bridge meets each cap — while the control's edges run
///    straight with an even gap.
///  * **Bug fixed:** the group's outline is a uniform capsule like the
///    control: an even gap to both rails across the whole straight section,
///    no kinks. *And* both buttons still respond: tapping search bumps
///    `search ×N`, and the menu switches the first icon (`view list` /
///    `view calendar`), in the body and the navigation bar alike.
///
/// The readout's last field says whether the group is the `native` platform
/// view or the Flutter `fallback` (iOS < 26). The fallback draws separate
/// buttons with no shared glass, so a `fallback` readout proves nothing.
///
/// ### Probes (for the fix, not the verdict)
///
///  * `spacing` / `icon` — the group's `spacing` and the symbols' size, the
///    two knobs the reporter tried. Defaults 8 and 24.
///  * `blend` — `spacingForGlass`, the `GlassEffectContainer` blend radius.
///    The native side raises anything below 80 to 80 for horizontal groups
///    of two or more (an earlier attempt to shrink this very waist), so the
///    default 40 really runs at 80; 120 and 200 test whether a wider blend
///    fills the waist in.
///  * `icon+icon` — swaps the popup for a plain icon button with the same
///    symbol, so the glyphs and widths are identical and only the SwiftUI
///    `Menu` wrapper is gone. A waist in both means the `HStack` +
///    per-button glass is the cause, not the menu.
///  * `union on` — sets `CNButtonDataConfig.glassEffectUnionId` on both
///    buttons (public API; the Button demo already uses it), asking SwiftUI
///    to draw the two effects as one unioned shape while each button keeps
///    its own glass for hit-testing. If that gives a uniform capsule *and*
///    both buttons still respond, a workaround exists today and the fix may
///    be far smaller than the rewrite. Unverified, hence a probe.
///
/// Every control change remounts both groups (and the control) through
/// their keys. That is deliberate: `CNGlassButtonGroup` never sends a
/// changed `spacing` or `spacingForGlass` to an existing native view
/// (`_syncButtonsToNativeIfNeeded` only records them), and the union id is
/// not part of its change detection either, so without a remount those
/// probes would silently do nothing.
class Issue50GlassButtonGroupDumbbellTestPage extends StatefulWidget {
  const Issue50GlassButtonGroupDumbbellTestPage({super.key});

  @override
  State<Issue50GlassButtonGroupDumbbellTestPage> createState() =>
      _Issue50GlassButtonGroupDumbbellTestPageState();
}

enum _Backdrop { dark, light, photo }

enum _Variant { popupIcon, iconIcon }

enum _View { list, calendar }

class _Issue50GlassButtonGroupDumbbellTestPageState
    extends State<Issue50GlassButtonGroupDumbbellTestPage> {
  /// The reporter passes none of these, so these are the package defaults:
  /// `CNGlassButtonGroup.spacing`, `CNSymbol.size`,
  /// `CNGlassButtonGroup.spacingForGlass`.
  static const double _defaultSpacing = 8;
  static const double _defaultIconSize = 24;
  static const double _defaultBlend = 40;

  static const List<double> _spacings = <double>[0, 4, 8, 16];
  static const List<double> _iconSizes = <double>[12, 16, 20, 24];
  static const List<double> _blends = <double>[40, 120, 200];

  /// `GlassButtonGroupSwiftUI.effectiveSpacingForGlass` never goes below
  /// this for a horizontal group of two or more buttons.
  static const double _nativeBlendFloor = 80;

  static const Color _darkBackdrop = Color(0xFF0B0B0D);
  static const Color _lightBackdrop = Color(0xFFF2F2F7);
  static const Color _railColor = Color(0xFFFF00AA);

  // Geometry, in points. Every glass shape is `_glassHeight` tall: the
  // buttons' native default `minHeight`, which the group also uses for its
  // own slot height.
  static const double _glassHeight = 44;

  /// Native insets of the group's content inside its platform view (room
  /// for badges): top and right.
  static const double _nativeTopInset = 3;
  static const double _nativeRightInset = 6;

  /// Native default horizontal padding of each button (12 + 12).
  static const double _buttonPadding = 24;

  static const double _stageWidth = 300;
  static const double _slotWidth = 180;
  static const double _navSlotWidth = 140;
  static const double _captionHeight = 22;
  static const double _railGap = 2;

  static const double _groupSlotTop = _captionHeight;
  static const double _groupGlassTop = _groupSlotTop + _nativeTopInset;
  static const double _controlCaptionTop = _groupGlassTop + _glassHeight + 26;
  static const double _controlTop = _controlCaptionTop + _captionHeight;
  static const double _stageHeight = _controlTop + _glassHeight + 16;

  /// Slot left edge that puts the group's centre — the centre of the slot
  /// minus the right inset — on the stage's centre line.
  static const double _groupSlotLeft =
      (_stageWidth - (_slotWidth - _nativeRightInset)) / 2;

  /// Rails: `_railGap` outside the expected top and bottom edge of the
  /// group's glass and of the control.
  static const List<double> _railYs = <double>[
    _groupGlassTop - _railGap,
    _groupGlassTop + _glassHeight + _railGap,
    _controlTop - _railGap,
    _controlTop + _glassHeight + _railGap,
  ];

  _Backdrop _backdrop = _Backdrop.dark;
  _Variant _variant = _Variant.popupIcon;
  double _spacing = _defaultSpacing;
  double _iconSize = _defaultIconSize;
  double _blend = _defaultBlend;
  bool _union = false;
  bool _rails = true;

  /// The reporter's `currentView`; the popup's selection switches it.
  _View _view = _View.list;
  int _searchTaps = 0;

  bool get _isDefaults =>
      _variant == _Variant.popupIcon &&
      _spacing == _defaultSpacing &&
      _iconSize == _defaultIconSize &&
      _blend == _defaultBlend &&
      !_union;

  /// Everything a native view is created with. Part of every native key, so
  /// any change recreates the views (see the class doc for why).
  String get _configKey =>
      '${_backdrop.name}|${_variant.name}|$_spacing|$_iconSize|$_blend|'
      '$_union';

  Color get _foreground => _backdrop == _Backdrop.light
      ? CupertinoColors.black
      : CupertinoColors.white;

  double get _controlWidth => 2 * (_iconSize * 1.2 + _buttonPadding) + _spacing;

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: _backdrop == _Backdrop.light
            ? Brightness.light
            : Brightness.dark,
      ),
      // The Builder's context is below the page theme, so the native views
      // are created with the backdrop's brightness.
      child: Builder(builder: _page),
    );
  }

  Widget _page(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: _backdrop == _Backdrop.light
          ? _lightBackdrop
          : _darkBackdrop,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Issue #50'),
        // Transparent, so the navigation-bar group sits over the same
        // backdrop as the body group.
        backgroundColor: const Color(0x00000000),
        border: null,
        enableBackgroundFilterBlur: false,
        trailing: SizedBox(width: _navSlotWidth, child: _group('nav')),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: _backdropFill()),
          Positioned.fill(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: <Widget>[
                  _controls(),
                  Center(child: _stage()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backdropFill() {
    switch (_backdrop) {
      case _Backdrop.dark:
        return const ColoredBox(color: _darkBackdrop);
      case _Backdrop.light:
        return const ColoredBox(color: _lightBackdrop);
      case _Backdrop.photo:
        return Image.asset('assets/home.jpg', fit: BoxFit.cover);
    }
  }

  /// The reporter's group, verbatim apart from the probes: popup (two items,
  /// icon follows the selection) then `magnifyingglass`.
  Widget _group(String where) {
    final CNButtonDataConfig config = CNButtonDataConfig(
      glassEffectUnionId: _union ? 'issue50-union' : null,
    );
    final CNSymbol viewIcon = CNSymbol(
      _view == _View.list ? 'list.bullet.below.rectangle' : 'calendar',
      size: _iconSize,
      color: _foreground,
    );
    return CNGlassButtonGroup(
      key: ValueKey<String>('$where|$_configKey'),
      spacing: _spacing,
      spacingForGlass: _blend,
      buttons: <CNButtonData>[
        if (_variant == _Variant.popupIcon)
          CNButtonData.popup(
            onMenuSelected: (int index) => setState(
              () => _view = index == 0 ? _View.list : _View.calendar,
            ),
            icon: viewIcon,
            popupItems: const <CNButtonDataPopupItem>[
              CNButtonDataPopupItem(label: 'Lista', sfSymbol: 'list.bullet'),
              CNButtonDataPopupItem(label: 'Calendar', sfSymbol: 'calendar'),
            ],
            config: config,
          )
        else
          CNButtonData.icon(
            onPressed: () => setState(
              () => _view = _view == _View.list ? _View.calendar : _View.list,
            ),
            icon: viewIcon,
            config: config,
          ),
        CNButtonData.icon(
          onPressed: () => setState(() => _searchTaps++),
          icon: CNSymbol(
            'magnifyingglass',
            size: _iconSize,
            color: _foreground,
          ),
          config: config,
        ),
      ],
    );
  }

  Widget _stage() {
    final double controlWidth = _controlWidth;
    return SizedBox(
      width: _stageWidth,
      height: _stageHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 0,
            top: 0,
            child: _caption('group · CNGlassButtonGroup'),
          ),
          Positioned(
            left: _groupSlotLeft,
            top: _groupSlotTop,
            width: _slotWidth,
            height: _glassHeight + _nativeTopInset,
            child: _group('body'),
          ),
          Positioned(
            left: 0,
            top: _controlCaptionTop,
            child: _caption('control · one glass capsule'),
          ),
          Positioned(
            left: (_stageWidth - controlWidth) / 2,
            top: _controlTop,
            width: controlWidth,
            height: _glassHeight,
            child: LiquidGlassContainer(
              key: ValueKey<String>('control|$_configKey'),
              config: const LiquidGlassConfig(
                effect: CNGlassEffect.regular,
                shape: CNGlassEffectShape.capsule,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          if (_rails)
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _Rails(_railYs, _railColor)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _caption(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _backdrop == _Backdrop.light
            ? const Color(0xFF3A3A3C)
            : const Color(0xCCFFFFFF),
      ),
    );
  }

  Widget _controls() {
    final String backend = PlatformVersion.shouldUseNativeGlass
        ? 'native'
        : 'fallback';
    final double effectiveBlend = _blend < _nativeBlendFloor
        ? _nativeBlendFloor
        : _blend;
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
            'Judge on defaults with rails on, then screenshot and zoom — the '
            'waist is about a point. Bug: the group pinches in between its '
            'two buttons (gap to the magenta rails wider mid-group than over '
            'each button, rim kinks at the joins) while the control\'s gap '
            'stays even. Fixed: the group\'s gap is as even as the '
            'control\'s, and search / the menu still respond.',
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
                child: CupertinoSegmentedControl<_Backdrop>(
                  groupValue: _backdrop,
                  onValueChanged: (_Backdrop v) =>
                      setState(() => _backdrop = v),
                  children: <_Backdrop, Widget>{
                    for (final _Backdrop b in _Backdrop.values)
                      b: Text(b.name, style: const TextStyle(fontSize: 12)),
                  },
                ),
              ),
              const SizedBox(width: 8),
              CupertinoSegmentedControl<bool>(
                groupValue: _rails,
                onValueChanged: (bool v) => setState(() => _rails = v),
                children: const <bool, Widget>{
                  true: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('rails', style: TextStyle(fontSize: 12)),
                  ),
                  false: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('none', style: TextStyle(fontSize: 12)),
                  ),
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: CupertinoSegmentedControl<_Variant>(
                  groupValue: _variant,
                  onValueChanged: (_Variant v) => setState(() => _variant = v),
                  children: const <_Variant, Widget>{
                    _Variant.popupIcon: Text(
                      'popup+icon',
                      style: TextStyle(fontSize: 12),
                    ),
                    _Variant.iconIcon: Text(
                      'icon+icon',
                      style: TextStyle(fontSize: 12),
                    ),
                  },
                ),
              ),
              const SizedBox(width: 8),
              CupertinoSegmentedControl<bool>(
                groupValue: _union,
                onValueChanged: (bool v) => setState(() => _union = v),
                children: const <bool, Widget>{
                  false: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('union off', style: TextStyle(fontSize: 12)),
                  ),
                  true: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('on', style: TextStyle(fontSize: 12)),
                  ),
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          _presetRow(
            'spacing',
            _spacings,
            _spacing,
            (double v) => setState(() => _spacing = v),
          ),
          const SizedBox(height: 8),
          _presetRow(
            'icon',
            _iconSizes,
            _iconSize,
            (double v) => setState(() => _iconSize = v),
          ),
          const SizedBox(height: 8),
          _presetRow(
            'blend',
            _blends,
            _blend,
            (double v) => setState(() => _blend = v),
          ),
          const SizedBox(height: 8),
          Text(
            '${_isDefaults ? 'defaults' : 'MODIFIED'} · '
            '${_variant == _Variant.popupIcon ? 'popup+icon' : 'icon+icon'} · '
            'spacing ${_spacing.toInt()} · '
            'icon ${_iconSize.toInt()} · '
            'blend ${_blend.toInt()}→${effectiveBlend.toInt()} · '
            'union ${_union ? 'on' : 'off'} · '
            'view ${_view.name} · '
            'search ×$_searchTaps · '
            'control ${_controlWidth.round()}×${_glassHeight.toInt()} · '
            '$backend',
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

  Widget _presetRow(
    String label,
    List<double> values,
    double current,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ),
        Expanded(
          child: CupertinoSegmentedControl<double>(
            groupValue: current,
            onValueChanged: onChanged,
            children: <double, Widget>{
              for (final double v in values)
                v: Text('${v.toInt()}', style: const TextStyle(fontSize: 12)),
            },
          ),
        ),
      ],
    );
  }
}

/// Full-width horizontal rails at fixed y values, drawn in Flutter above the
/// platform views. Each sits `_railGap` (2 pt) outside an expected glass
/// edge, so a uniform capsule keeps an even gap to it along its straight
/// section and a waist does not.
class _Rails extends CustomPainter {
  const _Rails(this.ys, this.color);

  final List<double> ys;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    for (final double y in ys) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_Rails oldDelegate) =>
      oldDelegate.ys != ys || oldDelegate.color != color;
}
