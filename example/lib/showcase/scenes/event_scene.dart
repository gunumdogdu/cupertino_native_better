import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

import '../ios_kit.dart';

/// A New Event form, as in Calendar: compact date pickers, a stepper, a
/// colour well and pop-up menus, all native.
class EventScene extends StatefulWidget {
  const EventScene({super.key});

  @override
  State<EventScene> createState() => _EventSceneState();
}

class _EventSceneState extends State<EventScene> {
  bool _allDay = false;
  DateTime _start = DateTime(2026, 11, 12, 10, 0);
  DateTime _end = DateTime(2026, 11, 12, 11, 0);
  int _repeat = 0;
  int _alert = 2;
  Color _color = CupertinoColors.systemOrange;
  double _guests = 3;

  static const _repeats = ['Never', 'Every Day', 'Every Week', 'Every Month'];
  static const _alerts = [
    'None',
    'At time of event',
    '15 minutes before',
    '1 hour before',
  ];

  CNDatePickerMode get _mode =>
      _allDay ? CNDatePickerMode.date : CNDatePickerMode.dateAndTime;

  Widget _menu(
    List<String> labels,
    int selected,
    ValueChanged<int> onSelected,
  ) {
    return CNPopupMenuButton(
      buttonLabel: labels[selected],
      buttonStyle: CNButtonStyle.plain,
      items: [
        for (var i = 0; i < labels.length; i++)
          CNPopupMenuItem(label: labels[i], checked: i == selected),
      ],
      onSelected: (i) => setState(() => onSelected(i)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return IOSPage(
      title: 'New Event',
      leading: const GlassCircleButton(symbol: 'xmark', label: 'Cancel'),
      trailing: SizedBox(
        width: 44,
        height: 44,
        child: CNButton.icon(
          icon: const CNSymbol('checkmark', size: 17),
          tint: CupertinoColors.systemRed,
          semanticLabel: 'Add',
          config: const CNButtonConfig(style: CNButtonStyle.prominentGlass),
          onPressed: () {},
        ),
      ),
      children: [
        const IOSSection(
          rows: [
            IOSRow(title: 'Design Review'),
            IOSRow(title: 'Studio 4, Infinite Loop'),
          ],
        ),
        IOSSection(
          rows: [
            IOSRow(
              title: 'All-day',
              trailing: CNSwitch(
                value: _allDay,
                semanticLabel: 'All-day',
                onChanged: (v) => setState(() => _allDay = v),
              ),
            ),
            IOSRow(
              title: 'Starts',
              trailing: CNDatePicker(
                value: _start,
                mode: _mode,
                style: CNDatePickerStyle.compact,
                tint: CupertinoColors.systemRed,
                semanticLabel: 'Starts',
                onChanged: (v) => setState(() {
                  _end = _end.add(v.difference(_start));
                  _start = v;
                }),
              ),
            ),
            IOSRow(
              title: 'Ends',
              trailing: CNDatePicker(
                value: _end,
                mode: _mode,
                style: CNDatePickerStyle.compact,
                tint: CupertinoColors.systemRed,
                minimumDate: _start,
                semanticLabel: 'Ends',
                onChanged: (v) => setState(() => _end = v),
              ),
            ),
            IOSRow(
              title: 'Repeat',
              trailing: _menu(_repeats, _repeat, (i) => _repeat = i),
            ),
          ],
        ),
        IOSSection(
          rows: [
            IOSRow(
              title: 'Calendar',
              value: 'Work',
              trailing: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: CNColorWell(
                  color: _color,
                  size: 28,
                  title: 'Calendar Color',
                  supportsAlpha: false,
                  semanticLabel: 'Calendar color',
                  onChanged: (c) => setState(() => _color = c),
                ),
              ),
            ),
            IOSRow(
              title: 'Invitees',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_guests.round()} people',
                    style: IOS.body.copyWith(color: secondary),
                  ),
                  const SizedBox(width: 10),
                  CNStepper(
                    value: _guests,
                    min: 1,
                    max: 20,
                    semanticLabel: 'Invitees',
                    onChanged: (v) => setState(() => _guests = v),
                  ),
                ],
              ),
            ),
            IOSRow(
              title: 'Alert',
              trailing: _menu(_alerts, _alert, (i) => _alert = i),
            ),
          ],
        ),
        IOSSection(
          footer: 'Invitees get the event as soon as you add it.',
          rows: [
            IOSRow(
              title: 'Notes',
              subtitle: 'Bring the new prototypes',
              leading: Container(
                width: 6,
                height: 36,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
