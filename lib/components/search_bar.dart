import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/glass_effect.dart';
import '../style/sf_symbol.dart';
import '../utils/modal_hide_mixin.dart';
import '../utils/optional_method_call.dart';
import '../utils/theme_helper.dart';
import '../utils/version_detector.dart';
import 'liquid_glass_container.dart';

/// Controller for imperatively managing [CNSearchBar] state.
class CNSearchBarController {
  MethodChannel? _channel;
  VoidCallback? _onExpandChanged;
  bool _isExpanded = false;

  void _attach(MethodChannel channel) {
    _channel = channel;
  }

  void _detach() {
    _channel = null;
  }

  void _setExpandedState(bool expanded) {
    _isExpanded = expanded;
    _onExpandChanged?.call();
  }

  /// Whether the search bar is currently expanded.
  bool get isExpanded => _isExpanded;

  /// Expands the search bar to show the text field.
  Future<void> expand({bool animated = true}) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod('expand', {'animated': animated});
  }

  /// Collapses the search bar back to icon-only mode.
  Future<void> collapse({bool animated = true}) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod('collapse', {'animated': animated});
  }

  /// Clears the search text.
  Future<void> clear() async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod('clear', null);
  }

  /// Sets the search text programmatically.
  Future<void> setText(String text) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod('setText', {'text': text});
  }

  /// Focuses the search text field.
  Future<void> focus() async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod('focus', null);
  }

  /// Unfocuses the search text field.
  Future<void> unfocus() async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod('unfocus', null);
  }

  /// Listen to expand/collapse state changes.
  set onExpandChanged(VoidCallback? callback) {
    _onExpandChanged = callback;
  }
}

/// A native expandable search bar with Liquid Glass effects.
///
/// When [expandable] is true, the search bar starts as a compact icon button
/// and expands to a full-width text field when tapped. This creates an
/// elegant iOS-native animation.
///
/// On iOS 26+ it is a SwiftUI search bar with a Liquid Glass background; on
/// older iOS and on other platforms it is drawn in Flutter. The [controller]'s
/// methods work on the iOS bar as on macOS: `setText` and `clear` report the
/// new text through [onChanged], `expand` and `collapse` through
/// [onExpandStateChanged] (collapsing also clears the text and ends
/// editing), and `focus` opens a collapsed bar before it brings up the
/// keyboard.
///
/// On macOS (every supported version) it is a native `NSSearchField`, which
/// keeps the keyboard while the user types and hands it back to Flutter when
/// the search ends. macOS search fields have no Cancel button, so there:
///
/// * [expandable] works like the search item of a window toolbar: the bar
///   starts as a magnifying-glass button ([collapsedWidth] wide, Liquid
///   Glass on macOS 26+), a click opens the field and focuses it, and the
///   field closes again when it loses focus while empty.
/// * Esc is the cancel gesture: the first Esc clears the text, Esc in an
///   empty field ends the search, closes an expandable bar and calls
///   [onCancelTap]. [showCancelButton] and [cancelText] are not used.
/// * [tint] colours the magnifying glass, the insertion point and the
///   collapsed button; the field itself keeps the system look.
/// * [recentsAutosaveName] keeps a menu of recent searches.
/// * The [controller]'s methods all work; `setText` and `clear` report the
///   new text through [onChanged], as a click on the clear button does.
///
/// Example:
/// ```dart
/// CNSearchBar(
///   placeholder: 'Search...',
///   onChanged: (text) => print('Search: $text'),
///   onSubmitted: (text) => performSearch(text),
///   expandable: true,
/// )
/// ```
class CNSearchBar extends StatefulWidget {
  /// Creates an expandable search bar.
  const CNSearchBar({
    super.key,
    this.placeholder = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.onCancelTap,
    this.onExpandStateChanged,
    this.expandable = true,
    this.initiallyExpanded = false,
    this.collapsedWidth = 44.0,
    this.expandedHeight = 36.0,
    this.tint,
    this.backgroundColor,
    this.textColor,
    this.placeholderColor,
    this.showCancelButton = true,
    this.cancelText = 'Cancel',
    this.autofocus = false,
    this.controller,
    this.searchIcon,
    this.clearIcon,
    this.autoHideOnModal = true,
    this.recentsAutosaveName,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.keyboardType = TextInputType.text,
    this.clearButtonSemanticLabel,
  });

  /// Placeholder text shown when the search field is empty.
  final String placeholder;

  /// Called when the search text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the search (presses return).
  final ValueChanged<String>? onSubmitted;

  /// Called when the cancel button is tapped.
  final VoidCallback? onCancelTap;

  /// Called when the expand/collapse state changes.
  final ValueChanged<bool>? onExpandStateChanged;

  /// Whether the search bar can expand from icon to full width.
  final bool expandable;

  /// Whether the search bar starts in expanded state.
  final bool initiallyExpanded;

  /// Width of the collapsed search bar (icon-only mode).
  final double collapsedWidth;

  /// Height of the expanded search bar.
  final double expandedHeight;

  /// Tint color for the search bar and icon.
  final Color? tint;

  /// Background color for the search field.
  final Color? backgroundColor;

  /// Color for the search text.
  final Color? textColor;

  /// Color for the placeholder text.
  final Color? placeholderColor;

  /// Whether to show the cancel button when expanded.
  final bool showCancelButton;

  /// Text for the cancel button.
  final String cancelText;

  /// Whether to automatically focus when expanded.
  final bool autofocus;

  /// Controller for programmatic control.
  final CNSearchBarController? controller;

  /// Custom search icon (defaults to magnifyingglass SF Symbol).
  ///
  /// On iOS 26+ the icon is drawn at [CNSymbol.size] (16 pt by default) at
  /// the default text size, and grows and shrinks with Dynamic Type like the
  /// field's text.
  final CNSymbol? searchIcon;

  /// Custom clear icon (defaults to xmark.circle.fill SF Symbol), sized like
  /// [searchIcon].
  final CNSymbol? clearIcon;

  /// Whether the keyboard capitalizes what the user types. Defaults to none,
  /// as for the system search fields, so a query such as a username isn't
  /// capitalized.
  final TextCapitalization textCapitalization;

  /// Whether the keyboard corrects what the user types. Turn it off for a
  /// query such as a file name or a command.
  final bool autocorrect;

  /// The keyboard shown for the field, e.g. [TextInputType.emailAddress] or
  /// [TextInputType.number] (iOS; the macOS field takes typing from the
  /// hardware keyboard).
  final TextInputType keyboardType;

  /// What VoiceOver reads for the button that clears the text. Defaults to
  /// the localized "Clear" of [CupertinoLocalizations.clearButtonLabel].
  final String? clearButtonSemanticLabel;

  /// When true (default), destroys the native search bar's PlatformView while
  /// a modal sheet is presented above this widget's host route. Fixes the
  /// iOS hybrid-composition z-order bleed (Issue #53) where a host-page
  /// CNSearchBar's pixels leak through a sheet that also contains a
  /// CN-widget. Requires `CNTabBarRouteObserver()` to be registered in the
  /// app's `navigatorObservers`. No effect on iOS < 26 / non-iOS (Flutter
  /// fallback).
  ///
  /// When false, the native view stays while a modal (a dialog, popup or
  /// sheet) is up, and its Liquid Glass glow is clipped to the view's bounds
  /// from the modal's push until its exit animation ends, so no box shows
  /// around it through the modal's barrier (Issue #124).
  final bool autoHideOnModal;

  /// macOS only: the name under which the field saves its recent searches
  /// (`NSSearchField.recentsAutosaveName`). When set, the magnifying glass
  /// opens a menu of them; a search is recorded when the user presses
  /// Return. Searches saved under the same name are shared between fields.
  final String? recentsAutosaveName;

  @override
  State<CNSearchBar> createState() => _CNSearchBarState();
}

class _CNSearchBarState extends State<CNSearchBar>
    with
        SingleTickerProviderStateMixin,
        ModalHideMixin<CNSearchBar>,
        HaloContainmentMixin<CNSearchBar> {
  @override
  bool get autoHideOnModal => widget.autoHideOnModal;

  @override
  MethodChannel? get platformViewChannel => _channel;

  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late TextEditingController _textController;
  late FocusNode _focusNode;

  MethodChannel? _channel;
  CNSearchBarController? _internalController;
  bool _isExpanded = false;
  String _searchText = '';

  // Halo containment (Issues #29 and #124) is driven by
  // HaloContainmentMixin.

  bool? _lastIsDark;

  /// The options last sent to the macOS search field, to send changes only.
  Map<String, Object?>? _lastMacConfig;

  CNSearchBarController get _controller =>
      widget.controller ?? (_internalController ??= CNSearchBarController());

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded || !widget.expandable;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _textController = TextEditingController();
    _textController.addListener(_onTextChanged);

    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);

    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
    _syncMacConfigIfNeeded();
  }

  @override
  void didUpdateWidget(covariant CNSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMacConfigIfNeeded();
  }

  bool get _usesMacSearchField =>
      defaultTargetPlatform == TargetPlatform.macOS &&
      PlatformVersion.shouldUseNativeControls;

  /// The options of the macOS field that can change after it is created.
  Map<String, Object?> _macConfig(BuildContext context) => <String, Object?>{
    'placeholder': widget.placeholder,
    'tint': resolveColorToArgb(widget.tint, context),
    'backgroundColor': resolveColorToArgb(widget.backgroundColor, context),
    'textColor': resolveColorToArgb(widget.textColor, context),
    'placeholderColor': resolveColorToArgb(widget.placeholderColor, context),
    'searchIconName': widget.searchIcon?.name ?? 'magnifyingglass',
    'clearIconName': widget.clearIcon?.name ?? 'xmark.circle.fill',
    'collapsedWidth': widget.collapsedWidth,
    'autofocus': widget.autofocus,
  };

  void _syncMacConfigIfNeeded() {
    final ch = _channel;
    if (ch == null || !_usesMacSearchField) return;
    final config = _macConfig(context);
    if (mapEquals(config, _lastMacConfig)) return;
    _lastMacConfig = config;
    ch.invokeOptionalMethod('setConfig', config).catchError((_) {});
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    final isDark = ThemeHelper.isDark(context);
    if (_lastIsDark != isDark) {
      try {
        await ch.invokeMethod('setBrightness', {'isDark': isDark});
        _lastIsDark = isDark;
      } catch (_) {
        // The native view is gone, e.g. hidden under a sheet; it is created
        // again with the current brightness.
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _controller._detach();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textController.text;
    if (_searchText != text) {
      setState(() => _searchText = text);
      widget.onChanged?.call(text);
      _channel?.invokeMethod('textChanged', {'text': text});
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && widget.expandable && !_isExpanded) {
      _expand();
    }
  }

  void _onPlatformViewCreated(int id) {
    final ch = MethodChannel('CNSearchBar_$id');
    _channel = ch;
    _controller._attach(ch);
    ch.setMethodCallHandler(_onMethodCall);
    _lastIsDark = ThemeHelper.isDark(context);
    if (_usesMacSearchField) _lastMacConfig = _macConfig(context);
    resetHaloContainment();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'textChanged':
        final text = call.arguments['text'] as String? ?? '';
        if (mounted) {
          setState(() => _searchText = text);
          _textController.text = text;
          widget.onChanged?.call(text);
        }
        break;
      case 'submitted':
        final text = call.arguments['text'] as String? ?? '';
        widget.onSubmitted?.call(text);
        break;
      case 'expanded':
        _setExpanded(true);
        break;
      case 'collapsed':
        _setExpanded(false);
        break;
      case 'cancelTapped':
        widget.onCancelTap?.call();
        _collapse();
        break;
    }
    return null;
  }

  void _setExpanded(bool expanded) {
    if (_isExpanded != expanded) {
      setState(() => _isExpanded = expanded);
      _controller._setExpandedState(expanded);
      widget.onExpandStateChanged?.call(expanded);

      if (expanded) {
        _animationController.forward();
        if (widget.autofocus) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _focusNode.requestFocus();
          });
        }
      } else {
        _animationController.reverse();
        _focusNode.unfocus();
      }
    }
  }

  void _expand() {
    if (!_isExpanded && widget.expandable) {
      _setExpanded(true);
      _channel?.invokeMethod('expand', {'animated': true});
    }
  }

  void _collapse() {
    if (_isExpanded && widget.expandable) {
      _setExpanded(false);
      _textController.clear();
      _channel?.invokeMethod('collapse', {'animated': true});
    }
  }

  void _onTap() {
    if (!_isExpanded) {
      _expand();
    }
  }

  void _onCancelTap() {
    widget.onCancelTap?.call();
    _collapse();
  }

  void _onClear() {
    _textController.clear();
    _channel?.invokeMethod('clear', null);
  }

  void _onSubmitted(String text) {
    widget.onSubmitted?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    // macOS: NSSearchField, which every supported macOS has.
    if (_usesMacSearchField) {
      return _buildMacOSSearchBar(context);
    }

    if (defaultTargetPlatform == TargetPlatform.iOS &&
        PlatformVersion.shouldUseNativeGlass) {
      return _buildNativeSearchBar(context);
    }

    return _buildFlutterSearchBar(context);
  }

  /// The creation parameters of the native views.
  Map<String, dynamic> _creationParams(
    BuildContext context,
  ) => <String, dynamic>{
    'placeholder': widget.placeholder,
    'expandable': widget.expandable,
    'initiallyExpanded': widget.initiallyExpanded,
    'collapsedWidth': widget.collapsedWidth,
    'expandedHeight': widget.expandedHeight,
    'tint': resolveColorToArgb(widget.tint, context),
    'backgroundColor': resolveColorToArgb(widget.backgroundColor, context),
    'textColor': resolveColorToArgb(widget.textColor, context),
    'placeholderColor': resolveColorToArgb(widget.placeholderColor, context),
    'showCancelButton': widget.showCancelButton,
    'cancelText': widget.cancelText,
    'autofocus': widget.autofocus,
    'searchIconName': widget.searchIcon?.name ?? 'magnifyingglass',
    'clearIconName': widget.clearIcon?.name ?? 'xmark.circle.fill',
    if (widget.searchIcon?.size != null)
      'searchIconSize': widget.searchIcon!.size,
    if (widget.clearIcon?.size != null) 'clearIconSize': widget.clearIcon!.size,
    'clearButtonLabel': _clearButtonLabel(context),
    ..._keyboardParams,
    // The view is created again after a modal (autoHideOnModal) or a move
    // in the tree: it starts with the text and the expanded state the bar
    // has now, not the initial ones (#134).
    'expanded': _isExpanded,
    if (_searchText.isNotEmpty) 'text': _searchText,
    'isDark': ThemeHelper.isDark(context),
  };

  String _clearButtonLabel(BuildContext context) =>
      widget.clearButtonSemanticLabel ??
      Localizations.of<CupertinoLocalizations>(
        context,
        CupertinoLocalizations,
      )?.clearButtonLabel ??
      'Clear';

  /// [CNSearchBar.textCapitalization], [CNSearchBar.autocorrect] and
  /// [CNSearchBar.keyboardType] for the native field.
  Map<String, Object> get _keyboardParams {
    final type = widget.keyboardType.toJson();
    return <String, Object>{
      'textCapitalization': widget.textCapitalization.name,
      'autocorrect': widget.autocorrect,
      'keyboardType': type['name'] as String,
      if (type['decimal'] == true) 'keyboardDecimal': true,
      if (type['signed'] == true) 'keyboardSigned': true,
    };
  }

  /// macOS: an `NSSearchField` as wide as the parent allows (the window
  /// when the parent is unbounded), or a [CNSearchBar.collapsedWidth] wide
  /// magnifying-glass button that Flutter widens into the field.
  Widget _buildMacOSSearchBar(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final platformView = AppKitView(
      viewType: 'CNSearchBar',
      creationParams: <String, dynamic>{
        ..._creationParams(context),
        if (widget.recentsAutosaveName != null)
          'recentsAutosaveName': widget.recentsAutosaveName,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );

    return _BarIntrinsics(
      minWidth: widget.collapsedWidth,
      maxWidth: screenWidth,
      height: widget.expandedHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final expandedWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : screenWidth;
          double widthAt(double t) => widget.expandable
              ? widget.collapsedWidth +
                    (expandedWidth - widget.collapsedWidth) * t
              : expandedWidth;
          final hidden = maybeHiddenPlaceholder(
            height: widget.expandedHeight,
            width: widthAt(_expandAnimation.value),
          );
          if (hidden != null) return hidden;
          return wrapWithModalInteractionGuard(
            AnimatedBuilder(
              animation: _expandAnimation,
              // Starts at the leading edge and takes only the bar's width
              // when the parent lets it, so a collapsed bar is a button.
              builder: (context, child) => Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 1,
                heightFactor: 1,
                child: SizedBox(
                  width: widthAt(_expandAnimation.value),
                  height: widget.expandedHeight,
                  child: child,
                ),
              ),
              child: platformView,
            ),
          );
        },
      ),
    );
  }

  Widget _buildNativeSearchBar(BuildContext context) {
    // Match the live build's width formula exactly so the placeholder occupies
    // the same footprint while the native view is hidden behind a modal.
    final expandedWidth = MediaQuery.of(context).size.width;
    final placeholderWidth = widget.expandable
        ? widget.collapsedWidth +
              (expandedWidth - widget.collapsedWidth) * _expandAnimation.value
        : expandedWidth;
    final hidden = maybeHiddenPlaceholder(
      height: widget.expandedHeight,
      width: placeholderWidth,
    );
    if (hidden != null) return hidden;

    final platformView = UiKitView(
      // The keyboard options, icon sizes and clear-button name are set when
      // the view is created; a change creates it again, with its text.
      key: ValueKey<Object>(
        Object.hash(
          widget.textCapitalization,
          widget.autocorrect,
          widget.keyboardType,
          widget.searchIcon?.size,
          widget.clearIcon?.size,
          _clearButtonLabel(context),
        ),
      ),
      viewType: 'CNSearchBar',
      creationParams: _creationParams(context),
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );

    return wrapWithModalInteractionGuard(
      AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, child) {
          final expandedWidth = MediaQuery.of(context).size.width;
          final width = widget.expandable
              ? widget.collapsedWidth +
                    (expandedWidth - widget.collapsedWidth) *
                        _expandAnimation.value
              : expandedWidth;

          return SizedBox(
            width: width,
            height: widget.expandedHeight,
            child: child,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.expandedHeight / 2),
          child: platformView,
        ),
      ),
    );
  }

  Widget _buildFlutterSearchBar(BuildContext context) {
    final effectiveTint = widget.tint ?? CupertinoColors.systemBlue;
    final effectiveBackgroundColor =
        widget.backgroundColor ??
        CupertinoColors.systemGrey6.resolveFrom(context);
    final effectiveTextColor =
        widget.textColor ?? CupertinoColors.label.resolveFrom(context);
    final effectivePlaceholderColor =
        widget.placeholderColor ??
        CupertinoColors.placeholderText.resolveFrom(context);

    // Caps the row at the parent's width; an unbounded parent (a horizontal
    // scroll view) gets the screen width.
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      child: AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, child) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The bar expands into what the Cancel button leaves of the row.
            Flexible(
              child: _BarIntrinsics(
                minWidth: widget.collapsedWidth,
                maxWidth: MediaQuery.sizeOf(context).width,
                height: widget.expandedHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final expandedWidth = constraints.maxWidth;
                    final currentWidth = widget.expandable
                        ? widget.collapsedWidth +
                              (expandedWidth - widget.collapsedWidth) *
                                  _expandAnimation.value
                        : expandedWidth;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: currentWidth,
                      height: widget.expandedHeight,
                      child: GestureDetector(
                        onTap: _onTap,
                        child: LiquidGlassContainer(
                          config: LiquidGlassConfig(
                            effect: CNGlassEffect.regular,
                            shape: CNGlassEffectShape.capsule,
                            tint: effectiveBackgroundColor,
                            interactive: true,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.search,
                                  size: 18,
                                  color: effectiveTint,
                                ),
                                if (_expandAnimation.value > 0.3) ...[
                                  // The gap sits inside Expanded: the field
                                  // appears while AnimatedContainer still lags
                                  // near collapsedWidth, too narrow for a fixed
                                  // 8 px gap.
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Opacity(
                                        opacity:
                                            (_expandAnimation.value - 0.3) /
                                            0.7,
                                        child: CupertinoTextField(
                                          controller: _textController,
                                          focusNode: _focusNode,
                                          placeholder: widget.placeholder,
                                          placeholderStyle: TextStyle(
                                            color: effectivePlaceholderColor,
                                          ),
                                          style: TextStyle(
                                            color: effectiveTextColor,
                                          ),
                                          decoration: null,
                                          padding: EdgeInsets.zero,
                                          onSubmitted: _onSubmitted,
                                          textCapitalization:
                                              widget.textCapitalization,
                                          autocorrect: widget.autocorrect,
                                          keyboardType: widget.keyboardType,
                                          textInputAction:
                                              TextInputAction.search,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_searchText.isNotEmpty)
                                    Semantics(
                                      button: true,
                                      label: _clearButtonLabel(context),
                                      excludeSemantics: true,
                                      child: GestureDetector(
                                        onTap: _onClear,
                                        child: Icon(
                                          CupertinoIcons.xmark_circle_fill,
                                          size: 18,
                                          color: effectivePlaceholderColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Hidden but still sized while collapsing, so the bar does not
            // first widen into the space Cancel gives back.
            if (widget.showCancelButton &&
                (_isExpanded || _animationController.isAnimating)) ...[
              const SizedBox(width: 8),
              Visibility(
                visible: _isExpanded,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _onCancelTap,
                  child: Text(
                    widget.cancelText,
                    style: TextStyle(color: effectiveTint),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Answers intrinsic size queries for the fallback bar, whose width comes
/// from a [LayoutBuilder] that cannot answer them: the collapsed width at
/// least, the screen width at most, and the bar's height. Lets the bar sit
/// inside [IntrinsicHeight] or [IntrinsicWidth].
class _BarIntrinsics extends SingleChildRenderObjectWidget {
  const _BarIntrinsics({
    required this.minWidth,
    required this.maxWidth,
    required this.height,
    required super.child,
  });

  final double minWidth;
  final double maxWidth;
  final double height;

  @override
  _RenderBarIntrinsics createRenderObject(BuildContext context) =>
      _RenderBarIntrinsics(minWidth, maxWidth, height);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBarIntrinsics renderObject,
  ) {
    renderObject.update(minWidth, maxWidth, height);
  }
}

class _RenderBarIntrinsics extends RenderProxyBox {
  _RenderBarIntrinsics(this._minWidth, this._maxWidth, this._height);

  double _minWidth;
  double _maxWidth;
  double _height;

  void update(double minWidth, double maxWidth, double height) {
    if (minWidth == _minWidth && maxWidth == _maxWidth && height == _height) {
      return;
    }
    _minWidth = minWidth;
    _maxWidth = maxWidth;
    _height = height;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _minWidth;

  @override
  double computeMaxIntrinsicWidth(double height) => _maxWidth;

  @override
  double computeMinIntrinsicHeight(double width) => _height;

  @override
  double computeMaxIntrinsicHeight(double width) => _height;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    Size(
      constraints.hasBoundedWidth ? constraints.maxWidth : _maxWidth,
      _height,
    ),
  );
}
