import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #151 reproduction: `seekOnTap` on a thumbless `CNSlider` lands too
/// far towards the ends of the track.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/151
/// Reported by @cogwheel0.
///
/// ### The claim
///
/// `valueAt` maps a tap between the thumb's centres at the minimum and the
/// maximum whenever `thumbRect` has a width. A thumbless slider draws no
/// thumb, but `thumbRect` still reports one about 37 pt wide, so the range
/// shrinks by that width: on an 88 pt track a tap at 75% reports about
/// 0.93, and taps in the first or last ~18 pt land on 0 or 1.
///
/// ### How this screen proves it
///
/// An 88 pt thumbless slider (the reporter's), a 240 pt thumbless slider
/// and a 240 pt slider with a thumb, all with `seekOnTap`. The marks under
/// each track sit at 25%, 50% and 75% of its width. Tap a mark: the value
/// beside the slider is what the tap reported.
///
///  * **Bug:** on the thumbless sliders the 75% mark reports about 0.93 on
///    the 88 pt slider (0.80 on the 240 pt one), the 25% mark about 0.07.
///  * **Fixed:** each mark reports its own fraction (0.25, 0.50, 0.75)
///    within a hair; the slider with a thumb is unchanged.
class Issue151ThumblessSliderSeekTestPage extends StatefulWidget {
  const Issue151ThumblessSliderSeekTestPage({super.key});

  @override
  State<Issue151ThumblessSliderSeekTestPage> createState() =>
      _Issue151ThumblessSliderSeekTestPageState();
}

class _Issue151ThumblessSliderSeekTestPageState
    extends State<Issue151ThumblessSliderSeekTestPage> {
  final List<double> _values = [0, 0, 0];

  Widget _row(int i, double width, CNSliderStyle style, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: width,
                child: Column(
                  children: [
                    CNSlider(
                      value: _values[i],
                      style: style,
                      seekOnTap: true,
                      onChanged: (v) => setState(() => _values[i] = v),
                    ),
                    _Marks(width: width),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _values[i].toStringAsFixed(3),
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#151: Thumbless seek'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            _row(0, 88, CNSliderStyle.thumbless, 'Thumbless, 88 pt'),
            _row(1, 240, CNSliderStyle.thumbless, 'Thumbless, 240 pt'),
            _row(2, 240, CNSliderStyle.standard, 'With a thumb, 240 pt'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tap a mark (25%, 50%, 75% of the width). Bug: the thumbless '
                'sliders report values pushed towards 0 and 1 (about 0.93 '
                'for the 75% mark at 88 pt). Fixed: 0.25, 0.50, 0.75.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Marks extends StatelessWidget {
  const _Marks({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final color = CupertinoColors.systemRed.resolveFrom(context);
    return SizedBox(
      width: width,
      height: 10,
      child: Stack(
        children: [
          for (final f in const [0.25, 0.5, 0.75])
            Positioned(
              left: width * f - 1,
              top: 0,
              child: Container(width: 2, height: 10, color: color),
            ),
        ],
      ),
    );
  }
}
