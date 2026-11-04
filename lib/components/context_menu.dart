import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../utils/native_context_menu.dart';
import 'popup_menu_button.dart';

/// Opens a native context menu for its [child]: a secondary click (right
/// click, two-finger click) or a Control-click on macOS, a long press on iOS.
///
/// The menu is built from the same entries as [CNPopupMenuButton] —
/// [CNPopupMenuItem] (icon, subtitle, checked, destructive, disabled),
/// [CNPopupMenuDivider] and [CNPopupMenuSubmenu] — and reports the chosen
/// item's path to [onSelected], as [CNPopupMenuButton.onPathSelected] does:
/// `[2]` is `items[2]`, `[3, 1]` the second entry of the submenu at
/// `items[3]`. Dividers count in every index.
///
/// - **macOS**: an `NSMenu` opens with its top-left corner at the pointer,
///   as every context menu on the Mac does. SF Symbol icons stay visible on
///   macOS 27, which otherwise hides menu item images. Destructive items are
///   drawn in the system red.
/// - **iOS 17.4+**: a long press opens the system `UIMenu` from the point
///   that was pressed (a secondary click with a pointer does too), with
///   Liquid Glass on iOS 26. Below iOS 17.4, which cannot open a menu
///   without a touch on its own button, the menu is shown as a
///   `CupertinoActionSheet`.
/// - **Other platforms**: the `CupertinoActionSheet` fallback of
///   [CNPopupMenuButton], opened by a long press or a secondary click.
///
/// ```dart
/// CNContextMenu(
///   items: const [
///     CNPopupMenuItem(label: 'Copy', icon: CNSymbol('doc.on.doc')),
///     CNPopupMenuItem(
///       label: 'Share',
///       subtitle: 'AirDrop, Messages, Mail',
///       icon: CNSymbol('square.and.arrow.up'),
///     ),
///     CNPopupMenuDivider(),
///     CNPopupMenuItem(
///       label: 'Delete',
///       icon: CNSymbol('trash'),
///       isDestructive: true,
///     ),
///   ],
///   onSelected: (path) => debugPrint('chose $path'),
///   child: const PhotoTile(),
/// )
/// ```
///
/// The child keeps its own gestures: a tap still reaches a button inside it.
/// Screen readers get the menu as the child's long-press action
/// (VoiceOver: double-tap and hold), opened at the child's centre.
class CNContextMenu extends StatefulWidget {
  /// Creates a native context menu region around [child].
  const CNContextMenu({
    super.key,
    required this.items,
    required this.onSelected,
    required this.child,
    this.enabled = true,
    this.enableHapticFeedback = true,
  });

  /// Entries of the menu: items, dividers and submenus.
  final List<CNPopupMenuEntry> items;

  /// Called with the path to the chosen item. Not called when the menu is
  /// closed without a choice.
  final ValueChanged<List<int>> onSelected;

  /// The region that opens the menu.
  final Widget child;

  /// Whether the menu opens. When false the child is shown as is.
  final bool enabled;

  /// Whether a long press that opens the menu gives haptic feedback (iOS).
  final bool enableHapticFeedback;

  @override
  State<CNContextMenu> createState() => CNContextMenuState();
}

/// State of a [CNContextMenu]; [showMenu] opens the menu from code.
class CNContextMenuState extends State<CNContextMenu> {
  bool _showing = false;

  /// Opens the menu at [globalPosition], or at the centre of the child when
  /// null. Does nothing while the menu is already open.
  Future<void> showMenu({Offset? globalPosition}) async {
    if (_showing || !widget.enabled || widget.items.isEmpty) return;
    final position = globalPosition ?? _centre();
    if (position == null) return;
    _showing = true;
    try {
      final path = await showNativeContextMenu(
        context,
        items: widget.items,
        globalPosition: position,
      );
      if (path != null && path.isNotEmpty && mounted) {
        widget.onSelected(List<int>.unmodifiable(path));
      }
    } finally {
      _showing = false;
    }
  }

  @override
  void dispose() {
    // A menu left open by a region that is gone could only report to no one.
    if (_showing) dismissNativeContextMenu();
    super.dispose();
  }

  Offset? _centre() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  void _onLongPress(LongPressStartDetails details) {
    if (widget.enableHapticFeedback) HapticFeedback.mediumImpact();
    showMenu(globalPosition: details.globalPosition);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.items.isEmpty) return widget.child;
    final platform = defaultTargetPlatform;
    final isDesktop =
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;

    return Semantics(
      onLongPress: () => showMenu(),
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        gestures: <Type, GestureRecognizerFactory>{
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(debugOwner: this),
                (t) => t.onSecondaryTapUp = (d) =>
                    showMenu(globalPosition: d.globalPosition),
              ),
          // A long press is the touch gesture for a context menu; with a
          // mouse it is not, so desktops leave it to the child.
          if (!isDesktop)
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer
                >(
                  () => LongPressGestureRecognizer(debugOwner: this),
                  (l) => l.onLongPressStart = _onLongPress,
                ),
          if (platform == TargetPlatform.macOS)
            ControlClickGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  ControlClickGestureRecognizer
                >(
                  () => ControlClickGestureRecognizer(debugOwner: this),
                  (c) => c.onControlClick = (position) =>
                      showMenu(globalPosition: position),
                ),
        },
        child: widget.child,
      ),
    );
  }
}

/// Recognizes a Control-click (primary mouse button with Control held), the
/// Mac's other context-menu click, and wins the gesture arena at once, so
/// the child does not also take it as a tap.
@visibleForTesting
class ControlClickGestureRecognizer extends OneSequenceGestureRecognizer {
  /// Creates a Control-click recognizer.
  ControlClickGestureRecognizer({super.debugOwner});

  /// Called with the global position of the click when the button is
  /// released.
  void Function(Offset globalPosition)? onControlClick;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    return event.kind == PointerDeviceKind.mouse &&
        event.buttons == kPrimaryMouseButton &&
        HardwareKeyboard.instance.isControlPressed &&
        super.isPointerAllowed(event);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent) {
      stopTrackingPointer(event.pointer);
      onControlClick?.call(event.position);
    } else if (event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'control click';
}
