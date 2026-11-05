import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/sf_symbol.dart';
import '../style/tab_bar_search_item.dart';
import '../utils/version_detector.dart';
import '../utils/theme_helper.dart';
import 'icon.dart';
import 'tab_bar.dart';
import 'toolbar.dart';

/// A search scaffold item configuration.
class CNSearchScaffoldItem {
  /// Creates a search scaffold item.
  const CNSearchScaffoldItem({
    this.label,
    this.icon,
    this.activeIcon,
    this.isSearchTab = false,
  });

  /// The label for the tab.
  final String? label;

  /// The SF Symbol for the tab (unselected state).
  final CNSymbol? icon;

  /// The SF Symbol for the tab when selected.
  final CNSymbol? activeIcon;

  /// Whether this tab is the search tab.
  /// Only one tab should be marked as search.
  /// This tab will trigger the iOS 26 liquid glass search morphing.
  final bool isSearchTab;
}

/// A full-screen scaffold with native tabs and search.
///
/// - **iOS 26+**: a `UITabBarController` with a `UISearchTab`, for the
///   native Liquid Glass morphing effect when search is activated. Flutter
///   content is rendered on top of the native tab bar controller.
/// - **macOS** (every supported version): the Mac form of tabs and search,
///   in the window toolbar (see [CNToolbar]): the tabs that are not the
///   search tab are a segmented control in the middle of the toolbar (with
///   the tabs look of macOS 27), and the search tab is the toolbar's search
///   field (`NSSearchToolbarItem`) at its trailing edge. Clicking into the
///   field selects the search tab and calls [onSearchActiveChanged]; the
///   text goes to [onSearchChanged] and Return to [onSearchSubmit].
///   [searchController] starts and ends the search and sets its text. The
///   content fills the window under the toolbar. [tint] and
///   [unselectedTint] are not used: toolbar controls take the accent
///   colour. A tab is shown by its label, or by its icon when it has none.
/// - **iOS below 26 and other platforms**: a `CupertinoTabScaffold`.
///
/// Unlike [CNTabBar], this widget manages the entire screen layout.
///
/// Example:
/// ```dart
/// CNSearchScaffold(
///   items: [
///     CNSearchScaffoldItem(label: 'Home', icon: CNSymbol('house.fill')),
///     CNSearchScaffoldItem(label: 'Browse', icon: CNSymbol('square.grid.2x2')),
///     CNSearchScaffoldItem(label: 'Search', icon: CNSymbol('magnifyingglass'), isSearchTab: true),
///   ],
///   currentIndex: _index,
///   onTap: (i) => setState(() => _index = i),
///   onSearchChanged: (query) => filterResults(query),
///   children: [
///     HomePage(),
///     BrowsePage(),
///     SearchResultsPage(),
///   ],
/// )
/// ```
class CNSearchScaffold extends StatefulWidget {
  /// Creates a search scaffold with native iOS 26 liquid glass support.
  const CNSearchScaffold({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.children,
    this.tint,
    this.unselectedTint,
    this.onSearchChanged,
    this.onSearchSubmit,
    this.onSearchActiveChanged,
    this.searchPlaceholder = 'Search',
    this.searchController,
  }) : assert(
         items.length == children.length,
         'items and children must have same length',
       ),
       assert(items.length >= 2, 'Must have at least 2 items');

  /// Items to display in the tab bar.
  final List<CNSearchScaffoldItem> items;

  /// The index of the currently selected tab.
  final int currentIndex;

  /// Called when a tab is selected.
  final ValueChanged<int> onTap;

  /// The widget to display for each tab.
  /// Must have the same length as [items].
  final List<Widget> children;

  /// The tint color for selected items.
  final Color? tint;

  /// The tint color for unselected items.
  final Color? unselectedTint;

  /// Called when the search text changes.
  final ValueChanged<String>? onSearchChanged;

  /// Called when search is submitted.
  final ValueChanged<String>? onSearchSubmit;

  /// Called when search active state changes.
  final ValueChanged<bool>? onSearchActiveChanged;

  /// Placeholder text for the search bar.
  final String searchPlaceholder;

  /// Optional controller for programmatic search management.
  final CNTabBarSearchController? searchController;

  @override
  State<CNSearchScaffold> createState() => _CNSearchScaffoldState();
}

class _CNSearchScaffoldState extends State<CNSearchScaffold> {
  MethodChannel? _channel;
  int? _lastIndex;
  bool _isSearchActive = false;
  String _searchText = '';

  bool get _isDark => ThemeHelper.isDark(context);
  Color? get _effectiveTint =>
      widget.tint ?? ThemeHelper.getPrimaryColor(context);

  // Search tab index (can be used for conditional logic)
  // ignore: unused_element
  int get _searchTabIndex =>
      widget.items.indexWhere((item) => item.isSearchTab);

  @override
  void initState() {
    super.initState();
    widget.searchController?.addListener(_onSearchControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CNSearchScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController?.removeListener(_onSearchControllerChanged);
      widget.searchController?.addListener(_onSearchControllerChanged);
    }
    _syncPropsToNativeIfNeeded();
  }

  @override
  void dispose() {
    widget.searchController?.removeListener(_onSearchControllerChanged);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _onSearchControllerChanged() {
    final controller = widget.searchController;
    if (controller == null) return;

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
      // Ignore errors during hot reload
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return _buildMacScaffold(context);
    }
    // Only use native on iOS 26+
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final shouldUseNative = isIOS && PlatformVersion.shouldUseNativeGlass;

    if (!shouldUseNative) {
      return _buildFlutterFallback(context);
    }

    return _buildNativeScaffold(context);
  }

  Widget _buildNativeScaffold(BuildContext context) {
    final labels = widget.items.map((e) => e.label ?? '').toList();
    final symbols = widget.items.map((e) => e.icon?.name ?? '').toList();
    final activeSymbols = widget.items
        .map((e) => e.activeIcon?.name ?? e.icon?.name ?? '')
        .toList();
    final searchFlags = widget.items.map((e) => e.isSearchTab).toList();

    final creationParams = <String, dynamic>{
      'labels': labels,
      'sfSymbols': symbols,
      'activeSfSymbols': activeSymbols,
      'searchFlags': searchFlags,
      'selectedIndex': widget.currentIndex,
      'isDark': _isDark,
      'style': encodeStyle(context, tint: _effectiveTint)
        ..addAll({
          if (widget.unselectedTint != null)
            'unselectedTint': resolveColorToArgb(
              widget.unselectedTint,
              context,
            ),
        }),
      'searchPlaceholder': widget.searchPlaceholder,
    };

    return Stack(
      children: [
        // Native UITabBarController fills the screen
        Positioned.fill(
          child: UiKitView(
            viewType: 'CNSearchScaffold',
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
          ),
        ),
        // Flutter content rendered on top
        Positioned.fill(
          child: Column(
            children: [
              // Content area (above tab bar)
              Expanded(
                child: IndexedStack(
                  index: widget.currentIndex,
                  children: widget.children,
                ),
              ),
              // Safe area padding for tab bar
              SizedBox(height: MediaQuery.of(context).padding.bottom + 49),
            ],
          ),
        ),
      ],
    );
  }

  void _onCreated(int id) {
    final ch = MethodChannel('CNSearchScaffold_$id');
    _channel = ch;
    ch.setMethodCallHandler(_onMethodCall);
    _lastIndex = widget.currentIndex;
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'valueChanged':
        final args = call.arguments as Map?;
        final idx = (args?['index'] as num?)?.toInt();
        if (idx != null && idx != _lastIndex) {
          widget.onTap(idx);
          _lastIndex = idx;
        }
        break;

      case 'searchTextChanged':
        final args = call.arguments as Map?;
        final text = args?['text'] as String? ?? '';
        _searchText = text;
        widget.onSearchChanged?.call(text);
        widget.searchController?.updateFromNative(text: text);
        break;

      case 'searchActiveChanged':
        final args = call.arguments as Map?;
        final isActive = args?['isActive'] as bool? ?? false;
        setState(() => _isSearchActive = isActive);
        widget.onSearchActiveChanged?.call(isActive);
        widget.searchController?.updateFromNative(isActive: isActive);
        break;

      case 'searchSubmitted':
        final args = call.arguments as Map?;
        final text = args?['text'] as String? ?? '';
        widget.onSearchSubmit?.call(text);
        break;

      case 'tabDidAppear':
        // Tab became visible - could be used for lazy loading
        break;
    }
    return null;
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;

    final idx = widget.currentIndex;
    if (_lastIndex != idx) {
      try {
        await ch.invokeMethod('setSelectedIndex', {'index': idx});
        _lastIndex = idx;
      } catch (e) {
        // Ignore errors
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    try {
      await ch.invokeMethod('setBrightness', {'isDark': _isDark});
    } catch (e) {
      // Ignore errors
    }
  }

  /// macOS: the tabs and the search field in the window toolbar, the
  /// selected tab's content under it.
  Widget _buildMacScaffold(BuildContext context) {
    final searchIndex = widget.items.indexWhere((item) => item.isSearchTab);
    final tabs = <int>[
      for (var i = 0; i < widget.items.length; i++)
        if (!widget.items[i].isSearchTab) i,
    ];
    final selected = tabs.indexOf(widget.currentIndex);
    final searchItem = searchIndex >= 0 ? widget.items[searchIndex] : null;

    void select(int index) {
      if (index == widget.currentIndex) return;
      _lastIndex = index;
      widget.onTap(index);
    }

    return Column(
      children: [
        CNToolbar(
          items: [
            if (tabs.isNotEmpty)
              CNToolbarSegmentedGroup(
                id: 'tabs',
                label: 'Tabs',
                role: CNToolbarGroupRole.tabs,
                centered: true,
                segments: [
                  for (final i in tabs)
                    CNToolbarSegment(
                      label: widget.items[i].label ?? '',
                      // A label reads better than an icon in a toolbar.
                      icon: (widget.items[i].label ?? '').isEmpty
                          ? widget.items[i].icon
                          : null,
                    ),
                ],
                selectedIndices: selected >= 0 ? {selected} : const {},
                onSelected: (segment) => select(tabs[segment]),
              ),
            const CNToolbarSpace.flexible(),
            if (searchItem != null)
              CNToolbarSearch(
                id: 'search',
                label: searchItem.label ?? 'Search',
                placeholder: widget.searchPlaceholder,
                controller: widget.searchController,
                onChanged: (text) {
                  _searchText = text;
                  widget.onSearchChanged?.call(text);
                },
                onSubmitted: widget.onSearchSubmit,
                onActiveChanged: (active) {
                  if (active) select(searchIndex);
                  setState(() => _isSearchActive = active);
                  widget.onSearchActiveChanged?.call(active);
                },
              ),
          ],
        ),
        Expanded(
          child: IndexedStack(
            index: widget.currentIndex,
            children: widget.children,
          ),
        ),
      ],
    );
  }

  Widget _buildFlutterFallback(BuildContext context) {
    // Use regular CNTabBar for non-iOS 26 platforms
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: [
          for (final item in widget.items)
            BottomNavigationBarItem(
              // The item's symbol: native on iOS, the package's placeholder
              // elsewhere.
              icon: item.icon != null
                  ? CNIcon(symbol: item.icon, size: 24)
                  : const Icon(CupertinoIcons.circle),
              activeIcon: (item.activeIcon ?? item.icon) != null
                  ? CNIcon(
                      symbol: item.activeIcon ?? item.icon,
                      size: 24,
                      color: _effectiveTint,
                    )
                  : null,
              label: item.label,
            ),
        ],
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
        activeColor: _effectiveTint,
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(builder: (context) => widget.children[index]);
      },
    );
  }
}
