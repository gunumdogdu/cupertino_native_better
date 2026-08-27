import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #66 verification — uncoloured `imageAsset` icons don't adapt to Liquid
/// Glass, and glass buttons are force-tinted with the app accent.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/66
///
/// ### The claims
///
/// 1. An `imageAsset` supplied **without** `color` is handed to UIKit as a
///    non-template `UIImage`, so it keeps its baked pixels. On an iOS 26
///    glass button the material resolves light/dark from the *backdrop*, so a
///    black-baked glyph over a dark backdrop goes invisible (and a
///    white-baked one disappears over a light backdrop). `customIcon` and SF
///    Symbols already get `.alwaysTemplate` and don't have this problem.
/// 2. `_effectiveTint` in `button.dart` / `popup_menu_button.dart` always
///    falls back to the theme accent, so Dart never lets the native side pick
///    its own foreground for the plain `glass` style.
///
/// ### How this screen proves it
///
/// Each row puts the **same artwork** through four paths on a glass button:
/// SF Symbol, `customIcon` (IconData), `imageAsset` with no colour, and
/// `imageAsset` with an explicit colour. The left-most chip shows the raw
/// source art rendered by Flutter, so you always know what the bytes look
/// like before iOS touches them.
///
/// Flip the **backdrop** to `black` and leave brightness on `light`: that is
/// the exact condition in the report — light UI, dark backdrop, so the glass
/// resolves dark. If claim 1 holds, the black-baked `imageAsset` column
/// vanishes while the SF Symbol and `customIcon` columns stay legible.
///
/// The **multicolour** row is the regression check that matters: those bytes
/// are deliberately four different colours. Template rendering throws colour
/// away and flattens them to a silhouette. If a build shows the multicolour
/// chip as a flat blob, template-ifying by default has broken colour art.
///
/// The **accent** row watches claim 2: change the app accent from the palette
/// button on the home screen and see whether the plain-glass icons follow it.
class Pr66GlassImageAssetTintTestPage extends StatefulWidget {
  const Pr66GlassImageAssetTintTestPage({
    super.key,
    this.initialBackdrop,
    this.initialBrightness,
  });

  /// One of `black`, `white`, `photo`, `split`. Lets a headless probe launch
  /// straight into one configuration instead of tapping through the UI.
  final String? initialBackdrop;

  /// `light` or `dark`.
  final String? initialBrightness;

  @override
  State<Pr66GlassImageAssetTintTestPage> createState() =>
      _Pr66GlassImageAssetTintTestPageState();
}

enum _Backdrop { black, white, photo, mixed }

class _Pr66GlassImageAssetTintTestPageState
    extends State<Pr66GlassImageAssetTintTestPage> {
  _Backdrop _backdrop = _Backdrop.black;
  Brightness _brightness = Brightness.light;

  Uint8List? _blackGlyph;
  Uint8List? _whiteGlyph;
  Uint8List? _multicolour;

  @override
  void initState() {
    super.initState();
    switch (widget.initialBackdrop) {
      case 'black':
        _backdrop = _Backdrop.black;
      case 'white':
        _backdrop = _Backdrop.white;
      case 'photo':
        _backdrop = _Backdrop.photo;
      case 'split':
        _backdrop = _Backdrop.mixed;
    }
    if (widget.initialBrightness == 'dark') _brightness = Brightness.dark;
    if (widget.initialBrightness == 'light') _brightness = Brightness.light;
    _buildArt();
  }

  Future<void> _buildArt() async {
    final Uint8List black = await _glyphPng(
      CupertinoIcons.bookmark_fill,
      const Color(0xFF000000),
    );
    final Uint8List white = await _glyphPng(
      CupertinoIcons.bookmark_fill,
      const Color(0xFFFFFFFF),
    );
    final Uint8List multi = await _multicolourPng();
    if (!mounted) return;
    setState(() {
      _blackGlyph = black;
      _whiteGlyph = white;
      _multicolour = multi;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = _blackGlyph != null;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #66: glass icon tint'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: _backdropWidget()),
          Positioned.fill(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
                children: <Widget>[
                  // Probe launches preset their state, and the controls card
                  // is tall enough to push the rows off a screenshot.
                  if (widget.initialBackdrop == null) ...<Widget>[
                    _controls(),
                    const SizedBox(height: 12),
                  ],
                  if (!ready)
                    const Center(child: CupertinoActivityIndicator())
                  else
                    CupertinoTheme(
                      data: CupertinoTheme.of(
                        context,
                      ).copyWith(brightness: _brightness),
                      child: Column(
                        children: <Widget>[
                          _section(
                            'glass · black-baked art',
                            'Over a dark backdrop the glass resolves dark. '
                                'A black-baked, uncoloured imageAsset has '
                                'nothing to adapt with.',
                            _rowFor(_blackGlyph!, CNButtonStyle.glass),
                          ),
                          _section(
                            'glass · white-baked art',
                            'The same failure in reverse — flip the backdrop '
                                'to white.',
                            _rowFor(_whiteGlyph!, CNButtonStyle.glass),
                          ),
                          _section(
                            'glass · MULTICOLOUR art (regression check)',
                            'These bytes are four distinct colours. If the '
                                'imageAsset chip renders as one flat colour, '
                                'template rendering has destroyed the art.',
                            _rowFor(_multicolour!, CNButtonStyle.glass),
                          ),
                          _section(
                            'prominentGlass · black-baked art',
                            'prominentGlass keeps its accent fallback by '
                                'design; it should not change.',
                            _rowFor(_blackGlyph!, CNButtonStyle.prominentGlass),
                          ),
                          _section(
                            'glass · asset path (not raw bytes)',
                            'assets/icons/close.png goes through '
                                'loadFlutterAsset — a different native branch '
                                'to the byte path above.',
                            _assetPathRow(),
                          ),
                          _section(
                            'accent tracking (claim 2)',
                            'Set a loud accent from the palette button on the '
                                'home screen. Today plain-glass icons follow '
                                'the accent; PR #66 hands them to the system '
                                'instead.',
                            _accentRow(),
                          ),
                          _section(
                            'popup menu items',
                            'Open the menu: the item images take the same '
                                'template path in '
                                'CupertinoPopupMenuButtonPlatformView.',
                            _popupRow(),
                          ),
                          _section(
                            'glass button GROUP',
                            'The group renders through GlassButtonSwiftUI, '
                                'where PR #66 swaps the iconColor/tint '
                                'precedence.',
                            _groupRow(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- rows ---------------------------------------------------------------

  /// Source art, then the same art through each icon path on a glass button.
  Widget _rowFor(Uint8List bytes, CNButtonStyle style) {
    return Row(
      children: <Widget>[
        _cell('source', Image.memory(bytes, width: 22, height: 22)),
        _cell(
          'SF Symbol',
          CNButton.icon(
            icon: const CNSymbol('bookmark.fill', size: 22),
            config: CNButtonConfig(style: style),
            onPressed: () {},
          ),
        ),
        _cell(
          'customIcon',
          CNButton.icon(
            customIcon: CupertinoIcons.bookmark_fill,
            config: CNButtonConfig(style: style, customIconSize: 22),
            onPressed: () {},
          ),
        ),
        _cell(
          'imageAsset\n(no colour)',
          CNButton.icon(
            imageAsset: CNImageAsset(
              '',
              imageData: bytes,
              imageFormat: 'png',
              size: 22,
            ),
            config: CNButtonConfig(style: style),
            onPressed: () {},
          ),
        ),
        _cell(
          'imageAsset\n(explicit)',
          CNButton.icon(
            imageAsset: CNImageAsset(
              '',
              imageData: bytes,
              imageFormat: 'png',
              size: 22,
              color: CupertinoColors.systemPink,
            ),
            config: CNButtonConfig(style: style),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _assetPathRow() {
    return Row(
      children: <Widget>[
        _cell(
          'source',
          Image.asset('assets/icons/close.png', width: 22, height: 22),
        ),
        _cell(
          'no colour',
          CNButton.icon(
            imageAsset: const CNImageAsset('assets/icons/close.png', size: 22),
            config: const CNButtonConfig(style: CNButtonStyle.glass),
            onPressed: () {},
          ),
        ),
        _cell(
          'explicit',
          CNButton.icon(
            imageAsset: const CNImageAsset(
              'assets/icons/close.png',
              size: 22,
              color: CupertinoColors.systemPink,
            ),
            config: const CNButtonConfig(style: CNButtonStyle.glass),
            onPressed: () {},
          ),
        ),
        _cell(
          'svg, no colour',
          CNButton.icon(
            imageAsset: const CNImageAsset('assets/icons/home.svg', size: 22),
            config: const CNButtonConfig(style: CNButtonStyle.glass),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _accentRow() {
    return Row(
      children: <Widget>[
        _cell(
          'glass',
          CNButton.icon(
            icon: const CNSymbol('star.fill', size: 22),
            config: const CNButtonConfig(style: CNButtonStyle.glass),
            onPressed: () {},
          ),
        ),
        _cell(
          'glass + label',
          CNButton(
            label: 'Label',
            config: const CNButtonConfig(style: CNButtonStyle.glass),
            onPressed: () {},
          ),
        ),
        _cell(
          'plain',
          CNButton.icon(
            icon: const CNSymbol('star.fill', size: 22),
            config: const CNButtonConfig(style: CNButtonStyle.plain),
            onPressed: () {},
          ),
        ),
        _cell(
          'tinted',
          CNButton.icon(
            icon: const CNSymbol('star.fill', size: 22),
            config: const CNButtonConfig(style: CNButtonStyle.tinted),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _popupRow() {
    final Uint8List bytes = _blackGlyph!;
    return Row(
      children: <Widget>[
        _cell(
          'menu (bytes)',
          CNPopupMenuButton.icon(
            buttonIcon: const CNSymbol('ellipsis', size: 20),
            items: <CNPopupMenuEntry>[
              CNPopupMenuItem(
                label: 'imageAsset, no colour',
                imageAsset: CNImageAsset(
                  '',
                  imageData: bytes,
                  imageFormat: 'png',
                  size: 20,
                ),
              ),
              CNPopupMenuItem(
                label: 'imageAsset, explicit',
                imageAsset: CNImageAsset(
                  '',
                  imageData: bytes,
                  imageFormat: 'png',
                  size: 20,
                  color: CupertinoColors.systemPink,
                ),
              ),
              CNPopupMenuItem(
                label: 'multicolour asset',
                imageAsset: CNImageAsset(
                  '',
                  imageData: _multicolour!,
                  imageFormat: 'png',
                  size: 20,
                ),
              ),
              const CNPopupMenuItem(
                label: 'SF Symbol',
                icon: CNSymbol('star.fill'),
              ),
            ],
            onSelected: (_) {},
          ),
        ),
        _cell(
          'menu (path)',
          CNPopupMenuButton.icon(
            buttonIcon: const CNSymbol('ellipsis.circle', size: 20),
            items: const <CNPopupMenuEntry>[
              CNPopupMenuItem(
                label: 'close.png, no colour',
                imageAsset: CNImageAsset('assets/icons/close.png', size: 20),
              ),
              CNPopupMenuItem(
                label: 'home.svg, no colour',
                imageAsset: CNImageAsset('assets/icons/home.svg', size: 20),
              ),
            ],
            onSelected: (_) {},
          ),
        ),
      ],
    );
  }

  Widget _groupRow() {
    return Align(
      alignment: Alignment.centerLeft,
      child: CNGlassButtonGroup(
        buttons: <CNButtonData>[
          CNButtonData.icon(
            imageAsset: CNImageAsset(
              '',
              imageData: _blackGlyph!,
              imageFormat: 'png',
              size: 22,
            ),
            onPressed: () {},
          ),
          CNButtonData.icon(
            imageAsset: CNImageAsset(
              '',
              imageData: _multicolour!,
              imageFormat: 'png',
              size: 22,
            ),
            onPressed: () {},
          ),
          CNButtonData.icon(
            icon: const CNSymbol('star.fill', size: 22),
            onPressed: () {},
          ),
          CNButtonData.icon(
            icon: const CNSymbol('heart.fill', size: 22),
            tint: CupertinoColors.systemPink,
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // --- chrome -------------------------------------------------------------

  Widget _cell(String caption, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 48, child: Center(child: child)),
          const SizedBox(height: 4),
          SizedBox(
            width: 62,
            child: Text(
              caption,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                height: 1.15,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String blurb, Widget body) {
    // Probe launches drop the prose so all eight sections fit one screenshot.
    final bool compact = widget.initialBackdrop != null;
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 6 : 12),
      padding: EdgeInsets.all(compact ? 6 : 12),
      decoration: BoxDecoration(
        // Deliberately translucent: the backdrop has to reach the glass.
        color: const Color(0x14808080),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33808080)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: _onBackdropColor,
            ),
          ),
          if (!compact) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              blurb,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                color: _onBackdropColor.withValues(alpha: 0.7),
              ),
            ),
          ],
          SizedBox(height: compact ? 4 : 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: body,
          ),
        ],
      ),
    );
  }

  Color get _onBackdropColor => _backdrop == _Backdrop.white
      ? CupertinoColors.black
      : CupertinoColors.white;

  Widget _controls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'backdrop (what the glass samples)',
            style: TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 6),
          CupertinoSegmentedControl<_Backdrop>(
            groupValue: _backdrop,
            onValueChanged: (_Backdrop v) => setState(() => _backdrop = v),
            children: const <_Backdrop, Widget>{
              _Backdrop.black: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('black', style: TextStyle(fontSize: 12)),
              ),
              _Backdrop.white: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('white', style: TextStyle(fontSize: 12)),
              ),
              _Backdrop.photo: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('photo', style: TextStyle(fontSize: 12)),
              ),
              _Backdrop.mixed: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('split', style: TextStyle(fontSize: 12)),
              ),
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'CupertinoTheme brightness (what Dart tells the native side)',
            style: TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 6),
          CupertinoSegmentedControl<Brightness>(
            groupValue: _brightness,
            onValueChanged: (Brightness v) => setState(() => _brightness = v),
            children: const <Brightness, Widget>{
              Brightness.light: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('light', style: TextStyle(fontSize: 12)),
              ),
              Brightness.dark: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('dark', style: TextStyle(fontSize: 12)),
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _backdropWidget() {
    switch (_backdrop) {
      case _Backdrop.black:
        return const ColoredBox(color: CupertinoColors.black);
      case _Backdrop.white:
        return const ColoredBox(color: CupertinoColors.white);
      case _Backdrop.photo:
        return Image.asset('assets/home.jpg', fit: BoxFit.cover);
      case _Backdrop.mixed:
        // Half black, half white so one screenshot covers both failures.
        // SizedBox.expand is load-bearing: a childless ColoredBox collapses to
        // zero height under the Row's loose cross-axis constraint.
        return const Row(
          children: <Widget>[
            Expanded(
              child: ColoredBox(
                color: CupertinoColors.black,
                child: SizedBox.expand(),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: CupertinoColors.white,
                child: SizedBox.expand(),
              ),
            ),
          ],
        );
    }
  }
}

// --- runtime artwork ------------------------------------------------------

/// Renders [icon] into a 72x72 PNG with [color] baked into the pixels.
///
/// Generated at runtime so the test art is unambiguous — a pure #000000 or
/// #FFFFFF glyph, not whatever grey a checked-in asset happens to use.
Future<Uint8List> _glyphPng(IconData icon, Color color) async {
  const double px = 72;
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        inherit: false,
        fontSize: px * 0.8,
        color: color,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  painter.paint(
    canvas,
    Offset((px - painter.width) / 2, (px - painter.height) / 2),
  );
  final ui.Image image = await recorder.endRecording().toImage(
    px.toInt(),
    px.toInt(),
  );
  final ByteData? data = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Four-colour artwork — the case template rendering cannot represent.
Future<Uint8List> _multicolourPng() async {
  const double px = 72;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  const List<Color> colors = <Color>[
    Color(0xFFFF3B30),
    Color(0xFF34C759),
    Color(0xFF007AFF),
    Color(0xFFFFCC00),
  ];
  const double r = px / 4;
  final List<Offset> centres = <Offset>[
    const Offset(px * 0.3, px * 0.3),
    const Offset(px * 0.7, px * 0.3),
    const Offset(px * 0.3, px * 0.7),
    const Offset(px * 0.7, px * 0.7),
  ];
  for (int i = 0; i < 4; i++) {
    canvas.drawCircle(centres[i], r * 0.8, Paint()..color = colors[i]);
  }
  final ui.Image image = await recorder.endRecording().toImage(
    px.toInt(),
    px.toInt(),
  );
  final ByteData? data = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  image.dispose();
  return data!.buffer.asUint8List();
}
