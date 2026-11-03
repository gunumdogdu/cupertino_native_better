import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// CNStepper: a whole-number stepper, a decimal one that wraps, a tinted one
/// and a disabled one, each with its value next to it.
///
/// [autoCycle] steps the values and the tint on a timer, so the page can be
/// checked from screenshots without tapping (`PROBE=stepper`).
class StepperDemoPage extends StatefulWidget {
  const StepperDemoPage({super.key, this.autoCycle = false});

  /// Changes the values every 1.5 s.
  final bool autoCycle;

  @override
  State<StepperDemoPage> createState() => _StepperDemoPageState();
}

class _StepperDemoPageState extends State<StepperDemoPage> {
  double _guests = 2;
  double _rating = 3.5;
  double _tinted = 5;
  double _floor = 0;
  bool _pink = true;
  bool _toggledEnabled = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        setState(() {
          _guests = _guests >= 12 ? 1 : _guests + 1;
          _rating = _rating >= 5 ? 0 : _rating + 0.5;
          _tinted = _tinted >= 10 ? 0 : _tinted + 1;
          _pink = !_pink;
          _toggledEnabled = !_toggledEnabled;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _row(String label, String value, Widget stepper) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          stepper,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Stepper')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            _row(
              'Guests',
              'Value: ${_guests.toInt()} (1 to 12)',
              CNStepper(
                value: _guests,
                min: 1,
                max: 12,
                semanticLabel: 'Guests',
                onChanged: (v) => setState(() => _guests = v),
              ),
            ),
            _row(
              'Rating',
              'Value: ${_rating.toStringAsFixed(1)} (step 0.5, wraps)',
              CNStepper(
                value: _rating,
                min: 0,
                max: 5,
                step: 0.5,
                wraps: true,
                semanticLabel: 'Rating',
                onChanged: (v) => setState(() => _rating = v),
              ),
            ),
            _row(
              'With color',
              'Value: ${_tinted.toInt()} (${_pink ? 'pink' : 'green'})',
              CNStepper(
                value: _tinted,
                max: 10,
                color: _pink
                    ? CupertinoColors.systemPink
                    : CupertinoColors.systemGreen,
                semanticLabel: 'Tinted value',
                onChanged: (v) => setState(() => _tinted = v),
              ),
            ),
            _row(
              'Disabled',
              'Value: 4',
              CNStepper(
                value: 4,
                max: 10,
                enabled: false,
                semanticLabel: 'Disabled value',
                onChanged: (_) {},
              ),
            ),
            if (widget.autoCycle)
              _row(
                'Enabled changes',
                'Value: ${_guests.toInt()} (${_toggledEnabled ? 'enabled' : 'disabled'})',
                CNStepper(
                  value: _guests,
                  min: 1,
                  max: 12,
                  enabled: _toggledEnabled,
                  semanticLabel: 'Guests again',
                  onChanged: (v) => setState(() => _guests = v),
                ),
              ),
            _row(
              'At the minimum',
              'Value: ${_floor.toInt()} (− is dimmed at 0)',
              CNStepper(
                value: _floor,
                max: 10,
                semanticLabel: 'Minimum',
                onChanged: (v) => setState(() => _floor = v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
