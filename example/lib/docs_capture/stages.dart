import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'capture_stage.dart';

class StageSpec {
  const StageSpec({required this.kind, required this.loopMs, required this.build});
  final String kind;   // 'static' | 'animated'
  final int loopMs;
  final Widget Function() build;
}

final Map<String, StageSpec> kStages = {
  'cn-button': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'cn-button',
      size: const Size(220, 80),
      child: CNButton(
        label: 'Get Started',
        icon: const CNSymbol('arrow.right', size: 18),
        config: const CNButtonConfig(style: CNButtonStyle.filled),
        onPressed: () {},
      ),
    ),
  ),
};
