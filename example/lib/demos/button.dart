import 'package:cupertino_native_plus/cupertino_native.dart';
import 'package:flutter/cupertino.dart';

class ButtonDemoPage extends StatefulWidget {
  const ButtonDemoPage({super.key});

  @override
  State<ButtonDemoPage> createState() => _ButtonDemoPageState();
}

class _ButtonDemoPageState extends State<ButtonDemoPage> {
  String _last = 'None';
  bool _useAlternateSvgIcons = false;

  void _set(String what) => setState(() => _last = what);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Button')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Text buttons'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                CNButton(
                  label: 'Plain',
                  onPressed: () => _set('Plain'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.plain,
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Gray',
                  onPressed: () => _set('Gray'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.gray,
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Tinted',
                  onPressed: () => _set('Tinted'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.tinted,
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Bordered',
                  onPressed: () => _set('Bordered'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.bordered,
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'BorderedProminent',
                  onPressed: () => _set('BorderedProminent'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.borderedProminent,
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Filled',
                  onPressed: () => _set('Filled'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.filled,
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Glass',
                  onPressed: () => _set('Glass'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Glass Chat',
                  imageAsset: CNImageAsset('assets/icons/chat.svg', size: 18),
                  onPressed: () => _set('Glass Chat'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    imagePadding: 10,
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(horizontal: 24),
                  ),
                ),
                CNButton(
                  label: 'ProminentGlass',
                  onPressed: () => _set('ProminentGlass'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.prominentGlass,
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Disabled',
                  onPressed: null,
                  config: const CNButtonConfig(
                    style: CNButtonStyle.bordered,
                    shrinkWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Text('Icon buttons (SF Symbols)'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                CNButton.icon(
                  icon: const CNSymbol('heart.fill', size: 18),
                  onPressed: () => _set('Icon Plain'),
                  config: const CNButtonConfig(style: CNButtonStyle.plain),
                ),
                CNButton.icon(
                  icon: const CNSymbol('heart.fill', size: 18),
                  onPressed: () => _set('Icon Gray'),
                  config: const CNButtonConfig(style: CNButtonStyle.gray),
                ),
                CNButton.icon(
                  icon: const CNSymbol('heart.fill', size: 18),
                  onPressed: () => _set('Icon Tinted'),
                  config: const CNButtonConfig(style: CNButtonStyle.tinted),
                ),
                CNButton.icon(
                  icon: const CNSymbol('heart.fill', size: 18),
                  onPressed: () => _set('Icon Bordered'),
                  config: const CNButtonConfig(style: CNButtonStyle.bordered),
                ),
                CNButton.icon(
                  icon: const CNSymbol('heart.fill', size: 18),
                  onPressed: () => _set('Icon BorderedProminent'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.borderedProminent,
                  ),
                ),
                CNButton.icon(
                  icon: const CNSymbol('heart.fill', size: 18),
                  onPressed: () => _set('Icon Filled'),
                  config: const CNButtonConfig(style: CNButtonStyle.filled),
                ),
                CNButton.icon(
                  icon: const CNSymbol('heart.fill', size: 18),
                  onPressed: () => _set('Icon Glass'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
                CNButton.icon(
                  icon: const CNSymbol('heart.fill', size: 18),
                  onPressed: () => _set('Icon ProminentGlass'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.prominentGlass,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Text('Icon buttons (Custom Icons)'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                CNButton.icon(
                  icon: const CNSymbol('house.fill', size: 18),
                  customIcon: CupertinoIcons.home, // Custom IconData!
                  onPressed: () => _set('Custom Icon Plain'),
                  config: const CNButtonConfig(style: CNButtonStyle.plain),
                ),
                CNButton.icon(
                  icon: const CNSymbol('house.fill', size: 18),
                  customIcon: CupertinoIcons.home,
                  onPressed: () => _set('Custom Icon Gray'),
                  config: const CNButtonConfig(style: CNButtonStyle.gray),
                ),
                CNButton.icon(
                  icon: const CNSymbol('house.fill', size: 18),
                  customIcon: CupertinoIcons.home,
                  onPressed: () => _set('Custom Icon Tinted'),
                  config: const CNButtonConfig(style: CNButtonStyle.tinted),
                ),
                CNButton.icon(
                  icon: const CNSymbol('house.fill', size: 18),
                  customIcon: CupertinoIcons.home,
                  onPressed: () => _set('Custom Icon Bordered'),
                  config: const CNButtonConfig(style: CNButtonStyle.bordered),
                ),
                CNButton.icon(
                  icon: const CNSymbol('house.fill', size: 18),
                  customIcon: CupertinoIcons.home,
                  onPressed: () => _set('Custom Icon Glass'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Icon buttons (SVG Assets)'),
                CupertinoButton(
                  onPressed: () {
                    setState(() {
                      _useAlternateSvgIcons = !_useAlternateSvgIcons;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: CupertinoColors.systemBlue.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _useAlternateSvgIcons ? 'Reset' : 'Switch',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                CNButton.icon(
                  icon: const CNSymbol('house.fill', size: 18),
                  imageAsset: CNImageAsset(
                    _useAlternateSvgIcons
                        ? 'assets/icons/profile.svg'
                        : 'assets/icons/home.svg',
                    size: 18,
                  ),
                  onPressed: () => _set('SVG Plain'),
                  config: const CNButtonConfig(style: CNButtonStyle.plain),
                ),
                CNButton.icon(
                  icon: const CNSymbol('house.fill', size: 18),
                  imageAsset: CNImageAsset(
                    _useAlternateSvgIcons
                        ? 'assets/icons/chat.svg'
                        : 'assets/icons/search.svg',
                    size: 18,
                  ),
                  onPressed: () => _set('SVG Gray'),
                  config: const CNButtonConfig(style: CNButtonStyle.gray),
                ),
                CNButton.icon(
                  icon: const CNSymbol('house.fill', size: 18),
                  imageAsset: CNImageAsset(
                    _useAlternateSvgIcons
                        ? 'assets/icons/home.svg'
                        : 'assets/icons/profile.svg',
                    size: 18,
                  ),
                  onPressed: () => _set('SVG Tinted'),
                  config: const CNButtonConfig(style: CNButtonStyle.tinted),
                ),
                CNButton.icon(
                  icon: const CNSymbol('house.fill', size: 18),
                  imageAsset: CNImageAsset(
                    _useAlternateSvgIcons
                        ? 'assets/icons/search.svg'
                        : 'assets/icons/chat.svg',
                    size: 18,
                  ),
                  onPressed: () => _set('SVG Bordered'),
                  config: const CNButtonConfig(style: CNButtonStyle.bordered),
                ),
                CNButton.icon(
                  icon: const CNSymbol('house.fill', size: 18),
                  imageAsset: CNImageAsset(
                    _useAlternateSvgIcons
                        ? 'assets/icons/chat.svg'
                        : 'assets/icons/home.svg',
                    size: 18,
                    color: CupertinoColors.systemRed,
                  ),
                  onPressed: () => _set('SVG Glass'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
                CNButton.icon(
                  icon: const CNSymbol('house.fill', size: 18),
                  imageAsset: CNImageAsset(
                    _useAlternateSvgIcons
                        ? 'assets/icons/profile.svg'
                        : 'assets/icons/search.svg',
                    size: 18,
                    color: CupertinoColors.systemBlue,
                  ),
                  onPressed: () => _set('SVG ProminentGlass'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.prominentGlass,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Text('Icon buttons (PNG Assets)'),
            const SizedBox(height: 12),
            const Text(
              'PNG icons with automatic format detection - no need to specify imageFormat!',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                CNButton.icon(
                  imageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 18,
                  ),
                  onPressed: () => _set('PNG Plain'),
                  config: const CNButtonConfig(style: CNButtonStyle.plain),
                ),
                CNButton.icon(
                  imageAsset: CNImageAsset('assets/icons/clock.png', size: 18),
                  onPressed: () => _set('PNG Gray'),
                  config: const CNButtonConfig(style: CNButtonStyle.gray),
                ),
                CNButton.icon(
                  imageAsset: CNImageAsset(
                    'assets/icons/clock_filled.png',
                    size: 18,
                  ),
                  onPressed: () => _set('PNG Tinted'),
                  config: const CNButtonConfig(style: CNButtonStyle.tinted),
                ),
                CNButton.icon(
                  imageAsset: CNImageAsset('assets/icons/close.png', size: 18),
                  onPressed: () => _set('PNG Bordered'),
                  config: const CNButtonConfig(style: CNButtonStyle.bordered),
                ),
                CNButton.icon(
                  imageAsset: CNImageAsset('assets/icons/coins.png', size: 18),
                  onPressed: () => _set('PNG Glass'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
                CNButton.icon(
                  imageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 18,
                    color: CupertinoColors.systemGreen,
                  ),
                  onPressed: () => _set('PNG Colored'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
                CNButton(
                  label: 'PNG with Text',
                  imageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 16,
                    color: CupertinoColors.activeGreen,
                  ),
                  tint: CupertinoColors.activeGreen,
                  onPressed: () => _set('PNG with Text'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    imagePlacement: CNImagePlacement.leading,
                    imagePadding: 8.0,
                    shrinkWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Text('Icon Buttons - Different Sizes'),
            const SizedBox(height: 12),
            const Text(
              'Icon buttons with various sizes to demonstrate flexibility',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                CNButton.icon(
                  icon: const CNSymbol('heart.fill', size: 12),
                  onPressed: () => _set('12px'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
                CNButton.icon(
                  icon: const CNSymbol('heart.fill', size: 16),
                  onPressed: () => _set('16px'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
                CNButton.icon(
                  icon: const CNSymbol('heart.fill', size: 20),
                  onPressed: () => _set('20px'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
                CNButton.icon(
                  icon: const CNSymbol('heart.fill', size: 24),
                  onPressed: () => _set('24px'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
                CNButton.icon(
                  icon: const CNSymbol('heart.fill', size: 28),
                  onPressed: () => _set('28px'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
                CNButton.icon(
                  icon: const CNSymbol('heart.fill', size: 32),
                  onPressed: () => _set('32px'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                CNButton.icon(
                  imageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 12,
                  ),
                  onPressed: () => _set('PNG 12px'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
                CNButton.icon(
                  imageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 16,
                  ),
                  onPressed: () => _set('PNG 16px'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
                CNButton.icon(
                  imageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 20,
                  ),
                  onPressed: () => _set('PNG 20px'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
                CNButton.icon(
                  imageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 24,
                  ),
                  onPressed: () => _set('PNG 24px'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
                CNButton.icon(
                  imageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 28,
                  ),
                  onPressed: () => _set('PNG 28px'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
                CNButton.icon(
                  imageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 32,
                  ),
                  onPressed: () => _set('PNG 32px'),
                  config: const CNButtonConfig(style: CNButtonStyle.glass),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Text('Adaptive Appearance - Glass Buttons'),
            const SizedBox(height: 12),
            const Text(
              'Same glass button adapts its appearance based on content behind it (like UITabBar)',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            // Light background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Light Background',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CNButton(
                    label: 'Adaptive Button',
                    icon: const CNSymbol('star.fill', size: 18),
                    onPressed: () => _set('Light BG'),
                    config: const CNButtonConfig(
                      style: CNButtonStyle.glass,
                      shrinkWrap: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Dark background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dark Background',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CNButton(
                    label: 'Adaptive Button',
                    icon: const CNSymbol('star.fill', size: 18),
                    onPressed: () => _set('Dark BG'),
                    config: const CNButtonConfig(
                      style: CNButtonStyle.glass,
                      shrinkWrap: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Colored backgrounds
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Blue BG',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CNButton.icon(
                          icon: const CNSymbol('heart.fill', size: 18),
                          onPressed: () => _set('Blue BG'),
                          config: const CNButtonConfig(
                            style: CNButtonStyle.glass,
                            shrinkWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Green BG',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CNButton.icon(
                          icon: const CNSymbol('heart.fill', size: 18),
                          onPressed: () => _set('Green BG'),
                          config: const CNButtonConfig(
                            style: CNButtonStyle.glass,
                            shrinkWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Red BG',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CNButton.icon(
                          icon: const CNSymbol('heart.fill', size: 18),
                          onPressed: () => _set('Red BG'),
                          config: const CNButtonConfig(
                            style: CNButtonStyle.glass,
                            shrinkWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Gradient-like background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CupertinoColors.systemPurple,
                    CupertinoColors.systemPink,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gradient Background',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CNButton(
                    label: 'Adaptive Button',
                    icon: const CNSymbol('sparkles', size: 18),
                    onPressed: () => _set('Gradient BG'),
                    config: const CNButtonConfig(
                      style: CNButtonStyle.glass,
                      shrinkWrap: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            const Text('Image Placement'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                CNButton(
                  label: 'Leading',
                  imageAsset: CNImageAsset('assets/icons/home.svg', size: 16),
                  onPressed: () => _set('Leading'),
                  config: const CNButtonConfig(
                    imagePlacement: CNImagePlacement.leading,
                    imagePadding: 6.0,
                    style: CNButtonStyle.glass,
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Trailing',
                  imageAsset: CNImageAsset('assets/icons/search.svg', size: 16),
                  onPressed: () => _set('Trailing'),
                  config: const CNButtonConfig(
                    imagePlacement: CNImagePlacement.trailing,
                    imagePadding: 6.0,
                    style: CNButtonStyle.glass,
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Top',
                  imageAsset: CNImageAsset(
                    'assets/icons/profile.svg',
                    size: 16,
                  ),
                  onPressed: () => _set('Top'),
                  config: const CNButtonConfig(
                    imagePlacement: CNImagePlacement.top,
                    imagePadding: 6.0,
                    style: CNButtonStyle.glass,
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Bottom',
                  imageAsset: CNImageAsset('assets/icons/chat.svg', size: 16),
                  onPressed: () => _set('Bottom'),
                  config: const CNButtonConfig(
                    imagePlacement: CNImagePlacement.bottom,
                    imagePadding: 6.0,
                    style: CNButtonStyle.glass,
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Top',
                  imageAsset: CNImageAsset(
                    'assets/icons/profile.svg',
                    size: 16,
                  ),
                  onPressed: () => _set('Top'),
                  config: const CNButtonConfig(
                    imagePlacement: CNImagePlacement.top,
                    imagePadding: 6.0,
                    style: CNButtonStyle.glass,
                    shrinkWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Text('Image Padding'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                CNButton(
                  label: 'No Padding',
                  imageAsset: CNImageAsset('assets/icons/home.svg', size: 16),
                  onPressed: () => _set('No Padding'),
                  config: const CNButtonConfig(
                    imagePlacement: CNImagePlacement.leading,
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'With Padding',
                  imageAsset: CNImageAsset('assets/icons/search.svg', size: 16),
                  onPressed: () => _set('With Padding'),
                  config: const CNButtonConfig(
                    imagePlacement: CNImagePlacement.leading,
                    imagePadding: 8.0,
                    shrinkWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Text('Horizontal Padding'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                CNButton(
                  label: 'Default',
                  onPressed: () => _set('Default'),
                  config: const CNButtonConfig(shrinkWrap: true),
                ),
                CNButton(
                  label: 'Extra Padding',
                  onPressed: () => _set('Extra Padding'),
                  config: const CNButtonConfig(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Minimal',
                  onPressed: () => _set('Minimal'),
                  config: const CNButtonConfig(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    shrinkWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Text('Liquid Glass Effects (iOS 26+)'),
            const SizedBox(height: 12),
            const Text(
              'These examples demonstrate Liquid Glass blending and morphing effects.',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            const Text('CNGlassButtonGroup - Horizontal Buttons'),
            const SizedBox(height: 12),
            const Text(
              'Using CNGlassButtonGroup for proper blending effects',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            CNGlassButtonGroup(
              axis: Axis.horizontal,
              spacing: 8.0,
              spacingForGlass: 40.0,
              buttons: [
                CNButton(
                  label: 'Home',
                  imageAsset: CNImageAsset('assets/icons/home.svg', size: 16),
                  onPressed: () => _set('Home'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    glassEffectUnionId: 'toolbar-group',
                    glassEffectId: 'toolbar-home',
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Search',
                  imageAsset: CNImageAsset('assets/icons/search.svg', size: 16),
                  onPressed: () => _set('Search'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    glassEffectUnionId: 'toolbar-group',
                    glassEffectId: 'toolbar-search',
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Profile',
                  imageAsset: CNImageAsset(
                    'assets/icons/profile.svg',
                    size: 16,
                  ),
                  onPressed: () => _set('Profile'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    glassEffectUnionId: 'toolbar-group',
                    glassEffectId: 'toolbar-profile',
                    shrinkWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('CNGlassButtonGroup - PNG Icons with Colors'),
            const SizedBox(height: 12),
            const Text(
              'PNG icons with custom colors in grouped buttons',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            CNGlassButtonGroup(
              axis: Axis.horizontal,
              spacing: 8.0,
              spacingForGlass: 40.0,
              buttons: [
                CNButton.icon(
                  imageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 18,
                    color: CupertinoColors.systemGreen,
                  ),
                  onPressed: () => _set('Check PNG'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    glassEffectUnionId: 'png-group',
                    glassEffectId: 'png-check',
                    shrinkWrap: true,
                  ),
                ),
                CNButton.icon(
                  imageAsset: CNImageAsset(
                    'assets/icons/clock.png',
                    size: 18,
                    color: CupertinoColors.systemBlue,
                  ),
                  onPressed: () => _set('Clock PNG'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    glassEffectUnionId: 'png-group',
                    glassEffectId: 'png-clock',
                    shrinkWrap: true,
                  ),
                ),
                CNButton.icon(
                  imageAsset: CNImageAsset(
                    'assets/icons/coins.png',
                    size: 18,
                    color: CupertinoColors.systemYellow,
                  ),
                  onPressed: () => _set('Coins PNG'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    glassEffectUnionId: 'png-group',
                    glassEffectId: 'png-coins',
                    shrinkWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Glass Effect Container with column of buttons - Using CNGlassButtonGroup
            const Text('Glass Effect Container - Column of Buttons'),
            const SizedBox(height: 12),
            const Text(
              'Vertical layout with proper blending',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            CNGlassButtonGroup(
              axis: Axis.vertical,
              spacing: 12.0,
              spacingForGlass: 40.0,
              buttons: [
                CNButton(
                  label: 'Option 1',
                  onPressed: () => _set('Option 1'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    glassEffectUnionId: 'menu-group',
                    glassEffectId: 'menu-option-1',
                    shrinkWrap: true,
                    borderRadius: 12.0,
                  ),
                ),
                CNButton(
                  label: 'Option 2',
                  onPressed: () => _set('Option 2'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    glassEffectUnionId: 'menu-group',
                    glassEffectId: 'menu-option-2',
                    shrinkWrap: true,
                    borderRadius: 12.0,
                  ),
                ),
                CNButton(
                  label: 'Option 3',
                  onPressed: () => _set('Option 3'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    glassEffectUnionId: 'menu-group',
                    glassEffectId: 'menu-option-3',
                    shrinkWrap: true,
                    borderRadius: 12.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Buttons with glassEffectId for morphing - Using CNGlassButtonGroup
            const Text('Glass Effect ID - Morphing Transitions'),
            const SizedBox(height: 12),
            const Text(
              'Buttons with glassEffectId can morph into each other during transitions.',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            CNGlassButtonGroup(
              axis: Axis.horizontal,
              spacing: 24.0,
              spacingForGlass: 24.0,
              buttons: [
                CNButton(
                  label: 'Morph Button 1',
                  imageAsset: CNImageAsset('assets/icons/clock.png', size: 18),
                  onPressed: () => _set('Morph Button 1'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    glassEffectId: 'morph-button',
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Morph Button 2',
                  customIcon: CupertinoIcons.star_fill,
                  onPressed: () => _set('Morph Button 2'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    glassEffectId: 'morph-button',
                    shrinkWrap: true,
                  ),
                ),
                CNButton(
                  label: 'Morph Button 3',
                  customIcon: CupertinoIcons.bookmark_fill,
                  onPressed: () => _set('Morph Button 3'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    glassEffectId: 'morph-button',
                    shrinkWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Interactive glass effects
            const Text('Interactive Glass Effects'),
            const SizedBox(height: 12),
            const Text(
              'Interactive glass effects respond to touch and pointer interactions in real time.',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                CNButton(
                  label: 'Interactive',
                  onPressed: () => _set('Interactive'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    glassEffectInteractive: true,
                    shrinkWrap: true,
                  ),
                ),
                CNButton.icon(
                  icon: const CNSymbol('hand.tap.fill', size: 18),
                  onPressed: () => _set('Interactive Icon'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    glassEffectInteractive: true,
                  ),
                ),
                CNButton(
                  label: 'Prominent Interactive',
                  onPressed: () => _set('Prominent Interactive'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.prominentGlass,
                    glassEffectInteractive: true,
                    shrinkWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Combined example: Union + ID + Interactive - Using CNGlassButtonGroup
            const Text('Combined Effects'),
            const SizedBox(height: 12),
            const Text(
              'Buttons can combine union, ID, and interactive effects.',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            CNGlassButtonGroup(
              axis: Axis.horizontal,
              spacing: 8.0,
              spacingForGlass: 40.0,
              buttons: [
                CNButton.icon(
                  icon: const CNSymbol('play.fill', size: 18),
                  onPressed: () => _set('Play'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.prominentGlass,
                    glassEffectUnionId: 'media-controls',
                    glassEffectId: 'play-button',
                    glassEffectInteractive: true,
                  ),
                ),
                CNButton.icon(
                  icon: const CNSymbol('pause.fill', size: 18),
                  onPressed: () => _set('Pause'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.prominentGlass,
                    glassEffectUnionId: 'media-controls',
                    glassEffectId: 'pause-button',
                    glassEffectInteractive: true,
                  ),
                ),
                CNButton.icon(
                  icon: const CNSymbol('stop.fill', size: 18),
                  onPressed: () => _set('Stop'),
                  config: const CNButtonConfig(
                    style: CNButtonStyle.prominentGlass,
                    glassEffectUnionId: 'media-controls',
                    glassEffectId: 'stop-button',
                    glassEffectInteractive: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Text('Parameter Change Test'),
            const SizedBox(height: 12),
            const Text(
              'Test that buttons properly update when parameters change (e.g., favorite button that changes icon and color).',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            _ParameterChangeTest(),
            const SizedBox(height: 48),
            Center(child: Text('Last pressed: $_last')),
          ],
        ),
      ),
    );
  }
}

/// Test widget that demonstrates parameter changes triggering platform view updates
class _ParameterChangeTest extends StatefulWidget {
  const _ParameterChangeTest();

  @override
  State<_ParameterChangeTest> createState() => _ParameterChangeTestState();
}

class _ParameterChangeTestState extends State<_ParameterChangeTest> {
  bool _isFavorited = false;
  int _currentImageIndex = 0;
  int _currentPngIndex = 0;
  int _currentIconIndex = 0;
  int _currentCustomIconIndex = 0;

  final List<String> _imagePaths = [
    'assets/icons/home.svg',
    'assets/icons/search.svg',
    'assets/icons/profile.svg',
    'assets/icons/chat.svg',
  ];

  final List<String> _pngPaths = [
    'assets/icons/checkcircle.png',
    'assets/icons/clock.png',
    'assets/icons/clock_filled.png',
    'assets/icons/close.png',
    'assets/icons/coins.png',
  ];

  final List<String> _iconNames = [
    'heart',
    'star',
    'bookmark',
    'bell',
  ];

  final List<IconData> _customIcons = [
    CupertinoIcons.heart,
    CupertinoIcons.star,
    CupertinoIcons.bookmark,
    CupertinoIcons.bell,
  ];

  void _toggleFavorite() {
    setState(() {
      _isFavorited = !_isFavorited;
    });
  }

  void _cycleImage() {
    setState(() {
      _currentImageIndex = (_currentImageIndex + 1) % _imagePaths.length;
    });
  }

  void _cyclePng() {
    setState(() {
      _currentPngIndex = (_currentPngIndex + 1) % _pngPaths.length;
    });
  }

  void _cycleIcon() {
    setState(() {
      _currentIconIndex = (_currentIconIndex + 1) % _iconNames.length;
    });
  }

  void _cycleCustomIcon() {
    setState(() {
      _currentCustomIconIndex = (_currentCustomIconIndex + 1) % _customIcons.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main use case: Favorite button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Favorite Button (Main Use Case)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Click the button to toggle favorite state. Icon should change from heart to heart.fill and color should change from gray to red.',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // SF Symbol version
                  CNButton.icon(
                    icon: CNSymbol(
                      _isFavorited ? 'heart.fill' : 'heart',
                      size: 20,
                      color: _isFavorited ? CupertinoColors.systemRed : CupertinoColors.secondaryLabel,
                    ),
                    onPressed: _toggleFavorite,
                    config: const CNButtonConfig(
                      style: CNButtonStyle.glass,
                    ),
                  ),
                  // Image asset version
                  CNButton.icon(
                    imageAsset: CNImageAsset(
                      _isFavorited ? 'assets/icons/checkcircle.png' : 'assets/icons/clock.png',
                      size: 20,
                      color: _isFavorited ? CupertinoColors.systemGreen : CupertinoColors.secondaryLabel,
                    ),
                    onPressed: _toggleFavorite,
                    config: const CNButtonConfig(
                      style: CNButtonStyle.glass,
                    ),
                  ),
                  // Custom icon version
                  CNButton.icon(
                    customIcon: _isFavorited ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    onPressed: _toggleFavorite,
                    config: CNButtonConfig(
                      style: CNButtonStyle.glass,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Test: SVG Image Asset Path Change
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SVG Image Asset Path Change',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap to cycle through different SVG assets. The button should update smoothly.',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CNButton.icon(
                    imageAsset: CNImageAsset(
                      _imagePaths[_currentImageIndex],
                      size: 20,
                    ),
                    onPressed: _cycleImage,
                    config: const CNButtonConfig(
                      style: CNButtonStyle.glass,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Current: ${_imagePaths[_currentImageIndex].split('/').last}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Test: PNG Image Asset Path Change
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PNG Image Asset Path Change',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap to cycle through different PNG assets. The button should update smoothly.',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CNButton.icon(
                    imageAsset: CNImageAsset(
                      _pngPaths[_currentPngIndex],
                      size: 20,
                      color: [
                        CupertinoColors.systemGreen,
                        CupertinoColors.systemBlue,
                        CupertinoColors.systemYellow,
                        CupertinoColors.systemRed,
                        CupertinoColors.systemPurple,
                        CupertinoColors.systemOrange,
                        CupertinoColors.systemPink,
                        CupertinoColors.systemBrown,
                      ][_currentPngIndex % _pngPaths.length],
                    ),
                    onPressed: _cyclePng,
                    config: const CNButtonConfig(
                      style: CNButtonStyle.glass,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Current: ${_pngPaths[_currentPngIndex].split('/').last}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Test: SF Symbol Icon Change
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SF Symbol Icon Change',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap to cycle through different SF Symbols. The button should update smoothly.',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CNButton.icon(
                    icon: CNSymbol(_iconNames[_currentIconIndex], size: 20),
                    onPressed: _cycleIcon,
                    config: const CNButtonConfig(
                      style: CNButtonStyle.glass,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Current: ${_iconNames[_currentIconIndex]}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Test: Custom Icon Change
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Custom Icon Change',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap to cycle through different custom icons. The button should update smoothly.',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CNButton.icon(
                    customIcon: _customIcons[_currentCustomIconIndex],
                    onPressed: _cycleCustomIcon,
                    config: const CNButtonConfig(
                      style: CNButtonStyle.glass,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Current: Custom Icon ${_currentCustomIconIndex + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Test: Button Group with Parameter Changes
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Button Group Parameter Changes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Test that button groups properly update when button parameters change. Tap buttons to toggle favorite state.',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 12),
              _ButtonGroupTest(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Test widget for button group parameter changes
class _ButtonGroupTest extends StatefulWidget {
  const _ButtonGroupTest();

  @override
  State<_ButtonGroupTest> createState() => _ButtonGroupTestState();
}

class _ButtonGroupTestState extends State<_ButtonGroupTest> {
  bool _homeFavorited = false;
  bool _searchFavorited = false;
  bool _profileFavorited = false;
  int _currentButtonSet = 0;

  final List<List<Map<String, dynamic>>> _buttonSets = [
    // Set 1: SVG icons
    [
      {'path': 'assets/icons/home.svg', 'label': 'Home'},
      {'path': 'assets/icons/search.svg', 'label': 'Search'},
      {'path': 'assets/icons/profile.svg', 'label': 'Profile'},
    ],
    // Set 2: PNG icons
    [
      {'path': 'assets/icons/checkcircle.png', 'label': 'Check'},
      {'path': 'assets/icons/clock.png', 'label': 'Clock'},
      {'path': 'assets/icons/coins.png', 'label': 'Coins'},
    ],
    // Set 3: SF Symbols
    [
      {'symbol': 'heart.fill', 'label': 'Heart'},
      {'symbol': 'star.fill', 'label': 'Star'},
      {'symbol': 'bookmark.fill', 'label': 'Bookmark'},
    ],
  ];

  void _toggleHomeFavorite() {
    setState(() {
      _homeFavorited = !_homeFavorited;
    });
  }

  void _toggleSearchFavorite() {
    setState(() {
      _searchFavorited = !_searchFavorited;
    });
  }

  void _toggleProfileFavorite() {
    setState(() {
      _profileFavorited = !_profileFavorited;
    });
  }

  void _cycleButtonSet() {
    setState(() {
      _currentButtonSet = (_currentButtonSet + 1) % _buttonSets.length;
      // Reset favorite states when changing button set
      _homeFavorited = false;
      _searchFavorited = false;
      _profileFavorited = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSet = _buttonSets[_currentButtonSet];
    final buttons = <CNButton>[];

    for (int i = 0; i < currentSet.length; i++) {
      final buttonData = currentSet[i];
      final isFavorited = i == 0 ? _homeFavorited : (i == 1 ? _searchFavorited : _profileFavorited);
      final onPressed = i == 0 ? _toggleHomeFavorite : (i == 1 ? _toggleSearchFavorite : _toggleProfileFavorite);

      if (buttonData.containsKey('path')) {
        // Image asset button
        buttons.add(
          CNButton(
            label: buttonData['label'] as String,
            imageAsset: CNImageAsset(
              buttonData['path'] as String,
              size: 16,
              color: isFavorited ? CupertinoColors.systemRed : null,
            ),
            onPressed: onPressed,
            config: CNButtonConfig(
              style: CNButtonStyle.glass,
              glassEffectUnionId: 'test-group',
              glassEffectId: 'test-button-$i',
              shrinkWrap: true,
            ),
          ),
        );
      } else if (buttonData.containsKey('symbol')) {
        // SF Symbol button
        buttons.add(
          CNButton(
            label: buttonData['label'] as String,
            icon: CNSymbol(
              buttonData['symbol'] as String,
              size: 16,
              color: isFavorited ? CupertinoColors.systemRed : null,
            ),
            onPressed: onPressed,
            config: CNButtonConfig(
              style: CNButtonStyle.glass,
              glassEffectUnionId: 'test-group',
              glassEffectId: 'test-button-$i',
              shrinkWrap: true,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Button set selector
        Row(
          children: [
            CNButton(
              label: 'Switch Set',
              onPressed: _cycleButtonSet,
              config: const CNButtonConfig(
                style: CNButtonStyle.glass,
                shrinkWrap: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Set ${_currentButtonSet + 1}: ${currentSet[0]['label']}, ${currentSet[1]['label']}, ${currentSet[2]['label']}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Button group
        CNGlassButtonGroup(
          axis: Axis.horizontal,
          spacing: 8.0,
          spacingForGlass: 40.0,
          buttons: buttons,
        ),
        const SizedBox(height: 12),
        // Favorite states indicator
        Text(
          'Favorites: ${_homeFavorited ? "Home " : ""}${_searchFavorited ? "Search " : ""}${_profileFavorited ? "Profile" : ""}',
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }
}
