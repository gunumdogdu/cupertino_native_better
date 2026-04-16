import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// PR #23 Test Page - Popup button support in CNGlassButtonGroup
class PR23PopupButtonGroupTestPage extends StatefulWidget {
  const PR23PopupButtonGroupTestPage({super.key});

  @override
  State<PR23PopupButtonGroupTestPage> createState() =>
      _PR23PopupButtonGroupTestPageState();
}

class _PR23PopupButtonGroupTestPageState
    extends State<PR23PopupButtonGroupTestPage> {
  final List<String> _log = [];

  void _addLog(String msg) {
    setState(() {
      _log.insert(0, msg);
      if (_log.length > 15) _log.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('PR #23 Test'),
        trailing: CNGlassButtonGroup(
          buttons: [
            CNButtonData.icon(
              icon: CNSymbol('heart'),
              onPressed: () => _addLog('Nav: heart pressed'),
            ),
            CNButtonData.popup(
              icon: CNSymbol('ellipsis'),
              popupItems: [
                const CNButtonDataPopupItem(label: 'Share', sfSymbol: 'square.and.arrow.up'),
                const CNButtonDataPopupItem(label: 'Copy', sfSymbol: 'doc.on.doc'),
                const CNButtonDataPopupItem(label: 'Delete', sfSymbol: 'trash'),
              ],
              onMenuSelected: (i) => _addLog('Nav: popup item $i selected'),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              'Test 1: Mixed group (icon + popup)',
              'Nav bar has a heart button + ellipsis popup. Tap ellipsis to see menu.',
              CNGlassButtonGroup(
                buttons: [
                  CNButtonData.icon(
                    icon: CNSymbol('square.and.arrow.up'),
                    onPressed: () => _addLog('Test1: share pressed'),
                  ),
                  CNButtonData.popup(
                    icon: CNSymbol('ellipsis.circle'),
                    popupItems: [
                      const CNButtonDataPopupItem(label: 'Edit', sfSymbol: 'pencil'),
                      const CNButtonDataPopupItem(label: 'Duplicate', sfSymbol: 'plus.square.on.square'),
                      const CNButtonDataPopupItem(label: 'Archive', sfSymbol: 'archivebox'),
                    ],
                    onMenuSelected: (i) => _addLog('Test1: popup item $i'),
                  ),
                ],
              ),
            ),
            _section(
              'Test 2: All popup buttons',
              'Three popup buttons in a group — each should open its own menu.',
              CNGlassButtonGroup(
                buttons: [
                  CNButtonData.popup(
                    icon: CNSymbol('textformat'),
                    popupItems: [
                      const CNButtonDataPopupItem(label: 'Bold', sfSymbol: 'bold'),
                      const CNButtonDataPopupItem(label: 'Italic', sfSymbol: 'italic'),
                      const CNButtonDataPopupItem(label: 'Underline', sfSymbol: 'underline'),
                    ],
                    onMenuSelected: (i) => _addLog('Test2-format: item $i'),
                  ),
                  CNButtonData.popup(
                    icon: CNSymbol('text.alignleft'),
                    popupItems: [
                      const CNButtonDataPopupItem(label: 'Left', sfSymbol: 'text.alignleft'),
                      const CNButtonDataPopupItem(label: 'Center', sfSymbol: 'text.aligncenter'),
                      const CNButtonDataPopupItem(label: 'Right', sfSymbol: 'text.alignright'),
                    ],
                    onMenuSelected: (i) => _addLog('Test2-align: item $i'),
                  ),
                  CNButtonData.popup(
                    icon: CNSymbol('list.bullet'),
                    popupItems: [
                      const CNButtonDataPopupItem(label: 'Bullet List', sfSymbol: 'list.bullet'),
                      const CNButtonDataPopupItem(label: 'Numbered', sfSymbol: 'list.number'),
                      const CNButtonDataPopupItem(label: 'Checklist', sfSymbol: 'checklist'),
                    ],
                    onMenuSelected: (i) => _addLog('Test2-list: item $i'),
                  ),
                ],
              ),
            ),
            _section(
              'Test 3: Single popup button',
              'Just one popup button alone in a group.',
              CNGlassButtonGroup(
                buttons: [
                  CNButtonData.popup(
                    icon: CNSymbol('plus'),
                    popupItems: [
                      const CNButtonDataPopupItem(label: 'New File', sfSymbol: 'doc.badge.plus'),
                      const CNButtonDataPopupItem(label: 'New Folder', sfSymbol: 'folder.badge.plus'),
                      const CNButtonDataPopupItem(label: 'Import', sfSymbol: 'square.and.arrow.down'),
                    ],
                    onMenuSelected: (i) => _addLog('Test3: item $i'),
                  ),
                ],
              ),
            ),
            _section(
              'Test 4: Popup with no SF Symbols',
              'Popup items without icons — just labels.',
              CNGlassButtonGroup(
                buttons: [
                  CNButtonData.popup(
                    icon: CNSymbol('chevron.down'),
                    popupItems: const [
                      CNButtonDataPopupItem(label: 'Option A'),
                      CNButtonDataPopupItem(label: 'Option B'),
                      CNButtonDataPopupItem(label: 'Option C'),
                    ],
                    onMenuSelected: (i) => _addLog('Test4: item $i'),
                  ),
                ],
              ),
            ),
            _section(
              'Event Log',
              'Tap buttons and popup items to see events',
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_log.isEmpty)
                      const Text('Tap buttons to see log...',
                          style: TextStyle(color: CupertinoColors.systemGrey))
                    else
                      ..._log.map((l) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(l,
                                style: const TextStyle(
                                    fontSize: 12, fontFamily: 'Menlo')),
                          )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String subtitle, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 13, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
