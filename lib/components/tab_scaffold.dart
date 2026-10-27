import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'foldable.dart';
import 'tab_bar.dart';
import 'tab_rail.dart';

/// Where [CNTabScaffold] puts its tabs.
enum CNTabPlacement {
  /// A [CNTabBar] floating at the bottom.
  bottom,

  /// A [CNTabRail] in the system's vertical-bar column (iPhone Duo outer
  /// display, and the inner display in landscape).
  rail,

  /// A sidebar-style [CNTabRail] on the leading side of a wide screen.
  sidebar,
}

/// A tab layout that follows the screen it is on — the answer to "the tab bar
/// should move to the side" on iPhone Duo.
///
/// iOS 27.1 moves a system tab bar to a vertical bar on one edge of the
/// iPhone Duo outer display, and of the inner display in landscape. It does
/// that only for system containers, so a [CNTabBar] stays at the bottom.
/// [CNTabScaffold] reproduces the behaviour: it shows a [CNTabBar] at the
/// bottom, swaps it for a [CNTabRail] in the vertical-bar column whenever the
/// system uses one, and, with [sidebarOnWideScreens], for a sidebar on screens
/// at least [sidebarMinWidth] wide (the open inner display in portrait).
///
/// It reads the vertical-bar side from [CNFoldable], so put a
/// [CNFoldableScope] above it (or anywhere above the app).
///
/// [body] stays mounted across every placement change, so folding and
/// unfolding never resets the page's state. It receives a `MediaQuery` whose
/// padding includes the space the tabs take, so scroll views keep their last
/// item clear of the bar.
class CNTabScaffold extends StatelessWidget {
  /// Creates an adaptive tab scaffold.
  const CNTabScaffold({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.body,
    this.tint,
    this.backgroundColor,
    this.sidebarOnWideScreens = false,
    this.sidebarMinWidth = 600,
    this.placement,
    this.tabBarBuilder,
  });

  /// The tabs, shared by the bottom bar and the rail.
  final List<CNTabBarItem> items;

  /// The selected tab.
  final int currentIndex;

  /// Called with the index of a tapped tab.
  final ValueChanged<int> onTap;

  /// The page for the selected tab.
  final Widget body;

  /// Colour of the selected tab.
  final Color? tint;

  /// Background behind [body]. Defaults to the system background.
  final Color? backgroundColor;

  /// Show a sidebar instead of the bottom bar on screens at least
  /// [sidebarMinWidth] wide. The vertical bar still takes precedence.
  final bool sidebarOnWideScreens;

  /// Narrowest screen that gets a sidebar when [sidebarOnWideScreens] is on.
  final double sidebarMinWidth;

  /// Forces a placement instead of choosing one. With [CNTabPlacement.rail]
  /// and no system vertical bar, the rail goes on the right.
  final CNTabPlacement? placement;

  /// Builds the bottom bar, for [CNTabBar] options this scaffold does not
  /// expose (split mode, search, fonts…). Defaults to a [CNTabBar] with
  /// [items], [currentIndex], [onTap] and [tint].
  final WidgetBuilder? tabBarBuilder;

  /// Height the bottom bar is assumed to take, above the bottom safe area.
  static const double bottomBarExtent = 64;

  /// The placement this scaffold uses in [context].
  CNTabPlacement resolvePlacement(BuildContext context) {
    if (placement != null) return placement!;
    if (CNFoldable.of(context).hasVerticalBar) return CNTabPlacement.rail;
    if (sidebarOnWideScreens &&
        MediaQuery.sizeOf(context).width >= sidebarMinWidth) {
      return CNTabPlacement.sidebar;
    }
    return CNTabPlacement.bottom;
  }

  /// Bottom offset for the rail: just above the bottom safe area, unless an
  /// active camera region (the iPhone Duo outer display puts its camera in a
  /// corner, which ends up at the bottom in landscape) sits in the rail's
  /// column — then just above that region.
  double _railBottom(BuildContext context, bool onLeft, double edge) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    var bottom = math.max(padding.bottom, 12.0);
    final railHeight = CNTabRail.railHeight(items.length);
    final left = onLeft ? edge : size.width - edge - CNTabRail.railWidth;
    for (final region in CNFoldable.of(context).regions) {
      if (region.kind != CNReservedRegionKind.occlusion || !region.isActive) {
        continue;
      }
      final rail = Rect.fromLTWH(
        left,
        size.height - bottom - railHeight,
        CNTabRail.railWidth,
        railHeight,
      );
      final avoid = region.frame.inflate(8);
      if (rail.overlaps(avoid) && avoid.center.dy > rail.center.dy) {
        bottom = size.height - avoid.top;
      }
    }
    return bottom;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final padding = mq.padding;
    final resolved = resolvePlacement(context);
    final barSide = CNFoldable.of(context).verticalBarSide;
    final railOnLeft = barSide == CNVerticalBarSide.left;

    // Where the body sits and how much extra padding it reports.
    var bodyLeft = 0.0;
    var bodyPadding = padding;
    late final Widget tabs;

    switch (resolved) {
      case CNTabPlacement.bottom:
        bodyPadding = padding.copyWith(
          bottom: padding.bottom + bottomBarExtent,
        );
        tabs = Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child:
                tabBarBuilder?.call(context) ??
                CNTabBar(
                  items: items,
                  currentIndex: currentIndex,
                  onTap: onTap,
                  tint: tint,
                ),
          ),
        );
      case CNTabPlacement.rail:
        // The system's vertical bar lives in the side safe-area inset, under
        // the vertical status bar; the rail goes in the same column, at the
        // bottom. Where that inset is too narrow (forced placement on another
        // device) the rail gets its own margin.
        final inset = railOnLeft ? padding.left : padding.right;
        final column = math.max(inset, CNTabRail.railWidth + 16);
        final edge = (column - CNTabRail.railWidth) / 2;
        bodyPadding = railOnLeft
            ? padding.copyWith(left: column)
            : padding.copyWith(right: column);
        final rail = CNTabRail(
          items: items,
          currentIndex: currentIndex,
          onTap: onTap,
          tint: tint,
        );
        tabs = Positioned(
          left: railOnLeft ? edge : null,
          right: railOnLeft ? null : edge,
          bottom: _railBottom(context, railOnLeft, edge),
          child: rail,
        );
      case CNTabPlacement.sidebar:
        const margin = 10.0;
        bodyLeft = padding.left + margin + CNTabRail.sidebarWidth;
        bodyPadding = padding.copyWith(left: 0);
        tabs = Positioned(
          left: padding.left + margin,
          top: padding.top + margin,
          bottom: math.max(padding.bottom, margin),
          child: CNTabRail(
            items: items,
            currentIndex: currentIndex,
            onTap: onTap,
            tint: tint,
            style: CNTabRailStyle.sidebar,
          ),
        );
    }

    return ColoredBox(
      color:
          backgroundColor ??
          CupertinoColors.systemBackground.resolveFrom(context),
      child: Stack(
        children: <Widget>[
          // Same type at the same index in every placement, so the body keeps
          // its state when the device folds or rotates.
          Positioned(
            left: bodyLeft,
            top: 0,
            right: 0,
            bottom: 0,
            child: MediaQuery(
              data: mq.copyWith(
                padding: bodyPadding,
                size: Size(
                  math.max(0, mq.size.width - bodyLeft),
                  mq.size.height,
                ),
              ),
              child: body,
            ),
          ),
          tabs,
        ],
      ),
    );
  }
}
