// Visual regression sweep for the glass tint change that landed with PR #66.
//
// `_effectiveTint` no longer forces the theme accent for the plain `glass`
// style, so the native side can resolve its own foreground. That is a global
// change: it touches every glass CNButton and CNPopupMenuButton in every app,
// not just the ones in the PR's test screen.
//
// This entrypoint deliberately uses only long-standing public API — no demo
// imports, nothing added after v1.5.4 — so the SAME file compiles against the
// pre-PR baseline and against HEAD. Build it on both, screenshot both, diff.
//
//   flutter run -t lib/sweep_entry.dart --dart-define=LABEL=BEFORE
//
// Accent defaults to pink because the whole question is "does the accent still
// reach this surface" — a blue accent on a light glass is too easy to misread.

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;

const String _label = String.fromEnvironment('LABEL', defaultValue: '');
const String _brightness = String.fromEnvironment(
  'BRIGHTNESS',
  defaultValue: 'light',
);

/// Selects which half of the sweep to render. Without tap automation a single
/// screenshot cannot reach past the fold, so page 2 renders the trailing rows
/// on their own instead.
const int _page = int.fromEnvironment('PAGE', defaultValue: 1);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _SweepApp());
}

class _SweepApp extends StatelessWidget {
  const _SweepApp();

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      theme: CupertinoThemeData(
        brightness: _brightness == 'dark' ? Brightness.dark : Brightness.light,
        primaryColor: CupertinoColors.systemPink,
      ),
      home: const _SweepPage(),
    );
  }
}

class _SweepPage extends StatelessWidget {
  const _SweepPage();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('glass tint sweep · $_label'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: _page == 2 ? _pageTwo() : _pageOne(),
        ),
      ),
    );
  }

  List<Widget> _pageOne() {
    return <Widget>[
            _row('glass + label — THE CHANGED SURFACE', <Widget>[
              CNButton(
                label: 'Save',
                config: const CNButtonConfig(style: CNButtonStyle.glass),
                onPressed: () {},
              ),
              CNButton(
                label: 'Cancel',
                config: const CNButtonConfig(style: CNButtonStyle.glass),
                onPressed: () {},
              ),
              CNButton(
                label: 'Tinted',
                tint: CupertinoColors.systemGreen,
                config: const CNButtonConfig(style: CNButtonStyle.glass),
                onPressed: () {},
              ),
            ]),
            _row('glass + icon + label', <Widget>[
              CNButton(
                label: 'Share',
                icon: const CNSymbol('square.and.arrow.up', size: 18),
                config: const CNButtonConfig(style: CNButtonStyle.glass),
                onPressed: () {},
              ),
              CNButton(
                label: 'Delete',
                icon: const CNSymbol('trash', size: 18),
                config: const CNButtonConfig(style: CNButtonStyle.glass),
                onPressed: () {},
              ),
            ]),
            _row('glass icon-only (icons were already system-coloured)', <
              Widget
            >[
              CNButton.icon(
                icon: const CNSymbol('star.fill', size: 20),
                onPressed: () {},
              ),
              CNButton.icon(
                icon: const CNSymbol('heart.fill', size: 20),
                onPressed: () {},
              ),
              CNButton.icon(
                icon: const CNSymbol('bell.fill', size: 20),
                tint: CupertinoColors.systemGreen,
                onPressed: () {},
              ),
            ]),
            _row('prominentGlass — control, must NOT change', <Widget>[
              CNButton(
                label: 'Save',
                config: const CNButtonConfig(
                  style: CNButtonStyle.prominentGlass,
                ),
                onPressed: () {},
              ),
              CNButton.icon(
                icon: const CNSymbol('star.fill', size: 20),
                config: const CNButtonConfig(
                  style: CNButtonStyle.prominentGlass,
                ),
                onPressed: () {},
              ),
            ]),
            _row('other styles — controls, must NOT change', <Widget>[
              CNButton(
                label: 'plain',
                config: const CNButtonConfig(style: CNButtonStyle.plain),
                onPressed: () {},
              ),
              CNButton(
                label: 'tinted',
                config: const CNButtonConfig(style: CNButtonStyle.tinted),
                onPressed: () {},
              ),
              CNButton(
                label: 'filled',
                config: const CNButtonConfig(style: CNButtonStyle.filled),
                onPressed: () {},
              ),
            ]),
    ];
  }

  List<Widget> _pageTwo() {
    return <Widget>[
            _row('CNPopupMenuButton, glass + label', <Widget>[
              CNPopupMenuButton(
                buttonLabel: 'Options',
                buttonStyle: CNButtonStyle.glass,
                items: const <CNPopupMenuEntry>[
                  CNPopupMenuItem(label: 'One'),
                  CNPopupMenuItem(label: 'Two'),
                ],
                onSelected: (_) {},
              ),
              CNPopupMenuButton(
                buttonLabel: 'Plain',
                buttonStyle: CNButtonStyle.plain,
                items: const <CNPopupMenuEntry>[
                  CNPopupMenuItem(label: 'One'),
                ],
                onSelected: (_) {},
              ),
            ]),
            _row('CNGlassButtonGroup', <Widget>[
              CNGlassButtonGroup(
                buttons: <CNButtonData>[
                  CNButtonData.icon(
                    icon: const CNSymbol('star.fill', size: 20),
                    onPressed: () {},
                  ),
                  CNButtonData.icon(
                    icon: const CNSymbol('heart.fill', size: 20),
                    onPressed: () {},
                  ),
                  CNButtonData.icon(
                    icon: const CNSymbol('bell.fill', size: 20),
                    tint: CupertinoColors.systemGreen,
                    onPressed: () {},
                  ),
                ],
              ),
            ]),
    ];
  }

  Widget _row(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 10, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}
