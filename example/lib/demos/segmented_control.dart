import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_plus/cupertino_native.dart';

class SegmentedControlDemoPage extends StatefulWidget {
  const SegmentedControlDemoPage({super.key});

  @override
  State<SegmentedControlDemoPage> createState() =>
      _SegmentedControlDemoPageState();
}

class _SegmentedControlDemoPageState extends State<SegmentedControlDemoPage> {
  int _basicSegmentedControlIndex = 0;
  int _coloredSegmentedControlIndex = 1;
  int _shrinkWrappedSegmentedControlIndex = 0;
  int _iconSegmentedControlIndex = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Segmented Control'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          children: [
            Row(
              children: [
                Text('Basic'),
                Spacer(),
                Text('Selected: ${_basicSegmentedControlIndex + 1}'),
              ],
            ),
            const SizedBox(height: 12),
            CNSegmentedControl(
              labels: const ['One', 'Two', 'Three'],
              selectedIndex: _basicSegmentedControlIndex,
              onValueChanged: (i) =>
                  setState(() => _basicSegmentedControlIndex = i),
            ),

            const SizedBox(height: 48),

            Row(
              children: [
                Text('Colored'),
                Spacer(),
                Text('Selected: ${_shrinkWrappedSegmentedControlIndex + 1}'),
              ],
            ),
            const SizedBox(height: 12),
            CNSegmentedControl(
              labels: const ['One', 'Two', 'Three'],
              selectedIndex: _shrinkWrappedSegmentedControlIndex,
              color: CupertinoColors.systemPink,
              onValueChanged: (i) =>
                  setState(() => _shrinkWrappedSegmentedControlIndex = i),
            ),

            const SizedBox(height: 48),

            Row(
              children: [
                Text('Shrink wrap'),
                Spacer(),
                Text('Selected: ${_coloredSegmentedControlIndex + 1}'),
              ],
            ),
            const SizedBox(height: 12),
            CNSegmentedControl(
              labels: const ['One', 'Two', 'Three'],
              selectedIndex: _coloredSegmentedControlIndex,
              onValueChanged: (i) =>
                  setState(() => _coloredSegmentedControlIndex = i),
              shrinkWrap: true,
            ),

            const SizedBox(height: 48),

            Row(
              children: [
                Text('Icons'),
                Spacer(),
                Text('Selected: ${_iconSegmentedControlIndex + 1}'),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: CNSegmentedControl(
                labels: const [],
                sfSymbols: const [
                  CNSymbol('list.clipboard'),
                  CNSymbol('leaf.arrow.trianglehead.clockwise'),
                  CNSymbol('figure.walk.diamond'),
                ],
                selectedIndex: _iconSegmentedControlIndex,
                iconColor: CupertinoColors.systemBlue,
                iconRenderingMode: CNSymbolRenderingMode.hierarchical,
                shrinkWrap: true,
                onValueChanged: (i) =>
                    setState(() => _iconSegmentedControlIndex = i),
                height: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
