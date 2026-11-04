import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// CNGlassButtonGroup with SF Symbols: icon buttons merged into one glass
/// shape, labelled buttons with badges and a menu, the glass styles, and a
/// vertical group. The last press is shown at the top.
///
/// Native on iOS 26+ and macOS 26+ (SwiftUI `GlassEffectContainer`); below
/// that the group is a row of CNButtons.
class GlassButtonGroupDemoPage extends StatefulWidget {
  const GlassButtonGroupDemoPage({super.key});

  @override
  State<GlassButtonGroupDemoPage> createState() =>
      _GlassButtonGroupDemoPageState();
}

class _GlassButtonGroupDemoPageState extends State<GlassButtonGroupDemoPage> {
  String _last = 'Nothing pressed yet';
  int _inbox = 3;

  void _set(String value) {
    debugPrint('GROUP_PRESSED $value');
    setState(() => _last = value);
  }

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Glass Button Group'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            Text('Last: $_last', style: const TextStyle(fontSize: 15)),
            _caption('Icons in one glass union'),
            CNGlassButtonGroup(
              buttons: [
                for (final (name, symbol) in [
                  ('Bold', 'bold'),
                  ('Italic', 'italic'),
                  ('Underline', 'underline'),
                  ('Strikethrough', 'strikethrough'),
                ])
                  CNButtonData.icon(
                    icon: CNSymbol(symbol, size: 18),
                    onPressed: () => _set(name),
                    config: CNButtonDataConfig(
                      glassEffectUnionId: 'format',
                      glassEffectId: 'format-$symbol',
                    ),
                  ),
              ],
            ),
            _caption('A badge, a menu and a label'),
            CNGlassButtonGroup(
              buttons: [
                CNButtonData.icon(
                  icon: const CNSymbol('tray', size: 18),
                  badgeCount: _inbox,
                  onPressed: () {
                    _set('Inbox');
                    setState(() => _inbox = _inbox >= 12 ? 0 : _inbox + 4);
                  },
                ),
                CNButtonData.popup(
                  icon: const CNSymbol('arrow.up.arrow.down', size: 18),
                  popupItems: const [
                    CNButtonDataPopupItem(label: 'Date', sfSymbol: 'calendar'),
                    CNButtonDataPopupItem(label: 'Name', sfSymbol: 'textformat'),
                    CNButtonDataPopupItem(label: 'Size', sfSymbol: 'ruler'),
                  ],
                  onMenuSelected: (i) => _set('Sort by #$i'),
                ),
                CNButtonData(
                  label: 'Compose',
                  icon: const CNSymbol('square.and.pencil', size: 16),
                  onPressed: () => _set('Compose'),
                ),
              ],
            ),
            _caption('Glass, clear glass, tinted clear glass'),
            CNGlassButtonGroup(
              spacingForGlass: 0,
              buttons: [
                CNButtonData.icon(
                  icon: const CNSymbol('heart', size: 18),
                  onPressed: () => _set('Glass'),
                ),
                CNButtonData.icon(
                  icon: const CNSymbol('star', size: 18),
                  onPressed: () => _set('Clear glass'),
                  config: const CNButtonDataConfig(
                    style: CNButtonStyle.clearGlass,
                  ),
                ),
                CNButtonData.icon(
                  icon: const CNSymbol('bolt.fill', size: 18),
                  tint: CupertinoColors.systemIndigo,
                  onPressed: () => _set('Tinted'),
                  config: const CNButtonDataConfig(
                    style: CNButtonStyle.prominentClearGlass,
                  ),
                ),
                CNButtonData.icon(
                  icon: const CNSymbol('trash', size: 18),
                  enabled: false,
                  onPressed: () => _set('Disabled'),
                ),
              ],
            ),
            _caption('Vertical'),
            CNGlassButtonGroup(
              axis: Axis.vertical,
              spacing: 10,
              buttons: [
                for (final option in ['Small', 'Medium', 'Large'])
                  CNButtonData(
                    label: option,
                    onPressed: () => _set(option),
                    config: CNButtonDataConfig(
                      borderRadius: 12,
                      glassEffectUnionId: 'sizes',
                      glassEffectId: 'size-$option',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
