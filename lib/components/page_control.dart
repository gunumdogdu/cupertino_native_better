import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../utils/version_detector.dart';
import '../utils/theme_helper.dart';
import '../utils/modal_hide_mixin.dart';
import '../channel/params.dart';

/// Background behind the dots of a [CNPageControl]
/// (`UIPageControl.BackgroundStyle`).
enum CNPageControlBackgroundStyle {
  /// A background that appears while the user interacts with the control.
  automatic,

  /// A background that is always shown.
  prominent,

  /// No background, even while the user interacts with the control.
  minimal,
}

/// A Cupertino-native page control: a row of dots, one per page, with the
/// current page highlighted.
///
/// On iOS 26+ this embeds a `UIPageControl` through a platform view. macOS
/// has no native page control, so on macOS, below iOS 26 and on other
/// platforms it is drawn in Flutter, with the same look and interactions:
/// a tap beside the current dot moves one page that way, and with
/// [allowsContinuousInteraction] a drag across the dots scrubs through the
/// pages.
///
/// ## With a PageView
///
/// Pass the [PageController] of a `PageView` as [controller]. The dots then
/// follow the PageView as the user swipes it, and a tap on the dots animates
/// the PageView to the new page ([pageAnimationDuration],
/// [pageAnimationCurve]); a scrub jumps to it. [currentPage] is not used, and
/// [onChanged] is still called for each page the user picks on the dots.
///
/// ```dart
/// final pages = PageController();
///
/// Column(
///   children: [
///     Expanded(child: PageView(controller: pages, children: slides)),
///     CNPageControl(numberOfPages: slides.length, controller: pages),
///   ],
/// )
/// ```
///
/// Without a controller the page control is controlled: it shows
/// [currentPage], and [onChanged] reports the page the user picks, which
/// the parent passes back as [currentPage].
class CNPageControl extends StatefulWidget {
  /// Creates a Cupertino-native page control.
  const CNPageControl({
    super.key,
    required this.numberOfPages,
    this.currentPage = 0,
    this.onChanged,
    this.controller,
    this.pageIndicatorColor,
    this.currentPageIndicatorColor,
    this.backgroundStyle = CNPageControlBackgroundStyle.automatic,
    this.hidesForSinglePage = false,
    this.allowsContinuousInteraction = true,
    this.enabled = true,
    this.height = 28.0,
    this.autoHideOnModal = true,
    this.semanticLabel,
  }) : assert(numberOfPages >= 0, 'CNPageControl.numberOfPages is negative');

  /// Number of pages, one dot each.
  final int numberOfPages;

  /// The highlighted page, from 0. Clamped to the pages there are. Not used
  /// when a [controller] is given.
  final int currentPage;

  /// Called with the page the user picks on the dots.
  final ValueChanged<int>? onChanged;

  /// The controller of a `PageView` the dots follow and move. See "With a
  /// PageView" above.
  final PageController? controller;

  /// Colour of the dots of the other pages. Defaults to
  /// [CupertinoColors.tertiaryLabel].
  ///
  /// UIPageControl's own colours are white dots, made to sit over a photo or
  /// a dark background, which vanish on a light one. The defaults here
  /// follow the theme instead: the same as UIKit's in dark mode, dark dots
  /// in light mode.
  final Color? pageIndicatorColor;

  /// Colour of the current page's dot. Defaults to [CupertinoColors.label].
  final Color? currentPageIndicatorColor;

  /// Background behind the dots. Defaults to
  /// [CNPageControlBackgroundStyle.automatic], shown while the user
  /// interacts with the control.
  final CNPageControlBackgroundStyle backgroundStyle;

  /// Whether the control hides itself when there is only one page. It keeps
  /// its space in the layout.
  final bool hidesForSinglePage;

  /// Whether the user can drag across the dots to scrub through the pages.
  /// When false, only taps move, one page at a time. Defaults to true.
  final bool allowsContinuousInteraction;

  /// Whether the user can change the page on the dots. A disabled control
  /// looks the same, as UIPageControl does, and still follows [currentPage]
  /// or its [controller]: use it for dots that only show the page.
  final bool enabled;

  /// Height of the control. The dots and their background keep the system
  /// size, centred in it.
  final double height;

  /// When true (default), destroys the native page control's PlatformView
  /// while a modal sheet is presented above this widget's host route.
  /// Prevents the iOS hybrid-composition z-order bleed (Issue #53) where the
  /// host-page PlatformView's pixels leak through a sheet that also contains
  /// a PlatformView (CN-widget). Requires `CNTabBarRouteObserver()` to be
  /// registered in the app's `navigatorObservers`. No effect on non-iOS or
  /// iOS < 26 (Flutter path).
  final bool autoHideOnModal;

  /// What VoiceOver reads for the control, before "page 2 of 5", e.g.
  /// `'Onboarding'`.
  final String? semanticLabel;

  /// How long a tap on the dots animates the [controller]'s PageView.
  static const Duration pageAnimationDuration = Duration(milliseconds: 300);

  /// The curve of that animation.
  static const Curve pageAnimationCurve = Curves.easeInOut;

  @override
  State<CNPageControl> createState() => _CNPageControlState();
}

class _CNPageControlState extends State<CNPageControl>
    with ModalHideMixin<CNPageControl> {
  @override
  bool get autoHideOnModal => widget.autoHideOnModal;

  @override
  MethodChannel? get platformViewChannel => _channel;

  MethodChannel? _channel;

  int? _lastNumberOfPages;
  int? _lastCurrentPage;
  int? _lastPageTint;
  int? _lastCurrentPageTint;
  CNPageControlBackgroundStyle? _lastBackgroundStyle;
  bool? _lastHidesForSinglePage;
  bool? _lastAllowsContinuous;
  bool? _lastEnabled;
  String? _lastSemanticLabel;
  bool? _lastIsDark;
  bool get _isDark => ThemeHelper.isDark(context);

  /// The page the controller's PageView is animating to after a tap on the
  /// dots. While it runs, the pages it passes are not shown, so the dots do
  /// not step back through them.
  int? _animatingTo;

  Color get _pageTint =>
      widget.pageIndicatorColor ?? CupertinoColors.tertiaryLabel;
  Color get _currentPageTint =>
      widget.currentPageIndicatorColor ?? CupertinoColors.label;

  /// The page shown when following a controller.
  int _controllerPage = 0;

  bool get _usesNative =>
      defaultTargetPlatform == TargetPlatform.iOS &&
      PlatformVersion.shouldUseNativeGlass;

  int get _shownPage {
    final page = widget.controller != null
        ? _controllerPage
        : widget.currentPage;
    if (widget.numberOfPages == 0) return 0;
    return page.clamp(0, widget.numberOfPages - 1);
  }

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CNPageControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      _animatingTo = null;
      _attachController(widget.controller);
    }
    _syncPropsToNativeIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
  }

  void _attachController(PageController? controller) {
    if (controller == null) return;
    controller.addListener(_onControllerChanged);
    _controllerPage = _pageOf(controller) ?? controller.initialPage;
  }

  /// The page [controller]'s PageView is closest to, once it is laid out.
  int? _pageOf(PageController controller) {
    if (!controller.hasClients || controller.positions.length != 1) {
      return null;
    }
    final position = controller.position;
    if (!position.hasContentDimensions || !position.hasPixels) return null;
    return controller.page?.round();
  }

  void _onControllerChanged() {
    final controller = widget.controller;
    if (controller == null || _animatingTo != null) return;
    final page = _pageOf(controller);
    if (page == null || page == _controllerPage) return;
    setState(() => _controllerPage = page);
    _syncPropsToNativeIfNeeded();
  }

  /// A page picked on the dots, natively or in the Flutter control.
  void _onUserPicked(int page, {required bool continuous}) {
    final controller = widget.controller;
    if (controller != null) {
      setState(() => _controllerPage = page);
      if (_pageOf(controller) != null) {
        if (continuous) {
          // A scrub follows the finger; animating every step would lag.
          controller.jumpToPage(page);
        } else {
          _animatingTo = page;
          controller
              .animateToPage(
                page,
                duration: CNPageControl.pageAnimationDuration,
                curve: CNPageControl.pageAnimationCurve,
              )
              .whenComplete(() {
                if (_animatingTo != page) return;
                _animatingTo = null;
                // A swipe may have stopped the animation elsewhere.
                if (mounted) _onControllerChanged();
              });
        }
      }
    }
    widget.onChanged?.call(page);
  }

  @override
  Widget build(BuildContext context) {
    if (!_usesNative) {
      return _CNFlutterPageControl(
        numberOfPages: widget.numberOfPages,
        currentPage: _shownPage,
        pageIndicatorColor: _pageTint,
        currentPageIndicatorColor: _currentPageTint,
        backgroundStyle: widget.backgroundStyle,
        hidesForSinglePage: widget.hidesForSinglePage,
        allowsContinuousInteraction: widget.allowsContinuousInteraction,
        enabled: widget.enabled,
        height: widget.height,
        semanticLabel: widget.semanticLabel,
        onPicked: _onUserPicked,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Platform views expand to the biggest size in unconstrained axes,
        // so in a Row the control would try to grow to an infinite width.
        // Fill a bounded width, as UIPageControl centres its dots and takes
        // taps on either side; otherwise use about the width of the dots.
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : _estimatedWidth(widget.numberOfPages);

        // Issue #53 fix: when a modal is presented above our host route,
        // destroy the native UIPageControl to remove its PlatformView from
        // the shared iOS PlatformView container.
        final hidden = maybeHiddenPlaceholder(
          height: widget.height,
          width: width,
        );
        if (hidden != null) return hidden;

        final creationParams = <String, dynamic>{
          'numberOfPages': widget.numberOfPages,
          'currentPage': _shownPage,
          'backgroundStyle': widget.backgroundStyle.name,
          'hidesForSinglePage': widget.hidesForSinglePage,
          'allowsContinuousInteraction': widget.allowsContinuousInteraction,
          'enabled': widget.enabled,
          if (widget.semanticLabel != null)
            'semanticLabel': widget.semanticLabel,
          'isDark': _isDark,
          'style': _style(),
        };

        return wrapWithModalInteractionGuard(
          ClipRect(
            child: SizedBox(
              width: width,
              height: widget.height,
              child: UiKitView(
                viewType: 'CupertinoNativePageControl',
                creationParamsCodec: const StandardMessageCodec(),
                creationParams: creationParams,
                onPlatformViewCreated: _onPlatformViewCreated,
                // Taps move one page; a press-and-drag scrubs.
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
                  Factory<HorizontalDragGestureRecognizer>(
                    () => HorizontalDragGestureRecognizer(),
                  ),
                  Factory<LongPressGestureRecognizer>(
                    () => LongPressGestureRecognizer(),
                  ),
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// About the width UIPageControl needs for [pages] dots and its
  /// background.
  /// A little more than that, as UIPageControl drops dots that do not fit.
  static double _estimatedWidth(int pages) =>
      math.max(44.0, pages * _kDotPitch + 2 * _kBackgroundPadding + 12);

  Map<String, dynamic> _style() {
    final page = resolveColorToArgb(_pageTint, context);
    final current = resolveColorToArgb(_currentPageTint, context);
    return <String, dynamic>{
      if (page != null) 'pageIndicatorTint': page,
      if (current != null) 'currentPageIndicatorTint': current,
    };
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('CupertinoNativePageControl_$id');
    _channel = channel;
    channel.setMethodCallHandler(_onMethodCall);
    _cacheCurrentProps();
    _syncBrightnessIfNeeded();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'pageChanged') {
      final args = call.arguments as Map?;
      final page = (args?['page'] as num?)?.toInt();
      if (page != null) {
        // Remember it first, so the rebuild that follows does not send the
        // page back to the control the user is touching.
        _lastCurrentPage = page;
        _onUserPicked(page, continuous: args?['continuous'] == true);
      }
    }
    return null;
  }

  void _cacheCurrentProps() {
    _lastNumberOfPages = widget.numberOfPages;
    _lastCurrentPage = _shownPage;
    _lastPageTint = resolveColorToArgb(_pageTint, context);
    _lastCurrentPageTint = resolveColorToArgb(_currentPageTint, context);
    _lastBackgroundStyle = widget.backgroundStyle;
    _lastHidesForSinglePage = widget.hidesForSinglePage;
    _lastAllowsContinuous = widget.allowsContinuousInteraction;
    _lastEnabled = widget.enabled;
    _lastSemanticLabel = widget.semanticLabel;
    _lastIsDark = _isDark;
  }

  /// Sends [method] to the native view, ignoring the error a view that has
  /// just been destroyed (e.g. hidden under a sheet) answers with. A view
  /// created again gets the current values from its creation params.
  Future<void> _invoke(
    MethodChannel channel,
    String method,
    Map<String, dynamic> args,
  ) async {
    try {
      await channel.invokeMethod(method, args);
    } catch (_) {}
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;

    // Resolve theme-dependent values before awaiting.
    final page = _shownPage;
    final pageTint = resolveColorToArgb(_pageTint, context);
    final currentTint = resolveColorToArgb(_currentPageTint, context);

    // The count goes first: UIPageControl clamps the page to it.
    if (_lastNumberOfPages != widget.numberOfPages) {
      _lastNumberOfPages = widget.numberOfPages;
      await _invoke(channel, 'setNumberOfPages', {
        'numberOfPages': widget.numberOfPages,
      });
    }

    if (_lastCurrentPage != page) {
      _lastCurrentPage = page;
      await _invoke(channel, 'setCurrentPage', {'currentPage': page});
    }

    if (_lastBackgroundStyle != widget.backgroundStyle ||
        _lastHidesForSinglePage != widget.hidesForSinglePage ||
        _lastAllowsContinuous != widget.allowsContinuousInteraction) {
      _lastBackgroundStyle = widget.backgroundStyle;
      _lastHidesForSinglePage = widget.hidesForSinglePage;
      _lastAllowsContinuous = widget.allowsContinuousInteraction;
      await _invoke(channel, 'setOptions', {
        'backgroundStyle': widget.backgroundStyle.name,
        'hidesForSinglePage': widget.hidesForSinglePage,
        'allowsContinuousInteraction': widget.allowsContinuousInteraction,
      });
    }

    if (_lastEnabled != widget.enabled) {
      _lastEnabled = widget.enabled;
      await _invoke(channel, 'setEnabled', {'enabled': widget.enabled});
    }

    if (_lastSemanticLabel != widget.semanticLabel) {
      _lastSemanticLabel = widget.semanticLabel;
      await _invoke(channel, 'setSemanticLabel', {
        'label': widget.semanticLabel,
      });
    }

    await _syncTints(channel, pageTint, currentTint);
  }

  /// Sends changed dot colours.
  Future<void> _syncTints(
    MethodChannel channel,
    int? pageTint,
    int? currentTint,
  ) async {
    if (_lastPageTint != pageTint || _lastCurrentPageTint != currentTint) {
      _lastPageTint = pageTint;
      _lastCurrentPageTint = currentTint;
      await _invoke(channel, 'setStyle', {
        'pageIndicatorTint': pageTint,
        'currentPageIndicatorTint': currentTint,
      });
    }
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;
    final isDark = _isDark;
    final pageTint = resolveColorToArgb(_pageTint, context);
    final currentTint = resolveColorToArgb(_currentPageTint, context);

    if (_lastIsDark != isDark) {
      _lastIsDark = isDark;
      await _invoke(channel, 'setBrightness', {'isDark': isDark});
    }

    // A dynamic colour resolves differently in the new brightness.
    await _syncTints(channel, pageTint, currentTint);
  }
}

// Sizes as UIPageControl lays its dots out on iOS 26 and 27.

/// Diameter of a dot.
const double _kDotSize = 8;

/// Distance between the centres of two dots.
const double _kDotPitch = 17.7;

/// Padding between the outer dots' slots and the ends of their background.
const double _kBackgroundPadding = 10;

/// Height of the background behind the dots.
const double _kBackgroundHeight = 26;

/// Most dots shown at once; with more pages, a window of them scrolls.
const int _kMaxVisibleDots = 10;

/// Fill of the background: quaternarySystemFill in light mode, a little
/// lighter than it in dark mode, matching UIPageControl's.
const CupertinoDynamicColor _kBackgroundColor =
    CupertinoDynamicColor.withBrightness(
      color: Color(0x14747480),
      darkColor: Color(0x42767680),
    );

/// The page control drawn in Flutter, on macOS and below iOS 26: dots in a
/// row, the current one highlighted, on an optional capsule background.
class _CNFlutterPageControl extends StatefulWidget {
  const _CNFlutterPageControl({
    required this.numberOfPages,
    required this.currentPage,
    required this.pageIndicatorColor,
    required this.currentPageIndicatorColor,
    required this.backgroundStyle,
    required this.hidesForSinglePage,
    required this.allowsContinuousInteraction,
    required this.enabled,
    required this.height,
    required this.semanticLabel,
    required this.onPicked,
  });

  final int numberOfPages;
  final int currentPage;
  final Color pageIndicatorColor;
  final Color currentPageIndicatorColor;
  final CNPageControlBackgroundStyle backgroundStyle;
  final bool hidesForSinglePage;
  final bool allowsContinuousInteraction;
  final bool enabled;
  final double height;
  final String? semanticLabel;
  final void Function(int page, {required bool continuous}) onPicked;

  @override
  State<_CNFlutterPageControl> createState() => _CNFlutterPageControlState();
}

class _CNFlutterPageControlState extends State<_CNFlutterPageControl> {
  /// Whether a finger is on the control, which shows the automatic
  /// background.
  bool _touching = false;

  /// The first dot drawn, when there are more pages than fit.
  int _firstVisible = 0;

  /// Layout of the dots from the last build, for hit testing.
  double _dotsLeft = 0;
  int _visibleCount = 0;

  int get _last => math.max(0, widget.numberOfPages - 1);

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  /// The position of [page] from the left; dots run right to left in a
  /// right-to-left layout, as UIPageControl's do. It maps both ways.
  int _logical(int page) => _rtl ? _last - page : page;

  void _pick(int page, {required bool continuous}) {
    if (!widget.enabled) return;
    final clamped = page.clamp(0, _last);
    if (clamped == widget.currentPage) return;
    widget.onPicked(clamped, continuous: continuous);
  }

  /// A tap beside the current dot moves one page towards it, as UIKit does.
  void _onTapUp(TapUpDetails details) {
    final current = _logical(widget.currentPage);
    final currentX =
        _dotsLeft + (current - _firstVisible) * _kDotPitch + _kDotPitch / 2;
    final step = details.localPosition.dx < currentX ? -1 : 1;
    _pick(_logical(current + step), continuous: false);
  }

  /// A drag picks the dot under the finger.
  void _onDrag(Offset local) {
    final int slot = ((local.dx - _dotsLeft) / _kDotPitch)
        .floor()
        .clamp(0, math.max(0, _visibleCount - 1))
        .toInt();
    _pick(_logical(_firstVisible + slot), continuous: true);
  }

  void _setTouching(bool touching) {
    if (_touching != touching) setState(() => _touching = touching);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.numberOfPages;
    if (n == 0 || (n == 1 && widget.hidesForSinglePage)) {
      return SizedBox(height: widget.height);
    }

    final current = CupertinoDynamicColor.resolve(
      widget.currentPageIndicatorColor,
      context,
    );
    final other = CupertinoDynamicColor.resolve(
      widget.pageIndicatorColor,
      context,
    );
    final background = CupertinoDynamicColor.resolve(
      _kBackgroundColor,
      context,
    );
    final showBackground = switch (widget.backgroundStyle) {
      CNPageControlBackgroundStyle.prominent => true,
      CNPageControlBackgroundStyle.minimal => false,
      CNPageControlBackgroundStyle.automatic => _touching,
    };

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: 'Page ${widget.currentPage + 1} of $n',
      enabled: widget.enabled,
      increasedValue: widget.enabled && widget.currentPage < _last
          ? 'Page ${widget.currentPage + 2} of $n'
          : null,
      decreasedValue: widget.enabled && widget.currentPage > 0
          ? 'Page ${widget.currentPage} of $n'
          : null,
      onIncrease: widget.enabled && widget.currentPage < _last
          ? () => _pick(widget.currentPage + 1, continuous: false)
          : null,
      onDecrease: widget.enabled && widget.currentPage > 0
          ? () => _pick(widget.currentPage - 1, continuous: false)
          : null,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // As many dots as fit; with more pages, a window of them that
            // follows the current page, its end dots drawn smaller to show
            // there are more.
            final available = constraints.hasBoundedWidth
                ? constraints.maxWidth - 2 * _kBackgroundPadding
                : n * _kDotPitch;
            final fit = math.max(1, (available / _kDotPitch).floor());
            _visibleCount = math.min(n, math.min(fit, _kMaxVisibleDots));
            // The window moves only when the current dot gets within two
            // of its ends, so the current dot is never a shrunk one.
            final currentSlot = _logical(widget.currentPage);
            final margin = math.min(2, (_visibleCount - 1) ~/ 2);
            if (currentSlot < _firstVisible + margin) {
              _firstVisible = currentSlot - margin;
            } else if (currentSlot >
                _firstVisible + _visibleCount - 1 - margin) {
              _firstVisible = currentSlot - (_visibleCount - 1 - margin);
            }
            _firstVisible = _firstVisible.clamp(0, n - _visibleCount);

            final dotsWidth = _visibleCount * _kDotPitch;
            final boxWidth = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : dotsWidth + 2 * _kBackgroundPadding;
            _dotsLeft = (boxWidth - dotsWidth) / 2;

            Widget dot(int slot) {
              final index = _logical(_firstVisible + slot);
              // The two dots at an end beyond which there are more pages
              // shrink, the outer one more.
              final moreBefore = _firstVisible > 0;
              final moreAfter = _firstVisible + _visibleCount < n;
              final fromEnd = math.min(
                moreBefore ? slot : 99,
                moreAfter ? _visibleCount - 1 - slot : 99,
              );
              final size = switch (fromEnd) {
                0 => _kDotSize * 0.5,
                1 => _kDotSize * 0.75,
                _ => _kDotSize,
              };
              return SizedBox(
                width: _kDotPitch,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == widget.currentPage ? current : other,
                    ),
                  ),
                ),
              );
            }

            // No gestures at all while disabled, so a surrounding scroll
            // view gets the drags.
            final scrubs = widget.enabled && widget.allowsContinuousInteraction;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: widget.enabled ? (_) => _setTouching(true) : null,
              onTapUp: widget.enabled
                  ? (d) {
                      _setTouching(false);
                      _onTapUp(d);
                    }
                  : null,
              onTapCancel: widget.enabled ? () => _setTouching(false) : null,
              onHorizontalDragStart: scrubs
                  ? (d) {
                      _setTouching(true);
                      _onDrag(d.localPosition);
                    }
                  : null,
              onHorizontalDragUpdate: scrubs
                  ? (d) => _onDrag(d.localPosition)
                  : null,
              onHorizontalDragEnd: scrubs ? (_) => _setTouching(false) : null,
              onHorizontalDragCancel: scrubs ? () => _setTouching(false) : null,
              child: SizedBox(
                width: boxWidth,
                height: widget.height,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _kBackgroundHeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: _kBackgroundPadding,
                    ),
                    decoration: BoxDecoration(
                      // Fades rather than pops in and out.
                      color: background.withValues(
                        alpha: showBackground ? background.a : 0,
                      ),
                      borderRadius: BorderRadius.circular(
                        _kBackgroundHeight / 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var slot = 0; slot < _visibleCount; slot++)
                          dot(slot),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
