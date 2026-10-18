import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bottom_sheet.dart';

/// Channel owned by `CNActionSheetManager` on the iOS side. It carries no
/// platform view — an action sheet is a modal presentation, so the native
/// implementation presents a `UIAlertController` on the top view controller
/// instead of embedding anything in the Flutter view hierarchy.
const MethodChannel _channel = MethodChannel('cn_action_sheet');

/// A single choice in a [CNActionSheet].
///
/// [T] is the type [CNActionSheet.show] returns when this action is selected.
///
/// ## Icons are intentionally absent
///
/// `UIAlertAction` exposes no public image property, so an icon field here
/// could never render on the native path. The `setValue(_:forKey: "image")`
/// workaround seen in the wild is KVC against an undeclared private property —
/// it risks App Store rejection and breaks silently across iOS releases. Use
/// [CNPopupMenuButton] when you need icons; its `UIMenu` path has a public
/// image API.
@immutable
class CNActionSheetAction<T> {
  /// Creates an action sheet choice.
  const CNActionSheetAction({
    required this.label,
    this.value,
    this.isDestructive = false,
    this.enabled = true,
  });

  /// The text shown on the button.
  final String label;

  /// Returned by [CNActionSheet.show] when this action is selected.
  ///
  /// Leave it null when the caller only cares that *something* was picked;
  /// `show` then resolves to null for this action, same as a cancel.
  final T? value;

  /// Marks the action as destructive (e.g. "Delete", "Log out").
  ///
  /// On iOS this maps to `UIAlertAction.Style.destructive`, which renders the
  /// label in the system destructive red. On the Flutter fallback it maps to
  /// `CupertinoActionSheetAction.isDestructiveAction`.
  ///
  /// Apple's Human Interface Guidelines place destructive choices at the top of
  /// the sheet. This API preserves the order you pass — reordering the list
  /// would silently break the mapping from index to [value] — so put the
  /// destructive action first yourself.
  final bool isDestructive;

  /// Whether the action can be selected. A disabled action renders greyed out
  /// and ignores taps.
  final bool enabled;
}

/// A native iOS action sheet.
///
/// On iOS this presents a real `UIAlertController` in
/// `UIAlertController.Style.actionSheet`, so the sheet is the system control:
/// system destructive red, the detached cancel row, VoiceOver, Dynamic Type,
/// and — on iOS 26 — the Liquid Glass appearance, which the system applies with
/// no opt-in. Because the appearance comes from the OS, the native path is used
/// on every supported iOS version rather than being gated on iOS 26.
///
/// On every other platform the sheet falls back to a [CupertinoActionSheet]
/// presented through [CNBottomSheet.showModalPopup], which keeps the geometry
/// probe the package relies on to hide platform views behind modals.
///
/// ## Basic usage
///
/// ```dart
/// final choice = await CNActionSheet.show<String>(
///   context: context,
///   title: 'Delete photo?',
///   message: 'This cannot be undone.',
///   actions: const [
///     CNActionSheetAction(
///       label: 'Delete',
///       value: 'delete',
///       isDestructive: true,
///     ),
///     CNActionSheetAction(label: 'Duplicate', value: 'duplicate'),
///   ],
///   cancelLabel: 'Cancel',
/// );
///
/// if (choice == 'delete') _deletePhoto();
/// ```
///
/// ## Anchoring
///
/// Starting in iOS 26 an action sheet anchors to the view it came from on
/// iPhone as well as iPad, appearing directly over that view. Pass
/// [anchorRect] — the global rect of the widget that triggered the sheet — to
/// get that presentation and its transition. Omitting it is still valid: the
/// system centres the sheet, and from iOS 26 gives it a cancel button. Below
/// iOS 26 the centred sheet shows only the actions you passed, so supply a
/// `cancelLabel` there.
///
/// ```dart
/// final box = _buttonKey.currentContext!.findRenderObject()! as RenderBox;
/// final rect = box.localToGlobal(Offset.zero) & box.size;
///
/// await CNActionSheet.show<String>(
///   context: context,
///   anchorRect: rect,
///   actions: const [CNActionSheetAction(label: 'Share', value: 'share')],
/// );
/// ```
class CNActionSheet {
  CNActionSheet._();

  /// Presents the action sheet and resolves to the selected action's
  /// [CNActionSheetAction.value].
  ///
  /// Resolves to null when the sheet is cancelled, dismissed by tapping
  /// outside, or when the selected action carries no value.
  ///
  /// [title] and [message] are the sheet's header. [cancelLabel] adds a
  /// cancel-styled button. From iOS 26 the system supplies one of its own for a
  /// centred sheet, so passing null is safe there; below iOS 26 UIKit adds
  /// nothing, and a sheet with no cancel row can only be left by picking one of
  /// its actions. Pass a [cancelLabel] unless forcing a choice is the point.
  ///
  /// A call with no actions *and* no [cancelLabel] would present a sheet with
  /// nothing to press and never resolve, so it asserts in debug and resolves to
  /// null without presenting anything in release.
  ///
  /// Apple's Human Interface Guidelines recommend at most four buttons
  /// including cancel. Longer lists work, but scroll.
  static Future<T?> show<T>({
    required BuildContext context,
    required List<CNActionSheetAction<T>> actions,
    String? title,
    String? message,
    String? cancelLabel,
    Rect? anchorRect,
  }) {
    assert(
      actions.isNotEmpty || cancelLabel != null,
      'CNActionSheet.show needs at least one action or a cancelLabel: a sheet '
      'with neither has nothing to press and never resolves.',
    );
    // `actions` is often built from a collection that can come out empty. With
    // no cancel button either, the native sheet has no button and no dismissal
    // path, so none of the three paths that complete the call can run and the
    // caller's await hangs for the life of the process. Answer it here instead
    // of presenting a modal there is no way out of.
    if (actions.isEmpty && cancelLabel == null) return Future<T?>.value(null);

    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return _showFallback<T>(
        context: context,
        actions: actions,
        title: title,
        message: message,
        cancelLabel: cancelLabel,
      );
    }

    return _showNative<T>(
      actions: actions,
      title: title,
      message: message,
      cancelLabel: cancelLabel,
      anchorRect: anchorRect,
    );
  }

  static Future<T?> _showNative<T>({
    required List<CNActionSheetAction<T>> actions,
    required String? title,
    required String? message,
    required String? cancelLabel,
    required Rect? anchorRect,
  }) async {
    final payload = debugBuildActionSheetPayload(
      actions: actions,
      title: title,
      message: message,
      cancelLabel: cancelLabel,
      anchorRect: anchorRect,
    );

    try {
      final index = await _channel.invokeMethod<int>('show', payload);
      if (index == null || index < 0 || index >= actions.length) return null;
      return actions[index].value;
    } on PlatformException catch (e) {
      debugPrint(
        '⚠️ [cupertino_native_better] CNActionSheet failed: ${e.code} '
        '${e.message ?? ''}',
      );
      return null;
    } on MissingPluginException {
      // The iOS side is not registered (unit tests without a mock handler, or
      // a host app on an older plugin build). Treat it as a dismissal rather
      // than throwing into the caller's await.
      return null;
    }
  }

  static Future<T?> _showFallback<T>({
    required BuildContext context,
    required List<CNActionSheetAction<T>> actions,
    required String? title,
    required String? message,
    required String? cancelLabel,
  }) {
    return CNBottomSheet.showModalPopup<T>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        message: message == null ? null : Text(message),
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: action.isDestructive,
              onPressed: action.enabled
                  ? () => Navigator.of(popupContext).pop(action.value)
                  : () {},
              child: Opacity(
                opacity: action.enabled ? 1.0 : 0.4,
                child: Text(action.label),
              ),
            ),
        ],
        cancelButton: cancelLabel == null
            ? null
            : CupertinoActionSheetAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(popupContext).pop(),
                child: Text(cancelLabel),
              ),
      ),
    );
  }
}

/// Builds the method channel payload for [CNActionSheet.show].
///
/// Exposed for tests: the payload is the contract shared with
/// `CNActionSheetManager.swift`, so it is asserted directly rather than through
/// a platform round trip.
@visibleForTesting
Map<String, Object?> debugBuildActionSheetPayload({
  required List<CNActionSheetAction<Object?>> actions,
  String? title,
  String? message,
  String? cancelLabel,
  Rect? anchorRect,
}) {
  return <String, Object?>{
    'title': title,
    'message': message,
    'cancelLabel': cancelLabel,
    'actions': [
      for (final action in actions)
        <String, Object?>{
          'label': action.label,
          'destructive': action.isDestructive,
          'enabled': action.enabled,
        },
    ],
    if (anchorRect != null)
      'anchorRect': <String, double>{
        'x': anchorRect.left,
        'y': anchorRect.top,
        'width': anchorRect.width,
        'height': anchorRect.height,
      },
  };
}
