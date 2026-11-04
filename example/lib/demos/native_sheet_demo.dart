import 'dart:io';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// A map-style screen with a native sheet over it: it rests collapsed to its
/// tab bar, medium or large, never closes, and keeps the screen behind it
/// usable up to medium. Four pages put a tab bar inside the sheet.
class NativeSheetDemoPage extends StatefulWidget {
  const NativeSheetDemoPage({
    super.key,
    this.autoLaunch = false,
    this.backgroundFile,
    this.avatarFiles = const [],
    this.smallDetent = CNSheetDetent.collapsed,
    this.middleDetent = CNSheetDetent.medium,
    this.startSmall = false,
    this.people = const [
      ('Alexandria', 'Brooklyn, New York · Now', '2.4 km'),
      ('Elif', 'Shoreditch, London · 5 min. ago', '5.1 km'),
    ],
    this.singlePage = false,
  });

  /// The People page's rows: name, place and distance.
  final List<(String, String, String)> people;

  /// Shows only the People page, without a tab bar.
  final bool singlePage;

  /// The sheet's smallest height.
  final CNSheetDetent smallDetent;

  /// The height the sheet opens at, between its small and large heights.
  final CNSheetDetent middleDetent;

  /// Opens the sheet at [smallDetent] instead of [middleDetent].
  final bool startSmall;

  /// Shows the sheet as soon as the page appears.
  final bool autoLaunch;

  /// An image file drawn behind the sheet instead of the built-in backdrop
  /// (screenshot comparisons).
  final String? backgroundFile;

  /// Image files for the people's photos, in place of the bundled ones.
  final List<String> avatarFiles;

  @override
  State<NativeSheetDemoPage> createState() => _NativeSheetDemoPageState();
}

class _NativeSheetDemoPageState extends State<NativeSheetDemoPage> {
  String _status = 'Sheet closed';
  int _taps = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _show());
    }
  }

  @override
  void dispose() {
    CNNativeSheet.dismiss();
    super.dispose();
  }

  CNImageAsset? _avatar(int i) {
    if (widget.avatarFiles.isEmpty) {
      const bundled = [
        'assets/showcase/avatar_a.png',
        'assets/showcase/avatar_e.png',
      ];
      return i < bundled.length ? CNImageAsset(bundled[i]) : null;
    }
    if (i >= widget.avatarFiles.length) return null;
    return CNImageAsset(
      '',
      imageData: File(widget.avatarFiles[i]).readAsBytesSync(),
      imageFormat: 'png',
    );
  }

  Future<void> _show() async {
    final isDark =
        CupertinoTheme.of(context).brightness == Brightness.dark ||
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final shown = await CNNativeSheet.show(
      pages: [
        CNSheetPage(
          title: 'People',
          sfSymbol: const CNSymbol('person.2.fill'),
          buttons: const [
            CNSheetButton(
              id: 'add',
              sfSymbol: CNSymbol('plus'),
              label: 'Share My Location',
            ),
          ],
          items: [
            for (final (i, (name, place, distance)) in widget.people.indexed)
              CNListItem(
                title: name,
                subtitle: place,
                trailingText: distance,
                leadingImage: _avatar(i),
                leadingSymbol: const CNSymbol('person.crop.circle.fill'),
              ),
          ],
        ),
        if (!widget.singlePage) ...[
          const CNSheetPage(
            title: 'Devices',
            sfSymbol: CNSymbol('macbook.and.iphone'),
            items: [
              CNListItem(
                title: 'iPhone',
                subtitle: 'With You',
                leadingSymbol: CNSymbol('iphone'),
              ),
              CNListItem(
                title: 'MacBook Pro',
                subtitle: 'Home · 5 min. ago',
                trailingText: '0 km',
                leadingSymbol: CNSymbol('laptopcomputer'),
              ),
            ],
          ),
          const CNSheetPage(
            title: 'Items',
            sfSymbol: CNSymbol('circle.circle'),
            items: [
              CNListItem(
                title: 'Keys',
                subtitle: 'Home · Now',
                leadingSymbol: CNSymbol('key.fill'),
              ),
            ],
          ),
          const CNSheetPage(title: 'Me', sfSymbol: CNSymbol('location.fill')),
        ],
      ],
      detents: [widget.smallDetent, widget.middleDetent, CNSheetDetent.large],
      initialDetent: widget.startSmall
          ? widget.smallDetent
          : widget.middleDetent,
      undimmedDetent: widget.middleDetent,
      dismissible: false,
      isDark: isDark,
      onDetentChanged: (d) => setState(() => _status = 'Detent changed'),
      onItemTap: (page, index) =>
          setState(() => _status = 'Tapped row $index on page $page'),
      onButtonTap: (page, id) => setState(() => _status = 'Tapped $id'),
      onDismissed: () => setState(() => _status = 'Sheet closed'),
    );
    if (mounted && shown) setState(() => _status = 'Sheet shown');
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.backgroundFile;
    return CupertinoPageScaffold(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (file != null)
            Image.file(File(file), fit: BoxFit.cover)
          else
            CustomPaint(
              painter: _MapPainter(
                dark:
                    MediaQuery.platformBrightnessOf(context) == Brightness.dark,
              ),
            ),
          if (file == null && !widget.autoLaunch)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CupertinoButton.filled(
                      onPressed: _show,
                      child: const Text('Show sheet'),
                    ),
                    const SizedBox(height: 12),
                    // Proves the screen behind an undimmed sheet takes taps.
                    CupertinoButton(
                      color: CupertinoColors.white,
                      onPressed: () => setState(() => _taps++),
                      child: Text(
                        'Behind the sheet: $_taps taps',
                        style: const TextStyle(color: CupertinoColors.black),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _status,
                      style: const TextStyle(color: CupertinoColors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A made-up city map behind the sheet: blocks, a river, parks, a few
/// places and the user's position.
class _MapPainter extends CustomPainter {
  const _MapPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ground = dark ? const Color(0xFF2C313C) : const Color(0xFFF1EEE8);
    final minor = dark ? const Color(0xFF3E4554) : const Color(0xFFFFFFFF);
    final major = dark ? const Color(0xFF5A6478) : const Color(0xFFFFE7A8);
    final water = dark ? const Color(0xFF233C8C) : const Color(0xFFA9CBF2);
    final park = dark ? const Color(0xFF2E5640) : const Color(0xFFCDE8C4);
    final label = dark ? const Color(0xFFA3ACBD) : const Color(0xFF6B7280);

    canvas.drawRect(Offset.zero & size, Paint()..color = ground);

    // Minor streets on a slightly turned grid.
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-0.18);
    final streets = Paint()
      ..color = minor
      ..strokeWidth = 5;
    for (var x = -w; x <= w; x += 46) {
      canvas.drawLine(Offset(x, -h), Offset(x, h), streets);
    }
    for (var y = -h; y <= h; y += 58) {
      canvas.drawLine(Offset(-w, y), Offset(w, y), streets);
    }
    canvas.restore();

    final parks = Paint()..color = park;
    for (final r in [
      Rect.fromLTWH(w * 0.06, h * 0.12, w * 0.30, h * 0.10),
      Rect.fromLTWH(w * 0.62, h * 0.50, w * 0.28, h * 0.09),
      Rect.fromLTWH(w * 0.10, h * 0.68, w * 0.22, h * 0.12),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(14)),
        parks,
      );
    }

    // The river.
    canvas.drawPath(
      Path()
        ..moveTo(-20, h * 0.40)
        ..cubicTo(w * 0.30, h * 0.34, w * 0.55, h * 0.50, w + 20, h * 0.42),
      Paint()
        ..color = water
        ..strokeWidth = 64
        ..style = PaintingStyle.stroke,
    );

    // Avenues.
    final avenues = Paint()
      ..color = major
      ..strokeWidth = 11
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-20, h * 0.30), Offset(w + 20, h * 0.18), avenues);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.70, -20)
        ..quadraticBezierTo(w * 0.52, h * 0.45, w * 0.78, h + 20),
      avenues,
    );

    void place(String text, Offset at, Color dot) {
      canvas.drawCircle(at, 9, Paint()..color = dot);
      canvas.drawCircle(
        at,
        9,
        Paint()
          ..color = ground
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: label,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, at + Offset(14, -painter.height / 2));
    }

    place(
      'Riverside Market',
      Offset(w * 0.14, h * 0.27),
      const Color(0xFFF2994A),
    );
    place('City Library', Offset(w * 0.55, h * 0.12), const Color(0xFF9B6DFF));
    place('Harbour Park', Offset(w * 0.66, h * 0.55), const Color(0xFF3FB27F));
    place('Old Town', Offset(w * 0.20, h * 0.60), const Color(0xFFE5677D));

    // The user's position.
    final me = Offset(w * 0.46, h * 0.29);
    canvas.drawCircle(me, 22, Paint()..color = const Color(0x330A84FF));
    canvas.drawCircle(me, 9, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(me, 7, Paint()..color = const Color(0xFF0A84FF));
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => oldDelegate.dark != dark;
}
