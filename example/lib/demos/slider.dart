import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

class SliderDemoPage extends StatefulWidget {
  const SliderDemoPage({super.key});

  @override
  State<SliderDemoPage> createState() => _SliderDemoPageState();
}

class _SliderDemoPageState extends State<SliderDemoPage> {
  double _defaultSliderValue = 50;
  double _stepSliderValue = 50;
  double _coloredSliderValue = 50;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Slider')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                const Text('Default'),
                Spacer(),
                Text('Value: ${_defaultSliderValue.toStringAsFixed(1)}'),
              ],
            ),
            CNSlider(
              value: _defaultSliderValue,
              min: 0,
              max: 100,
              enabled: true,
              onChanged: (v) => setState(() => _defaultSliderValue = v),
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                const Text('Shared value'),
                Spacer(),
                Text('Value: ${_defaultSliderValue.toStringAsFixed(1)}'),
              ],
            ),
            CNSlider(
              value: _defaultSliderValue,
              min: 0,
              max: 100,
              enabled: true,
              onChanged: (v) => setState(() => _defaultSliderValue = v),
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                const Text('With color'),
                Spacer(),
                Text('Value: ${_coloredSliderValue.toStringAsFixed(1)}'),
              ],
            ),
            CNSlider(
              value: _coloredSliderValue,
              min: 0,
              max: 100,
              enabled: true,
              color: CupertinoColors.systemPink,
              onChanged: (v) => setState(() => _coloredSliderValue = v),
            ),
            const SizedBox(height: 48),

            Row(
              children: [
                const Text('Step slider'),
                Spacer(),
                Text('Value: ${_stepSliderValue.toStringAsFixed(0)}'),
              ],
            ),
            CNSlider(
              value: _stepSliderValue,
              min: 0,
              max: 100,
              enabled: true,
              step: 10,
              onChanged: (v) => setState(() => _stepSliderValue = v),
            ),

            const SizedBox(height: 48),

            const Text('Disabled'),
            CNSlider(
              value: 50,
              min: 0,
              max: 100,
              enabled: false,
              onChanged: (_) {},
            ),

            const SizedBox(height: 48),
            const Text(
              'iOS 26: thumbless, ticks, neutral value',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Slider26Showcase(),
          ],
        ),
      ),
    );
  }
}

/// The iOS 26 slider options: [CNSliderStyle.thumbless], tick marks with and
/// without snapping, explicit tick values and a neutral value. With
/// [animate], a timer moves the values so they can be seen without
/// dragging. Used by the slider demo and by `PROBE=slider26`.
class Slider26Showcase extends StatefulWidget {
  const Slider26Showcase({super.key, this.animate = false});

  final bool animate;

  @override
  State<Slider26Showcase> createState() => _Slider26ShowcaseState();
}

class _Slider26ShowcaseState extends State<Slider26Showcase> {
  double _media = 35;
  double _ticked = 50;
  double _free = 30;
  double _explicit = 25;
  double _balance = 4;
  double _thumblessTicked = 2;
  Timer? _timer;
  int _step = 0;

  static const _explicitTicks = <double>[0, 10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        if (!mounted) return;
        setState(() {
          _step++;
          _media = (_media + 17) % 100;
          _ticked = [0.0, 25.0, 50.0, 75.0, 100.0][_step % 5];
          _free = (_free + 23) % 100;
          _explicit = _explicitTicks[_step % _explicitTicks.length];
          _balance = [-8.0, -3.0, 0.0, 5.0, 9.0][_step % 5];
          _thumblessTicked = (_step % 5).toDouble();
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _row(String title, double value, Widget slider) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
        slider,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(
          'Thumbless (media scrubber)',
          _media,
          CNSlider(
            value: _media,
            min: 0,
            max: 100,
            style: CNSliderStyle.thumbless,
            semanticLabel: 'Playback position',
            onChanged: (v) => setState(() => _media = v),
          ),
        ),
        _row(
          '5 ticks, snapping (numberOfTicks: 5)',
          _ticked,
          CNSlider(
            value: _ticked,
            min: 0,
            max: 100,
            numberOfTicks: 5,
            onChanged: (v) => setState(() => _ticked = v),
          ),
        ),
        _row(
          '11 ticks, free (allowsTickValuesOnly: false)',
          _free,
          CNSlider(
            value: _free,
            min: 0,
            max: 100,
            numberOfTicks: 11,
            allowsTickValuesOnly: false,
            color: CupertinoColors.systemPink,
            onChanged: (v) => setState(() => _free = v),
          ),
        ),
        _row(
          'tickValues: 0, 10, 25, 50, 100',
          _explicit,
          CNSlider(
            value: _explicit,
            min: 0,
            max: 100,
            tickValues: _explicitTicks,
            color: CupertinoColors.systemGreen,
            onChanged: (v) => setState(() => _explicit = v),
          ),
        ),
        _row(
          'neutralValue: 0 (-10 … 10)',
          _balance,
          CNSlider(
            value: _balance,
            min: -10,
            max: 10,
            neutralValue: 0,
            color: CupertinoColors.systemOrange,
            onChanged: (v) => setState(() => _balance = v),
          ),
        ),
        _row(
          'Thumbless with 5 ticks (0 … 4)',
          _thumblessTicked,
          CNSlider(
            value: _thumblessTicked,
            min: 0,
            max: 4,
            numberOfTicks: 5,
            style: CNSliderStyle.thumbless,
            color: CupertinoColors.systemIndigo,
            onChanged: (v) => setState(() => _thumblessTicked = v),
          ),
        ),
      ],
    );
  }
}
