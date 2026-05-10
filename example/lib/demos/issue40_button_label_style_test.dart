import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #40 reproduction / verification:
/// "How to modify the label font size and text color of CNButton"
///
/// Today, `CNButton` has no `labelFontSize` / `labelFontFamily` /
/// `labelColor` parameters — the label is rendered natively via
/// `UIButton.Configuration` and ignores Flutter's `CupertinoTheme`
/// `textTheme.textStyle`. The user's `CupertinoTheme(...)` wrap doesn't
/// propagate.
///
/// This screen exposes interactive controls (font-size slider, label
/// color toggle, font-family input) so we can:
///   1. Confirm baseline: changes do NOT affect CNButton's label.
///   2. After we add `labelFontSize` / `labelFontFamily` / `labelColor`
///      to `CNButtonConfig`, re-run the screen and watch the same
///      controls actually change the label visually.
///
/// The final reference at the bottom shows the user's exact snippet
/// from the issue (CupertinoTheme wrap with textTheme.textStyle.fontSize:
/// 48.0) — currently no effect.
class Issue40ButtonLabelStyleTest extends StatefulWidget {
  const Issue40ButtonLabelStyleTest({super.key});

  @override
  State<Issue40ButtonLabelStyleTest> createState() =>
      _Issue40ButtonLabelStyleTestState();
}

class _Issue40ButtonLabelStyleTestState
    extends State<Issue40ButtonLabelStyleTest> {
  double _fontSize = 17;
  Color _labelColor = CupertinoColors.systemOrange;
  String _label = '1';
  // Flutter system fonts that ship by default — used for the family
  // dropdown so we don't need to register custom fonts. Empty string
  // means "use system default" (CupertinoSegmentedControl needs a
  // non-null type argument).
  String _fontFamily = '';
  static const _families = <String>['', '.SF Pro Text', 'Courier'];

  CNButtonStyle _style = CNButtonStyle.glass;

  static const _styles = <CNButtonStyle>[
    CNButtonStyle.glass,
    CNButtonStyle.prominentGlass,
    CNButtonStyle.tinted,
    CNButtonStyle.bordered,
    CNButtonStyle.borderedProminent,
    CNButtonStyle.filled,
    CNButtonStyle.gray,
    CNButtonStyle.plain,
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#40 — CNButton label style'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The button under test — sized big so font changes are
              // obvious. Currently `labelFontSize`/`labelColor`/
              // `labelFontFamily` don't exist on CNButtonConfig so the
              // controls below have no effect on this button.
              Center(
                child: CNButton(
                  label: _label,
                  tint: _labelColor,
                  onPressed: () {},
                  config: CNButtonConfig(
                    width: 220,
                    minHeight: 96,
                    style: _style,
                    labelFontSize: _fontSize,
                    labelFontFamily: _fontFamily.isEmpty ? null : _fontFamily,
                    labelColor: _labelColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Controls below: change font size / color / family. '
                'BEFORE the fix, only `tint` reaches the native label '
                '(and only for non-filled styles). AFTER the fix, '
                'fontSize / fontFamily / labelColor will all take '
                'effect on the native label.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),

              _Section(
                title: 'Font size: ${_fontSize.toStringAsFixed(0)}pt',
                child: CupertinoSlider(
                  min: 10,
                  max: 64,
                  divisions: 54,
                  value: _fontSize,
                  onChanged: (v) => setState(() => _fontSize = v),
                ),
              ),

              _Section(
                title: 'Label color',
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final c in [
                      CupertinoColors.systemOrange,
                      CupertinoColors.systemBlue,
                      CupertinoColors.systemGreen,
                      CupertinoColors.systemPink,
                      CupertinoColors.black,
                      CupertinoColors.white,
                    ])
                      _Swatch(
                        color: c,
                        selected: c.toARGB32() == _labelColor.toARGB32(),
                        onTap: () => setState(() => _labelColor = c),
                      ),
                  ],
                ),
              ),

              _Section(
                title: 'Font family',
                child: CupertinoSegmentedControl<String>(
                  groupValue: _fontFamily,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: {
                    for (final f in _families)
                      f: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          f.isEmpty ? 'system' : f,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  },
                  onValueChanged: (v) => setState(() => _fontFamily = v),
                ),
              ),

              _Section(
                title: 'Label text',
                child: CupertinoTextField(
                  placeholder: 'Type label',
                  controller: TextEditingController(
                    text: _label,
                  )..selection = TextSelection.collapsed(offset: _label.length),
                  onChanged: (v) => setState(() => _label = v),
                ),
              ),

              _Section(
                title: 'Style',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in _styles)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: CupertinoButton(
                            color: _style == s
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.systemGrey5,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            onPressed: () => setState(() => _style = s),
                            child: Text(
                              s.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: _style == s
                                    ? CupertinoColors.white
                                    : CupertinoColors.black,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? CupertinoColors.activeBlue
                : CupertinoColors.systemGrey4,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
