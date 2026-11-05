import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// Bottom Navigation Test with Custom SVG Icons
/// Tests CNImageAsset icon sizing in CNTabBar
class BottomNavCustomIconsTestPage extends StatefulWidget {
  const BottomNavCustomIconsTestPage({super.key});

  @override
  State<BottomNavCustomIconsTestPage> createState() =>
      _BottomNavCustomIconsTestPageState();
}

class _BottomNavCustomIconsTestPageState
    extends State<BottomNavCustomIconsTestPage> {
  int _currentIndex = 0;
  double _iconSize = 24.0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Custom Icons Nav Test'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: Column(
        children: [
          Expanded(child: _buildCurrentScreen()),
          SafeArea(
            top: false,
            child: CNTabBar(
              iconSize: _iconSize,
              items: [
                CNTabBarItem(
                  label: 'Home',
                  imageAsset: CNImageAsset('assets/icons/home.svg'),
                  activeImageAsset: CNImageAsset(
                    'assets/icons/home_filled.svg',
                  ),
                ),
                CNTabBarItem(
                  label: 'Search',
                  imageAsset: CNImageAsset('assets/icons/search.svg'),
                  activeImageAsset: CNImageAsset(
                    'assets/icons/search-filled.svg',
                  ),
                ),
                CNTabBarItem(
                  label: 'Chat',
                  imageAsset: CNImageAsset('assets/icons/chat.svg'),
                  activeImageAsset: CNImageAsset(
                    'assets/icons/chat-filled.svg',
                  ),
                ),
                CNTabBarItem(
                  label: 'Profile',
                  imageAsset: CNImageAsset('assets/icons/profile.svg'),
                  activeImageAsset: CNImageAsset(
                    'assets/icons/profile-filled.svg',
                  ),
                ),
              ],
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return _buildSizeControl();
      case 1:
        return _buildPlaceholder(
          'Search',
          CupertinoIcons.search,
          CupertinoColors.systemOrange,
        );
      case 2:
        return _buildPlaceholder(
          'Chat',
          CupertinoIcons.chat_bubble_fill,
          CupertinoColors.systemGreen,
        );
      case 3:
        return _buildPlaceholder(
          'Profile',
          CupertinoIcons.person_fill,
          CupertinoColors.systemPurple,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSizeControl() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SVG Icon Size Control',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      onPressed: _iconSize > 15
                          ? () => setState(() => _iconSize -= 2)
                          : null,
                      child: const Text('-', style: TextStyle(fontSize: 20)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            '${_iconSize.toInt()}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'pt',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      onPressed: _iconSize < 40
                          ? () => setState(() => _iconSize += 2)
                          : null,
                      child: const Text('+', style: TextStyle(fontSize: 20)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'CNTabBar(iconSize: X) with CNImageAsset SVGs',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What to test',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('1. Increase/decrease icon size with +/- buttons'),
                Text('2. SVG icons should resize in the tab bar'),
                Text('3. Active (filled) icons should show when selected'),
                Text('4. Icons should not clip or overflow'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String title, IconData icon, Color color) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Screen switches work!',
              style: TextStyle(color: CupertinoColors.systemGrey),
            ),
          ],
        ),
      ),
    );
  }
}
