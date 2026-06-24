import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'stages.dart';

const _id = String.fromEnvironment('CN_CAPTURE', defaultValue: 'cn-button');

void main() {
  final spec = kStages[_id];
  runApp(CupertinoApp(
    debugShowCheckedModeBanner: false,
    navigatorObservers: [CNTabBarRouteObserver()],
    home: CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      child: spec == null
          ? Center(child: Text('Unknown capture id: $_id'))
          : spec.build(),
    ),
  ));
}
