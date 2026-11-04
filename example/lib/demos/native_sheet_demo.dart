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

  /// Image files for the people's photos.
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
      detents: [
        widget.smallDetent,
        widget.middleDetent,
        CNSheetDetent.large,
      ],
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
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B3A5C), Color(0xFF2E6B4F)],
                ),
              ),
            ),
          if (file == null)
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
