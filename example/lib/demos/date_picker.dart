import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// CNDatePicker in every style and mode, with limits, a disabled picker and
/// a UTC value.
class DatePickerDemoPage extends StatefulWidget {
  const DatePickerDemoPage({super.key, this.section, this.autoCycle = false});

  /// Shows only one section, for screenshots: `compact`, `inline`,
  /// `inlineTime`, `wheels` or `limits`. Null shows them all.
  final String? section;

  /// Moves the shared value to a new month every few seconds, so the inline
  /// calendar's height change and outside value changes can be seen without
  /// tapping.
  final bool autoCycle;

  @override
  State<DatePickerDemoPage> createState() => _DatePickerDemoPageState();
}

class _DatePickerDemoPageState extends State<DatePickerDemoPage> {
  // February 2026 starts on a Sunday and fills four week rows, August 2026
  // six and November 2026 five, so cycling through them resizes the calendar.
  static final List<DateTime> _cycle = [
    DateTime(2026, 11, 3, 9, 41),
    DateTime(2026, 2, 14, 18, 30),
    DateTime(2026, 8, 31, 7, 15),
  ];

  DateTime _value = _cycle.first;
  DateTime _monthYear = DateTime(2026, 11);
  DateTime _quarterHour = DateTime(2026, 11, 3, 9, 45);
  DateTime _utc = DateTime.utc(2026, 11, 3);
  late DateTime _limited = _today.add(const Duration(hours: 12));
  Timer? _timer;
  int _step = 0;

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        setState(() => _value = _cycle[++_step % _cycle.length]);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _show(String section) =>
      widget.section == null || widget.section == section;

  String _two(int n) => n.toString().padLeft(2, '0');

  String _format(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)} '
      '${_two(d.hour)}:${_two(d.minute)}${d.isUtc ? 'Z' : ''}';

  void _set(DateTime v) => setState(() => _value = v);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Date Picker')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _Readout(text: 'Value: ${_format(_value)}'),
            if (_show('compact')) ...[
              const _Header('Compact'),
              _Row(
                label: 'Date',
                child: CNDatePicker(
                  value: _value,
                  semanticLabel: 'Date',
                  onChanged: _set,
                ),
              ),
              _Row(
                label: 'Time',
                child: CNDatePicker(
                  value: _value,
                  mode: CNDatePickerMode.time,
                  semanticLabel: 'Time',
                  onChanged: _set,
                ),
              ),
              _Row(
                label: 'Date and time',
                child: CNDatePicker(
                  value: _value,
                  mode: CNDatePickerMode.dateAndTime,
                  style: CNDatePickerStyle.compact,
                  semanticLabel: 'Date and time',
                  onChanged: _set,
                ),
              ),
              _Row(
                label: 'Pink tint',
                child: CNDatePicker(
                  value: _value,
                  tint: CupertinoColors.systemPink,
                  semanticLabel: 'Pink date',
                  onChanged: _set,
                ),
              ),
            ],
            if (_show('inline')) ...[
              const _Header('Inline'),
              CNDatePicker(
                value: _value,
                style: CNDatePickerStyle.inline,
                semanticLabel: 'Inline date',
                onChanged: _set,
              ),
            ],
            if (_show('inline') || _show('inlineTime')) ...[
              const _Header('Inline, date and time'),
              CNDatePicker(
                value: _value,
                mode: CNDatePickerMode.dateAndTime,
                style: CNDatePickerStyle.inline,
                tint: CupertinoColors.systemOrange,
                semanticLabel: 'Inline date and time',
                onChanged: _set,
              ),
            ],
            if (_show('wheels')) ...[
              const _Header('Wheels'),
              CNDatePicker(
                value: _value,
                mode: CNDatePickerMode.dateAndTime,
                style: CNDatePickerStyle.wheels,
                semanticLabel: 'Date and time wheels',
                onChanged: _set,
              ),
              const _Header('Time, every 15 minutes'),
              _Readout(text: 'Value: ${_format(_quarterHour)}'),
              CNDatePicker(
                value: _quarterHour,
                mode: CNDatePickerMode.time,
                style: CNDatePickerStyle.wheels,
                minuteInterval: 15,
                semanticLabel: 'Quarter hour',
                onChanged: (v) => setState(() => _quarterHour = v),
              ),
              const _Header('Month and year'),
              _Readout(text: 'Value: ${_format(_monthYear)}'),
              CNDatePicker(
                value: _monthYear,
                mode: CNDatePickerMode.yearAndMonth,
                semanticLabel: 'Month',
                onChanged: (v) => setState(() => _monthYear = v),
              ),
            ],
            if (_show('limits')) ...[
              const _Header('Today to a week from now'),
              _Readout(text: 'Value: ${_format(_limited)}'),
              _Row(
                label: 'Limited',
                child: CNDatePicker(
                  value: _limited,
                  mode: CNDatePickerMode.dateAndTime,
                  minimumDate: _today,
                  maximumDate: _today.add(const Duration(days: 7)),
                  semanticLabel: 'Limited',
                  onChanged: (v) => setState(() => _limited = v),
                ),
              ),
              CNDatePicker(
                value: _limited,
                mode: CNDatePickerMode.date,
                style: CNDatePickerStyle.wheels,
                minimumDate: _today,
                maximumDate: _today.add(const Duration(days: 7)),
                semanticLabel: 'Limited wheels',
                onChanged: (v) => setState(() => _limited = v),
              ),
              const _Header('UTC value'),
              _Readout(text: 'Value: ${_format(_utc)}'),
              _Row(
                label: 'UTC',
                child: CNDatePicker(
                  value: _utc,
                  mode: CNDatePickerMode.dateAndTime,
                  semanticLabel: 'UTC',
                  onChanged: (v) => setState(() => _utc = v),
                ),
              ),
              const _Header('Disabled'),
              _Row(
                label: 'Disabled',
                child: CNDatePicker(
                  value: _value,
                  enabled: false,
                  semanticLabel: 'Disabled',
                  onChanged: (_) {},
                ),
              ),
              CNDatePicker(
                value: _value,
                style: CNDatePickerStyle.wheels,
                enabled: false,
                semanticLabel: 'Disabled wheels',
                onChanged: (_) {},
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: CupertinoColors.label.resolveFrom(context),
        ),
      ),
    );
  }
}

/// A label on the leading side and the picker on the trailing side, as in a
/// Settings row. The picker sits in a Row, so its width must be its own.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const Spacer(),
          child,
        ],
      ),
    );
  }
}
