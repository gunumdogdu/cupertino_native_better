import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

/// PR #67 verification — `iconDataToImageBytes` pixelates thin strokes.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/67
///
/// ### The claim
///
/// `lib/utils/icon_renderer.dart` paints the glyph at 1x `fontSize` onto a
/// canvas scaled by `devicePixelRatio`, crops to the ink bounds, then
/// re-blits that crop into a `size x size` canvas "scaled to fill". Because
/// icon fonts pad their glyphs inside the em-box, the ink is *smaller* than
/// the requested `size`, so the re-blit is an **upscale** — and it is drawn
/// with a bare `Paint()`, whose `filterQuality` defaults to
/// `FilterQuality.none` (nearest neighbour). Thin strokes get jaggies.
///
/// The PR changes two things at once:
///   1. `fontSize: size * 2` **and** `canvas.scale(pixelRatio * 2)`
///   2. `Paint()..filterQuality = FilterQuality.high` on the re-blit
///
/// ### How this screen proves it
///
/// It reimplements the renderer with the two knobs separated, so each half of
/// the PR can be judged on its own:
///
///  * **current** — fontx1, canvasx1, `FilterQuality.none` (what ships today)
///  * **fq only** — fontx1, canvasx1, `FilterQuality.high`
///  * **2x linear** — fontx1, canvasx2, `FilterQuality.high`
///  * **PR #67** — fontx2, canvasx2, `FilterQuality.high`
///
/// Note the PR doubles *both* the font size and the canvas scale, so the
/// intermediate buffer is **4x linear = 16x the pixels**, not the "4x" the PR
/// description claims. That buffer is scanned pixel-by-pixel in Dart to find
/// the ink bounds, so the cost shows up in the `scan` column.
///
/// Each variant is compared against a **reference** render (fontx4, canvasx2,
/// high quality) — the closest thing to a ground-truth rasterisation at this
/// output size. `MAE` is the mean absolute alpha error against that
/// reference: lower is closer to ideal.
///
/// Tap a swatch to flip the backdrop between white and black.
class Pr67IconSupersampleTestPage extends StatefulWidget {
  const Pr67IconSupersampleTestPage({
    super.key,
    this.initialIcon,
    this.initialSize,
    this.initialOnBlack = false,
  });

  /// Preselects a glyph by its key in [_icons]. Lets a headless probe launch
  /// straight into one configuration instead of tapping through the UI.
  final String? initialIcon;
  final double? initialSize;
  final bool initialOnBlack;

  @override
  State<Pr67IconSupersampleTestPage> createState() =>
      _Pr67IconSupersampleTestPageState();
}

/// One knob configuration for the renderer under test.
class _Variant {
  const _Variant(this.name, this.fontMul, this.canvasMul, this.fq, this.note);

  final String name;
  final double fontMul;
  final double canvasMul;
  final FilterQuality fq;
  final String note;
}

/// Everything one render produced, plus what it cost.
class _Rendered {
  const _Rendered({
    required this.png,
    required this.alpha,
    required this.outputPixelSize,
    required this.scannedPixels,
    required this.renderMicros,
    required this.inkFraction,
  });

  final Uint8List png;

  /// Alpha channel of the output, row-major, `outputPixelSize` square.
  final Uint8List alpha;
  final int outputPixelSize;
  final int scannedPixels;
  final int renderMicros;

  /// Longest ink dimension as a fraction of the em box, measured on the
  /// intermediate canvas. The renderer scales the ink to FILL the output, so
  /// if this fraction moves between variants the glyph's *drawn* size moves
  /// with it — a supersampling change must not quietly resize icons.
  final double inkFraction;
}

const List<_Variant> _variants = <_Variant>[
  _Variant('current', 1.0, 1.0, FilterQuality.none, 'ships today'),
  _Variant('fq only', 1.0, 1.0, FilterQuality.high, 'filter half of the PR'),
  _Variant('2x raw', 1.0, 2.0, FilterQuality.none, 'supersample half, alone'),
  _Variant('2x linear', 1.0, 2.0, FilterQuality.high, '2x + high filter'),
  _Variant('PR #67', 2.0, 2.0, FilterQuality.high, 'font AND canvas x2'),
];

const _Variant _reference = _Variant(
  'reference',
  4.0,
  2.0,
  FilterQuality.high,
  'ground truth',
);

/// Thin-stroke glyphs — the ones the PR says are worst affected.
const Map<String, IconData> _icons = <String, IconData>{
  'chevron': CupertinoIcons.chevron_right,
  'plus': CupertinoIcons.plus,
  'check': CupertinoIcons.checkmark,
  'xmark': CupertinoIcons.xmark,
  'material close': Icons.close,
  'heart (filled)': CupertinoIcons.heart_fill,
};

class _Pr67IconSupersampleTestPageState
    extends State<Pr67IconSupersampleTestPage> {
  String _iconKey = 'chevron';
  double _size = 20;
  bool _onBlack = false;

  Map<String, _Rendered>? _results;
  _Rendered? _ref;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_icons.containsKey(widget.initialIcon)) _iconKey = widget.initialIcon!;
    if (widget.initialSize != null) _size = widget.initialSize!;
    _onBlack = widget.initialOnBlack;
    WidgetsBinding.instance.addPostFrameCallback((_) => _rerender());
  }

  Future<void> _rerender() async {
    if (_busy) return;
    setState(() => _busy = true);
    final IconData icon = _icons[_iconKey]!;
    final _Rendered? ref = await _renderVariant(icon, _size, _reference);
    final Map<String, _Rendered> out = <String, _Rendered>{};
    for (final _Variant v in _variants) {
      // Render twice and keep the second timing — the first pass pays for
      // font-atlas warmup and would slander whichever variant runs first.
      await _renderVariant(icon, _size, v);
      final _Rendered? r = await _renderVariant(icon, _size, v);
      if (r != null) out[v.name] = r;
    }
    if (!mounted) return;
    setState(() {
      _results = out;
      _ref = ref;
      _busy = false;
    });
  }

  /// Mean absolute alpha error against the reference, on a 0-255 scale.
  double? _mae(_Rendered? r) {
    final _Rendered? ref = _ref;
    if (r == null || ref == null) return null;
    if (r.alpha.length != ref.alpha.length) return null;
    int sum = 0;
    for (int i = 0; i < r.alpha.length; i++) {
      sum += (r.alpha[i] - ref.alpha[i]).abs();
    }
    return sum / r.alpha.length;
  }

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    // Probe launches preset their state; the two header cards are tall enough
    // to push the variant rows off a single screenshot.
    final bool compact = widget.initialIcon != null;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          compact
              ? 'PR #67 · $_iconKey · ${_size.toStringAsFixed(0)}pt'
              : 'PR #67: icon supersampling',
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
          children: <Widget>[
            if (!compact) _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'What to look for',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Every swatch below is the SAME output bitmap, blown up '
                    'with nearest-neighbour so you see real pixels. If the '
                    'bug is real, "current" shows blocky staircase edges on '
                    'the diagonal strokes and the rows below it are smooth.\n\n'
                    'MAE is the mean alpha error vs a ground-truth render — '
                    'lower is better. "scan" is the intermediate buffer the '
                    'renderer walks pixel-by-pixel in Dart to find the ink '
                    'bounds; that is the cost side of the trade.',
                    style: TextStyle(fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'devicePixelRatio ${dpr.toStringAsFixed(1)}  ·  '
                    'output ${(_size * dpr).ceil()}x${(_size * dpr).ceil()} px',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            if (!compact) const SizedBox(height: 12),
            if (!compact) _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Glyph',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _icons.keys.map((String k) {
                      final bool on = k == _iconKey;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _iconKey = k);
                          _rerender();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: on
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.systemGrey5.resolveFrom(
                                    context,
                                  ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            k,
                            style: TextStyle(
                              fontSize: 13,
                              color: on
                                  ? CupertinoColors.white
                                  : CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Text('size ${_size.toStringAsFixed(0)} pt'),
                      Expanded(
                        child: CupertinoSlider(
                          value: _size,
                          min: 12,
                          max: 32,
                          divisions: 20,
                          onChanged: (double v) => setState(() => _size = v),
                          onChangeEnd: (_) => _rerender(),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      const Text('backdrop'),
                      const SizedBox(width: 12),
                      CupertinoSegmentedControl<bool>(
                        groupValue: _onBlack,
                        onValueChanged: (bool v) =>
                            setState(() => _onBlack = v),
                        children: const <bool, Widget>{
                          false: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('white'),
                          ),
                          true: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('black'),
                          ),
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!compact) const SizedBox(height: 12),
            if (_busy && _results == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CupertinoActivityIndicator()),
              )
            else
              ..._variants.map(_row),
            const SizedBox(height: 12),
            if (_ref != null)
              _card(
                child: Row(
                  children: <Widget>[
                    _swatch(_ref!),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'reference — fontx4, canvasx2, high. Used only as the '
                        'MAE baseline, never shipped.',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.systemGrey,
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
  }

  /// Shrunk for probe launches so all five variant rows land in one screenshot.
  double get _swatchSize => widget.initialIcon != null ? 92 : 120;

  Widget _row(_Variant v) {
    final _Rendered? r = _results?[v.name];
    final double? mae = _mae(r);
    return Padding(
      padding: EdgeInsets.only(bottom: widget.initialIcon != null ? 6 : 12),
      child: _card(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (r != null)
              _swatch(r)
            else
              SizedBox(width: _swatchSize, height: _swatchSize),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    v.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    v.note,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _stat(
                    'font x${v.fontMul.toStringAsFixed(0)}  '
                    'canvas x${v.canvasMul.toStringAsFixed(0)}',
                  ),
                  _stat('filter ${v.fq.name}'),
                  if (r != null) ...<Widget>[
                    _stat('scan ${_fmtCount(r.scannedPixels)} px'),
                    _stat('render ${(r.renderMicros / 1000).toStringAsFixed(1)} ms'),
                  ],
                  if (mae != null)
                    _stat(
                      'MAE ${mae.toStringAsFixed(2)}',
                      strong: true,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(_Rendered r) {
    return GestureDetector(
      onTap: () => setState(() => _onBlack = !_onBlack),
      child: Container(
        width: _swatchSize,
        height: _swatchSize,
        decoration: BoxDecoration(
          color: _onBlack ? CupertinoColors.black : CupertinoColors.white,
          border: Border.all(
            color: CupertinoColors.systemGrey3.resolveFrom(context),
          ),
        ),
        alignment: Alignment.center,
        child: ColorFiltered(
          // The glyphs are rendered opaque black; invert them on the dark
          // backdrop so the edge structure stays readable either way.
          colorFilter: _onBlack
              ? const ColorFilter.matrix(<double>[
                  -1, 0, 0, 0, 255, //
                  0, -1, 0, 0, 255, //
                  0, 0, -1, 0, 255, //
                  0, 0, 0, 1, 0, //
                ])
              : const ColorFilter.mode(
                  Color(0x00000000),
                  BlendMode.dst,
                ),
          child: Image.memory(
            r.png,
            width: _swatchSize - 8,
            height: _swatchSize - 8,
            filterQuality: FilterQuality.none,
            isAntiAlias: false,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }

  Widget _stat(String s, {bool strong = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      s,
      style: TextStyle(
        fontSize: 12.5,
        fontFamily: 'Menlo',
        fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
        color: strong
            ? CupertinoColors.activeBlue
            : CupertinoColors.label.resolveFrom(context),
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: EdgeInsets.all(widget.initialIcon != null ? 8 : 14),
    decoration: BoxDecoration(
      color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );

  static String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return '$n';
  }
}

/// The same glyphs rendered by the **real** package code path.
///
/// The variant ladder above compares a reimplementation of the renderer. This
/// page instead puts `CNIcon` on screen, so whatever `iconDataToImageBytes`
/// currently does is what you see, at true device pixels and at the sizes
/// icons are actually used. Screenshot it before and after a change to
/// `lib/utils/icon_renderer.dart` to judge the difference in situ.
class Pr67NativeStripPage extends StatelessWidget {
  const Pr67NativeStripPage({super.key, this.label = ''});

  /// Stamped into the nav bar so a before/after pair is self-identifying.
  final String label;

  static const List<double> _sizes = <double>[16, 20, 24, 28, 34];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('PR #67 native · $label'),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _band(context, Brightness.light),
            _band(context, Brightness.dark),
          ],
        ),
      ),
    );
  }

  Widget _band(BuildContext context, Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    return Expanded(
      child: Container(
        width: double.infinity,
        color: dark ? CupertinoColors.black : CupertinoColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: CupertinoTheme(
          data: CupertinoTheme.of(context).copyWith(brightness: brightness),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _icons.entries.map((MapEntry<String, IconData> e) {
              return Row(
                children: <Widget>[
                  SizedBox(
                    width: 96,
                    child: Text(
                      e.key,
                      style: TextStyle(
                        fontSize: 11,
                        color: dark
                            ? CupertinoColors.systemGrey
                            : CupertinoColors.systemGrey2,
                      ),
                    ),
                  ),
                  ..._sizes.map(
                    (double s) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: CNIcon(
                        customIcon: e.value,
                        size: s,
                        color: dark
                            ? CupertinoColors.white
                            : CupertinoColors.black,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Runs every glyph through every variant and prints a table to stdout.
///
/// The visual comparison needs eyes on a screen, but the MAE and the cost
/// numbers don't — this makes them reproducible from a plain `flutter run`
/// log, on device, at the real device pixel ratio.
Future<void> pr67PrintReport({List<double> sizes = const <double>[20, 28]}) async {
  final StringBuffer out = StringBuffer();
  out.writeln('=== PR67-REPORT ===');
  out.writeln(
    'devicePixelRatio '
    '${ui.PlatformDispatcher.instance.views.first.devicePixelRatio}',
  );
  out.writeln(
    'glyph            size  variant     scan_px    ms     MAE_vs_ref  ink_frac',
  );
  for (final double size in sizes) {
    for (final MapEntry<String, IconData> e in _icons.entries) {
      final _Rendered? ref = await _renderVariant(e.value, size, _reference);
      for (final _Variant v in _variants) {
        await _renderVariant(e.value, size, v); // warm-up pass
        final _Rendered? r = await _renderVariant(e.value, size, v);
        if (r == null || ref == null) continue;
        int sum = 0;
        for (int i = 0; i < r.alpha.length; i++) {
          sum += (r.alpha[i] - ref.alpha[i]).abs();
        }
        final double mae = sum / r.alpha.length;
        out.writeln(
          '${e.key.padRight(16)} '
          '${size.toStringAsFixed(0).padLeft(4)}  '
          '${v.name.padRight(10)} '
          '${r.scannedPixels.toString().padLeft(9)} '
          '${(r.renderMicros / 1000).toStringAsFixed(1).padLeft(6)} '
          '${mae.toStringAsFixed(3).padLeft(8)} '
          '${r.inkFraction.toStringAsFixed(4).padLeft(9)}',
        );
      }
    }
  }
  out.writeln('=== PR67-REPORT-END ===');
  debugPrint(out.toString(), wrapWidth: 1000);
}

/// A knob-for-knob reimplementation of `iconDataToImageBytes`, with the two
/// things PR #67 changes exposed as parameters.
///
/// [fontMul] scales both the `TextPainter` font size and the padding (the PR
/// keeps those locked together); [canvasMul] scales the recording canvas.
/// The output bitmap is always `size * devicePixelRatio` square, exactly as
/// the shipping renderer produces.
Future<_Rendered?> _renderVariant(
  IconData iconData,
  double size,
  _Variant v,
) async {
  final Stopwatch sw = Stopwatch()..start();
  try {
    final double pixelRatio =
        ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final double canvasScale = pixelRatio * v.canvasMul;

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          inherit: false,
          color: const Color(0xFF000000),
          fontSize: size * v.fontMul,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double padding = size * v.fontMul;
    final double logicalWidth = painter.width + padding * 2;
    final double logicalHeight = painter.height + padding * 2;
    final int paddedPixelWidth = (logicalWidth * canvasScale).ceil();
    final int paddedPixelHeight = (logicalHeight * canvasScale).ceil();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)..scale(canvasScale);
    painter.paint(canvas, Offset(padding, padding));
    final ui.Image paddedImage = await recorder.endRecording().toImage(
      paddedPixelWidth,
      paddedPixelHeight,
    );

    final ByteData? rgbaData = await paddedImage.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (rgbaData == null) {
      paddedImage.dispose();
      return null;
    }
    final Uint8List rgba = rgbaData.buffer.asUint8List();

    int minX = paddedPixelWidth;
    int minY = paddedPixelHeight;
    int maxX = -1;
    int maxY = -1;
    for (int y = 0; y < paddedPixelHeight; y++) {
      final int rowOffset = y * paddedPixelWidth * 4;
      for (int x = 0; x < paddedPixelWidth; x++) {
        if (rgba[rowOffset + x * 4 + 3] != 0) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) {
      paddedImage.dispose();
      return null;
    }

    final double glyphPixelWidth = (maxX - minX + 1).toDouble();
    final double glyphPixelHeight = (maxY - minY + 1).toDouble();

    final int outputPixelSize = (size * pixelRatio).ceil();
    final double maxGlyphDim = glyphPixelWidth > glyphPixelHeight
        ? glyphPixelWidth
        : glyphPixelHeight;
    final double fitScale = outputPixelSize / maxGlyphDim;
    final double drawnWidth = glyphPixelWidth * fitScale;
    final double drawnHeight = glyphPixelHeight * fitScale;
    final double dstX = (outputPixelSize - drawnWidth) / 2.0;
    final double dstY = (outputPixelSize - drawnHeight) / 2.0;

    final ui.PictureRecorder squareRecorder = ui.PictureRecorder();
    final Canvas squareCanvas = Canvas(squareRecorder);
    squareCanvas.drawImageRect(
      paddedImage,
      Rect.fromLTWH(
        minX.toDouble(),
        minY.toDouble(),
        glyphPixelWidth,
        glyphPixelHeight,
      ),
      Rect.fromLTWH(dstX, dstY, drawnWidth, drawnHeight),
      Paint()..filterQuality = v.fq,
    );
    final ui.Image squareImage = await squareRecorder.endRecording().toImage(
      outputPixelSize,
      outputPixelSize,
    );
    paddedImage.dispose();

    final ByteData? outRgba = await squareImage.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    final ByteData? pngData = await squareImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    squareImage.dispose();
    sw.stop();
    if (pngData == null || outRgba == null) return null;

    final Uint8List flat = outRgba.buffer.asUint8List();
    final Uint8List alpha = Uint8List(outputPixelSize * outputPixelSize);
    for (int i = 0; i < alpha.length; i++) {
      alpha[i] = flat[i * 4 + 3];
    }

    return _Rendered(
      png: pngData.buffer.asUint8List(),
      alpha: alpha,
      outputPixelSize: outputPixelSize,
      scannedPixels: paddedPixelWidth * paddedPixelHeight,
      renderMicros: sw.elapsedMicroseconds,
      inkFraction: maxGlyphDim / (size * v.fontMul * canvasScale),
    );
  } catch (e) {
    debugPrint('render failed: $e');
    return null;
  }
}
