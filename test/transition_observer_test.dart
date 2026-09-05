import 'package:cupertino_native_better/utils/transition_observer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('glass stays contained until the outgoing pop animation ends', (
    tester,
  ) async {
    final calls = <String>[];
    const channel = MethodChannel('cupertino_native');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [CNTransitionObserver()],
        home: const Scaffold(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    navigatorKey.currentState!.push(
      CupertinoPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    calls.clear();

    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, ['beginTransition']);
    await tester.pumpAndSettle();
    expect(calls, ['beginTransition', 'endTransition']);
  });
}
