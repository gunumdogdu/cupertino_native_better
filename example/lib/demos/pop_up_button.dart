import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// CNPopUpButton: value pickers with icons, sections, a disabled item and a
/// placeholder, every button style and height, a disabled button, a parent
/// that refuses a choice, and buttons in a long list to check that a touch
/// that starts on one still scrolls.
///
/// Each choice prints `CNB_RESULT popup <name> <value>`, for scripts.
class PopUpButtonDemoPage extends StatefulWidget {
  const PopUpButtonDemoPage({
    super.key,
    this.autoCycle = false,
    this.initialScrollOffset = 0,
  });

  /// Changes every picker's value on a timer, so the title and width
  /// changes can be watched (and screenshot) without a tap.
  final bool autoCycle;

  /// Where the list starts, for screenshots of its lower sections.
  final double initialScrollOffset;

  @override
  State<PopUpButtonDemoPage> createState() => _PopUpButtonDemoPageState();
}

enum _Size { small, medium, large, extraLarge }

class _PopUpButtonDemoPageState extends State<PopUpButtonDemoPage> {
  _Size _size = _Size.medium;
  String _color = 'blue';
  String _sort = 'name';
  String? _city;
  String _plan = 'free';
  int _styled = 1;
  final List<int> _listValues = List<int>.filled(12, 0);
  Timer? _timer;
  int _tick = 0;
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: widget.initialScrollOffset,
  );

  static const _colors = <(String, String, Color)>[
    ('red', 'Red', CupertinoColors.systemRed),
    ('orange', 'Orange', CupertinoColors.systemOrange),
    ('yellow', 'Yellow', CupertinoColors.systemYellow),
    ('green', 'Green', CupertinoColors.systemGreen),
    ('blue', 'Blue', CupertinoColors.systemBlue),
    ('purple', 'Purple', CupertinoColors.systemPurple),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      _timer = Timer.periodic(const Duration(seconds: 2), (_) {
        setState(() {
          _tick++;
          _size = _Size.values[_tick % _Size.values.length];
          _color = _colors[(_tick * 2) % _colors.length].$1;
          _sort = const ['name', 'date', 'size', 'kind'][_tick % 4];
          _city = _tick.isEven ? null : 'Lisbon';
          _styled = _tick % 3;
        });
        debugPrint('CNB_SHOT cycle$_tick');
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _report(String name, Object? value) =>
      debugPrint('CNB_RESULT popup $name $value');

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

  Widget _row(String label, Widget control) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(width: 112, child: Text(label)),
        Flexible(child: control),
      ],
    ),
  );

  static const _sizeItems = <CNPopUpButtonEntry<_Size>>[
    CNPopUpButtonItem(value: _Size.small, label: 'Small'),
    CNPopUpButtonItem(value: _Size.medium, label: 'Medium'),
    CNPopUpButtonItem(value: _Size.large, label: 'Large'),
    CNPopUpButtonItem(value: _Size.extraLarge, label: 'Extra Large'),
  ];

  List<CNPopUpButtonEntry<String>> get _colorItems => [
    CNPopUpButtonSection(
      title: 'Warm',
      items: [
        for (final (value, label, color) in _colors.take(3))
          CNPopUpButtonItem(
            value: value,
            label: label,
            icon: CNSymbol('circle.fill', color: color, size: 14),
          ),
      ],
    ),
    CNPopUpButtonSection(
      title: 'Cool',
      items: [
        for (final (value, label, color) in _colors.skip(3))
          CNPopUpButtonItem(
            value: value,
            label: label,
            icon: CNSymbol('circle.fill', color: color, size: 14),
          ),
      ],
    ),
    const CNPopUpButtonDivider(),
    const CNPopUpButtonItem(
      value: 'gray',
      label: 'Gray (unavailable)',
      icon: CNSymbol('circle.dashed'),
      enabled: false,
    ),
  ];

  static const _sortItems = <CNPopUpButtonEntry<String>>[
    CNPopUpButtonItem(
      value: 'name',
      label: 'Name',
      icon: CNSymbol('textformat'),
    ),
    CNPopUpButtonItem(
      value: 'date',
      label: 'Date Modified',
      icon: CNSymbol('calendar'),
    ),
    CNPopUpButtonItem(
      value: 'size',
      label: 'Size',
      icon: CNSymbol('internaldrive'),
    ),
    CNPopUpButtonDivider(),
    CNPopUpButtonItem(
      value: 'kind',
      label: 'Kind',
      imageAsset: CNImageAsset('assets/icons/home.svg', size: 16),
    ),
    CNPopUpButtonItem(
      value: 'tags',
      label: 'Tags',
      imageAsset: CNImageAsset('assets/icons/coins.png', size: 16),
    ),
  ];

  static const _cityItems = <CNPopUpButtonEntry<String?>>[
    CNPopUpButtonItem(value: null, label: 'Choose a city…'),
    CNPopUpButtonDivider(),
    CNPopUpButtonItem(value: 'Lisbon', label: 'Lisbon'),
    CNPopUpButtonItem(value: 'Oslo', label: 'Oslo'),
    CNPopUpButtonItem(value: 'Tokyo', label: 'Tokyo'),
  ];

  static const _planItems = <CNPopUpButtonEntry<String>>[
    CNPopUpButtonItem(value: 'free', label: 'Free'),
    CNPopUpButtonItem(value: 'pro', label: 'Pro'),
    CNPopUpButtonItem(value: 'team', label: 'Team (refused)'),
  ];

  static const _numberItems = <CNPopUpButtonEntry<int>>[
    CNPopUpButtonItem(value: 0, label: 'Zero'),
    CNPopUpButtonItem(value: 1, label: 'One'),
    CNPopUpButtonItem(value: 2, label: 'Two'),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Pop-Up Button'),
      ),
      child: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            _caption('Pickers (the button shows the choice)'),
            _row(
              'Size',
              CNPopUpButton<_Size>(
                value: _size,
                items: _sizeItems,
                semanticLabel: 'Size',
                onChanged: (v) {
                  _report('size', v.name);
                  setState(() => _size = v);
                },
              ),
            ),
            _row(
              'Colour',
              CNPopUpButton<String>(
                value: _color,
                items: _colorItems,
                semanticLabel: 'Colour',
                onChanged: (v) {
                  _report('colour', v);
                  setState(() => _color = v);
                },
              ),
            ),
            _row(
              'Sort by',
              CNPopUpButton<String>(
                value: _sort,
                items: _sortItems,
                semanticLabel: 'Sort by',
                onChanged: (v) {
                  _report('sort', v);
                  setState(() => _sort = v);
                },
              ),
            ),
            _row(
              'City',
              CNPopUpButton<String?>(
                value: _city,
                items: _cityItems,
                semanticLabel: 'City',
                onChanged: (v) {
                  _report('city', v);
                  setState(() => _city = v);
                },
              ),
            ),
            _row(
              'Plan',
              CNPopUpButton<String>(
                value: _plan,
                items: _planItems,
                semanticLabel: 'Plan',
                onChanged: (v) {
                  _report('plan', v);
                  // The parent keeps "free" for "team": the button goes back.
                  if (v != 'team') setState(() => _plan = v);
                },
              ),
            ),
            _row(
              'Disabled',
              CNPopUpButton<_Size>(
                value: _Size.large,
                items: _sizeItems,
                enabled: false,
                semanticLabel: 'Disabled size',
                onChanged: (_) {},
              ),
            ),
            Text(
              'Size ${_size.name} · colour $_color · sort $_sort · '
              'city ${_city ?? 'none'} · plan $_plan',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            _caption('Styles (null is the platform pop-up)'),
            for (final style in <CNButtonStyle?>[
              null,
              CNButtonStyle.plain,
              CNButtonStyle.gray,
              CNButtonStyle.tinted,
              CNButtonStyle.bordered,
              CNButtonStyle.filled,
              CNButtonStyle.glass,
              CNButtonStyle.prominentGlass,
            ])
              _row(
                style?.name ?? 'default',
                CNPopUpButton<int>(
                  value: _styled,
                  items: _numberItems,
                  buttonStyle: style,
                  semanticLabel: 'Style ${style?.name ?? 'default'}',
                  onChanged: (v) {
                    _report('style', v);
                    setState(() => _styled = v);
                  },
                ),
              ),
            _row(
              'pink tint',
              CNPopUpButton<int>(
                value: _styled,
                items: _numberItems,
                buttonStyle: CNButtonStyle.prominentGlass,
                tint: CupertinoColors.systemPink,
                onChanged: (v) => setState(() => _styled = v),
              ),
            ),
            _caption('Heights 20, 24, 32, 44 (macOS controlSize follows)'),
            for (final height in const [20.0, 24.0, 32.0, 44.0])
              _row(
                '${height.toInt()} pt',
                CNPopUpButton<_Size>(
                  value: _size,
                  items: _sizeItems,
                  height: height,
                  onChanged: (v) => setState(() => _size = v),
                ),
              ),
            for (final height in const [24.0, 44.0])
              _row(
                'glass ${height.toInt()}',
                CNPopUpButton<_Size>(
                  value: _size,
                  items: _sizeItems,
                  height: height,
                  buttonStyle: CNButtonStyle.glass,
                  onChanged: (v) => setState(() => _size = v),
                ),
              ),
            _caption('Full width (a parent that forces the width)'),
            SizedBox(
              width: double.infinity,
              child: CNPopUpButton<String>(
                value: _sort,
                items: _sortItems,
                buttonStyle: CNButtonStyle.bordered,
                onChanged: (v) => setState(() => _sort = v),
              ),
            ),
            _caption(
              'In a list: start a scroll on a button, it still scrolls; '
              'tap one, its menu opens',
            ),
            for (var i = 0; i < _listValues.length; i++)
              _row(
                'Row ${i + 1}',
                CNPopUpButton<int>(
                  value: _listValues[i],
                  items: _numberItems,
                  onChanged: (v) {
                    _report('row$i', v);
                    setState(() => _listValues[i] = v);
                  },
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
