import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/native_list.dart';
import '../style/sf_symbol.dart';
import '../utils/list_item_encoder.dart';
import '../utils/route_changes.dart';
import '../utils/theme_helper.dart';
import 'bottom_sheet.dart';

/// Channel owned by `CNPopoverManager` on the iOS and macOS sides. Like the
/// alert, action sheet and context menu channels it carries no platform
/// view: the popover is presented by the window, above everything Flutter
/// draws.
const MethodChannel _channel = MethodChannel('cn_popover');

/// The side of its anchor a [CNPopover] prefers to appear on.
///
/// When there is not enough room on that side, the popover appears on the
/// opposite one, as AppKit's and UIKit's popovers do.
enum CNPopoverEdge {
  /// Above the anchor, its arrow pointing down at it.
  top,

  /// Below the anchor, its arrow pointing up at it.
  bottom,

  /// Before the anchor in reading order: to its left in a left-to-right
  /// layout.
  leading,

  /// After the anchor in reading order: to its right in a left-to-right
  /// layout.
  trailing,
}

/// A row of a [CNPopover]: a native list row that closes the popover when
/// it is tapped, making [CNPopover.show] return [id].
///
/// The row is described by a [CNListItem], the model of the package's other
/// native lists: a title, a subtitle, a leading SF Symbol or image, text at
/// the trailing end and a chevron.
///
/// For a choice list, set [checked] on the current choice: a checkmark is
/// drawn on that row (at the trailing end on iOS, at the leading end on
/// macOS, as in a menu) and VoiceOver reads it as selected.
@immutable
class CNPopoverRow {
  /// Creates a popover row.
  const CNPopoverRow({
    required this.id,
    required this.item,
    this.checked = false,
    this.enabled = true,
    this.readOnly = false,
  });

  /// Returned by [CNPopover.show] when the row is tapped.
  final String id;

  /// What the row shows.
  final CNListItem item;

  /// Whether the row carries a checkmark.
  final bool checked;

  /// Whether the row can be tapped. A disabled row is dimmed.
  final bool enabled;

  /// Whether the row only shows information, such as a label and its value
  /// in [CNListItem.trailingText].
  ///
  /// A read-only row is not a button: a tap on it does nothing and keeps
  /// the popover open, it is drawn at full strength, and VoiceOver reads it
  /// as text ("Prompt, 1,204") rather than as a button. Its [id] is never
  /// returned.
  final bool readOnly;
}

/// A switch in a [CNPopover].
///
/// Flipping it keeps the popover open and reports the new value to
/// `onToggleChanged`. The switch holds its own value from then on; call
/// [CNPopover.update] to set it from code, for example to turn it back off
/// when the change cannot be made.
@immutable
class CNPopoverToggle {
  /// Creates a popover switch.
  const CNPopoverToggle({
    required this.id,
    required this.label,
    required this.value,
    this.subtitle,
    this.symbol,
    this.enabled = true,
  });

  /// Passed to `onToggleChanged` with the new value.
  final String id;

  /// The switch's label, also what VoiceOver reads for it.
  final String label;

  /// Whether the switch is on.
  final bool value;

  /// A line of secondary text under [label].
  final String? subtitle;

  /// An SF Symbol before the label.
  final CNSymbol? symbol;

  /// Whether the switch can be flipped.
  final bool enabled;
}

/// How a [CNPopoverAction] button looks and behaves.
enum CNPopoverActionStyle {
  /// An ordinary button.
  plain,

  /// The popover's main action: a prominent button that also answers the
  /// Return key.
  defaultAction,

  /// A button that destroys data, drawn in the system red.
  destructive,

  /// Closes the popover without a choice, as a tap outside does:
  /// [CNPopover.show] returns null. It answers the Escape key. Create it
  /// with [CNPopoverAction.cancel].
  cancel,
}

/// A button at the bottom of a [CNPopover]. Pressing it closes the popover.
@immutable
class CNPopoverAction {
  /// Creates a button that makes [CNPopover.show] return [id].
  const CNPopoverAction({
    required String this.id,
    required this.label,
    this.style = CNPopoverActionStyle.plain,
  }) : assert(
         style != CNPopoverActionStyle.cancel,
         'Use CNPopoverAction.cancel for a cancel button.',
       );

  /// Creates a cancel button: it closes the popover and [CNPopover.show]
  /// returns null.
  const CNPopoverAction.cancel({required this.label})
    : id = null,
      style = CNPopoverActionStyle.cancel;

  /// Returned by [CNPopover.show] when the button is pressed; null for a
  /// cancel button.
  final String? id;

  /// The button's text.
  final String label;

  /// The button's role.
  final CNPopoverActionStyle style;
}

/// A labelled bar in a [CNPopover] that shows how full something is, such
/// as storage used or a quota (#135).
///
/// It is drawn natively, as a SwiftUI `ProgressView`, with [label] on the
/// left and [valueText] on the right above the bar. VoiceOver reads the
/// label and the value ([valueText], or the fraction as a percentage).
@immutable
class CNPopoverGauge {
  /// Creates a gauge for [value] between [min] and [max].
  const CNPopoverGauge({
    required this.label,
    required this.value,
    this.min = 0,
    this.max = 1,
    this.valueText,
    this.tint,
  }) : assert(max > min, 'A CNPopoverGauge needs max > min.');

  /// What the bar measures, e.g. `'Storage'`.
  final String label;

  /// The current value, between [min] and [max] (clamped when outside).
  final double value;

  /// The value of an empty bar.
  final double min;

  /// The value of a full bar.
  final double max;

  /// The value as text, e.g. `'42 GB of 128 GB'` or `'42%'`. Null shows no
  /// text, and VoiceOver reads the fraction as a percentage.
  final String? valueText;

  /// The colour of the filled part. Null uses the popover's tint.
  final Color? tint;

  /// [value] as a fraction of the bar, from 0 to 1.
  double get fraction => ((value - min) / (max - min)).clamp(0.0, 1.0);
}

/// What a [CNPopover] shows, top to bottom: [title] and [message], [gauges],
/// [rows], [toggles], then [actions] as buttons.
///
/// Every part is optional, but a popover needs at least one.
@immutable
class CNPopoverContent {
  /// Creates the content of a popover.
  const CNPopoverContent({
    this.title,
    this.message,
    this.gauges = const [],
    this.rows = const [],
    this.toggles = const [],
    this.actions = const [],
  });

  /// A heading at the top, read by VoiceOver as a header.
  final String? title;

  /// Text under the title, in the secondary colour.
  final String? message;

  /// Labelled bars under the message, e.g. storage used.
  final List<CNPopoverGauge> gauges;

  /// Rows that close the popover and return their id when tapped.
  final List<CNPopoverRow> rows;

  /// Switches that keep the popover open and report their changes.
  final List<CNPopoverToggle> toggles;

  /// Buttons at the bottom that close the popover.
  final List<CNPopoverAction> actions;

  /// Whether there is nothing to show.
  bool get isEmpty =>
      (title ?? '').isEmpty &&
      (message ?? '').isEmpty &&
      gauges.isEmpty &&
      rows.isEmpty &&
      toggles.isEmpty &&
      actions.isEmpty;
}

/// A native popover anchored to a Flutter widget: a bubble with an arrow
/// pointing at the widget, drawn by AppKit or UIKit, with Liquid Glass on
/// macOS 26 and iOS 26.
///
/// [show] opens it next to the anchor and returns, once it closes, the id of
/// the [CNPopoverRow] or [CNPopoverAction] that closed it, or null when it
/// was closed without a choice: a click or tap outside, Escape, a cancel
/// button, [dismiss], or another popover opening. Switches
/// ([CNPopoverToggle]) keep it open and report each change while it is up.
///
/// - **macOS** (every supported version): an `NSPopover` with the
///   `.transient` behaviour, shown from the anchor's rect in the Flutter
///   view. A click outside or Escape closes it. Its window takes the
///   keyboard, so Return presses the [CNPopoverActionStyle.defaultAction]
///   button and Tab moves through its controls when keyboard navigation is
///   on.
/// - **iOS** (every supported version): a view controller presented with
///   the `.popover` style from the anchor's rect, on iPhone as on iPad (it
///   does not adapt into a sheet on iPhone). A tap outside closes it.
/// - **Other platforms**: the content in a Cupertino popup from the bottom
///   of the screen.
///
/// The content is native SwiftUI built from a [CNPopoverContent]: a title
/// and message, a list of [CNPopoverRow]s (a [CNListItem] each, with an
/// optional checkmark for a choice list), [CNPopoverToggle]s and
/// [CNPopoverAction] buttons. Flutter widgets cannot be placed inside the
/// popover: it is a separate native window (macOS) or view controller
/// (iOS), and Flutter can draw into it only through its multi-window API,
/// which is not stable as of Flutter 3.44.
///
/// ```dart
/// final sortKey = GlobalKey();
/// // ...
/// CNButton(key: sortKey, label: 'Sort', onPressed: () async {
///   final id = await CNPopover.show(
///     context: context,
///     anchorKey: sortKey,
///     content: CNPopoverContent(
///       title: 'Sort by',
///       rows: [
///         for (final (id, label) in [('name', 'Name'), ('date', 'Date')])
///           CNPopoverRow(
///             id: id,
///             item: CNListItem(title: label),
///             checked: id == _sort,
///           ),
///       ],
///       toggles: [
///         CNPopoverToggle(id: 'folders', label: 'Folders on top', value: _foldersOnTop),
///       ],
///     ),
///     onToggleChanged: (id, value) => setState(() => _foldersOnTop = value),
///   );
///   if (id != null) setState(() => _sort = id);
/// })
/// ```
///
/// ## Anchoring
///
/// The popover points at `anchorKey`'s widget, at `anchorRect` (a rect in
/// global logical coordinates), or, with neither, at the widget of
/// `context`. While it is open it follows the anchor when it moves or when
/// the window is resized.
///
/// It closes, answering null, when the anchor's route stops being the
/// current one (a route pushed over it, or popped) and when the anchor
/// widget is removed. With `CNTabBarRouteObserver` or `CNTransitionObserver`
/// in the app's `navigatorObservers` it also closes on any navigation they
/// see, which covers a route pushed on the root navigator over a page of a
/// nested one (a tab's). As the package's other native overlays, the
/// popover is drawn above the Flutter view, so platform views never show
/// through it and the observers' modal counters are left alone. A hot
/// restart closes it too.
///
/// ## Accessibility
///
/// VoiceOver moves into the popover when it opens and stays inside it until
/// it closes. It reads the title as a header, each row as a button (a
/// checked one as selected) and each switch with its state. The escape
/// gesture (a two-finger scrub on iOS) closes the popover like a tap
/// outside. Text follows Dynamic Type on iOS.
class CNPopover {
  CNPopover._();

  static _PopoverSession? _session;

  /// Starts from the clock, so a popover left open by an isolate that was
  /// hot restarted never shares its session id with a new one.
  static int _lastSessionId =
      DateTime.now().millisecondsSinceEpoch % 1000000000;

  /// Whether a popover is open (or, on platforms without a native popover,
  /// its Cupertino popup).
  static bool get isShown => _session != null || _fallback != null;

  /// Opens a popover showing [content] next to its anchor and returns, once
  /// it closes, the id of the row or button that closed it, or null.
  ///
  /// The anchor is `anchorKey`'s widget, `anchorRect` (global logical
  /// coordinates), or with neither the widget of [context]. Pass at most
  /// one of the two. [preferredEdge] is the side of the anchor the popover
  /// opens on when there is room. [width] fixes the popover's width; by
  /// default it fits its content, between about 200 and 360 points. [tint]
  /// colours checkmarks, switches and the default button; null keeps the
  /// system accent colour. [onToggleChanged] gets each switch change while
  /// the popover is open.
  ///
  /// A popover that is already open closes first, and its own [show]
  /// returns null. The popover follows the theme's brightness, or the
  /// system's when the theme sets none.
  ///
  /// A popover that can't be shown also returns null by default: the anchor
  /// isn't laid out, there is no view to present it from, or UIKit refuses
  /// the presentation. With [throwOnFailure], [show] throws a
  /// [PlatformException] instead, so the caller can tell a failure from a
  /// dismissal and fall back to another UI (#135). Its code is `no_anchor`,
  /// `refused` (UIKit didn't present it), or the native side's own code,
  /// such as `no_view` or `no_presenter`.
  static Future<String?> show({
    required BuildContext context,
    required CNPopoverContent content,
    GlobalKey? anchorKey,
    Rect? anchorRect,
    CNPopoverEdge preferredEdge = CNPopoverEdge.bottom,
    double? width,
    Color? tint,
    void Function(String id, bool value)? onToggleChanged,
    bool throwOnFailure = false,
  }) async {
    assert(
      anchorKey == null || anchorRect == null,
      'Pass either anchorKey or anchorRect to CNPopover.show, not both.',
    );
    assert(!content.isEmpty, 'A CNPopover needs something to show.');
    assert(width == null || width > 0);

    _closeFallback();

    final platform = defaultTargetPlatform;
    if (kIsWeb ||
        (platform != TargetPlatform.iOS && platform != TargetPlatform.macOS)) {
      return _showFallback(
        context: context,
        content: content,
        tint: tint,
        onToggleChanged: onToggleChanged,
      );
    }

    final anchorContext = anchorRect == null
        ? (anchorKey?.currentContext ?? context)
        : null;
    final rect = anchorRect ?? _globalRect(anchorContext!);
    if (rect == null) {
      if (throwOnFailure) {
        throw PlatformException(
          code: 'no_anchor',
          message: 'CNPopover: the anchor is not laid out.',
        );
      }
      debugPrint(
        '⚠️ [cupertino_native_better] CNPopover: the anchor is not laid out.',
      );
      return null;
    }

    final session = _PopoverSession(
      id: ++_lastSessionId,
      route: ModalRoute.of(context),
      anchor: anchorContext,
      rect: rect,
      onToggleChanged: onToggleChanged,
    );
    // A popover already open is closed by the native side, which answers
    // its show with null; from here on its events are dropped.
    _session?.end();
    _session = session;
    _channel.setMethodCallHandler(_handle);
    // Any navigation the package's observers see closes the popover, as a
    // transient popover closes on any interaction outside it.
    session.listenToRouteChanges(() {
      if (!session.open || !identical(_session, session)) return;
      session.end();
      unawaited(_dismissSession(session));
    });

    final payload = debugBuildPopoverPayload(
      session: session.id,
      content: content,
      anchor: rect,
      edge: _edgeName(preferredEdge, Directionality.maybeOf(context)),
      width: width,
      tint: resolveColorToArgb(tint, context),
      isDark: ThemeHelper.themeIsDark(context),
      context: context,
    );
    _watch(session);

    String? chosen;
    var missingNativeSide = false;
    try {
      chosen = await _channel.invokeMethod<String>('show', payload);
    } on PlatformException catch (e) {
      if (throwOnFailure) rethrow;
      debugPrint(
        '⚠️ [cupertino_native_better] CNPopover failed: ${e.code} '
        '${e.message ?? ''}',
      );
    } on MissingPluginException {
      // No native side (a test without a mock handler, or an older plugin
      // build): the content is still shown, by the fallback.
      missingNativeSide = true;
    } finally {
      session.end();
      if (identical(_session, session)) _session = null;
    }
    if (missingNativeSide && context.mounted) {
      return _showFallback(
        context: context,
        content: content,
        tint: tint,
        onToggleChanged: onToggleChanged,
      );
    }
    return chosen;
  }

  /// Replaces the content of the open popover. Does nothing when none is
  /// open.
  ///
  /// The popover resizes to the new content. Switches take the values in
  /// [content]; no `onToggleChanged` is sent for them.
  static Future<void> update(CNPopoverContent content) async {
    assert(!content.isEmpty, 'A CNPopover needs something to show.');
    final fallback = _fallback;
    if (fallback != null) {
      fallback.content.value = content;
      return;
    }
    final session = _session;
    if (session == null) return;
    try {
      await _channel.invokeMethod<void>('update', {
        'session': session.id,
        'content': debugEncodePopoverContent(content, context: session.anchor),
      });
    } on MissingPluginException {
      // Nothing native to update.
    }
  }

  /// Closes the open popover; its [show] returns null. Does nothing when
  /// none is open.
  static Future<void> dismiss() async {
    if (_fallback != null) {
      _closeFallback();
      return;
    }
    final session = _session;
    if (session == null) return;
    session.end();
    await _dismissSession(session);
  }

  static Future<void> _dismissSession(_PopoverSession session) async {
    try {
      await _channel.invokeMethod<void>('dismiss', {'session': session.id});
    } on MissingPluginException {
      // Nothing native to close.
    }
  }

  static Future<dynamic> _handle(MethodCall call) async {
    final args = call.arguments;
    switch (call.method) {
      case 'onToggleChanged':
        final session = _session;
        if (args is! Map || session == null || !session.open) return null;
        if (args['session'] != session.id) return null;
        session.onToggleChanged?.call(
          args['id'] as String,
          args['value'] as bool,
        );
        return null;
    }
    throw MissingPluginException();
  }

  /// Follows the anchor while [session] is open: closes the popover when
  /// the anchor's route stops being current or the anchor is removed, and
  /// moves it when the anchor moves.
  ///
  /// The anchor's rect is read after each frame (post-frame callbacks do
  /// not schedule frames, so an idle app does no work). The route is also
  /// checked on a timer: an app whose window is hidden or covered draws no
  /// frames, yet a route pushed meanwhile must still close the popover.
  static void _watch(_PopoverSession session) {
    session.timer ??= Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (!session.open || !identical(_session, session)) {
        t.cancel();
        return;
      }
      _closeIfAnchorGone(session);
    });
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!session.open || !identical(_session, session)) return;
      if (_closeIfAnchorGone(session)) return;
      final anchor = session.anchor;
      if (anchor != null) {
        final rect = _globalRect(anchor);
        if (rect != null && rect != session.rect) {
          session.rect = rect;
          unawaited(
            _channel
                .invokeMethod<void>('setAnchor', {
                  'session': session.id,
                  'anchor': _rectMap(rect),
                })
                .catchError((Object _) {}),
          );
        }
      }
      _watch(session);
    });
  }

  /// Closes the popover of [session] when its anchor's route is no longer
  /// the current one or its anchor widget is gone. Returns whether it did.
  static bool _closeIfAnchorGone(_PopoverSession session) {
    final route = session.route;
    final anchor = session.anchor;
    if ((route != null && !route.isCurrent) ||
        (anchor != null && !anchor.mounted)) {
      session.end();
      unawaited(_dismissSession(session));
      return true;
    }
    return false;
  }

  // MARK: Fallback (platforms without a native popover)

  static _FallbackSession? _fallback;

  static Future<String?> _showFallback({
    required BuildContext context,
    required CNPopoverContent content,
    required Color? tint,
    required void Function(String id, bool value)? onToggleChanged,
  }) {
    final notifier = ValueNotifier<CNPopoverContent>(content);
    final session = _FallbackSession(notifier);
    _fallback = session;
    return CNBottomSheet.showModalPopup<String>(
      context: context,
      builder: (popupContext) {
        session.navigator = Navigator.of(popupContext);
        session.route = ModalRoute.of(popupContext);
        return _PopoverFallback(
          content: notifier,
          tint: tint,
          onToggleChanged: onToggleChanged,
        );
      },
    ).whenComplete(() {
      if (identical(_fallback, session)) _fallback = null;
      notifier.dispose();
    });
  }

  static void _closeFallback() {
    final session = _fallback;
    if (session == null) return;
    _fallback = null;
    final route = session.route;
    if (route != null && route.isActive) {
      session.navigator?.removeRoute(route);
    }
  }
}

class _PopoverSession {
  _PopoverSession({
    required this.id,
    required this.route,
    required this.anchor,
    required this.rect,
    required this.onToggleChanged,
  });

  final int id;
  final ModalRoute<Object?>? route;

  /// The element the popover points at, or null for an explicit rect.
  final BuildContext? anchor;
  Rect rect;
  final void Function(String id, bool value)? onToggleChanged;
  bool open = true;
  Timer? timer;
  VoidCallback? _onRouteChange;

  void listenToRouteChanges(VoidCallback listener) {
    _onRouteChange = listener;
    cnRouteChanges.addListener(listener);
  }

  void end() {
    open = false;
    timer?.cancel();
    timer = null;
    final listener = _onRouteChange;
    if (listener != null) cnRouteChanges.removeListener(listener);
    _onRouteChange = null;
  }
}

class _FallbackSession {
  _FallbackSession(this.content);

  final ValueNotifier<CNPopoverContent> content;
  NavigatorState? navigator;
  ModalRoute<Object?>? route;
}

Rect? _globalRect(BuildContext context) {
  if (!context.mounted) return null;
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

Map<String, double> _rectMap(Rect r) => {
  'x': r.left,
  'y': r.top,
  'width': r.width,
  'height': r.height,
};

/// The edge as the native side takes it: `top`, `bottom`, `left` or
/// `right`, with leading and trailing resolved for [direction].
String _edgeName(CNPopoverEdge edge, TextDirection? direction) {
  final rtl = direction == TextDirection.rtl;
  return switch (edge) {
    CNPopoverEdge.top => 'top',
    CNPopoverEdge.bottom => 'bottom',
    CNPopoverEdge.leading => rtl ? 'right' : 'left',
    CNPopoverEdge.trailing => rtl ? 'left' : 'right',
  };
}

String _actionStyleName(CNPopoverActionStyle style) => switch (style) {
  CNPopoverActionStyle.plain => 'plain',
  CNPopoverActionStyle.defaultAction => 'default',
  CNPopoverActionStyle.destructive => 'destructive',
  CNPopoverActionStyle.cancel => 'cancel',
};

/// Encodes [content] for the native side.
///
/// Exposed for tests: it is the contract shared with `CNPopoverManager.swift`
/// on both platforms.
@visibleForTesting
Map<String, Object?> debugEncodePopoverContent(
  CNPopoverContent content, {
  BuildContext? context,
}) => {
  if ((content.title ?? '').isNotEmpty) 'title': content.title,
  if ((content.message ?? '').isNotEmpty) 'message': content.message,
  if (content.gauges.isNotEmpty)
    'gauges': [
      for (final gauge in content.gauges)
        {
          'label': gauge.label,
          'fraction': gauge.fraction,
          if (gauge.valueText != null) 'valueText': gauge.valueText,
          if (gauge.tint != null)
            'tint': context != null && context.mounted
                ? resolveColorToArgb(gauge.tint, context)
                : gauge.tint!.toARGB32(),
        },
    ],
  'rows': [
    for (final row in content.rows)
      {
        ...encodeListItem(row.item),
        'id': row.id,
        'checked': row.checked,
        'enabled': row.enabled,
        if (row.readOnly) 'readOnly': true,
      },
  ],
  'toggles': [
    for (final toggle in content.toggles)
      {
        'id': toggle.id,
        'label': toggle.label,
        'value': toggle.value,
        'enabled': toggle.enabled,
        if (toggle.subtitle != null) 'subtitle': toggle.subtitle,
        if (toggle.symbol != null) 'sfSymbol': toggle.symbol!.name,
      },
  ],
  'actions': [
    for (final action in content.actions)
      {
        if (action.id != null) 'id': action.id,
        'label': action.label,
        'style': _actionStyleName(action.style),
      },
  ],
};

/// Builds the payload of [CNPopover.show]'s `show` call.
///
/// Exposed for tests: it is the contract shared with `CNPopoverManager.swift`
/// on both platforms. [edge] is `top`, `bottom`, `left` or `right`.
@visibleForTesting
Map<String, Object?> debugBuildPopoverPayload({
  required int session,
  required CNPopoverContent content,
  required Rect anchor,
  required String edge,
  double? width,
  int? tint,
  bool? isDark,
  BuildContext? context,
}) => {
  'session': session,
  'anchor': _rectMap(anchor),
  'edge': edge,
  'content': debugEncodePopoverContent(content, context: context),
  'width': ?width,
  'tint': ?tint,
  'isDark': ?isDark,
};

/// The content of a [CNPopover] in a Cupertino popup, on platforms without
/// a native popover.
class _PopoverFallback extends StatefulWidget {
  const _PopoverFallback({
    required this.content,
    required this.tint,
    required this.onToggleChanged,
  });

  final ValueListenable<CNPopoverContent> content;
  final Color? tint;
  final void Function(String id, bool value)? onToggleChanged;

  @override
  State<_PopoverFallback> createState() => _PopoverFallbackState();
}

class _PopoverFallbackState extends State<_PopoverFallback> {
  final Map<String, bool> _values = {};

  @override
  void initState() {
    super.initState();
    _takeValues();
    widget.content.addListener(_onContent);
  }

  @override
  void dispose() {
    widget.content.removeListener(_onContent);
    super.dispose();
  }

  void _takeValues() {
    _values
      ..clear()
      ..addEntries(
        widget.content.value.toggles.map((t) => MapEntry(t.id, t.value)),
      );
  }

  void _onContent() => setState(_takeValues);

  @override
  Widget build(BuildContext context) {
    final content = widget.content.value;
    final tint = widget.tint ?? CupertinoTheme.of(context).primaryColor;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final navigator = Navigator.of(context);
    final buttons = content.actions;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: CupertinoPopupSurface(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((content.title ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        header: true,
                        child: Text(
                          content.title!,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if ((content.message ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Text(
                        content.message!,
                        style: TextStyle(fontSize: 15, color: secondary),
                      ),
                    ),
                  for (final gauge in content.gauges)
                    _FallbackGauge(gauge: gauge, tint: gauge.tint ?? tint),
                  for (final row in content.rows)
                    Semantics(
                      selected: row.checked,
                      child: CupertinoListTile(
                        title: Text(row.item.title),
                        subtitle: row.item.subtitle == null
                            ? null
                            : Text(row.item.subtitle!),
                        additionalInfo: row.item.trailingText == null
                            ? null
                            : Text(row.item.trailingText!),
                        trailing: row.checked
                            ? Icon(CupertinoIcons.check_mark, color: tint)
                            : null,
                        onTap: row.enabled && !row.readOnly
                            ? () => navigator.pop(row.id)
                            : null,
                      ),
                    ),
                  for (final toggle in content.toggles)
                    CupertinoListTile(
                      title: Text(toggle.label),
                      subtitle: toggle.subtitle == null
                          ? null
                          : Text(toggle.subtitle!),
                      trailing: CupertinoSwitch(
                        value: _values[toggle.id] ?? toggle.value,
                        activeTrackColor: tint,
                        onChanged: toggle.enabled
                            ? (value) {
                                setState(() => _values[toggle.id] = value);
                                widget.onToggleChanged?.call(toggle.id, value);
                              }
                            : null,
                      ),
                    ),
                  if (buttons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final action in buttons)
                            _fallbackButton(action, navigator, tint),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackButton(
    CNPopoverAction action,
    NavigatorState navigator,
    Color tint,
  ) {
    final label = Text(action.label);
    void onPressed() => navigator.pop(action.id);
    switch (action.style) {
      case CNPopoverActionStyle.defaultAction:
        return CupertinoButton.filled(onPressed: onPressed, child: label);
      case CNPopoverActionStyle.destructive:
        return CupertinoButton(
          onPressed: onPressed,
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: CupertinoColors.destructiveRed),
            child: label,
          ),
        );
      case CNPopoverActionStyle.plain:
      case CNPopoverActionStyle.cancel:
        return CupertinoButton(onPressed: onPressed, child: label);
    }
  }
}

/// A [CNPopoverGauge] in the fallback popup: the label and value over a bar.
class _FallbackGauge extends StatelessWidget {
  const _FallbackGauge({required this.gauge, required this.tint});

  final CNPopoverGauge gauge;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final track = CupertinoColors.systemFill.resolveFrom(context);
    final percent = '${(gauge.fraction * 100).round()}%';
    return Semantics(
      label: gauge.label,
      value: gauge.valueText ?? percent,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(gauge.label)),
                if (gauge.valueText != null)
                  Text(gauge.valueText!, style: TextStyle(color: secondary)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: track),
                    FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: gauge.fraction,
                      child: ColoredBox(color: tint),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
