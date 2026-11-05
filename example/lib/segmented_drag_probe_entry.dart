// #120 check: a CNSegmentedControl inside a scrolling list. Press a segment
// and slide to another (the selection should follow, as in UIKit); a
// vertical drag that starts on the control should still scroll the list.
//   flutter run -t lib/segmented_drag_probe_entry.dart
// Logs lines starting with SEGDRAG.
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

void main() => runApp(const CupertinoApp(home: _Page()));

class _Page extends StatefulWidget {
  const _Page();

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  int _index = 0;
  double _slider = 0.5;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      debugPrint('SEGDRAG scroll ${_scroll.offset.toStringAsFixed(0)}');
    });
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(middle: Text('Segment $_index')),
    child: ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
      children: [
        CNSegmentedControl(
          labels: const ['Day', 'Week', 'Month', 'Year'],
          selectedIndex: _index,
          onValueChanged: (i) {
            debugPrint('SEGDRAG value $i');
            setState(() => _index = i);
          },
        ),
        const SizedBox(height: 24),
        CNSlider(
          value: _slider,
          onChanged: (v) {
            debugPrint('SEGDRAG slider ${v.toStringAsFixed(2)}');
            setState(() => _slider = v);
          },
        ),
        for (var i = 0; i < 30; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text('Row $i'),
          ),
      ],
    ),
  );
}
