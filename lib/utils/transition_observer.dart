import 'package:flutter/widgets.dart';
import '../cupertino_native_platform_interface.dart';

/// A navigation observer that automatically notifies native Cupertino components
/// when route transitions begin and end.
///
/// This prevents visual artifacts with Liquid Glass effects during Flutter
/// navigation transitions.
///
/// ## Usage
///
/// Add this observer to your app's navigatorObservers:
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [
///     CNTransitionObserver(),
///   ],
///   // ...
/// )
/// ```
///
/// Or with GoRouter:
///
/// ```dart
/// GoRouter(
///   observers: [
///     CNTransitionObserver(),
///   ],
///   // ...
/// )
/// ```
class CNTransitionObserver extends NavigatorObserver {
  /// Creates a [CNTransitionObserver] instance.
  CNTransitionObserver();

  int _transitionCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _beginTransition();
    _scheduleEndTransition(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _beginTransition();
    // The outgoing route owns the reverse animation.
    _scheduleEndTransition(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _beginTransition();
    _scheduleEndTransition(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _beginTransition();
    _scheduleEndTransition(previousRoute);
  }

  void _beginTransition() {
    _transitionCount++;
    if (_transitionCount == 1) {
      CupertinoNativePlatform.instance.beginTransition();
    }
  }

  void _scheduleEndTransition(Route<dynamic>? route) {
    // Get the animation from the route (only ModalRoute has animation)
    Animation<double>? animation;
    if (route is ModalRoute) {
      animation = route.animation;
    }

    if (animation != null && animation.status != AnimationStatus.completed) {
      // Wait for animation to complete
      void listener(AnimationStatus status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          animation!.removeStatusListener(listener);
          _endTransition();
        }
      }

      animation.addStatusListener(listener);
    } else {
      // No animation or already complete, end after a short delay
      Future.delayed(const Duration(milliseconds: 350), _endTransition);
    }
  }

  void _endTransition() {
    _transitionCount--;
    if (_transitionCount <= 0) {
      _transitionCount = 0;
      CupertinoNativePlatform.instance.endTransition();
    }
  }
}

/// Static utility methods for manual transition control.
///
/// Use these when you need fine-grained control over transition notifications,
/// such as with custom transitions or modal presentations.
class CNTransitionHelper {
  CNTransitionHelper._();

  /// Call this before starting a navigation transition.
  static Future<void> beginTransition() {
    return CupertinoNativePlatform.instance.beginTransition();
  }

  /// Call this after a navigation transition completes.
  static Future<void> endTransition() {
    return CupertinoNativePlatform.instance.endTransition();
  }

  /// Wraps an async navigation operation with transition notifications.
  ///
  /// Example:
  /// ```dart
  /// await CNTransitionHelper.withTransition(() async {
  ///   await Navigator.of(context).pushNamed('/details');
  /// });
  /// ```
  static Future<T> withTransition<T>(Future<T> Function() operation) async {
    await beginTransition();
    try {
      return await operation();
    } finally {
      // Delay end to allow animation to complete
      Future.delayed(const Duration(milliseconds: 350), endTransition);
    }
  }
}
