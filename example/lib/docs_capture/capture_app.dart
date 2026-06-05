import 'package:flutter/cupertino.dart';
import 'stages.dart';

const _id = String.fromEnvironment('CN_CAPTURE', defaultValue: 'cn-button');

void main() {
  final spec = kStages[_id];
  runApp(CupertinoApp(
    debugShowCheckedModeBanner: false,
    home: CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      child: spec == null
          ? Center(child: Text('Unknown capture id: $_id'))
          : spec.build(),
    ),
  ));
}
