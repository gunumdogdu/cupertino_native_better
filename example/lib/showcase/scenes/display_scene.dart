import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

import '../ios_kit.dart';

/// A Display settings page built from the native controls: segmented
/// control, slider, switches, a pop-up menu and SF Symbols.
class DisplayScene extends StatefulWidget {
  const DisplayScene({super.key, this.onBrightnessChanged});

  /// Called with true for Dark, so the showcase app can switch its theme.
  final ValueChanged<bool>? onBrightnessChanged;

  @override
  State<DisplayScene> createState() => _DisplaySceneState();
}

class _DisplaySceneState extends State<DisplayScene> {
  int _appearance = 0;
  double _brightness = 0.62;
  bool _trueTone = true;
  bool _boldText = false;
  int _glass = 0;

  static const _glassNames = ['Clear', 'Tinted'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appearance == 0 &&
        CupertinoTheme.brightnessOf(context) == Brightness.dark) {
      _appearance = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return IOSPage(
      title: 'Display & Brightness',
      leading: const GlassCircleButton(symbol: 'chevron.left', label: 'Back'),
      children: [
        IOSSection(
          header: 'Appearance',
          rows: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CNSegmentedControl(
                labels: const ['Light', 'Dark', 'Automatic'],
                semanticLabel: 'Appearance',
                selectedIndex: _appearance,
                onValueChanged: (i) {
                  setState(() => _appearance = i);
                  widget.onBrightnessChanged?.call(i == 1);
                },
              ),
            ),
            IOSRow(
              title: 'Liquid Glass',
              trailing: CNPopupMenuButton(
                buttonLabel: _glassNames[_glass],
                shrinkWrap: true,
                tint: secondary,
                items: [
                  CNPopupMenuItem(
                    label: 'Clear',
                    subtitle: 'More transparent',
                    checked: _glass == 0,
                  ),
                  CNPopupMenuItem(
                    label: 'Tinted',
                    subtitle: 'Increased opacity and contrast',
                    checked: _glass == 1,
                  ),
                ],
                onSelected: (i) => setState(() => _glass = i),
              ),
            ),
          ],
          footer: 'Liquid Glass adapts to the content beneath it.',
        ),
        IOSSection(
          header: 'Brightness',
          rows: [
            SizedBox(
              height: IOS.rowHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    CNIcon(
                      symbol: CNSymbol(
                        'sun.min.fill',
                        size: 15,
                        color: secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CNSlider(
                        value: _brightness,
                        onChanged: (v) => setState(() => _brightness = v),
                        semanticLabel: 'Brightness',
                      ),
                    ),
                    const SizedBox(width: 10),
                    CNIcon(
                      symbol: CNSymbol(
                        'sun.max.fill',
                        size: 22,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IOSRow(
              title: 'True Tone',
              trailing: CNSwitch(
                value: _trueTone,
                onChanged: (v) => setState(() => _trueTone = v),
                semanticLabel: 'True Tone',
              ),
            ),
          ],
          footer:
              'Automatically adapt iPhone display based on ambient lighting '
              'conditions to make colors appear consistent in different '
              'environments.',
        ),
        IOSSection(
          rows: [
            const IOSRow(
              title: 'Night Shift',
              icon: 'moon.fill',
              iconColor: CupertinoColors.systemIndigo,
              value: 'Off',
              chevron: true,
            ),
            const IOSRow(
              title: 'Auto-Lock',
              icon: 'lock.fill',
              iconColor: CupertinoColors.systemGrey,
              value: '30 seconds',
              chevron: true,
            ),
            IOSRow(
              title: 'Bold Text',
              icon: 'bold',
              iconColor: CupertinoColors.systemBlue,
              trailing: CNSwitch(
                value: _boldText,
                onChanged: (v) => setState(() => _boldText = v),
                semanticLabel: 'Bold Text',
              ),
            ),
          ],
        ),
        const IOSSection(
          header: 'Display',
          rows: [
            IOSRow(title: 'Text Size', chevron: true),
            IOSRow(title: 'Display Zoom', value: 'Default', chevron: true),
          ],
          footer:
              'Choose a view for iPhone. Larger Text shows larger '
              'controls. Default shows more content.',
        ),
      ],
    );
  }
}
