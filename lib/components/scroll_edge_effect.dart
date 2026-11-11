/// The iOS 26 scroll edge effect over Flutter content.
///
/// {@category Components}
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../utils/theme_helper.dart';
import '../utils/version_detector.dart';

/// The edge of the screen or scroll view a [CNScrollEdgeEffect] covers.
enum CNScrollEdge {
  /// The top edge, under the status bar or a bar at the top.
  top,

  /// The bottom edge, under the home indicator or a tab bar.
  bottom,
}

/// The look of a [CNScrollEdgeEffect], as `UIScrollEdgeEffect.Style`.
enum CNScrollEdgeStyle {
  /// A soft, progressive blur that fades into the content.
  soft,

  /// A band that ends in a sharp line instead of fading out, for a bar
  /// whose content needs a clear separation from what scrolls under it.
  hard,
}

/// The system scroll edge effect of iOS 26 over the Flutter content behind
/// it: the progressive blur UIKit and SwiftUI apps get where content scrolls
/// under the status bar, a bar or the home indicator.
///
/// The effect is drawn by iOS itself (`UIScrollEdgeEffect`), so it matches
/// native apps and follows accessibility settings such as Reduce
/// Transparency. Put it over the scrolling content, for example in a
/// [Stack]; it places itself at its [edge] and lets touches through:
///
/// ```dart
/// Stack(
///   children: [
///     CustomScrollView(controller: controller, slivers: ...),
///     CNScrollEdgeEffect(edge: CNScrollEdge.top, controller: controller),
///   ],
/// )
/// ```
///
/// With a [controller] (or [scrollMetrics]), the effect shows while content
/// is scrolled under the edge and is gone at rest, as in a native scroll
/// view. iOS switches it on as soon as content is under the edge; it doesn't
/// fade in with the offset. Without either, it always shows.
///
/// [CNTabScaffold] can put one behind its tab bar
/// (`bottomScrollEdgeEffect: true`).
///
/// iOS 26 and later only. Elsewhere (earlier iOS, macOS, other platforms)
/// it draws nothing.
class CNScrollEdgeEffect extends StatefulWidget {
  /// Creates a scroll edge effect at [edge].
  const CNScrollEdgeEffect({
    super.key,
    this.edge = CNScrollEdge.top,
    this.height,
    this.style = CNScrollEdgeStyle.soft,
    this.controller,
    this.scrollMetrics,
    this.brightness,
  }) : assert(height == null || height >= 0),
       assert(
         controller == null || scrollMetrics == null,
         'Pass a controller or scrollMetrics, not both',
       );

  /// The edge the effect covers. Defaults to [CNScrollEdge.top].
  final CNScrollEdge edge;

  /// The height of the band the effect covers, from the edge. The effect
  /// fades out over about 10 pt past it.
  ///
  /// Defaults to the safe area on that edge (the status bar, or the home
  /// indicator), or 20 where there is none, which is what iOS covers in a
  /// scroll view without bars. Under a bar, pass the bar's height plus the
  /// safe area.
  final double? height;

  /// The look of the effect. Defaults to [CNScrollEdgeStyle.soft].
  final CNScrollEdgeStyle style;

  /// The scroll view's controller: the effect shows while its content is
  /// scrolled under the edge. Without it, the effect always shows.
  final ScrollController? controller;

  /// The scroll view's metrics, for a scroll view without a controller:
  /// update it from a `NotificationListener<ScrollMetricsNotification>` and
  /// `NotificationListener<ScrollUpdateNotification>` around the scroll
  /// view. The effect shows while its content is under the edge. Null
  /// metrics keep the effect on.
  final ValueListenable<ScrollMetrics?>? scrollMetrics;

  /// Whether the effect is drawn for light or dark content. Defaults to the
  /// app's brightness.
  final Brightness? brightness;

  /// The extra height the view takes past [height], so the soft end of the
  /// effect isn't cut off.
  static const double _tail = 24;

  /// Whether the effect is drawn on this platform (iOS 26 and later).
  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.iOS &&
      PlatformVersion.shouldUseNativeGlass;

  @override
  State<CNScrollEdgeEffect> createState() => _CNScrollEdgeEffectState();
}

class _CNScrollEdgeEffectState extends State<CNScrollEdgeEffect> {
  MethodChannel? _channel;
  double? _lastUnderneath;
  String? _lastStyle;
  double? _lastBand;
  bool? _lastDark;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onScroll);
    widget.scrollMetrics?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(CNScrollEdgeEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.scrollMetrics != widget.scrollMetrics) {
      oldWidget.controller?.removeListener(_onScroll);
      oldWidget.scrollMetrics?.removeListener(_onScroll);
      widget.controller?.addListener(_onScroll);
      widget.scrollMetrics?.addListener(_onScroll);
      _onScroll();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onScroll);
    widget.scrollMetrics?.removeListener(_onScroll);
    super.dispose();
  }

  bool get _isDark => switch (widget.brightness) {
    Brightness.dark => true,
    Brightness.light => false,
    null => ThemeHelper.isDark(context),
  };

  double _band(BuildContext context) {
    final height = widget.height;
    if (height != null) return height;
    final padding = MediaQuery.paddingOf(context);
    final safe = widget.edge == CNScrollEdge.top ? padding.top : padding.bottom;
    return safe > 0 ? safe : 20;
  }

  /// The metrics of the scroll view the effect follows, or null.
  ScrollMetrics? get _metrics {
    final listenable = widget.scrollMetrics;
    if (listenable != null) return listenable.value;
    final controller = widget.controller;
    if (controller == null || !controller.hasClients) return null;
    final positions = controller.positions;
    if (positions.length != 1) return null;
    return positions.single;
  }

  /// How far the content is under the edge: null without a controller or
  /// metrics, which keeps the effect on; 0 until the scroll view has laid
  /// out, so the effect doesn't show for a frame at rest.
  double? get _underneath {
    if (widget.controller == null && widget.scrollMetrics == null) {
      return null;
    }
    final metrics = _metrics;
    if (metrics == null ||
        !metrics.hasContentDimensions ||
        !metrics.hasPixels) {
      return 0;
    }
    final value = widget.edge == CNScrollEdge.top
        ? metrics.pixels - metrics.minScrollExtent
        : metrics.maxScrollExtent - metrics.pixels;
    // Only how far, up to a point: the effect is either on or off.
    return value.clamp(0.0, 100.0);
  }

  void _onScroll() {
    final under = _underneath;
    if (under == _lastUnderneath) return;
    _lastUnderneath = under;
    _channel?.invokeMethod<void>('update', {'underneath': under});
  }

  Map<String, Object?> _params(BuildContext context) => {
    'edge': widget.edge.name,
    'style': widget.style.name,
    'band': _band(context),
    'isDark': _isDark,
    'underneath': _underneath,
  };

  void _syncIfNeeded(BuildContext context) {
    final channel = _channel;
    if (channel == null) return;
    final band = _band(context);
    final dark = _isDark;
    final style = widget.style.name;
    if (band == _lastBand && dark == _lastDark && style == _lastStyle) {
      return;
    }
    _lastBand = band;
    _lastDark = dark;
    _lastStyle = style;
    channel.invokeMethod<void>('update', {
      'band': band,
      'isDark': dark,
      'style': style,
    });
  }

  void _onCreated(int id) {
    final channel = MethodChannel('CNScrollEdgeEffect_$id');
    _channel = channel;
    _lastBand = _band(context);
    _lastDark = _isDark;
    _lastStyle = widget.style.name;
    // The view was created with the value from the build, before the scroll
    // view's layout: always send the current one once.
    _lastUnderneath = double.nan;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(channel, _channel)) _onScroll();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!CNScrollEdgeEffect.isSupported) return const SizedBox.shrink();
    _syncIfNeeded(context);
    final band = _band(context);
    final view = UiKitView(
      viewType: 'CNScrollEdgeEffect',
      creationParams: _params(context),
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onCreated,
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
    );
    return Align(
      alignment: widget.edge == CNScrollEdge.top
          ? Alignment.topCenter
          : Alignment.bottomCenter,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: SizedBox(
            width: double.infinity,
            height: band + CNScrollEdgeEffect._tail,
            child: view,
          ),
        ),
      ),
    );
  }
}
