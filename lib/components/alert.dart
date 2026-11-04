import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/theme_helper.dart';

/// Channel owned by `CNAlertManager` on the iOS and macOS sides. It carries no
/// platform view — an alert is a modal presentation, so the native
/// implementation presents a `UIAlertController` on the top view controller
/// (iOS) or an `NSAlert` sheet on the window (macOS) instead of embedding
/// anything in the Flutter view hierarchy.
const MethodChannel _channel = MethodChannel('cn_alert');

/// A single button in a [CNAlert].
///
/// [T] is the type [CNAlert.show] reports when this action is selected.
///
/// ## Icons are intentionally absent
///
/// `UIAlertAction` exposes no public image property, so an icon field here
/// could never render on the native path. The `setValue(_:forKey: "image")`
/// workaround seen in the wild is KVC against an undeclared private property —
/// it risks App Store rejection and breaks silently across iOS releases.
@immutable
class CNAlertAction<T> {
  /// Creates an alert button.
  const CNAlertAction({
    required this.label,
    this.value,
    this.isDefault = false,
    this.isCancel = false,
    this.isDestructive = false,
    this.enabled = true,
  });

  /// The text shown on the button.
  final String label;

  /// Reported as [CNAlertResult.value] when this action is selected.
  ///
  /// Leave it null when the caller only cares that the alert was answered; the
  /// result still arrives, with a null [CNAlertResult.value].
  final T? value;

  /// Marks the action as the preferred one.
  ///
  /// On iOS this becomes `UIAlertController.preferredAction`, which renders the
  /// label in a heavier weight. On macOS it is the alert's default button:
  /// at the trailing edge, answering Return. On the Flutter fallback it maps
  /// to [CupertinoDialogAction.isDefaultAction].
  ///
  /// At most one action in a call may set this — `preferredAction` holds a
  /// single reference, so a second one would silently win.
  final bool isDefault;

  /// Marks the action as the cancel button.
  ///
  /// Maps to `UIAlertAction.Style.cancel`, which UIKit positions itself
  /// regardless of where the action sits in the list. On macOS it is the
  /// button next to the default one, answering Escape.
  ///
  /// At most one action in a call may set this: UIKit raises
  /// `NSInternalInconsistencyException` when a second `.cancel` action is added,
  /// which is a crash, not a layout quirk.
  ///
  /// Unlike a plain dismissal, a cancel action still reports its [value] — an
  /// alert cannot be dismissed by tapping outside, so pressing cancel is a
  /// deliberate answer and the caller is told about it.
  final bool isCancel;

  /// Marks the action as destructive (e.g. "Delete", "Log out").
  ///
  /// Maps to `UIAlertAction.Style.destructive`, which renders the label in the
  /// system destructive red, to `NSButton.hasDestructiveAction` on macOS
  /// (which also keeps Return from pressing it unless it is [isDefault]), and
  /// to [CupertinoDialogAction.isDestructiveAction] on the fallback.
  ///
  /// Cannot be combined with [isCancel] — `UIAlertAction.Style` is a single
  /// value, so one of the two would be dropped.
  final bool isDestructive;

  /// Whether the action can be selected.
  ///
  /// Maps to `UIAlertAction.isEnabled`, which blocks taps on every iOS version.
  ///
  /// The greying-out is version-dependent. Early iOS 26 shipped a defect where
  /// a disabled action still rendered as though it were enabled (Apple
  /// developer forums threads 794819 and 794833); it refused taps but looked
  /// live. That is fixed by iOS 26.2, where the label is greyed out — verified
  /// on an iPhone 16e simulator. Treat the appearance on early 26.x as
  /// unreliable and the behaviour as correct throughout. The Flutter fallback
  /// greys it out on every version.
  final bool enabled;
}

/// One text input row inside a [CNAlert].
///
/// Maps to a `UITextField` added with `UIAlertController.addTextField` on iOS,
/// to an `NSTextField` (`NSSecureTextField` when [obscureText]) in the
/// `NSAlert` accessory view on macOS, and to a [CupertinoTextField] inside the
/// dialog body on the fallback.
///
/// Only the three fields that map cleanly onto both sides are exposed.
/// `keyboardType`, autocorrection and autocapitalization are deliberately
/// absent rather than half-mapped.
@immutable
class CNAlertTextField {
  /// Creates a text input row.
  const CNAlertTextField({
    this.placeholder,
    this.initialText,
    this.obscureText = false,
  });

  /// Grey prompt shown while the field is empty (`UITextField.placeholder`).
  final String? placeholder;

  /// Text the field starts with (`UITextField.text`).
  final String? initialText;

  /// Whether the field masks its content (`UITextField.isSecureTextEntry`).
  final bool obscureText;
}

/// What a [CNAlert] reported back.
///
/// [CNAlert.show] resolves to null when the alert produced no answer at all —
/// the plugin was not registered, the native side failed, or the fallback route
/// was popped without pressing a button. Anything else resolves to one of
/// these, even when the pressed action carried no [CNAlertAction.value].
@immutable
class CNAlertResult<T> {
  /// Creates a result.
  const CNAlertResult({this.value, this.textFields = const <String>[]});

  /// The [CNAlertAction.value] of the action that was pressed.
  ///
  /// Null when that action carried no value.
  final T? value;

  /// The contents of every [CNAlertTextField], in the order they were declared.
  ///
  /// Empty when the alert had no text fields.
  final List<String> textFields;
}

/// A native alert dialog: `UIAlertController` on iOS, `NSAlert` on macOS.
///
/// On iOS this presents a real `UIAlertController` in
/// `UIAlertController.Style.alert`, so the dialog is the system control: system
/// typography and button dividers, the destructive red, VoiceOver, Dynamic
/// Type, and — on iOS 26 — the Liquid Glass appearance. Because that appearance
/// comes from the OS with no opt-in, the native path is used on every supported
/// iOS version rather than being gated on iOS 26.
///
/// On macOS this presents a real `NSAlert` as a sheet on the app's window
/// (`beginSheetModal`, never a blocking modal loop), on every supported macOS
/// version:
///
/// - Buttons follow AppKit's order: the [CNAlertAction.isDefault] action at
///   the trailing edge, answering Return, the [CNAlertAction.isCancel] action
///   next to it, answering Escape, then the others. Without an `isDefault`
///   action the first action that is not cancel takes Return, unless it is
///   destructive.
/// - [CNAlertAction.isDestructive] sets `NSButton.hasDestructiveAction`.
/// - [CNAlertTextField]s are `NSTextField`s (`NSSecureTextField` when
///   obscured) in the alert's accessory view; the first one has the focus.
/// - The alert shows the app icon, as every `NSAlert` does.
///
/// On every other platform the alert falls back to a [CupertinoAlertDialog]
/// presented through [showCupertinoDialog] with `barrierDismissible: false`,
/// matching UIKit — a `.alert` cannot be dismissed by tapping outside.
///
/// ## Basic usage
///
/// ```dart
/// final result = await CNAlert.show<String>(
///   context: context,
///   title: 'Delete photo?',
///   message: 'This cannot be undone.',
///   actions: const [
///     CNAlertAction(label: 'Cancel', isCancel: true),
///     CNAlertAction(label: 'Delete', value: 'delete', isDestructive: true),
///   ],
/// );
///
/// if (result?.value == 'delete') _deletePhoto();
/// ```
///
/// ## With a text field
///
/// ```dart
/// final result = await CNAlert.show<String>(
///   context: context,
///   title: 'Rename',
///   textFields: const [
///     CNAlertTextField(placeholder: 'Name', initialText: 'Untitled'),
///   ],
///   actions: const [
///     CNAlertAction(label: 'Cancel', isCancel: true),
///     CNAlertAction(label: 'Save', value: 'save', isDefault: true),
///   ],
/// );
///
/// if (result?.value == 'save') rename(result!.textFields.first);
/// ```
///
/// ## What this deliberately does not do
///
/// - **No custom content.** `UIAlertController` has no public API for an
///   arbitrary content view; the properties that would allow it
///   (`contentViewController`, `_headerContentViewController`) are private.
/// - **No icons on actions.** `UIAlertAction` has no public image property.
/// - **No severity.** `UIAlertController.severity` is Mac Catalyst only.
/// - **No anchoring.** An alert is always centred; anchoring to a source view
///   is an action-sheet behaviour.
class CNAlert {
  CNAlert._();

  /// Presents the alert and resolves to what the user answered.
  ///
  /// Resolves to null when no answer was produced: the plugin is not
  /// registered, the native presentation failed (on macOS: no window to attach
  /// the sheet to), the fallback route was popped without a button press, or —
  /// on iOS and macOS — a second [CNAlert.show] superseded this one, taking its
  /// alert down and resolving this call to null. The Flutter fallback stacks instead: the earlier dialog stays up and
  /// resolves on its own button press. A pressed button — including a cancel
  /// button — always resolves to a [CNAlertResult].
  ///
  /// [title] and [message] are the alert's header. [textFields] adds one input
  /// row each, in order, and their contents come back in
  /// [CNAlertResult.textFields].
  ///
  /// Apple's Human Interface Guidelines recommend at most two buttons for an
  /// alert; more work, but stack vertically.
  ///
  /// Asserts in debug, and returns null without presenting anything in release,
  /// when [actions] is empty or every action is disabled — a `.alert` cannot be
  /// dismissed by tapping outside, so every way out of it runs an action
  /// handler. An alert with no button, or none that accepts a tap, can never be
  /// dismissed and the returned future would never complete.
  ///
  /// Also asserts against configurations UIKit cannot render: two actions with
  /// [CNAlertAction.isCancel] (a hard `NSInternalInconsistencyException`), two
  /// with [CNAlertAction.isDefault], and a single action that is both cancel
  /// and destructive.
  static Future<CNAlertResult<T>?> show<T>({
    required BuildContext context,
    required List<CNAlertAction<T>> actions,
    String? title,
    String? message,
    List<CNAlertTextField> textFields = const <CNAlertTextField>[],
  }) {
    assert(
      actions.isNotEmpty,
      'CNAlert.show needs at least one action: an alert cannot be dismissed by '
      'tapping outside, so one with no buttons never resolves.',
    );
    assert(
      actions.any((a) => a.enabled),
      'CNAlert.show needs at least one enabled action: an alert cannot be '
      'dismissed by tapping outside, so one whose buttons all refuse taps '
      'never resolves.',
    );
    assert(
      actions.where((a) => a.isCancel).length <= 1,
      'CNAlert.show accepts at most one action with isCancel: UIKit raises '
      'NSInternalInconsistencyException on a second .cancel action.',
    );
    assert(
      actions.where((a) => a.isDefault).length <= 1,
      'CNAlert.show accepts at most one action with isDefault: '
      'UIAlertController.preferredAction holds a single action.',
    );
    assert(
      !actions.any((a) => a.isCancel && a.isDestructive),
      'A CNAlertAction cannot be both isCancel and isDestructive: '
      'UIAlertAction.Style is one value, so one of the two would be dropped.',
    );

    // `actions` is often built from a collection that can come out empty, and
    // `enabled` is often computed per action from one flag that can be false for
    // all of them. The native alert would then have no button that answers a
    // tap and no dismissal path, so nothing could complete the call and the
    // caller's await would hang for the life of the process. Answer it here
    // instead of presenting a modal there is no way out of.
    if (!actions.any((a) => a.enabled)) {
      return Future<CNAlertResult<T>?>.value(null);
    }

    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return _showFallback<T>(
        context: context,
        actions: actions,
        title: title,
        message: message,
        textFields: textFields,
      );
    }

    return _showNative<T>(
      actions: actions,
      title: title,
      message: message,
      textFields: textFields,
      // The app's theme, not the window's: a light app on a dark system gets
      // a light alert, as CNActionSheet does. Null when the theme follows the
      // system, so the native alert does too (#118).
      isDark: context.mounted ? ThemeHelper.themeIsDark(context) : null,
    );
  }

  static Future<CNAlertResult<T>?> _showNative<T>({
    required List<CNAlertAction<T>> actions,
    required String? title,
    required String? message,
    required List<CNAlertTextField> textFields,
    required bool? isDark,
  }) async {
    final payload = debugBuildAlertPayload(
      actions: actions,
      title: title,
      message: message,
      textFields: textFields,
      isDark: isDark,
    );

    try {
      final reply = await _channel.invokeMapMethod<String, Object?>(
        'show',
        payload,
      );
      if (reply == null) return null;

      final index = reply['index'];
      if (index is! int || index < 0 || index >= actions.length) return null;

      return CNAlertResult<T>(
        value: actions[index].value,
        textFields: _decodeTextFields(reply['textFields']),
      );
    } on PlatformException catch (e) {
      debugPrint(
        '⚠️ [cupertino_native_better] CNAlert failed: ${e.code} '
        '${e.message ?? ''}',
      );
      return null;
    } on MissingPluginException {
      // The native side is not registered (unit tests without a mock handler,
      // or a host app on an older plugin build). Treat it as a dismissal rather
      // than throwing into the caller's await -- but say so, because a silent
      // null here is indistinguishable from the user pressing cancel.
      debugPrint(
        '⚠️ [cupertino_native_better] CNAlert: the cn_alert channel is not '
        'registered. The native plugin build is older than this Dart API, or '
        'this is a test without a mock handler. Returning null.',
      );
      return null;
    }
  }

  static List<String> _decodeTextFields(Object? raw) {
    if (raw is! List) return const <String>[];
    return <String>[for (final entry in raw) entry?.toString() ?? ''];
  }

  static Future<CNAlertResult<T>?> _showFallback<T>({
    required BuildContext context,
    required List<CNAlertAction<T>> actions,
    required String? title,
    required String? message,
    required List<CNAlertTextField> textFields,
  }) {
    return showCupertinoDialog<CNAlertResult<T>>(
      context: context,
      // UIKit parity: a `.alert` has no implicit outside-tap dismissal.
      barrierDismissible: false,
      builder: (dialogContext) => _CNAlertFallback<T>(
        title: title,
        message: message,
        actions: actions,
        textFields: textFields,
      ),
    );
  }
}

/// The Flutter-rendered stand-in used off iOS and macOS.
///
/// Stateful because each [CNAlertTextField] needs a [TextEditingController] that
/// outlives a rebuild and is disposed with the dialog.
class _CNAlertFallback<T> extends StatefulWidget {
  const _CNAlertFallback({
    required this.actions,
    required this.textFields,
    this.title,
    this.message,
  });

  final List<CNAlertAction<T>> actions;
  final List<CNAlertTextField> textFields;
  final String? title;
  final String? message;

  @override
  State<_CNAlertFallback<T>> createState() => _CNAlertFallbackState<T>();
}

class _CNAlertFallbackState<T> extends State<_CNAlertFallback<T>> {
  late final List<TextEditingController> _controllers = [
    for (final field in widget.textFields)
      TextEditingController(text: field.initialText),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget? _buildContent() {
    final children = <Widget>[
      if (widget.message != null) Text(widget.message!),
      for (var i = 0; i < _controllers.length; i++)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: CupertinoTextField(
            controller: _controllers[i],
            placeholder: widget.textFields[i].placeholder,
            obscureText: widget.textFields[i].obscureText,
          ),
        ),
    ];

    if (children.isEmpty) return null;
    if (children.length == 1) return children.single;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: widget.title == null ? null : Text(widget.title!),
      content: _buildContent(),
      actions: [
        for (final action in widget.actions)
          CupertinoDialogAction(
            isDefaultAction: action.isDefault,
            isDestructiveAction: action.isDestructive,
            onPressed: action.enabled
                ? () => Navigator.of(context).pop(
                    CNAlertResult<T>(
                      value: action.value,
                      textFields: [
                        for (final controller in _controllers) controller.text,
                      ],
                    ),
                  )
                : null,
            child: Text(action.label),
          ),
      ],
    );
  }
}

/// Builds the method channel payload for [CNAlert.show].
///
/// Exposed for tests: the payload is the contract shared with
/// `CNAlertManager.swift`, so it is asserted directly rather than through a
/// platform round trip.
@visibleForTesting
Map<String, Object?> debugBuildAlertPayload({
  required List<CNAlertAction<Object?>> actions,
  String? title,
  String? message,
  List<CNAlertTextField> textFields = const <CNAlertTextField>[],
  bool? isDark,
}) {
  return <String, Object?>{
    'title': title,
    'message': message,
    'isDark': ?isDark,
    'actions': [
      for (final action in actions)
        <String, Object?>{
          'label': action.label,
          'style': _styleName(action),
          'enabled': action.enabled,
          'preferred': action.isDefault,
        },
    ],
    'textFields': [
      for (final field in textFields)
        <String, Object?>{
          'placeholder': field.placeholder,
          'initialText': field.initialText,
          'obscure': field.obscureText,
        },
    ],
  };
}

/// Maps an action onto the `UIAlertAction.Style` case the native side builds.
///
/// Cancel wins over destructive; the two are asserted to be mutually exclusive
/// in [CNAlert.show], so this order only matters in release.
String _styleName(CNAlertAction<Object?> action) {
  if (action.isCancel) return 'cancel';
  if (action.isDestructive) return 'destructive';
  return 'default';
}
