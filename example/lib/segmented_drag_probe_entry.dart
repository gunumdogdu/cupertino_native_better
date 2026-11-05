// #120 check: a CNSegmentedControl inside a scrolling list. Press a segment
// and slide to another (the selection should follow, as in UIKit); a
// vertical drag that starts on the control should still scroll the list.
//   flutter run -t lib/segmented_drag_probe_entry.dart
//   flutter run -d macos -t lib/segmented_drag_probe_entry.dart --dart-define=CLICK=true
//     (macOS: clicks Year, then Week, through the debug cnb_mac_audit channel)
// Logs lines starting with SEGDRAG.
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

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
  final _segmentsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      debugPrint('SEGDRAG scroll ${_scroll.offset.toStringAsFixed(0)}');
    });
    if (const bool.fromEnvironment('CLICK')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoClick());
    }
  }

  /// Clicks a segment (as a fraction of the control's width) through the
  /// example's debug-only macOS audit channel, like a real mouse click.
  Future<void> _click(double fraction) async {
    final box = _segmentsKey.currentContext!.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    await const MethodChannel('cnb_mac_audit').invokeMethod('click', {
      'x': rect.left + rect.width * fraction,
      'y': rect.center.dy,
    });
  }

  Future<void> _autoClick() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    debugPrint('SEGDRAG click Year');
    await _click(7 / 8);
    await Future<void>.delayed(const Duration(seconds: 2));
    debugPrint('SEGDRAG click Week');
    await _click(3 / 8);
    await Future<void>.delayed(const Duration(seconds: 2));
    debugPrint('SEGDRAG done index $_index');
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(middle: Text('Segment $_index')),
    child: ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
      children: [
        CNSegmentedControl(
          key: _segmentsKey,
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
