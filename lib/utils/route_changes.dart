import 'package:flutter/foundation.dart';

/// Counts the route changes (push, pop, remove, replace) seen by the
/// package's navigator observers, `CNTabBarRouteObserver` and
/// `CNTransitionObserver`, on every navigator they are attached to.
///
/// `CNPopover` closes on any of them. It also watches its anchor's own
/// route, which covers apps without these observers, but only an observer
/// on the root navigator sees a route pushed there over a page of a nested
/// navigator (a tab's), which leaves that page the current route of its own
/// navigator.
final ValueNotifier<int> cnRouteChanges = ValueNotifier<int>(0);

/// Records a route change; called by the observers.
void notifyCNRouteChange() => cnRouteChanges.value++;
