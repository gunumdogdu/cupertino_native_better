import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Native views whose widgets were disposed, kept for a moment so that a
/// widget built again with the same configuration shows the same native
/// view in its first frame (#166).
///
/// A new platform view takes a few frames to show: the native view is
/// created through an asynchronous call, and only then composited. A
/// header that is swapped for a loading placeholder and back mounts a new
/// widget each time, so its native controls blinked out for those frames
/// while the Flutter content around them was already drawn. A kept view is
/// not composited while it waits, so it isn't on screen, as a platform view
/// under `Visibility(visible: false, maintainState: true)` isn't.
abstract final class ReusablePlatformViews {
  /// How long a native view is kept after its widget was disposed. Zero
  /// disposes of it at once.
  static Duration keepAlive = const Duration(seconds: 5);

  /// At most this many views are kept; the oldest goes first.
  static const int _maxParked = 8;

  static final List<_ParkedView> _parked = <_ParkedView>[];
  static final Stopwatch _clock = Stopwatch()..start();
  static bool _sweepScheduled = false;

  /// The time a view was kept at, from the clock that [keepAlive] is
  /// measured on. Tests can replace it.
  @visibleForTesting
  static Duration Function() debugNow = () => _clock.elapsed;

  static void _park(_ParkedView view) {
    _parked.add(view);
    while (_parked.length > _maxParked) {
      _parked.removeAt(0).controller.dispose();
    }
    _scheduleSweep();
  }

  static _ParkedView? _take(String key) {
    for (var i = _parked.length - 1; i >= 0; i--) {
      if (_parked[i].key == key) return _parked.removeAt(i);
    }
    return null;
  }

  // Swept at the end of frames rather than on a timer: a kept view waits
  // for the next frame after [keepAlive] (none come while nothing changes,
  // and it's only one native view), and no timer is left pending in tests.
  static void _scheduleSweep() {
    if (_sweepScheduled || _parked.isEmpty) return;
    _sweepScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _sweepScheduled = false;
      _sweep();
    });
  }

  static void _sweep() {
    final now = debugNow();
    _parked.removeWhere((view) {
      final expired = now - view.parkedAt >= keepAlive;
      if (expired) view.controller.dispose();
      return expired;
    });
    _scheduleSweep();
  }

  /// How many native views are kept now.
  @visibleForTesting
  static int get debugParkedCount => _parked.length;

  /// Forgets every kept view, so that one test can't reuse the views of
  /// another. Their native views are not disposed of (in tests they are
  /// mocks).
  @visibleForTesting
  static void debugReset() {
    _parked.clear();
    _sweepScheduled = false;
    keepAlive = const Duration(seconds: 5);
    debugNow = () => _clock.elapsed;
  }
}

/// Passes the engine's focus request to the widget showing the view now,
/// which changes when a kept view is reused.
class _FocusRelay {
  VoidCallback? target;
  void call() => target?.call();
}

class _ParkedView {
  _ParkedView({
    required this.key,
    required this.controller,
    required this.memo,
    required this.focus,
    required this.parkedAt,
  });

  final String key;
  final DarwinPlatformViewController controller;
  final Object? memo;
  final _FocusRelay focus;
  final Duration parkedAt;
}

/// A `UiKitView` (iOS) or `AppKitView` (macOS) whose native view can be kept
/// for reuse once this widget is disposed, and that can show a kept one
/// instead of creating a new one (#166).
class ReusableDarwinPlatformView extends StatefulWidget {
  /// Creates the platform view.
  const ReusableDarwinPlatformView({
    super.key,
    required this.viewType,
    this.creationParams,
    this.creationParamsCodec = const StandardMessageCodec(),
    this.onPlatformViewCreated,
    this.onPlatformViewReused,
    this.gestureRecognizers,
    this.hitTestBehavior = PlatformViewHitTestBehavior.opaque,
    this.reuseKey,
    this.reuse = true,
    this.memo,
  });

  /// The native view's type, as registered by the plugin.
  final String viewType;

  /// Sent to the native factory when a new view is created.
  final dynamic creationParams;

  /// Encodes [creationParams].
  final MessageCodec<dynamic> creationParamsCodec;

  /// Called with the id of a newly created native view.
  final PlatformViewCreatedCallback? onPlatformViewCreated;

  /// Called instead of [onPlatformViewCreated] when a kept view is shown,
  /// with its id and what [memo] returned when it was kept.
  ///
  /// It is called while this widget is built, so the native view can be
  /// brought up to date before the frame that shows it: it must not call
  /// `setState`.
  final void Function(int id, Object? memo)? onPlatformViewReused;

  /// Gestures the native view takes part in.
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  /// How the native view takes part in hit testing.
  final PlatformViewHitTestBehavior hitTestBehavior;

  /// Everything about the view that needs a new native view to change. A
  /// view is kept under it once this widget is disposed, and a new widget
  /// with the same key shows the kept view. Null never keeps the view.
  final String? reuseKey;

  /// Whether this widget may show a kept view when it is first built. It
  /// still keeps its own view when [reuseKey] is set.
  final bool reuse;

  /// What the native view shows when it is kept, handed to the next widget
  /// that shows it.
  final Object? Function()? memo;

  @override
  State<ReusableDarwinPlatformView> createState() =>
      _ReusableDarwinPlatformViewState();
}

class _ReusableDarwinPlatformViewState
    extends State<ReusableDarwinPlatformView> {
  DarwinPlatformViewController? _controller;
  FocusNode? _focusNode;
  _FocusRelay _focus = _FocusRelay();
  TextDirection? _layoutDirection;
  bool _initialized = false;

  static final Set<Factory<OneSequenceGestureRecognizer>> _noRecognizers =
      <Factory<OneSequenceGestureRecognizer>>{};

  bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final changed = _layoutDirection != direction;
    _layoutDirection = direction;
    if (!_initialized) {
      _initialized = true;
      _start();
    } else if (changed) {
      _controller?.setLayoutDirection(direction);
    }
  }

  @override
  void didUpdateWidget(ReusableDarwinPlatformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewType != oldWidget.viewType) {
      _controller?.dispose();
      _controller = null;
      _focusNode?.dispose();
      _focusNode = null;
      _create();
    }
  }

  void _start() {
    final key = widget.reuseKey;
    final kept = key != null && widget.reuse
        ? ReusablePlatformViews._take(key)
        : null;
    if (kept == null) {
      _create();
      return;
    }
    _controller = kept.controller;
    _focus = kept.focus..target = _requestFocus;
    _focusNode = FocusNode(debugLabel: 'ReusableDarwinPlatformView(id: '
        '${kept.controller.id})');
    kept.controller.setLayoutDirection(_layoutDirection!);
    widget.onPlatformViewReused?.call(kept.controller.id, kept.memo);
  }

  void _requestFocus() => _focusNode?.requestFocus();

  Future<void> _create() async {
    try {
      final id = platformViewsRegistry.getNextPlatformViewId();
      final focus = _FocusRelay()..target = _requestFocus;
      final DarwinPlatformViewController controller = _isMacOS
          ? await PlatformViewsService.initAppKitView(
              id: id,
              viewType: widget.viewType,
              layoutDirection: _layoutDirection!,
              creationParams: widget.creationParams,
              creationParamsCodec: widget.creationParamsCodec,
              onFocus: focus.call,
            )
          : await PlatformViewsService.initUiKitView(
              id: id,
              viewType: widget.viewType,
              layoutDirection: _layoutDirection!,
              creationParams: widget.creationParams,
              creationParamsCodec: widget.creationParamsCodec,
              onFocus: focus.call,
            );
      if (!mounted) {
        controller.dispose();
        return;
      }
      widget.onPlatformViewCreated?.call(id);
      setState(() {
        _controller = controller;
        _focus = focus;
        _focusNode = FocusNode(
          debugLabel: 'ReusableDarwinPlatformView(id: $id)',
        );
      });
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'cupertino_native_better',
          context: ErrorDescription('while creating a Darwin platform view'),
        ),
      );
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      final key = widget.reuseKey;
      if (key != null && ReusablePlatformViews.keepAlive > Duration.zero) {
        _focus.target = null;
        ReusablePlatformViews._park(
          _ParkedView(
            key: key,
            controller: controller,
            memo: widget.memo?.call(),
            focus: _focus,
            parkedAt: ReusablePlatformViews.debugNow(),
          ),
        );
      } else {
        controller.dispose();
      }
    }
    _focusNode?.dispose();
    _focusNode = null;
    super.dispose();
  }

  void _onFocusChange(bool isFocused, DarwinPlatformViewController c) {
    if (!isFocused) return;
    SystemChannels.textInput
        .invokeMethod<void>('TextInput.setPlatformViewClient', <String, dynamic>{
          'platformViewId': c.id,
        })
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.expand();
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) => _onFocusChange(focused, controller),
      child: _DarwinView(
        controller: controller,
        hitTestBehavior: widget.hitTestBehavior,
        gestureRecognizers: widget.gestureRecognizers ?? _noRecognizers,
      ),
    );
  }
}

class _DarwinView extends LeafRenderObjectWidget {
  const _DarwinView({
    required this.controller,
    required this.hitTestBehavior,
    required this.gestureRecognizers,
  });

  final DarwinPlatformViewController controller;
  final PlatformViewHitTestBehavior hitTestBehavior;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final c = controller;
    if (c is AppKitViewController) {
      return RenderAppKitView(
        viewController: c,
        hitTestBehavior: hitTestBehavior,
        gestureRecognizers: gestureRecognizers,
      );
    }
    return RenderUiKitView(
      viewController: c as UiKitViewController,
      hitTestBehavior: hitTestBehavior,
      gestureRecognizers: gestureRecognizers,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final c = controller;
    if (renderObject is RenderAppKitView && c is AppKitViewController) {
      renderObject
        ..viewController = c
        ..hitTestBehavior = hitTestBehavior
        ..updateGestureRecognizers(gestureRecognizers);
    } else if (renderObject is RenderUiKitView && c is UiKitViewController) {
      renderObject
        ..viewController = c
        ..hitTestBehavior = hitTestBehavior
        ..updateGestureRecognizers(gestureRecognizers);
    }
  }
}
