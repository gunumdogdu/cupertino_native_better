import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

/// Renders [child] centered in a fixed-size stage on a neutral background,
/// then prints a machine-readable readiness line with the stage's pixel rect.
class CaptureStage extends StatefulWidget {
  const CaptureStage({
    super.key,
    required this.id,
    required this.size,
    required this.child,
    this.animMs = 0,
    this.background = const Color(0xFFF2F2F7),
  });

  final String id;
  final Size size;
  final Widget child;
  final int animMs;
  final Color background;

  @override
  State<CaptureStage> createState() => _CaptureStageState();
}

class _CaptureStageState extends State<CaptureStage> {
  final GlobalKey _stageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _printReady());
    });
  }

  void _printReady() {
    final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final topLeft = box.localToGlobal(Offset.zero);
    final l = (topLeft.dx * dpr).round();
    final t = (topLeft.dy * dpr).round();
    final w = (box.size.width * dpr).round();
    final h = (box.size.height * dpr).round();
    debugPrint('CN_CAPTURE_READY id=${widget.id} rect=$l,$t,$w,$h dpr=$dpr anim_ms=${widget.animMs}');
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: _stageKey,
        width: widget.size.width,
        height: widget.size.height,
        alignment: Alignment.center,
        color: widget.background,
        padding: const EdgeInsets.all(12),
        child: widget.child,
      ),
    );
  }
}
