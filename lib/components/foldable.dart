import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const MethodChannel _channel = MethodChannel('cn_foldable');

/// Position of a foldable iPhone's hinge.
enum CNHingeStatus {
  /// Folded shut; the outer (cover) display is in use.
  closed,

  /// Neither shut nor flat — the book and tabletop poses.
  partiallyOpen,

  /// Open as far as the device allows; the inner display is flat.
  fullyOpen,

  /// The system reported a hinge but not its status.
  unknown,
}

/// The hinge of a foldable iPhone, as reported by `UIHingeInteraction`.
@immutable
class CNHinge {
  /// Creates a hinge snapshot.
  const CNHinge({required this.status, required this.angle});

  /// Closed, partially open or fully open.
  final CNHingeStatus status;

  /// Opening angle in radians: 0 is shut, π is flat.
  ///
  /// The rate and precision of angle updates are system policy. Use it for
  /// effects and interactions; for layout, prefer [status] and the reserved
  /// regions in [CNFoldableState.regions].
  final double angle;

  /// [angle] in degrees.
  double get degrees => angle * 180 / math.pi;

  @override
  bool operator ==(Object other) =>
      other is CNHinge && other.status == status && other.angle == angle;

  @override
  int get hashCode => Object.hash(status, angle);

  @override
  String toString() =>
      'CNHinge(${status.name}, ${degrees.toStringAsFixed(1)}°)';
}

/// Which physical side of the screen the system's vertical bar is on.
///
/// On iPhone Duo the system stacks the status bar, toolbar and tab bar
/// vertically on one edge — on the outer display, and on the inner display in
/// landscape. The bar is aligned with the hardware, so this is a physical
/// side, not leading/trailing: it does not flip in right-to-left languages.
enum CNVerticalBarSide {
  /// The system uses horizontal bars here.
  none,

  /// The vertical bar is on the left edge.
  left,

  /// The vertical bar is on the right edge.
  right,
}

/// The kind of a [CNReservedRegion].
enum CNReservedRegionKind {
  /// The fold of a foldable display.
  division,

  /// Hardware that covers part of the display, such as a camera.
  occlusion,
}

/// A part of the screen content should stay clear of: the fold
/// ([CNReservedRegionKind.division]) or the camera
/// ([CNReservedRegionKind.occlusion]).
@immutable
class CNReservedRegion {
  /// Creates a reserved region.
  const CNReservedRegion({
    required this.kind,
    required this.frame,
    required this.margins,
    required this.isActive,
  });

  /// Fold or camera.
  final CNReservedRegionKind kind;

  /// The region in logical pixels, in the Flutter view's coordinates — the
  /// same space as `MediaQuery.sizeOf(context)`. It already includes
  /// [margins].
  final Rect frame;

  /// The margin the system recommends around the hardware itself.
  final EdgeInsets margins;

  /// Whether content should avoid the region right now. A fold is active only
  /// while the device is partially open; flat, content may cross it.
  final bool isActive;

  /// Whether the region runs left to right (a tabletop fold) rather than top
  /// to bottom (a book fold).
  bool get isHorizontal => frame.width >= frame.height;

  @override
  bool operator ==(Object other) =>
      other is CNReservedRegion &&
      other.kind == kind &&
      other.frame == frame &&
      other.margins == margins &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(kind, frame, margins, isActive);

  @override
  String toString() =>
      'CNReservedRegion(${kind.name}, $frame, active: $isActive)';
}

/// Everything [CNFoldable] knows about the screen the Flutter view is on.
@immutable
class CNFoldableState {
  /// Creates a state snapshot.
  const CNFoldableState({
    this.isSupported = false,
    this.hinge,
    this.verticalBarSide = CNVerticalBarSide.none,
    this.regions = const <CNReservedRegion>[],
  });

  /// The state on platforms and OS versions without foldable APIs: no hinge,
  /// no vertical bar, no regions.
  static const CNFoldableState unsupported = CNFoldableState();

  /// Whether the foldable APIs are available (iOS 27.1+, plugin built with the
  /// iOS 27.1 SDK). True on every such iPhone, foldable or not.
  final bool isSupported;

  /// The hinge, or null when the device has none.
  final CNHinge? hinge;

  /// Where the system's vertical bar is, if it uses one here.
  final CNVerticalBarSide verticalBarSide;

  /// Folds and camera regions, active or not.
  final List<CNReservedRegion> regions;

  /// Whether this is a foldable device.
  bool get isFoldable => hinge != null;

  /// Whether the system uses a vertical bar on this screen.
  bool get hasVerticalBar => verticalBarSide != CNVerticalBarSide.none;

  /// The fold content should avoid right now, if any.
  CNReservedRegion? get activeFold {
    for (final r in regions) {
      if (r.kind == CNReservedRegionKind.division && r.isActive) return r;
    }
    return null;
  }

  /// The regions as Flutter [DisplayFeature]s: an active fold becomes a
  /// half-opened [DisplayFeatureType.fold] and a camera a
  /// [DisplayFeatureType.cutout]. Inactive folds are left out, because content
  /// may cross a flat fold. [CNFoldableScope] puts these into
  /// `MediaQuery.displayFeatures`, which Flutter's dialogs and popups already
  /// avoid.
  List<DisplayFeature> get displayFeatures => <DisplayFeature>[
    for (final r in regions)
      if (r.kind == CNReservedRegionKind.division && r.isActive)
        DisplayFeature(
          bounds: r.frame,
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        )
      else if (r.kind == CNReservedRegionKind.occlusion && r.isActive)
        DisplayFeature(
          bounds: r.frame,
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
  ];

  /// Parses the map sent by the native side.
  factory CNFoldableState.fromMap(Map<Object?, Object?>? map) {
    if (map == null || map['supported'] != true) return unsupported;
    final hingeMap = map['hinge'] as Map<Object?, Object?>?;
    final regionMaps = (map['regions'] as List<Object?>?) ?? const <Object?>[];
    double d(Map<Object?, Object?> m, String k) =>
        (m[k] as num?)?.toDouble() ?? 0;
    return CNFoldableState(
      isSupported: true,
      hinge: hingeMap == null
          ? null
          : CNHinge(
              status: switch (hingeMap['status']) {
                'closed' => CNHingeStatus.closed,
                'partiallyOpen' => CNHingeStatus.partiallyOpen,
                'fullyOpen' => CNHingeStatus.fullyOpen,
                _ => CNHingeStatus.unknown,
              },
              angle: d(hingeMap, 'angle'),
            ),
      verticalBarSide: switch (map['verticalBarSide']) {
        'left' => CNVerticalBarSide.left,
        'right' => CNVerticalBarSide.right,
        _ => CNVerticalBarSide.none,
      },
      regions: <CNReservedRegion>[
        for (final raw in regionMaps)
          if (raw is Map<Object?, Object?>)
            CNReservedRegion(
              kind: raw['kind'] == 'division'
                  ? CNReservedRegionKind.division
                  : CNReservedRegionKind.occlusion,
              frame: Rect.fromLTWH(
                d(raw, 'x'),
                d(raw, 'y'),
                d(raw, 'width'),
                d(raw, 'height'),
              ),
              margins: EdgeInsets.fromLTRB(
                d(raw, 'marginLeft'),
                d(raw, 'marginTop'),
                d(raw, 'marginRight'),
                d(raw, 'marginBottom'),
              ),
              isActive: raw['active'] == true,
            ),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CNFoldableState &&
      other.isSupported == isSupported &&
      other.hinge == hinge &&
      other.verticalBarSide == verticalBarSide &&
      listEquals(other.regions, regions);

  @override
  int get hashCode =>
      Object.hash(isSupported, hinge, verticalBarSide, Object.hashAll(regions));

  @override
  String toString() =>
      'CNFoldableState(hinge: $hinge, verticalBar: ${verticalBarSide.name}, '
      'regions: $regions)';
}

/// Foldable-device state for iPhone Duo: the hinge, the system's vertical
/// bar, and the fold and camera regions.
///
/// Wrap the app (or a subtree) in [CNFoldableScope] and read the state with
/// [CNFoldable.of]:
///
/// ```dart
/// final foldable = CNFoldable.of(context);
/// if (foldable.hinge?.status == CNHingeStatus.partiallyOpen) { ... }
/// ```
///
/// Without a scope, call [start] and [stop] yourself and listen to [state].
///
/// Needs iOS 27.1 and a plugin build with the iOS 27.1 SDK (Xcode 27.1). Every
/// other platform reports [CNFoldableState.unsupported].
class CNFoldable {
  CNFoldable._();

  static final ValueNotifier<CNFoldableState> _state =
      ValueNotifier<CNFoldableState>(CNFoldableState.unsupported);
  static int _clients = 0;
  static bool _handlerInstalled = false;

  /// The latest state. Updates while at least one [start] is active.
  static ValueListenable<CNFoldableState> get state => _state;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Begins observing. Balanced by [stop]; observation runs while any caller
  /// has started it.
  static Future<void> start() async {
    if (!_isIOS) return;
    _clients++;
    if (!_handlerInstalled) {
      _handlerInstalled = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onStateChanged') {
          _state.value = CNFoldableState.fromMap(
            call.arguments as Map<Object?, Object?>?,
          );
        }
      });
    }
    if (_clients != 1) return;
    try {
      final reply = await _channel.invokeMapMethod<Object?, Object?>('start');
      _state.value = CNFoldableState.fromMap(reply);
    } on MissingPluginException {
      // Tests and hot-restart edge cases: stay unsupported.
    } on PlatformException {
      // Same.
    }
  }

  /// Ends one [start].
  static Future<void> stop() async {
    if (!_isIOS || _clients == 0) return;
    _clients--;
    if (_clients != 0) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Nothing to stop.
    } on PlatformException {
      // Nothing to stop.
    }
  }

  /// The state from the nearest [CNFoldableScope], rebuilding the caller on
  /// every change. Falls back to [state] (without rebuilds) when there is no
  /// scope.
  static CNFoldableState of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_CNFoldableInherited>();
    return scope?.state ?? _state.value;
  }

  /// Overrides the state, for tests and previews.
  @visibleForTesting
  static void debugSetState(CNFoldableState value) => _state.value = value;
}

/// Starts [CNFoldable] for its subtree, exposes the state to
/// [CNFoldable.of], and adds the active fold and camera regions to
/// `MediaQuery.displayFeatures`.
///
/// With the display features in place, Flutter's own dialogs, popups and
/// [DisplayFeatureSubScreen] keep clear of the fold when the device is
/// partially open, with no other change to the app.
class CNFoldableScope extends StatefulWidget {
  /// Creates a foldable scope.
  const CNFoldableScope({
    super.key,
    required this.child,
    this.applyDisplayFeatures = true,
  });

  /// The subtree.
  final Widget child;

  /// Whether to add the fold and camera regions to
  /// `MediaQuery.displayFeatures`.
  final bool applyDisplayFeatures;

  @override
  State<CNFoldableScope> createState() => _CNFoldableScopeState();
}

class _CNFoldableScopeState extends State<CNFoldableScope> {
  @override
  void initState() {
    super.initState();
    CNFoldable.start();
  }

  @override
  void dispose() {
    CNFoldable.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CNFoldableState>(
      valueListenable: CNFoldable.state,
      builder: (context, state, child) {
        Widget result = child!;
        // Always wrapped when enabled, even with no features: adding and
        // removing the MediaQuery as the fold comes and goes would change the
        // tree's shape and rebuild the whole subtree from scratch.
        if (widget.applyDisplayFeatures) {
          final data = MediaQuery.of(context);
          // MediaQueryData compares display features by value, so an angle
          // change that leaves the fold where it was notifies no one.
          result = MediaQuery(
            data: data.copyWith(
              displayFeatures: <DisplayFeature>[
                ...data.displayFeatures,
                ...state.displayFeatures,
              ],
            ),
            child: result,
          );
        }
        return _CNFoldableInherited(state: state, child: result);
      },
      child: widget.child,
    );
  }
}

class _CNFoldableInherited extends InheritedWidget {
  const _CNFoldableInherited({required this.state, required super.child});

  final CNFoldableState state;

  @override
  bool updateShouldNotify(_CNFoldableInherited oldWidget) =>
      oldWidget.state != state;
}
