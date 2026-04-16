import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// Issue #28 Test Page - CNPopupMenuItem checked state
class Issue28CheckedStateTestPage extends StatefulWidget {
  const Issue28CheckedStateTestPage({super.key});

  @override
  State<Issue28CheckedStateTestPage> createState() =>
      _Issue28CheckedStateTestPageState();
}

class _Issue28CheckedStateTestPageState
    extends State<Issue28CheckedStateTestPage> {
  int _selectedSort = 0;
  int _selectedView = 1;
  final Set<int> _enabledFilters = {0, 2};

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Issue #28 Test'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              'Test 1: Single selection (radio-style)',
              'Only one sort option should have a checkmark at a time.',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonIcon: CNSymbol('arrow.up.arrow.down.circle', size: 20),
                    items: [
                      CNPopupMenuItem(
                        label: 'Name',
                        icon: const CNSymbol('textformat.abc'),
                        checked: _selectedSort == 0,
                      ),
                      CNPopupMenuItem(
                        label: 'Date',
                        icon: const CNSymbol('calendar'),
                        checked: _selectedSort == 1,
                      ),
                      CNPopupMenuItem(
                        label: 'Size',
                        icon: const CNSymbol('internaldrive'),
                        checked: _selectedSort == 2,
                      ),
                    ],
                    onSelected: (i) => setState(() => _selectedSort = i),
                  ),
                  const SizedBox(width: 12),
                  Text('Sort by: ${['Name', 'Date', 'Size'][_selectedSort]}'),
                ],
              ),
            ),
            _section(
              'Test 2: Single selection (view mode)',
              'Tap to change view mode — checkmark follows selection.',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonIcon: CNSymbol('eye', size: 20),
                    items: [
                      CNPopupMenuItem(
                        label: 'List',
                        icon: const CNSymbol('list.bullet'),
                        checked: _selectedView == 0,
                      ),
                      CNPopupMenuItem(
                        label: 'Grid',
                        icon: const CNSymbol('square.grid.2x2'),
                        checked: _selectedView == 1,
                      ),
                      CNPopupMenuItem(
                        label: 'Gallery',
                        icon: const CNSymbol('photo.on.rectangle'),
                        checked: _selectedView == 2,
                      ),
                    ],
                    onSelected: (i) => setState(() => _selectedView = i),
                  ),
                  const SizedBox(width: 12),
                  Text('View: ${['List', 'Grid', 'Gallery'][_selectedView]}'),
                ],
              ),
            ),
            _section(
              'Test 3: Multi-selection (toggle)',
              'Multiple items can be checked simultaneously.',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonIcon: CNSymbol('line.3.horizontal.decrease.circle', size: 20),
                    items: [
                      CNPopupMenuItem(
                        label: 'Photos',
                        icon: const CNSymbol('photo'),
                        checked: _enabledFilters.contains(0),
                      ),
                      CNPopupMenuItem(
                        label: 'Videos',
                        icon: const CNSymbol('video'),
                        checked: _enabledFilters.contains(1),
                      ),
                      CNPopupMenuItem(
                        label: 'Documents',
                        icon: const CNSymbol('doc'),
                        checked: _enabledFilters.contains(2),
                      ),
                    ],
                    onSelected: (i) => setState(() {
                      if (_enabledFilters.contains(i)) {
                        _enabledFilters.remove(i);
                      } else {
                        _enabledFilters.add(i);
                      }
                    }),
                  ),
                  const SizedBox(width: 12),
                  Text('Filters: ${_enabledFilters.map((i) => ['Photos', 'Videos', 'Docs'][i]).join(', ')}'),
                ],
              ),
            ),
            _section(
              'Test 4: Mixed checked + disabled',
              'Item 2 is checked but disabled.',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonIcon: CNSymbol('ellipsis.circle', size: 20),
                    items: [
                      const CNPopupMenuItem(
                        label: 'Active unchecked',
                        icon: CNSymbol('circle'),
                      ),
                      const CNPopupMenuItem(
                        label: 'Checked + disabled',
                        icon: CNSymbol('lock.fill'),
                        checked: true,
                        enabled: false,
                      ),
                      const CNPopupMenuItem(
                        label: 'Active checked',
                        icon: CNSymbol('checkmark.circle'),
                        checked: true,
                      ),
                    ],
                    onSelected: (i) => debugPrint('Test4: $i'),
                  ),
                  const SizedBox(width: 12),
                  const Text('Mixed states'),
                ],
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
