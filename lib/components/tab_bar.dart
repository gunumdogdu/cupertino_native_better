import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/sf_symbol.dart';
import '../style/tab_bar_search_item.dart';
import '../utils/icon_renderer.dart';
import '../utils/version_detector.dart';
import '../utils/theme_helper.dart';
import 'icon.dart';

/// Immutable data describing a single tab bar item.
class CNTabBarItem {
  /// Creates a tab bar item description.
  const CNTabBarItem({
    this.label,
    this.icon,
    this.activeIcon,
    this.badge,
    this.customIcon,
    this.activeCustomIcon,
    this.imageAsset,
    this.activeImageAsset,
  });

  /// Optional tab item label.
  final String? label;

  /// Optional SF Symbol for the item (unselected state).
  /// If both [icon] and [customIcon] are provided, [customIcon] takes precedence.
  final CNSymbol? icon;

  /// Optional SF Symbol for the item when selected.
  /// If not provided, [icon] is used for both states.
  final CNSymbol? activeIcon;

  /// Optional badge text to display on the tab bar item.
  /// On iOS, this displays as a red badge with the text.
  /// On macOS, badges are not supported by NSSegmentedControl.
  final String? badge;

  /// Optional custom icon for unselected state.
  /// Use icons from CupertinoIcons, Icons, or any custom IconData.
  /// The icon will be rendered to an image at 25pt (iOS standard tab bar icon size)
  /// and sent to the native platform. If provided, this takes precedence over [icon].
  ///
  /// Examples:
  /// ```dart
  /// customIcon: CupertinoIcons.house
  /// customIcon: Icons.home
  /// ```
  final IconData? customIcon;

  /// Optional custom icon for selected state.
  /// If not provided, [customIcon] is used for both states.
  final IconData? activeCustomIcon;

  /// Optional image asset for unselected state.
  /// If provided, this takes precedence over [icon] and [customIcon].
  /// Priority: [imageAsset] > [customIcon] > [icon]
  final CNImageAsset? imageAsset;

  /// Optional image asset for selected state.
  /// If not provided, [imageAsset] is used for both states.
  final CNImageAsset? activeImageAsset;
}

/// A Cupertino-native tab bar. Uses native UITabBar/NSTabView style visuals.
///
/// On iOS 26+, supports a dedicated search tab that follows Apple's native
/// behavior: appearing as a floating circular button that expands into a
/// full search bar when tapped.
///
/// Example with search:
/// ```dart
/// CNTabBar(
///   items: [
///     CNTabBarItem(label: 'Home', icon: CNSymbol('house.fill')),
///     CNTabBarItem(label: 'Profile', icon: CNSymbol('person.fill')),
///   ],
///   currentIndex: _index,
///   onTap: (i) => setState(() => _index = i),
///   searchItem: CNTabBarSearchItem(
///     placeholder: 'Find customer',
///     onSearchChanged: (query) => filterResults(query),
///   ),
/// )
/// ```
class CNTabBar extends StatefulWidget {
  /// Creates a Cupertino-native tab bar.
  ///
  /// According to Apple's Human Interface Guidelines, tab bars should contain
  /// 3-5 tabs for optimal usability. More than 5 tabs can make the interface
  /// cluttered and reduce tappability.
  const CNTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.tint,
    this.backgroundColor,
    this.iconSize,
    this.height,
    this.split = false,
    this.rightCount = 1,
    this.shrinkCentered = true,
    this.splitSpacing =
        12.0, // Apple's recommended spacing for visual separation
    this.searchItem,
    this.searchController,
  }) : assert(items.length >= 2, 'Tab bar must have at least 2 items'),
       assert(
         items.length <= 5,
         'Tab bar should have 5 or fewer items for optimal usability',
       ),
       assert(rightCount >= 1, 'Right count must be at least 1'),
       assert(
         rightCount < items.length || searchItem != null,
         'Right count must be less than total items',
       );

  /// Items to display in the tab bar.
  final List<CNTabBarItem> items;

  /// The index of the currently selected item.
  final int currentIndex;

  /// Called when the user selects a new item.
  final ValueChanged<int> onTap;

  /// Accent/tint color.
  final Color? tint;

  /// Background color for the bar.
  final Color? backgroundColor;

  /// Default icon size when item icon does not specify one.
  final double? iconSize;

  /// Fixed height; if null uses intrinsic height reported by native view.
  final double? height;

  /// When true, splits items between left and right sections.
  ///
  /// This follows Apple's HIG guidelines for organizing related tab functions
  /// into logical groups with clear visual separation.
  ///
  /// Note: When [searchItem] is provided, split mode is automatically enabled
  /// with the search tab appearing as a floating button on the right.
  final bool split;

  /// How many trailing items to pin right when [split] is true.
  ///
  /// Must be less than the total number of items. Follows Apple's HIG
  /// recommendation for maintaining balanced visual hierarchy.
  ///
  /// Note: When [searchItem] is provided, this value is ignored as the
  /// search tab automatically becomes the right-side floating element.
  final int rightCount; // how many trailing items to pin right when split

  /// When true, centers the split groups more tightly.
  final bool shrinkCentered;

  /// Gap between left/right halves when split.
  ///
  /// Defaults to 12pt following Apple's HIG recommendations for visual separation.
  final double splitSpacing; // gap between left/right halves when split

  /// Optional search tab configuration.
  ///
  /// When provided, adds a dedicated search tab that follows iOS 26's native
  /// behavior:
  /// - Appears as a separate floating circular button on the right
  /// - Expands into a full search bar when tapped
  /// - Collapses other tabs during search
  ///
  /// On iOS < 26, the search behavior is simulated using Flutter widgets.
  final CNTabBarSearchItem? searchItem;

  /// Optional controller for programmatic search management.
  ///
  /// Use this to:
  /// - Activate/deactivate search programmatically
  /// - Set or clear the search text
  /// - Listen to search state changes
  final CNTabBarSearchController? searchController;

  @override
  State<CNTabBar> createState() => _CNTabBarState();
}

class _CNTabBarState extends State<CNTabBar> {
  MethodChannel? _channel;
  int? _lastIndex;
  int? _lastTint;
  int? _lastBg;
  bool? _lastIsDark;
  double? _intrinsicHeight;
  double? _intrinsicWidth;
  List<String>? _lastLabels;
  List<String>? _lastSymbols;
  List<String>? _lastActiveSymbols;
  List<String>? _lastBadges;
  bool? _lastSplit;
  int? _lastRightCount;
  double? _lastSplitSpacing;

  // Search state
  bool _isSearchActive = false;
  String _searchText = '';
  FocusNode? _searchFocusNode;

  bool get _isDark => ThemeHelper.isDark(context);
  Color? get _effectiveTint =>
      widget.tint ?? ThemeHelper.getPrimaryColor(context);

  // Whether search mode is enabled
  bool get _hasSearch => widget.searchItem != null;

  @override
  void initState() {
    super.initState();
    widget.searchController?.addListener(_onSearchControllerChanged);
    if (_hasSearch) {
      _searchFocusNode = FocusNode();
    }
  }

  @override
  void didUpdateWidget(covariant CNTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle controller changes
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController?.removeListener(_onSearchControllerChanged);
      widget.searchController?.addListener(_onSearchControllerChanged);
    }
    // Handle search item changes
    if (_hasSearch && _searchFocusNode == null) {
      _searchFocusNode = FocusNode();
    }
    _syncPropsToNativeIfNeeded();
  }

  @override
  void dispose() {
    widget.searchController?.removeListener(_onSearchControllerChanged);
    _searchFocusNode?.dispose();
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _onSearchControllerChanged() {
    final controller = widget.searchController;
    if (controller == null) return;

    // Sync controller state to native
    final ch = _channel;
    if (ch == null) return;

    try {
      if (controller.isActive != _isSearchActive) {
        if (controller.isActive) {
          ch.invokeMethod('activateSearch');
        } else {
          ch.invokeMethod('deactivateSearch');
        }
        _isSearchActive = controller.isActive;
      }

      if (controller.text != _searchText) {
        ch.invokeMethod('setSearchText', {'text': controller.text});
        _searchText = controller.text;
      }
    } catch (e) {
      // Ignore MissingPluginException during hot reload or view recreation
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we should use native platform view
    final isIOSOrMacOS =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final shouldUseNative =
        isIOSOrMacOS && PlatformVersion.shouldUseNativeGlass;

    // Fallback to Flutter widgets for non-iOS/macOS or iOS/macOS < 26
    if (!shouldUseNative) {
      // For both non-iOS/macOS and iOS/macOS < 26, use Flutter-based implementation
      return _buildFlutterFallback(context);
    }

    // Render custom IconData to bytes
    return FutureBuilder<List<List<Uint8List?>>>(
      future: _renderCustomIcons(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Show placeholder while rendering
          return SizedBox(height: widget.height ?? 50, width: double.infinity);
        }

        final iconBytes = snapshot.data!;
        final customIconBytes = iconBytes[0];
        final activeCustomIconBytes = iconBytes[1];

        return FutureBuilder<Widget>(
          future: _buildNativeTabBar(
            context,
            customIconBytes: customIconBytes,
            activeCustomIconBytes: activeCustomIconBytes,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return SizedBox(height: widget.height);
            }
            // Keep native tab bar visible at all times
            // Search UI should be handled in app content area, not as tab bar overlay
            // This matches adaptive_platform_ui behavior
            return snapshot.data!;
          },
        );
      },
    );
  }

  Future<List<List<Uint8List?>>> _renderCustomIcons() async {
    final customIconBytes = <Uint8List?>[];
    final activeCustomIconBytes = <Uint8List?>[];

    for (final item in widget.items) {
      // Priority: imageAsset > customIcon > icon
      if (item.imageAsset != null) {
        // For imageAsset, we don't need to render to bytes - native code will handle it
        customIconBytes.add(null);
      } else if (item.customIcon != null) {
        final bytes = await iconDataToImageBytes(item.customIcon!, size: 25.0);
        customIconBytes.add(bytes);
      } else {
        customIconBytes.add(null);
      }

      // Render active custom icon
      if (item.activeImageAsset != null) {
        // For activeImageAsset, we don't need to render to bytes - native code will handle it
        activeCustomIconBytes.add(null);
      } else if (item.activeCustomIcon != null) {
        final bytes = await iconDataToImageBytes(
          item.activeCustomIcon!,
          size: 25.0,
        );
        activeCustomIconBytes.add(bytes);
      } else if (item.customIcon != null) {
        activeCustomIconBytes.add(customIconBytes.last); // Use same as normal
      } else {
        activeCustomIconBytes.add(null);
      }
    }

    return [customIconBytes, activeCustomIconBytes];
  }

  Future<Widget> _buildNativeTabBar(
    BuildContext context, {
    required List<Uint8List?> customIconBytes,
    required List<Uint8List?> activeCustomIconBytes,
  }) async {
    // Capture all context-derived values before any async operations
    final capturedDevicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final capturedIsDark = _isDark;
    final capturedStyle = encodeStyle(context, tint: _effectiveTint);
    final capturedBackgroundColor = resolveColorToArgb(
      widget.backgroundColor,
      context,
    );
    // Capture search style params before async operations
    final capturedSearchStyle = _hasSearch
        ? _buildSearchStyleParams(context)
        : null;

    final labels = widget.items.map((e) => e.label ?? '').toList();
    final symbols = widget.items.map((e) => e.icon?.name ?? '').toList();
    final activeSymbols = widget.items
        .map((e) => e.activeIcon?.name ?? e.icon?.name ?? '')
        .toList();
    final badges = widget.items.map((e) => e.badge ?? '').toList();

    // Extract imageAsset data and resolve asset paths based on device pixel ratio
    final imageAssetPaths = await Future.wait(
      widget.items.map(
        (e) async => e.imageAsset != null
            ? await resolveAssetPathForPixelRatio(e.imageAsset!.assetPath)
            : '',
      ),
    );
    final activeImageAssetPaths = await Future.wait(
      widget.items.map(
        (e) async => e.activeImageAsset != null
            ? await resolveAssetPathForPixelRatio(e.activeImageAsset!.assetPath)
            : '',
      ),
    );

    if (!mounted) return const SizedBox();

    final sizes = widget.items
        .map((e) => (widget.iconSize ?? e.icon?.size ?? e.imageAsset?.size))
        .toList();
    final colors = widget.items
        .map(
          (e) =>
              resolveColorToArgb(e.icon?.color ?? e.imageAsset?.color, context),
        )
        .toList();

    final imageAssetData = widget.items
        .map((e) => e.imageAsset?.imageData)
        .toList();
    final activeImageAssetData = widget.items
        .map((e) => e.activeImageAsset?.imageData)
        .toList();
    // Auto-detect format if not provided (use resolved paths)
    final imageAssetFormats = await Future.wait(
      widget.items.asMap().entries.map((entry) async {
        final e = entry.value;
        if (e.imageAsset == null) return '';
        final resolvedPath = imageAssetPaths[entry.key];
        return e.imageAsset!.imageFormat ??
            detectImageFormat(resolvedPath, e.imageAsset!.imageData) ??
            '';
      }),
    );
    final activeImageAssetFormats = await Future.wait(
      widget.items.asMap().entries.map((entry) async {
        final e = entry.value;
        if (e.activeImageAsset == null) return '';
        final resolvedPath = activeImageAssetPaths[entry.key];
        return e.activeImageAsset!.imageFormat ??
            detectImageFormat(resolvedPath, e.activeImageAsset!.imageData) ??
            '';
      }),
    );

    if (!mounted) return const SizedBox();

    final creationParams = <String, dynamic>{
      'labels': labels,
      'sfSymbols': symbols,
      'activeSfSymbols': activeSymbols,
      'badges': badges,
      'customIconBytes': customIconBytes,
      'activeCustomIconBytes': activeCustomIconBytes,
      'imageAssetPaths': imageAssetPaths,
      'activeImageAssetPaths': activeImageAssetPaths,
      'imageAssetData': imageAssetData,
      'activeImageAssetData': activeImageAssetData,
      'imageAssetFormats': imageAssetFormats,
      'activeImageAssetFormats': activeImageAssetFormats,
      'iconScale': capturedDevicePixelRatio, // Pass the scale!
      'sfSymbolSizes': sizes,
      'sfSymbolColors': colors,
      'selectedIndex': widget.currentIndex,
      'isDark': capturedIsDark,
      'split': _hasSearch
          ? true
          : widget.split, // Force split when search is enabled
      'rightCount': widget.rightCount,
      'splitSpacing': widget.splitSpacing,
      'style': capturedStyle
        ..addAll({
          if (capturedBackgroundColor != null)
            'backgroundColor': capturedBackgroundColor,
        }),
      // Search configuration (iOS 26+)
      if (_hasSearch) ...{
        'hasSearch': true,
        'searchPlaceholder': widget.searchItem!.placeholder,
        'searchLabel': widget.searchItem!.label,
        'searchSymbol': widget.searchItem!.icon?.name ?? 'magnifyingglass',
        'searchActiveSymbol':
            widget.searchItem!.activeIcon?.name ??
            widget.searchItem!.icon?.name ??
            'magnifyingglass',
        'automaticallyActivatesSearch':
            widget.searchItem!.automaticallyActivatesSearch,
        // Style configuration (captured before async operations)
        if (capturedSearchStyle != null) 'searchStyle': capturedSearchStyle,
      },
    };

    return _buildNativeTabBarPlatformView(creationParams);
  }

  Map<String, dynamic> _buildSearchStyleParams(BuildContext context) {
    final style = widget.searchItem?.style ?? const CNTabBarSearchStyle();
    return {
      if (style.iconSize != null) 'iconSize': style.iconSize,
      if (style.iconColor != null)
        'iconColor': resolveColorToArgb(style.iconColor, context),
      if (style.activeIconColor != null)
        'activeIconColor': resolveColorToArgb(style.activeIconColor, context),
      if (style.searchBarBackgroundColor != null)
        'searchBarBackgroundColor': resolveColorToArgb(
          style.searchBarBackgroundColor,
          context,
        ),
      if (style.searchBarTextColor != null)
        'searchBarTextColor': resolveColorToArgb(
          style.searchBarTextColor,
          context,
        ),
      if (style.searchBarPlaceholderColor != null)
        'searchBarPlaceholderColor': resolveColorToArgb(
          style.searchBarPlaceholderColor,
          context,
        ),
      if (style.clearButtonColor != null)
        'clearButtonColor': resolveColorToArgb(style.clearButtonColor, context),
      if (style.buttonSize != null) 'buttonSize': style.buttonSize,
      if (style.searchBarHeight != null)
        'searchBarHeight': style.searchBarHeight,
      if (style.searchBarBorderRadius != null)
        'searchBarBorderRadius': style.searchBarBorderRadius,
      if (style.searchBarPadding != null) ...{
        'searchBarPaddingLeft': style.searchBarPadding!.left,
        'searchBarPaddingRight': style.searchBarPadding!.right,
        'searchBarPaddingTop': style.searchBarPadding!.top,
        'searchBarPaddingBottom': style.searchBarPadding!.bottom,
      },
      if (style.contentPadding != null) ...{
        'contentPaddingLeft': style.contentPadding!.left,
        'contentPaddingRight': style.contentPadding!.right,
        'contentPaddingTop': style.contentPadding!.top,
        'contentPaddingBottom': style.contentPadding!.bottom,
      },
      if (style.spacing != null) 'spacing': style.spacing,
      if (style.animationDuration != null)
        'animationDuration': style.animationDuration!.inMilliseconds,
      'showClearButton': style.showClearButton,
      if (style.collapsedTabIcon != null)
        'collapsedTabIcon': style.collapsedTabIcon!.name,
    };
  }

  Future<Widget> _buildNativeTabBarPlatformView(
    Map<String, dynamic> creationParams,
  ) async {
    final viewType = 'CupertinoNativeTabBar';
    final platformView = defaultTargetPlatform == TargetPlatform.iOS
        ? UiKitView(
            viewType: viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
          )
        : AppKitView(
            viewType: viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
          );

    final h = widget.height ?? _intrinsicHeight ?? 50.0;
    if (!widget.split && widget.shrinkCentered) {
      final w = _intrinsicWidth;
      return ClipRect(
        child: SizedBox(height: h, width: w, child: platformView),
      );
    }
    return ClipRect(
      child: SizedBox(height: h, child: platformView),
    );
  }

  void _onCreated(int id) {
    final ch = MethodChannel('CupertinoNativeTabBar_$id');
    _channel = ch;
    ch.setMethodCallHandler(_onMethodCall);
    _lastIndex = widget.currentIndex;
    _lastTint = resolveColorToArgb(_effectiveTint, context);
    _lastBg = resolveColorToArgb(widget.backgroundColor, context);
    _lastIsDark = _isDark;
    _requestIntrinsicSize();
    _cacheItems();
    _lastSplit = widget.split;
    _lastRightCount = widget.rightCount;
    _lastSplitSpacing = widget.splitSpacing;

    // Force refresh for label rendering on iOS < 16
    // Wait for next frame to ensure view is fully initialized
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      Future.delayed(const Duration(milliseconds: 50), () async {
        if (mounted && _channel != null) {
          try {
            await _channel?.invokeMethod('refresh');
            // Ensure correct selection after refresh (refresh can reset selection state)
            await _channel?.invokeMethod('setSelectedIndex', {
              'index': widget.currentIndex,
            });
          } catch (e) {
            // Ignore MissingPluginException during hot reload or view recreation
            // This is expected when the platform view is being recreated
          }
        }
      });
    }
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'valueChanged') {
      final args = call.arguments as Map?;
      final idx = (args?['index'] as num?)?.toInt();
      if (idx != null && idx != _lastIndex) {
        widget.onTap(idx);
        _lastIndex = idx;
      }
    } else if (call.method == 'searchTextChanged') {
      final args = call.arguments as Map?;
      final text = args?['text'] as String? ?? '';
      _searchText = text;
      widget.searchItem?.onSearchChanged?.call(text);
      widget.searchController?.updateFromNative(text: text);
    } else if (call.method == 'searchActiveChanged') {
      final args = call.arguments as Map?;
      final isActive = args?['isActive'] as bool? ?? false;
      setState(() => _isSearchActive = isActive);
      widget.searchItem?.onSearchActiveChanged?.call(isActive);
      widget.searchController?.updateFromNative(isActive: isActive);
    } else if (call.method == 'searchSubmitted') {
      final args = call.arguments as Map?;
      final text = args?['text'] as String? ?? '';
      widget.searchItem?.onSearchSubmit?.call(text);
    }
    return null;
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    // Capture theme-dependent values before awaiting
    final idx = widget.currentIndex;
    final tint = resolveColorToArgb(_effectiveTint, context);
    final bg = resolveColorToArgb(widget.backgroundColor, context);
    final iconScale = MediaQuery.of(context).devicePixelRatio;

    try {
      if (_lastIndex != idx) {
        await ch.invokeMethod('setSelectedIndex', {'index': idx});
        _lastIndex = idx;
      }

      final style = <String, dynamic>{};
      if (_lastTint != tint && tint != null) {
        style['tint'] = tint;
        _lastTint = tint;
      }
      if (_lastBg != bg && bg != null) {
        style['backgroundColor'] = bg;
        _lastBg = bg;
      }
      if (style.isNotEmpty) {
        await ch.invokeMethod('setStyle', style);
      }

      // Items update (for hot reload or dynamic changes)
      final labels = widget.items.map((e) => e.label ?? '').toList();
      final symbols = widget.items.map((e) => e.icon?.name ?? '').toList();
      final activeSymbols = widget.items
          .map((e) => e.activeIcon?.name ?? e.icon?.name ?? '')
          .toList();
      final badges = widget.items.map((e) => e.badge ?? '').toList();

      // Fast path: if ONLY badges changed, use lightweight setBadges method
      final badgesChanged = _lastBadges?.join('|') != badges.join('|');
      final labelsChanged = _lastLabels?.join('|') != labels.join('|');
      final symbolsChanged = _lastSymbols?.join('|') != symbols.join('|');
      final activeSymbolsChanged =
          _lastActiveSymbols?.join('|') != activeSymbols.join('|');

      if (badgesChanged &&
          !labelsChanged &&
          !symbolsChanged &&
          !activeSymbolsChanged) {
        // Only badges changed - use lightweight update
        await ch.invokeMethod('setBadges', {'badges': badges});
        _lastBadges = badges;
        return;
      }

      // Check if basic properties changed
      if (labelsChanged ||
          symbolsChanged ||
          activeSymbolsChanged ||
          badgesChanged) {
        // Re-render custom icons if items changed
        final iconBytes = await _renderCustomIcons();
        final customIconBytes = iconBytes[0];
        final activeCustomIconBytes = iconBytes[1];

        // Extract imageAsset properties
        final imageAssetPaths = widget.items
            .map((e) => e.imageAsset?.assetPath ?? '')
            .toList();
        final activeImageAssetPaths = widget.items
            .map((e) => e.activeImageAsset?.assetPath ?? '')
            .toList();
        final imageAssetData = widget.items
            .map((e) => e.imageAsset?.imageData)
            .toList();
        final activeImageAssetData = widget.items
            .map((e) => e.activeImageAsset?.imageData)
            .toList();
        // Auto-detect format if not provided
        final imageAssetFormats = widget.items
            .map(
              (e) =>
                  e.imageAsset?.imageFormat ??
                  detectImageFormat(
                    e.imageAsset?.assetPath,
                    e.imageAsset?.imageData,
                  ) ??
                  '',
            )
            .toList();
        final activeImageAssetFormats = widget.items
            .map(
              (e) =>
                  e.activeImageAsset?.imageFormat ??
                  detectImageFormat(
                    e.activeImageAsset?.assetPath,
                    e.activeImageAsset?.imageData,
                  ) ??
                  '',
            )
            .toList();

        await ch.invokeMethod('setItems', {
          'labels': labels,
          'sfSymbols': symbols,
          'activeSfSymbols': activeSymbols,
          'badges': badges,
          'customIconBytes': customIconBytes,
          'activeCustomIconBytes': activeCustomIconBytes,
          'imageAssetPaths': imageAssetPaths,
          'activeImageAssetPaths': activeImageAssetPaths,
          'imageAssetData': imageAssetData,
          'activeImageAssetData': activeImageAssetData,
          'imageAssetFormats': imageAssetFormats,
          'activeImageAssetFormats': activeImageAssetFormats,
          'iconScale': iconScale,
          'selectedIndex': widget.currentIndex,
        });
        _lastLabels = labels;
        _lastSymbols = symbols;
        _lastActiveSymbols = activeSymbols;
        _lastBadges = badges;
        // Re-measure width in case content changed
        _requestIntrinsicSize();
      }

      // Layout updates (split / insets)
      if (_lastSplit != widget.split ||
          _lastRightCount != widget.rightCount ||
          _lastSplitSpacing != widget.splitSpacing) {
        await ch.invokeMethod('setLayout', {
          'split': widget.split,
          'rightCount': widget.rightCount,
          'splitSpacing': widget.splitSpacing,
          'selectedIndex': widget.currentIndex,
        });
        _lastSplit = widget.split;
        _lastRightCount = widget.rightCount;
        _lastSplitSpacing = widget.splitSpacing;
        _requestIntrinsicSize();
      }
    } catch (e) {
      // Ignore MissingPluginException during hot reload or view recreation
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
    _syncPropsToNativeIfNeeded();
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    final isDark = _isDark;
    if (_lastIsDark != isDark) {
      try {
        await ch.invokeMethod('setBrightness', {'isDark': isDark});
        _lastIsDark = isDark;
      } catch (e) {
        // Ignore MissingPluginException during hot reload or view recreation
      }
    }
  }

  void _cacheItems() {
    _lastLabels = widget.items.map((e) => e.label ?? '').toList();
    _lastSymbols = widget.items.map((e) => e.icon?.name ?? '').toList();
    _lastActiveSymbols = widget.items
        .map((e) => e.activeIcon?.name ?? e.icon?.name ?? '')
        .toList();
    _lastBadges = widget.items.map((e) => e.badge ?? '').toList();
    // Note: Custom icon bytes are cached in _syncPropsToNativeIfNeeded when rendered
  }

  Future<void> _requestIntrinsicSize() async {
    if (widget.height != null) return;
    final ch = _channel;
    if (ch == null) return;
    try {
      final size = await ch.invokeMethod<Map>('getIntrinsicSize');
      final h = (size?['height'] as num?)?.toDouble();
      final w = (size?['width'] as num?)?.toDouble();
      if (!mounted) return;
      setState(() {
        if (h != null && h > 0) _intrinsicHeight = h;
        if (w != null && w > 0) _intrinsicWidth = w;
      });
    } catch (_) {}
  }

  /// Builds the Flutter fallback for non-iOS 26+ platforms.
  /// Includes search functionality when searchItem is provided.
  Widget _buildFlutterFallback(BuildContext context) {
    final tintColor = widget.tint ?? ThemeHelper.getPrimaryColor(context);
    final style = widget.searchItem?.style ?? const CNTabBarSearchStyle();

    // If no search item, just return regular CupertinoTabBar
    if (!_hasSearch) {
      return SizedBox(
        height: widget.height,
        child: CupertinoTabBar(
          items: [
            for (final item in widget.items)
              BottomNavigationBarItem(
                icon: _buildTabIcon(item, isActive: false),
                activeIcon: _buildTabIcon(item, isActive: true),
                label: item.label,
              ),
          ],
          currentIndex: widget.currentIndex,
          onTap: widget.onTap,
          backgroundColor: widget.backgroundColor,
          inactiveColor: CupertinoColors.inactiveGray,
          activeColor: tintColor,
        ),
      );
    }

    // With search: build a custom layout that mimics iOS 26 behavior
    final buttonSize = style.buttonSize ?? 44.0;
    final iconSize = style.iconSize ?? 20.0;
    final spacing = style.spacing ?? 12.0;
    final contentPadding =
        style.contentPadding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    return Container(
      height: widget.height ?? 50,
      padding: contentPadding,
      child: Row(
        children: [
          // Left side: Tab items or collapsed indicator
          Expanded(
            child: AnimatedSwitcher(
              duration:
                  style.animationDuration ?? const Duration(milliseconds: 400),
              child: _isSearchActive
                  ? _buildCollapsedTabIndicator(
                      context,
                      tintColor,
                      buttonSize,
                      iconSize,
                      style,
                    )
                  : _buildTabItems(context, tintColor),
            ),
          ),
          SizedBox(width: spacing),
          // Right side: Search button or expanded search bar
          AnimatedSwitcher(
            duration:
                style.animationDuration ?? const Duration(milliseconds: 400),
            child: _isSearchActive
                ? _buildExpandedSearchBar(context, tintColor, style)
                : _buildSearchButton(
                    context,
                    tintColor,
                    buttonSize,
                    iconSize,
                    style,
                  ),
          ),
        ],
      ),
    );
  }

  /// Old method kept for Flutter fallback compatibility
  Widget _buildCollapsedTabIndicator(
    BuildContext context,
    Color tintColor,
    double buttonSize,
    double iconSize,
    CNTabBarSearchStyle style,
  ) {
    final collapsedIcon =
        style.collapsedTabIcon?.name ??
        widget.items.first.icon?.name ??
        'square.grid.2x2';

    return GestureDetector(
      onTap: () {
        // Unfocus and close keyboard first
        _searchFocusNode?.unfocus();
        setState(() => _isSearchActive = false);
        widget.searchItem?.onSearchActiveChanged?.call(false);
        widget.searchController?.updateFromNative(isActive: false);
        // Notify native iOS to deactivate search
        _channel?.invokeMethod('deactivateSearch');
      },
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(buttonSize / 2),
        ),
        child: CNIcon(
          symbol: CNSymbol(collapsedIcon),
          size: iconSize,
          color: style.activeIconColor ?? tintColor,
        ),
      ),
    );
  }

  Widget _buildTabItems(BuildContext context, Color tintColor) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < widget.items.length; i++)
            GestureDetector(
              onTap: () => widget.onTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: FittedBox(
                        child: _buildTabIcon(
                          widget.items[i],
                          isActive: widget.currentIndex == i,
                        ),
                      ),
                    ),
                    if (widget.items[i].label != null &&
                        widget.items[i].label!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        widget.items[i].label!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: widget.currentIndex == i
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: widget.currentIndex == i
                              ? tintColor
                              : CupertinoColors.inactiveGray,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchButton(
    BuildContext context,
    Color tintColor,
    double buttonSize,
    double iconSize,
    CNTabBarSearchStyle style,
  ) {
    final searchSymbol = widget.searchItem?.icon?.name ?? 'magnifyingglass';
    final autoActivate =
        widget.searchItem?.automaticallyActivatesSearch ?? true;

    return GestureDetector(
      onTap: () {
        setState(() => _isSearchActive = true);
        widget.searchItem?.onSearchActiveChanged?.call(true);
        widget.searchController?.updateFromNative(isActive: true);
        // Auto-focus search field if enabled
        if (autoActivate) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _searchFocusNode?.requestFocus();
          });
        }
      },
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(buttonSize / 2),
        ),
        child: CNIcon(
          symbol: CNSymbol(searchSymbol),
          size: iconSize,
          color: style.iconColor ?? CupertinoColors.secondaryLabel,
        ),
      ),
    );
  }

  Widget _buildExpandedSearchBar(
    BuildContext context,
    Color tintColor,
    CNTabBarSearchStyle style,
  ) {
    final searchSymbol = widget.searchItem?.icon?.name ?? 'magnifyingglass';
    final padding =
        style.searchBarPadding ??
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    return Expanded(
      child: Container(
        height: style.searchBarHeight ?? 36,
        decoration: BoxDecoration(
          color:
              style.searchBarBackgroundColor ??
              CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(
            style.searchBarBorderRadius ?? (style.searchBarHeight ?? 36) / 2,
          ),
        ),
        padding: padding,
        child: Row(
          children: [
            CNIcon(
              symbol: CNSymbol(searchSymbol),
              size: (style.iconSize ?? 20) * 0.8,
              color:
                  style.searchBarPlaceholderColor ??
                  CupertinoColors.secondaryLabel,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CupertinoTextField.borderless(
                focusNode: _searchFocusNode,
                autofocus: false, // Never auto-focus - we control this manually
                placeholder: widget.searchItem?.placeholder ?? 'Search',
                placeholderStyle: TextStyle(
                  color:
                      style.searchBarPlaceholderColor ??
                      CupertinoColors.secondaryLabel,
                ),
                style: TextStyle(
                  color: style.searchBarTextColor ?? CupertinoColors.label,
                ),
                onChanged: (text) {
                  setState(() => _searchText = text);
                  widget.searchItem?.onSearchChanged?.call(text);
                  widget.searchController?.updateFromNative(text: text);
                },
                onSubmitted: (text) {
                  widget.searchItem?.onSearchSubmit?.call(text);
                },
              ),
            ),
            if (style.showClearButton && _searchText.isNotEmpty)
              GestureDetector(
                onTap: () {
                  setState(() => _searchText = '');
                  widget.searchItem?.onSearchChanged?.call('');
                  widget.searchController?.updateFromNative(text: '');
                },
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: (style.iconSize ?? 20) * 0.8,
                  color:
                      style.clearButtonColor ?? CupertinoColors.secondaryLabel,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds an icon widget for the tab bar fallback.
  /// Priority: imageAsset > customIcon > icon (SF Symbol)
  Widget _buildTabIcon(CNTabBarItem item, {required bool isActive}) {
    const defaultSize = 25.0;

    // Check for image asset (highest priority)
    if (isActive && item.activeImageAsset != null) {
      return CNIcon(
        imageAsset: item.activeImageAsset,
        size: item.activeImageAsset!.size,
      );
    }
    if (item.imageAsset != null) {
      return CNIcon(imageAsset: item.imageAsset, size: item.imageAsset!.size);
    }

    // Check for custom icon (medium priority)
    if (isActive && item.activeCustomIcon != null) {
      return Icon(item.activeCustomIcon, size: defaultSize);
    }
    if (item.customIcon != null) {
      return Icon(item.customIcon, size: defaultSize);
    }

    // Check for SF Symbol (lowest priority)
    if (isActive && item.activeIcon != null) {
      return CNIcon(
        symbol: item.activeIcon,
        size: item.activeIcon!.size,
        color: item.activeIcon!.color,
      );
    }
    if (item.icon != null) {
      return CNIcon(
        symbol: item.icon,
        size: item.icon!.size,
        color: item.icon!.color,
      );
    }

    // Fallback to empty circle if nothing provided
    return const Icon(CupertinoIcons.circle, size: defaultSize);
  }
}
