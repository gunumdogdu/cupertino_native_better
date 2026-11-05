// Runs on a device or simulator: the package's widgets build in a real app
// and answer their platform channels without errors.
//
//   flutter test integration_test/plugin_integration_test.dart -d <device>

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native controls build and report their changes', (tester) async {
    var pressed = 0;
    var on = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (context, setState) => CupertinoPageScaffold(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CNButton(label: 'Press', onPressed: () => pressed++),
                  CNSwitch(value: on, onChanged: (v) => setState(() => on = v)),
                  const CNProgressIndicator(value: 0.4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(CNButton), findsOneWidget);
    expect(find.byType(CNSwitch), findsOneWidget);
    expect(find.byType(CNProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
