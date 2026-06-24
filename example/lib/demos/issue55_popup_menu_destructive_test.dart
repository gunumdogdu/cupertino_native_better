import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #55: `CNPopupMenuButton` did not expose a `isDestructive` flag.
/// You could color the icon via `iconColor`, but the LABEL stayed in
/// `CupertinoColors.label` — so a "Delete" item with a red trash icon
/// still rendered the word "Delete" in white/black text.
///
/// This screen verifies that `CNPopupMenuItem(isDestructive: true)`:
///   • on iOS 14+ adds `UIMenuElement.Attributes.destructive` →
///     the label renders in the system destructive red.
///   • on iOS 13 fallback uses `UIAlertAction.Style.destructive`.
///   • on iOS < 26 / non-iOS fallback uses
///     `CupertinoActionSheetAction(isDestructiveAction: true)`.
class Issue55PopupMenuDestructiveTest extends StatefulWidget {
  const Issue55PopupMenuDestructiveTest({super.key});

  @override
  State<Issue55PopupMenuDestructiveTest> createState() =>
      _Issue55PopupMenuDestructiveTestState();
}

class _Issue55PopupMenuDestructiveTestState
    extends State<Issue55PopupMenuDestructiveTest> {
  String _lastSelected = '—';

  void _handleSelected(List<String> labels, int index) {
    setState(() => _lastSelected = labels[index]);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#55: PopupMenu isDestructive'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tap any button below. The destructive items should render '
                'their LABEL in red (system destructive color), not just the '
                'icon.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),

              const Text(
                'Text button — File menu with Delete',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildTextMenu(),
              const SizedBox(height: 24),

              const Text(
                'Icon button — Account actions with Logout',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildIconMenu(),
              const SizedBox(height: 24),

              const Text(
                'Multiple destructive items + divider',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildMixedMenu(),

              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Last selected: ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(_lastSelected),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextMenu() {
    const labels = ['New', 'Open…', 'Save', 'Delete'];
    return CNPopupMenuButton(
      buttonLabel: 'File',
      buttonStyle: CNButtonStyle.bordered,
      items: const [
        CNPopupMenuItem(
          label: 'New',
          icon: CNSymbol('doc.badge.plus'),
        ),
        CNPopupMenuItem(
          label: 'Open…',
          icon: CNSymbol('folder'),
        ),
        CNPopupMenuItem(
          label: 'Save',
          icon: CNSymbol('square.and.arrow.down'),
        ),
        CNPopupMenuDivider(),
        // The point of this issue — Delete should be visually destructive.
        CNPopupMenuItem(
          label: 'Delete',
          icon: CNSymbol('trash'),
          isDestructive: true,
        ),
      ],
      onSelected: (i) => _handleSelected(labels, i),
    );
  }

  Widget _buildIconMenu() {
    const labels = ['Profile', 'Settings', 'Logout'];
    return CNPopupMenuButton.icon(
      buttonIcon: const CNSymbol('person.crop.circle'),
      buttonStyle: CNButtonStyle.glass,
      items: const [
        CNPopupMenuItem(
          label: 'Profile',
          icon: CNSymbol('person'),
        ),
        CNPopupMenuItem(
          label: 'Settings',
          icon: CNSymbol('gear'),
        ),
        CNPopupMenuDivider(),
        CNPopupMenuItem(
          label: 'Logout',
          icon: CNSymbol('arrow.right.square'),
          isDestructive: true,
        ),
      ],
      onSelected: (i) => _handleSelected(labels, i),
    );
  }

  Widget _buildMixedMenu() {
    const labels = [
      'View Details',
      'Edit',
      'Archive',
      'Remove from list',
      'Delete permanently',
    ];
    return CNPopupMenuButton(
      buttonLabel: 'Actions',
      buttonStyle: CNButtonStyle.tinted,
      items: const [
        CNPopupMenuItem(
          label: 'View Details',
          icon: CNSymbol('info.circle'),
        ),
        CNPopupMenuItem(
          label: 'Edit',
          icon: CNSymbol('pencil'),
        ),
        CNPopupMenuItem(
          label: 'Archive',
          icon: CNSymbol('archivebox'),
        ),
        CNPopupMenuDivider(),
        CNPopupMenuItem(
          label: 'Remove from list',
          icon: CNSymbol('minus.circle'),
          isDestructive: true,
        ),
        CNPopupMenuItem(
          label: 'Delete permanently',
          icon: CNSymbol('trash.fill'),
          isDestructive: true,
        ),
      ],
      onSelected: (i) => _handleSelected(labels, i),
    );
  }
}
