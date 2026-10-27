import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp, Scaffold;
import 'package:flutter_test/flutter_test.dart';

/// `semanticLabel` on icon-only buttons (#88): what VoiceOver reads instead of
/// the SF Symbol's built-in name. These cover the Flutter fallback; the native
/// path applies the same string to the UIButton or SwiftUI view.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Android, so the widgets take their Flutter fallback in the test host.
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  Widget host(Widget child) => CupertinoApp(home: Center(child: child));

  // The Android fallbacks of CNSwitch and CNSlider are Material widgets.
  Widget materialHost(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('CNButton.icon exposes its semanticLabel', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        CNButton.icon(
          icon: const CNSymbol('moon'),
          semanticLabel: 'Switch to dark mode',
          onPressed: () {},
        ),
      ),
    );

    expect(find.bySemanticsLabel('Switch to dark mode'), findsOneWidget);
    // Let the icon fallback's deferred timer run before teardown.
    await tester.pump(const Duration(seconds: 1));
    semantics.dispose();
  }, variant: android);

  testWidgets('CNButton without a semanticLabel keeps its title', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(CNButton(label: 'Save', onPressed: () {})));

    expect(find.bySemanticsLabel('Save'), findsOneWidget);
    semantics.dispose();
  }, variant: android);

  testWidgets('CNPopupMenuButton.icon exposes its semanticLabel', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        CNPopupMenuButton.icon(
          buttonIcon: const CNSymbol('paintpalette.fill'),
          semanticLabel: 'Accent colour',
          items: const <CNPopupMenuEntry>[CNPopupMenuItem(label: 'Blue')],
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.bySemanticsLabel('Accent colour'), findsOneWidget);
    semantics.dispose();
  }, variant: android);

  testWidgets('CNSwitch reads its semanticLabel with its state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      materialHost(
        CNSwitch(value: true, semanticLabel: 'Wi-Fi', onChanged: (_) {}),
      ),
    );

    // One node carries both the label and the switch's state.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Wi-Fi')),
      isSemantics(label: 'Wi-Fi', isToggled: true),
    );
    semantics.dispose();
  }, variant: android);

  testWidgets('CNSlider exposes its semanticLabel', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      materialHost(
        SizedBox(
          width: 300,
          child: CNSlider(
            value: 0.5,
            semanticLabel: 'Volume',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Volume'), findsOneWidget);
    semantics.dispose();
  }, variant: android);
}
