import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

class PopupMenuButtonDemoPage extends StatefulWidget {
  const PopupMenuButtonDemoPage({super.key});

  @override
  State<PopupMenuButtonDemoPage> createState() =>
      _PopupMenuButtonDemoPageState();
}

class _PopupMenuButtonDemoPageState extends State<PopupMenuButtonDemoPage> {
  int? _lastSelected;
  List<int>? _lastPath;
  bool _useAlternateSvgIcons = false;
  bool _showPreview = true;

  /// Shows the index a menu reported, and prints it for the macOS probe
  /// (`lib/mac_popup_probe_entry.dart`).
  void _onSelected(String menu, int index) {
    debugPrint('CNB_RESULT popup $menu index=$index');
    setState(() => _lastSelected = index);
  }

  /// Shows the path a menu reported, and prints it for the macOS probe.
  void _onPathSelected(String menu, List<int> path) {
    debugPrint('CNB_RESULT popup $menu path=$path');
    setState(() => _lastPath = path);
  }

  @override
  Widget build(BuildContext context) {
    // A formatting palette, a sort section shown in place, and zoom items
    // that keep the menu open.
    const layoutItems = <CNPopupMenuEntry>[
      CNPopupMenuSubmenu(
        label: 'Format',
        style: CNPopupMenuSubmenuStyle.palette,
        items: [
          CNPopupMenuItem(label: 'Bold', icon: CNSymbol('bold')),
          CNPopupMenuItem(label: 'Italic', icon: CNSymbol('italic')),
          CNPopupMenuItem(label: 'Underline', icon: CNSymbol('underline')),
          CNPopupMenuItem(
            label: 'Strikethrough',
            icon: CNSymbol('strikethrough'),
          ),
        ],
      ),
      CNPopupMenuSubmenu(
        label: 'Sort by',
        style: CNPopupMenuSubmenuStyle.inline,
        elementSize: CNPopupMenuElementSize.medium,
        items: [
          CNPopupMenuItem(label: 'Name', icon: CNSymbol('textformat.abc')),
          CNPopupMenuItem(label: 'Date', icon: CNSymbol('calendar')),
          CNPopupMenuItem(label: 'Size', icon: CNSymbol('internaldrive')),
        ],
      ),
      CNPopupMenuDivider(),
      CNPopupMenuItem(
        label: 'Zoom in',
        icon: CNSymbol('plus.magnifyingglass'),
        keepsMenuPresented: true,
      ),
      CNPopupMenuItem(
        label: 'Zoom out',
        icon: CNSymbol('minus.magnifyingglass'),
        keepsMenuPresented: true,
      ),
    ];
    // One of each kind of entry, for checking a menu at a glance: a checked
    // item with a subtitle, a disabled one, a nested submenu with SVG, PNG
    // and custom icons, items with an SVG, a PNG and a coloured custom icon,
    // and a destructive one.
    final kindItems = <CNPopupMenuEntry>[
      CNPopupMenuItem(
        label: 'Show Preview',
        subtitle: 'Checked, with a subtitle',
        icon: const CNSymbol('eye'),
        checked: _showPreview,
      ),
      const CNPopupMenuItem(
        label: 'Archive',
        subtitle: 'Disabled',
        icon: CNSymbol('archivebox'),
        enabled: false,
      ),
      const CNPopupMenuDivider(),
      CNPopupMenuSubmenu(
        label: 'Move to',
        icon: const CNSymbol('folder'),
        items: [
          CNPopupMenuItem(
            label: 'Home',
            imageAsset: CNImageAsset('assets/icons/home.svg', size: 16),
          ),
          CNPopupMenuItem(
            label: 'Recents',
            imageAsset: CNImageAsset('assets/icons/clock.png', size: 16),
          ),
          const CNPopupMenuItem(
            label: 'Favourites',
            customIcon: CupertinoIcons.heart,
          ),
          const CNPopupMenuDivider(),
          const CNPopupMenuItem(label: 'Elsewhere', enabled: false),
        ],
      ),
      CNPopupMenuItem(
        label: 'Search (SVG)',
        imageAsset: CNImageAsset('assets/icons/search.svg', size: 16),
      ),
      CNPopupMenuItem(
        label: 'Coins (PNG)',
        imageAsset: CNImageAsset('assets/icons/coins.png', size: 16),
      ),
      const CNPopupMenuItem(
        label: 'Star (custom icon)',
        customIcon: CupertinoIcons.star_fill,
        iconColor: CupertinoColors.systemOrange,
      ),
      const CNPopupMenuDivider(),
      const CNPopupMenuItem(
        label: 'Delete',
        icon: CNSymbol('trash'),
        isDestructive: true,
      ),
    ];
    final items = [
      CNPopupMenuItem(label: 'New File', icon: const CNSymbol('doc', size: 18)),
      CNPopupMenuItem(
        label: 'New Folder',
        icon: const CNSymbol('folder', size: 18),
      ),
      const CNPopupMenuDivider(),
      CNPopupMenuItem(
        label: 'Rename',
        icon: const CNSymbol('rectangle.and.pencil.and.ellipsis', size: 18),
      ),
      CNPopupMenuItem(
        label: 'Delete',
        icon: const CNSymbol('trash', size: 18),
        enabled: false,
      ),
    ];

    // Items with colored icons
    final coloredItems = [
      CNPopupMenuItem(
        label: 'New File',
        icon: const CNSymbol(
          'doc.fill',
          size: 18,
          color: CupertinoColors.systemBlue,
        ),
      ),
      CNPopupMenuItem(
        label: 'New Folder',
        icon: const CNSymbol(
          'folder.fill',
          size: 18,
          color: CupertinoColors.systemYellow,
        ),
      ),
      const CNPopupMenuDivider(),
      CNPopupMenuItem(
        label: 'Share',
        icon: const CNSymbol(
          'square.and.arrow.up',
          size: 18,
          color: CupertinoColors.systemGreen,
        ),
      ),
      CNPopupMenuItem(
        label: 'Delete',
        icon: const CNSymbol(
          'trash.fill',
          size: 18,
          color: CupertinoColors.systemRed,
        ),
      ),
    ];

    final customIconItems = [
      CNPopupMenuItem(
        label: 'Home',
        customIcon: CupertinoIcons.home, // Custom IconData!
        iconColor: CupertinoColors.systemBlue, // Tint the custom icon blue!
      ),
      CNPopupMenuItem(
        label: 'Profile',
        icon: const CNSymbol(
          'person',
          size: 18,
          color: CupertinoColors.systemPurple,
        ),
      ),
      const CNPopupMenuDivider(),
      CNPopupMenuItem(
        label: 'Settings',
        customIcon: CupertinoIcons.settings,
        iconColor: CupertinoColors
            .systemOrange, // Different icon with different color!
      ),
    ];

    final svgItems = [
      CNPopupMenuItem(
        label: 'Home',
        imageAsset: CNImageAsset(
          _useAlternateSvgIcons
              ? 'assets/icons/profile.svg'
              : 'assets/icons/home.svg',
          size: 18,
        ),
      ),
      CNPopupMenuItem(
        label: 'Search',
        imageAsset: CNImageAsset(
          _useAlternateSvgIcons
              ? 'assets/icons/chat.svg'
              : 'assets/icons/search.svg',
          size: 18,
        ),
      ),
      const CNPopupMenuDivider(),
      CNPopupMenuItem(
        label: 'Profile',
        imageAsset: CNImageAsset(
          _useAlternateSvgIcons
              ? 'assets/icons/home.svg'
              : 'assets/icons/profile.svg',
          size: 18,
        ),
      ),
      CNPopupMenuItem(
        label: 'Chat',
        imageAsset: CNImageAsset(
          _useAlternateSvgIcons
              ? 'assets/icons/search.svg'
              : 'assets/icons/chat.svg',
          size: 18,
        ),
      ),
    ];

    final coloredSvgItems = [
      CNPopupMenuItem(
        label: 'Home',
        imageAsset: CNImageAsset(
          _useAlternateSvgIcons
              ? 'assets/icons/profile.svg'
              : 'assets/icons/home.svg',
          size: 18,
          color: CupertinoColors.systemBlue,
        ),
      ),
      CNPopupMenuItem(
        label: 'Search',
        imageAsset: CNImageAsset(
          _useAlternateSvgIcons
              ? 'assets/icons/chat.svg'
              : 'assets/icons/search.svg',
          size: 18,
          color: CupertinoColors.systemGreen,
        ),
      ),
      const CNPopupMenuDivider(),
      CNPopupMenuItem(
        label: 'Profile',
        imageAsset: CNImageAsset(
          _useAlternateSvgIcons
              ? 'assets/icons/home.svg'
              : 'assets/icons/profile.svg',
          size: 18,
          color: CupertinoColors.systemPurple,
        ),
      ),
      CNPopupMenuItem(
        label: 'Chat',
        imageAsset: CNImageAsset(
          _useAlternateSvgIcons
              ? 'assets/icons/search.svg'
              : 'assets/icons/chat.svg',
          size: 18,
          color: CupertinoColors.systemRed,
        ),
      ),
    ];

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Popup Menu Button'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Text button'),
                Spacer(),
                CNPopupMenuButton(
                  buttonLabel: 'Actions',
                  items: items,
                  onSelected: (index) => _onSelected('actions', index),
                  buttonStyle: CNButtonStyle.plain,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Icon button'),
                Spacer(),
                CNPopupMenuButton.icon(
                  buttonIcon: const CNSymbol('ellipsis', size: 18),
                  size: 44,
                  items: items,
                  onSelected: (index) => _onSelected('icon', index),
                  buttonStyle: CNButtonStyle.glass,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Colored icons'),
                Spacer(),
                CNPopupMenuButton.icon(
                  buttonIcon: const CNSymbol(
                    'paintbrush.fill',
                    size: 18,
                    color: CupertinoColors.systemPink,
                  ),
                  size: 44,
                  items: coloredItems,
                  onSelected: (index) => _onSelected('colored', index),
                  buttonStyle: CNButtonStyle.bordered,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Custom icon button'),
                Spacer(),
                CNPopupMenuButton.icon(
                  buttonIcon: const CNSymbol('ellipsis', size: 18),
                  buttonCustomIcon:
                      CupertinoIcons.ellipsis_circle, // Custom IconData!
                  size: 44,
                  items: customIconItems,
                  onSelected: (index) => _onSelected('custom', index),
                  buttonStyle: CNButtonStyle.tinted,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SVG menu items'),
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
                      color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: CupertinoColors.systemBlue.withValues(
                          alpha: 0.3,
                        ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CNPopupMenuButton.icon(
                  buttonIcon: const CNSymbol('ellipsis', size: 18),
                  buttonImageAsset: CNImageAsset(
                    _useAlternateSvgIcons
                        ? 'assets/icons/profile.svg'
                        : 'assets/icons/home.svg',
                    size: 18,
                  ),
                  size: 44,
                  items: svgItems,
                  onSelected: (index) => _onSelected('svg', index),
                  buttonStyle: CNButtonStyle.glass,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Colored SVG items'),
                Spacer(),
                CNPopupMenuButton.icon(
                  buttonIcon: const CNSymbol('ellipsis', size: 18),
                  buttonImageAsset: CNImageAsset(
                    _useAlternateSvgIcons
                        ? 'assets/icons/chat.svg'
                        : 'assets/icons/search.svg',
                    size: 18,
                    color: CupertinoColors.white,
                  ),
                  size: 44,
                  items: coloredSvgItems,
                  onSelected: (index) => _onSelected('colored_svg', index),
                  buttonStyle: CNButtonStyle.borderedProminent,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'PNG Menu Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CNPopupMenuButton.icon(
                  buttonIcon: const CNSymbol('ellipsis', size: 18),
                  buttonImageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 18,
                  ),
                  size: 44,
                  items: [
                    CNPopupMenuItem(
                      label: 'Check',
                      imageAsset: CNImageAsset(
                        'assets/icons/checkcircle.png',
                        size: 18,
                      ),
                    ),
                    CNPopupMenuItem(
                      label: 'Clock',
                      imageAsset: CNImageAsset(
                        'assets/icons/clock.png',
                        size: 18,
                      ),
                    ),
                    const CNPopupMenuDivider(),
                    CNPopupMenuItem(
                      label: 'Close',
                      imageAsset: CNImageAsset(
                        'assets/icons/close.png',
                        size: 18,
                      ),
                    ),
                    CNPopupMenuItem(
                      label: 'Coins',
                      imageAsset: CNImageAsset(
                        'assets/icons/coins.png',
                        size: 18,
                      ),
                    ),
                  ],
                  onSelected: (index) => _onSelected('png', index),
                  buttonStyle: CNButtonStyle.glass,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'PNG Menu Items with Colors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CNPopupMenuButton.icon(
                  buttonIcon: const CNSymbol('ellipsis', size: 18),
                  buttonImageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 18,
                    color: CupertinoColors.white,
                  ),
                  size: 44,
                  items: [
                    CNPopupMenuItem(
                      label: 'Check',
                      imageAsset: CNImageAsset(
                        'assets/icons/checkcircle.png',
                        size: 18,
                        color: CupertinoColors.systemGreen,
                      ),
                    ),
                    CNPopupMenuItem(
                      label: 'Clock',
                      imageAsset: CNImageAsset(
                        'assets/icons/clock.png',
                        size: 18,
                        color: CupertinoColors.systemOrange,
                      ),
                    ),
                    const CNPopupMenuDivider(),
                    CNPopupMenuItem(
                      label: 'Close',
                      imageAsset: CNImageAsset(
                        'assets/icons/close.png',
                        size: 18,
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                    CNPopupMenuItem(
                      label: 'Coins',
                      imageAsset: CNImageAsset(
                        'assets/icons/coins.png',
                        size: 18,
                        color: CupertinoColors.systemYellow,
                      ),
                    ),
                  ],
                  onSelected: (index) => _onSelected('colored_png', index),
                  buttonStyle: CNButtonStyle.borderedProminent,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'PNG Button Icons - Different Sizes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                CNPopupMenuButton.icon(
                  buttonImageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 12,
                  ),
                  size: 32,
                  items: [
                    CNPopupMenuItem(
                      label: 'Small',
                      imageAsset: CNImageAsset(
                        'assets/icons/checkcircle.png',
                        size: 12,
                      ),
                    ),
                  ],
                  onSelected: (index) => _onSelected('png_small', index),
                  buttonStyle: CNButtonStyle.glass,
                ),
                CNPopupMenuButton.icon(
                  buttonImageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 16,
                  ),
                  size: 36,
                  items: [
                    CNPopupMenuItem(
                      label: 'Medium',
                      imageAsset: CNImageAsset(
                        'assets/icons/checkcircle.png',
                        size: 16,
                      ),
                    ),
                  ],
                  onSelected: (index) => _onSelected('png_medium', index),
                  buttonStyle: CNButtonStyle.glass,
                ),
                CNPopupMenuButton.icon(
                  buttonImageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 20,
                  ),
                  size: 44,
                  items: [
                    CNPopupMenuItem(
                      label: 'Large',
                      imageAsset: CNImageAsset(
                        'assets/icons/checkcircle.png',
                        size: 20,
                      ),
                    ),
                  ],
                  onSelected: (index) => _onSelected('png_large', index),
                  buttonStyle: CNButtonStyle.glass,
                ),
                CNPopupMenuButton.icon(
                  buttonImageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 24,
                  ),
                  size: 48,
                  items: [
                    CNPopupMenuItem(
                      label: 'XLarge',
                      imageAsset: CNImageAsset(
                        'assets/icons/checkcircle.png',
                        size: 24,
                      ),
                    ),
                  ],
                  onSelected: (index) => _onSelected('png_xlarge', index),
                  buttonStyle: CNButtonStyle.glass,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text('Palette, inline section, kept open (2.0)'),
                ),
                CNPopupMenuButton.icon(
                  buttonIcon: const CNSymbol('textformat', size: 18),
                  size: 44,
                  items: layoutItems,
                  onPathSelected: (path) => _onPathSelected('layout', path),
                  buttonStyle: CNButtonStyle.glass,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text(
                    'Every item kind: checked, subtitle, disabled, '
                    'submenu, SVG, PNG, custom icon, destructive',
                  ),
                ),
                CNPopupMenuButton(
                  buttonLabel: 'Item kinds',
                  items: kindItems,
                  onSelected: (index) {
                    _onSelected('kinds', index);
                    if (index == 0) {
                      setState(() => _showPreview = !_showPreview);
                    }
                  },
                  onPathSelected: (path) => _onPathSelected('kinds', path),
                  buttonStyle: CNButtonStyle.bordered,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_lastPath != null)
              Center(child: Text('Selected path: $_lastPath')),
            if (_lastSelected != null)
              Center(child: Text('Selected index: $_lastSelected')),
          ],
        ),
      ),
    );
  }
}
