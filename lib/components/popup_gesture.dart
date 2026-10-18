import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icon.dart';
import 'popup_menu_button.dart';

/// A widget that wraps a child and shows a popup menu on long press.
///
/// Usage:
/// ```dart
/// CNPopupGesture(
///   items: [
///     CNPopupMenuItem(label: 'Copy', icon: CNSymbol('doc.on.doc')),
///     CNPopupMenuItem(label: 'Share', icon: CNSymbol('square.and.arrow.up')),
///   ],
///   onSelected: (index) => print('Selected: $index'),
///   child: Text('Long press me'),
/// )
/// ```
class CNPopupGesture extends StatelessWidget {
  /// Creates a popup gesture wrapper.
  const CNPopupGesture({
    super.key,
    required this.items,
    required this.onSelected,
    required this.child,
    this.overlayColor,
    this.enableHapticFeedback = true,
  });

  /// Menu items to show in the popup.
  final List<CNPopupMenuEntry> items;

  /// Called when an item is selected.
  final ValueChanged<int> onSelected;

  /// The widget to wrap.
  final Widget child;

  /// Color for the overlay backdrop. Defaults to semi-transparent black.
  final Color? overlayColor;

  /// Whether to provide haptic feedback on long press.
  final bool enableHapticFeedback;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showPopup(context),
      child: child,
    );
  }

  Future<void> _showPopup(BuildContext context) async {
    if (enableHapticFeedback) {
      // Provide haptic feedback on iOS
      HapticFeedback.mediumImpact();
    }

    // Get the render box of the widget
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Show popup menu with overlay
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: overlayColor ?? Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _CNPopupMenuOverlay(
          position: position,
          size: size,
          items: items,
          onSelected: (index) {
            Navigator.of(context).pop();
            onSelected(index);
          },
          animation: animation,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}

/// Internal widget that displays the popup menu overlay
class _CNPopupMenuOverlay extends StatelessWidget {
  const _CNPopupMenuOverlay({
    required this.position,
    required this.size,
    required this.items,
    required this.onSelected,
    required this.animation,
  });

  final Offset position;
  final Size size;
  final List<CNPopupMenuEntry> items;
  final ValueChanged<int> onSelected;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Calculate menu position (above the widget by default)
    const menuWidth = 220.0;
    final menuHeight = _calculateMenuHeight();

    double left = position.dx + (size.width / 2) - (menuWidth / 2);
    double top = position.dy - menuHeight - 8; // 8px gap

    // Keep menu within screen bounds
    if (left < 8) left = 8;
    if (left + menuWidth > screenSize.width - 8) {
      left = screenSize.width - menuWidth - 8;
    }

    // If menu would go above screen, show below instead
    if (top < 50) {
      top = position.dy + size.height + 8;
    }

    return Stack(
      children: [
        // Highlighted child widget
        Positioned(
          left: position.dx,
          top: position.dy,
          width: size.width,
          height: size.height,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.05).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),

        // Popup menu
        Positioned(
          left: left,
          top: top,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: menuWidth,
                decoration: BoxDecoration(
                  color: CupertinoTheme.of(
                    context,
                  ).scaffoldBackgroundColor.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildMenuItems(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _calculateMenuHeight() {
    var height = 0.0;
    for (final item in items) {
      if (item is CNPopupMenuItem) {
        height += 48.0; // Item height
      } else if (item is CNPopupMenuDivider) {
        height += 8.0; // Divider height
      }
    }
    return height;
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final widgets = <Widget>[];
    var itemIndex = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;

      if (item is CNPopupMenuItem) {
        // Captured per item: a closure over the shared counter would report
        // the final count for every item.
        final int selectedIndex = itemIndex;
        widgets.add(
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            onPressed: item.enabled ? () => onSelected(selectedIndex) : null,
            child: Row(
              children: [
                if (item.icon != null) ...[
                  CNIcon(
                    symbol: item.icon,
                    size: item.icon!.size,
                    color:
                        item.iconColor ??
                        item.icon!.color ??
                        (item.enabled
                            ? CupertinoTheme.of(context).primaryColor
                            : CupertinoColors.inactiveGray),
                  ),
                  const SizedBox(width: 12),
                ],
                if (item.customIcon != null) ...[
                  Icon(
                    item.customIcon,
                    size: 20,
                    color:
                        item.iconColor ??
                        (item.enabled
                            ? CupertinoTheme.of(context).primaryColor
                            : CupertinoColors.inactiveGray),
                  ),
                  const SizedBox(width: 12),
                ],
                if (item.checked) ...[
                  Icon(
                    CupertinoIcons.checkmark,
                    size: 16,
                    color: CupertinoTheme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: item.enabled
                          ? CupertinoTheme.of(context).textTheme.textStyle.color
                          : CupertinoColors.inactiveGray,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        if (!isLast) {
          widgets.add(
            Divider(
              height: 1,
              thickness: 0.5,
              color: CupertinoColors.separator.withValues(alpha: 0.5),
            ),
          );
        }
        itemIndex++;
      } else if (item is CNPopupMenuDivider) {
        widgets.add(
          const Divider(
            height: 8,
            thickness: 1,
            color: CupertinoColors.separator,
          ),
        );
      }
    }

    return widgets;
  }
}
