import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// PR #26 Test Page - labelFontFamily and labelFontSize for CNTabBar
class PR26TabBarFontTestPage extends StatefulWidget {
  const PR26TabBarFontTestPage({super.key});

  @override
  State<PR26TabBarFontTestPage> createState() => _PR26TabBarFontTestPageState();
}

class _PR26TabBarFontTestPageState extends State<PR26TabBarFontTestPage> {
  int _tabIndex = 0;
  String? _fontFamily;
  double? _fontSize;

  final _items = [
    CNTabBarItem(label: 'Home', icon: CNSymbol('house'), activeIcon: CNSymbol('house.fill')),
    CNTabBarItem(label: 'Search', icon: CNSymbol('magnifyingglass')),
    CNTabBarItem(label: 'Profile', icon: CNSymbol('person'), activeIcon: CNSymbol('person.fill')),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('PR #26 Test'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Tab Bar Label Font',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Font family selector
                  const Text('Font Family:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _fontButton('System Default', null),
                      _fontButton('Courier', 'Courier'),
                      _fontButton('Georgia', 'Georgia'),
                      _fontButton('Helvetica', 'Helvetica'),
                      _fontButton('Menlo', 'Menlo'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Font size selector
                  const Text('Font Size:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _sizeButton('Default', null),
                      _sizeButton('8pt', 8),
                      _sizeButton('10pt', 10),
                      _sizeButton('12pt', 12),
                      _sizeButton('14pt', 14),
                      _sizeButton('16pt', 16),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground.resolveFrom(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current font: ${_fontFamily ?? "system"}',
                            style: const TextStyle(fontSize: 13, fontFamily: 'Menlo')),
                        Text('Current size: ${_fontSize ?? "default"}',
                            style: const TextStyle(fontSize: 13, fontFamily: 'Menlo')),
                        Text('Selected tab: $_tabIndex',
                            style: const TextStyle(fontSize: 13, fontFamily: 'Menlo')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: CNTabBar(
              items: _items,
              currentIndex: _tabIndex,
              onTap: (i) => setState(() => _tabIndex = i),
              labelFontFamily: _fontFamily,
              labelFontSize: _fontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fontButton(String label, String? family) {
    final isSelected = _fontFamily == family;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isSelected ? CupertinoColors.systemBlue : CupertinoColors.systemGrey5,
      onPressed: () => setState(() => _fontFamily = family),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: isSelected ? CupertinoColors.white : CupertinoColors.label,
        ),
      ),
    );
  }

  Widget _sizeButton(String label, double? size) {
    final isSelected = _fontSize == size;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isSelected ? CupertinoColors.systemBlue : CupertinoColors.systemGrey5,
      onPressed: () => setState(() => _fontSize = size),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: isSelected ? CupertinoColors.white : CupertinoColors.label,
        ),
      ),
    );
  }
}
