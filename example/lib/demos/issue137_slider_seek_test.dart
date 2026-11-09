import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #137 reproduction: a tap doesn't seek on a thumbless `CNSlider`,
/// and a touch that ends without moving reports the unchanged value again.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/137
/// Reported by @cogwheel0.
///
/// ### The claims
///
/// 1. `UISlider` follows only a drag, so a tap on a thumbless track does
///    nothing.
/// 2. UIKit sends `.valueChanged` when a touch ends without moving, and the
///    package forwarded it: `onChanged` got the value the slider already had,
///    so an app seeking in `onChanged` seeked to where it already was.
/// 3. No `onChangeStart` / `onChangeEnd`.
///
/// ### How this screen proves it
///
/// A thumbless "scrubber" whose value moves on its own once a second, as
/// playback would, with `seekOnTap` on. The log lists every callback.
///
///  * **Tap the track at about 80%**: **bug:** nothing moves, and the log
///    shows `onChanged` with the old value when the finger lifts. **Fixed:**
///    the bar jumps to about 0.8 and the log shows `start`, one `changed
///    0.80`, then `end 0.80`.
///  * **Touch and lift without moving** (seekOnTap off): **fixed:** `start`
///    and `end` only, no `changed`.
///  * **Drag**: `start`, a run of `changed`, then `end`.
class Issue137SliderSeekTestPage extends StatefulWidget {
  const Issue137SliderSeekTestPage({super.key});

  @override
  State<Issue137SliderSeekTestPage> createState() =>
      _Issue137SliderSeekTestPageState();
}

class _Issue137SliderSeekTestPageState
    extends State<Issue137SliderSeekTestPage> {
  double _position = 0.2;
  bool _seekOnTap = true;
  bool _playing = true;
  final List<String> _log = <String>[];

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    while (mounted) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || !_playing) continue;
      setState(() => _position = (_position + 0.01).clamp(0.0, 1.0));
    }
  }

  void _add(String line) {
    debugPrint('CNB_137 $line');
    setState(() {
      _log.insert(0, line);
      if (_log.length > 14) _log.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#137: Slider tap to seek'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CNSlider(
              style: CNSliderStyle.thumbless,
              value: _position,
              seekOnTap: _seekOnTap,
              semanticLabel: 'Position',
              onChangeStart: (v) => _add('start ${v.toStringAsFixed(2)}'),
              onChanged: (v) {
                _add('changed ${v.toStringAsFixed(2)}');
                setState(() => _position = v);
              },
              onChangeEnd: (v) => _add('end ${v.toStringAsFixed(2)}'),
            ),
            Text(
              'position ${_position.toStringAsFixed(2)}',
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
            ),
            Row(
              children: [
                const Expanded(child: Text('seekOnTap')),
                CupertinoSwitch(
                  value: _seekOnTap,
                  onChanged: (v) => setState(() => _seekOnTap = v),
                ),
              ],
            ),
            Row(
              children: [
                const Expanded(child: Text('playing (moves 0.01/s)')),
                CupertinoSwitch(
                  value: _playing,
                  onChanged: (v) => setState(() => _playing = v),
                ),
              ],
            ),
            CupertinoButton(
              onPressed: () => setState(_log.clear),
              child: const Text('Clear log'),
            ),
            for (final line in _log)
              Text(
                line,
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}
