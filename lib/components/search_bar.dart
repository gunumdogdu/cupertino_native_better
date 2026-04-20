import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/glass_effect.dart';
import '../style/sf_symbol.dart';
import '../utils/version_detector.dart';
import 'liquid_glass_container.dart';
import 'tab_bar.dart' show CNTabBarRouteObserver;

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
  final CNSymbol? searchIcon;

  /// Custom clear icon (defaults to xmark.circle.fill SF Symbol).
  final CNSymbol? clearIcon;

  @override
  State<CNSearchBar> createState() => _CNSearchBarState();
}

class _CNSearchBarState extends State<CNSearchBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late TextEditingController _textController;
  late FocusNode _focusNode;

  MethodChannel? _channel;
  CNSearchBarController? _internalController;
  bool _isExpanded = false;
  String _searchText = '';

  // Issue #29 halo containment via setTransitioning.
  Animation<double>? _secondaryRouteAnim;
  bool _modalAbove = false;

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

    CNTabBarRouteObserver.anyModalDepth.addListener(_onAnyModalDepthChanged);
    _onAnyModalDepthChanged();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachSecondaryRouteAnim();
  }

  @override
  void dispose() {
    _secondaryRouteAnim?.removeListener(_onSecondaryRouteAnimChanged);
    _secondaryRouteAnim = null;
    CNTabBarRouteObserver.anyModalDepth.removeListener(_onAnyModalDepthChanged);
    _animationController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _controller._detach();
    super.dispose();
  }

  void _attachSecondaryRouteAnim() {
    final route = ModalRoute.of(context);
    final newAnim = route?.secondaryAnimation;
    if (identical(newAnim, _secondaryRouteAnim)) return;
    _secondaryRouteAnim?.removeListener(_onSecondaryRouteAnimChanged);
    _secondaryRouteAnim = newAnim;
    _secondaryRouteAnim?.addListener(_onSecondaryRouteAnimChanged);
    _onSecondaryRouteAnimChanged();
  }

  void _onSecondaryRouteAnimChanged() => _pushContainmentIfNeeded();

  void _onAnyModalDepthChanged() {
    _modalAbove = CNTabBarRouteObserver.anyModalDepth.value > 0;
    _pushContainmentIfNeeded();
  }

  void _pushContainmentIfNeeded() {
    final anim = _secondaryRouteAnim;
    final animating =
        anim?.status == AnimationStatus.forward ||
        anim?.status == AnimationStatus.reverse;
    final active = animating || _modalAbove;
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.invokeMethod('setTransitioning', {'active': active});
    } catch (_) {}
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
    _pushContainmentIfNeeded();
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
    final isIOSOrMacOS =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final shouldUseNative =
        isIOSOrMacOS && PlatformVersion.shouldUseNativeGlass;

    if (shouldUseNative) {
      return _buildNativeSearchBar(context);
    }

    return _buildFlutterSearchBar(context);
  }

  Widget _buildNativeSearchBar(BuildContext context) {
    const viewType = 'CNSearchBar';
    final creationParams = <String, dynamic>{
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
      'isDark': Theme.of(context).brightness == Brightness.dark,
    };

    final platformView = defaultTargetPlatform == TargetPlatform.iOS
        ? UiKitView(
            viewType: viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          )
        : AppKitView(
            viewType: viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          );

    return AnimatedBuilder(
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

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final expandedWidth = MediaQuery.of(context).size.width;
        final currentWidth = widget.expandable
            ? widget.collapsedWidth +
                  (expandedWidth - widget.collapsedWidth) *
                      _expandAnimation.value
            : expandedWidth;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: Opacity(
                              opacity: (_expandAnimation.value - 0.3) / 0.7,
                              child: CupertinoTextField(
                                controller: _textController,
                                focusNode: _focusNode,
                                placeholder: widget.placeholder,
                                placeholderStyle: TextStyle(
                                  color: effectivePlaceholderColor,
                                ),
                                style: TextStyle(color: effectiveTextColor),
                                decoration: null,
                                padding: EdgeInsets.zero,
                                onSubmitted: _onSubmitted,
                              ),
                            ),
                          ),
                          if (_searchText.isNotEmpty)
                            GestureDetector(
                              onTap: _onClear,
                              child: Icon(
                                CupertinoIcons.xmark_circle_fill,
                                size: 18,
                                color: effectivePlaceholderColor,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.showCancelButton && _isExpanded) ...[
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _onCancelTap,
                child: Text(
                  widget.cancelText,
                  style: TextStyle(color: effectiveTint),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
