import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../utils/native_context_menu.dart';
import '../utils/theme_helper.dart';
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
///   `CupertinoActionSheet`. With [showsPreview] (any iOS) the long press
///   instead lifts a preview of the child above the dimmed screen, as a
///   system context menu does.
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
/// On iOS, screen readers get the menu as the child's long-press action
/// (VoiceOver: double-tap and hold), opened at the child's centre. On macOS
/// VoiceOver cannot open it: Flutter's macOS embedder exposes no "show menu"
/// action. Offer the same commands another way, such as a
/// [CNPopupMenuButton], where VoiceOver users need them.
class CNContextMenu extends StatefulWidget {
  /// Creates a native context menu region around [child].
  const CNContextMenu({
    super.key,
    required this.items,
    required this.onSelected,
    required this.child,
    this.enabled = true,
    this.enableHapticFeedback = true,
    this.showsPreview = false,
    this.previewCornerRadius = 12,
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

  /// iOS: whether a long press lifts a preview of [child], as a system
  /// context menu does in Photos or Messages: the child rises above the
  /// blurred screen with the menu beside it, and settles back when the menu
  /// closes (#138). Off, the menu opens at the pressed point with nothing
  /// lifted. macOS menus have no preview.
  ///
  /// A menu opened from code is a button menu, which UIKit never shows with
  /// a preview, so with this on a clear native view with a
  /// `UIContextMenuInteraction` is laid over the child, and the child is
  /// drawn to an image when the finger goes down. A tap still reaches the
  /// child; a long press goes to the native view. Each such region is a
  /// platform view, so in a long list keep it to the rows that need it.
  final bool showsPreview;

  /// The corner radius of the lifted preview's platter, when [showsPreview]
  /// is on. Match the child's own corners, e.g. 12 for a card.
  final double previewCornerRadius;

  @override
  State<CNContextMenu> createState() => CNContextMenuState();
}

/// State of a [CNContextMenu]; [showMenu] opens the menu from code.
class CNContextMenuState extends State<CNContextMenu> {
  bool _showing = false;

  /// The child's repaint boundary, drawn for the lifted preview.
  final GlobalKey _previewKey = GlobalKey();

  /// The channel of the native preview view (`showsPreview` on iOS).
  MethodChannel? _previewChannel;
  bool? _lastIsDark;

  bool get _wantsPreview =>
      widget.showsPreview &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void didUpdateWidget(covariant CNContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    final channel = _previewChannel;
    if (channel == null) return;
    if (!identical(oldWidget.items, widget.items)) _sendMenu();
    if (oldWidget.previewCornerRadius != widget.previewCornerRadius) {
      channel
          .invokeMethod<void>('setCornerRadius', {
            'radius': widget.previewCornerRadius,
          })
          .catchError((_) {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final channel = _previewChannel;
    if (channel == null) return;
    final isDark = ThemeHelper.isDark(context);
    if (isDark != _lastIsDark) {
      _lastIsDark = isDark;
      channel
          .invokeMethod<void>('setBrightness', {'isDark': isDark})
          .catchError((_) {});
    }
  }

  void _onPreviewViewCreated(int id) {
    final channel = MethodChannel('CNContextMenuPreview_$id');
    _previewChannel = channel;
    _lastIsDark = ThemeHelper.isDark(context);
    channel.setMethodCallHandler((call) async {
      if (call.method == 'selected' && mounted && widget.enabled) {
        final path = (call.arguments as Map?)?['path'] as List?;
        if (path != null && path.isNotEmpty) {
          widget.onSelected(
            List<int>.unmodifiable(path.map((e) => (e as num).toInt())),
          );
        }
      }
      return null;
    });
    _sendMenu();
  }

  Future<void> _sendMenu() async {
    final channel = _previewChannel;
    if (channel == null) return;
    final menu = await encodeNativeContextMenu(context, widget.items);
    if (menu == null || !identical(channel, _previewChannel)) return;
    await channel
        .invokeMethod<void>('setMenu', {'menu': menu})
        .catchError((_) {});
  }

  /// Draws the child for the lifted preview when a finger goes down, well
  /// before the long press opens the menu.
  Future<void> _sendPreview() async {
    final channel = _previewChannel;
    final boundary = _previewKey.currentContext?.findRenderObject();
    if (channel == null ||
        boundary is! RenderRepaintBoundary ||
        !boundary.hasSize ||
        !boundary.attached) {
      return;
    }
    try {
      final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3.0;
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;
      await channel.invokeMethod<void>('setPreview', {
        'png': data.buffer.asUint8List(),
      });
    } catch (_) {
      // Not painted yet, or the view is gone: no preview this time.
    }
  }

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
                (t) =>
                    t.onSecondaryTapUp = (d) =>
                        showMenu(globalPosition: d.globalPosition),
              ),
          // A long press is the touch gesture for a context menu; with a
          // mouse it is not, so desktops leave it to the child. With a
          // preview, the native view over the child takes the long press.
          if (!isDesktop && !_wantsPreview)
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
                  (c) =>
                      c.onControlClick = (position) =>
                          showMenu(globalPosition: position),
                ),
        },
        child: _wantsPreview ? _withPreviewView(context) : widget.child,
      ),
    );
  }

  /// The child under the native view whose context menu interaction lifts
  /// its preview (#138).
  Widget _withPreviewView(BuildContext context) {
    return _ChildFirstHitStack(
      children: [
        RepaintBoundary(key: _previewKey, child: widget.child),
        Positioned.fill(
          child: UiKitView(
            viewType: 'CNContextMenuPreview',
            // The child under it keeps its taps; only a long press, once it
            // wins, goes to the native view (see _ChildFirstHitStack).
            hitTestBehavior: PlatformViewHitTestBehavior.translucent,
            creationParams: <String, Object?>{
              'cornerRadius': widget.previewCornerRadius,
              'isDark': ThemeHelper.isDark(context),
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPreviewViewCreated,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<LongPressGestureRecognizer>(
                () =>
                    LongPressGestureRecognizer(debugOwner: this)
                      ..onLongPressDown = (_) => _sendPreview(),
              ),
            },
          ),
        ),
      ],
    );
  }
}

/// A [Stack] that hit-tests its children in paint order, every one of them.
///
/// The preview's native view is painted over the child, but a platform
/// view's gesture team always holds its own captain, which never gives up:
/// a gesture nothing else claims goes to the arena member that joined first,
/// and with the native view hit first that was always the native view, so a
/// tap never reached the child. Hit first, the child's recognizers join the
/// arena first and win a tap, while the native view's long press still wins
/// a long press.
class _ChildFirstHitStack extends Stack {
  const _ChildFirstHitStack({required super.children});

  @override
  RenderStack createRenderObject(BuildContext context) {
    return _RenderChildFirstHitStack(
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      fit: fit,
      clipBehavior: clipBehavior,
    );
  }
}

class _RenderChildFirstHitStack extends RenderStack {
  _RenderChildFirstHitStack({
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
  });

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var hit = false;
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as StackParentData;
      final current = child;
      hit =
          result.addWithPaintOffset(
            offset: parentData.offset,
            position: position,
            hitTest: (result, transformed) =>
                current.hitTest(result, position: transformed),
          ) ||
          hit;
      child = parentData.nextSibling;
    }
    return hit;
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
