import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// CNGauge: every style, labels, warning and critical zones (rising and
/// falling scales), tick marks, an editable rating, and gauges in tappable
/// rows of a list (a tap reaches the row, a drag scrolls).
///
/// The editable rating and the rows print `CNB_RESULT gauge <what> <value>`,
/// for scripts.
class GaugeDemoPage extends StatefulWidget {
  const GaugeDemoPage({
    super.key,
    this.autoCycle = false,
    this.initialScrollOffset = 0,
  });

  /// Moves the shared value on a timer, so the zone colours and the native
  /// value changes can be watched (and screenshot) without a tap. Prints
  /// `CNB_SHOT gauge<n>` after each step.
  final bool autoCycle;

  /// Where the list starts, for screenshots of its lower sections.
  final double initialScrollOffset;

  @override
  State<GaugeDemoPage> createState() => _GaugeDemoPageState();
}

class _GaugeDemoPageState extends State<GaugeDemoPage> {
  double _level = 62;
  double _rating = 3;
  int _rowTaps = 0;
  Timer? _timer;
  int _tick = 0;
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: widget.initialScrollOffset,
  );

  static const _steps = [62.0, 81.0, 95.0, 18.0, 40.0];

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        setState(() {
          _tick++;
          _level = _steps[_tick % _steps.length];
          _rating = (_tick % 6).toDouble();
        });
        debugPrint('CNB_SHOT gauge$_tick');
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );

  Widget _labelled(String label, Widget gauge) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(height: 64, child: Center(child: gauge)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final level = _level.round();
    final battery = (100 - _level).roundToDouble();
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Gauge')),
      child: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          children: [
            _caption('Value $level of 100 (drag the slider)'),
            CNSlider(
              value: _level,
              min: 0,
              max: 100,
              semanticLabel: 'Gauge value',
              onChanged: (v) => setState(() => _level = v),
            ),
            _caption('Capacity with labels, warning 75, critical 90'),
            CNGauge(
              value: _level,
              max: 100,
              warningValue: 75,
              criticalValue: 90,
              label: 'Storage',
              currentValueLabel: '$level GB',
              minimumValueLabel: '0',
              maximumValueLabel: '100',
            ),
            _caption('Capacity, no labels; tinted'),
            CNGauge(value: _level, max: 100, semanticLabel: 'Progress'),
            const SizedBox(height: 10),
            CNGauge(
              value: _level,
              max: 100,
              tint: CupertinoColors.systemIndigo,
              semanticLabel: 'Indigo',
            ),
            _caption('Falling scale (battery): critical 20, warning 40'),
            CNGauge(
              value: battery,
              max: 100,
              warningValue: 40,
              criticalValue: 20,
              label: 'Battery',
              currentValueLabel: '${battery.round()}%',
            ),
            _caption('Discrete capacity, 10 segments, tick marks (macOS)'),
            CNGauge(
              value: _level / 10,
              max: 10,
              style: CNGaugeStyle.discreteCapacity,
              warningValue: 7,
              criticalValue: 9,
              tickMarkCount: 11,
              majorTickMarkCount: 3,
              semanticLabel: 'Signal',
            ),
            _caption('Relevancy'),
            CNGauge(
              value: _level,
              max: 100,
              style: CNGaugeStyle.relevancy,
              semanticLabel: 'Relevance',
            ),
            _caption('Rating: read-only, and editable (click or drag)'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                CNGauge(
                  value: 3.5,
                  max: 5,
                  style: CNGaugeStyle.rating,
                  semanticLabel: 'Average rating',
                ),
                CNGauge(
                  value: _rating,
                  max: 5,
                  style: CNGaugeStyle.rating,
                  tint: CupertinoColors.systemOrange,
                  semanticLabel: 'Your rating',
                  onChanged: (v) {
                    debugPrint('CNB_RESULT gauge rating $v');
                    setState(() => _rating = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Your rating: ${_rating.round()} of 5',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            _caption('Rings and the line'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _labelled(
                  'circular capacity',
                  CNGauge(
                    value: _level,
                    max: 100,
                    style: CNGaugeStyle.circularCapacity,
                    currentValueLabel: '$level',
                    semanticLabel: 'Speed',
                  ),
                ),
                _labelled(
                  'circular, zones',
                  CNGauge(
                    value: _level,
                    max: 100,
                    style: CNGaugeStyle.circular,
                    warningValue: 60,
                    criticalValue: 85,
                    currentValueLabel: '$level',
                    minimumValueLabel: '0',
                    maximumValueLabel: '100',
                    semanticLabel: 'Temperature',
                  ),
                ),
                _labelled(
                  'tinted',
                  CNGauge(
                    value: _level,
                    max: 100,
                    style: CNGaugeStyle.circularCapacity,
                    tint: CupertinoColors.systemPink,
                    currentValueLabel: '$level',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CNGauge(
              value: _level,
              max: 100,
              style: CNGaugeStyle.linear,
              warningValue: 60,
              criticalValue: 85,
              minimumValueLabel: '0',
              maximumValueLabel: '100',
              semanticLabel: 'Level',
            ),
            _caption(
              'In tappable rows: a tap on a gauge reaches the row '
              '(taps: $_rowTaps), a drag on it scrolls',
            ),
            for (var i = 0; i < 8; i++)
              CupertinoListTile(
                title: Text('Disk ${i + 1}'),
                trailing: SizedBox(
                  width: 120,
                  child: CNGauge(
                    value: (i * 13 + _level) % 100,
                    max: 100,
                    warningValue: 75,
                    criticalValue: 90,
                    semanticLabel: 'Disk ${i + 1}',
                  ),
                ),
                onTap: () {
                  debugPrint('CNB_RESULT gauge row $i');
                  setState(() => _rowTaps++);
                },
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
