import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_plus/cupertino_native.dart';

class SwitchDemoPage extends StatefulWidget {
  const SwitchDemoPage({super.key});

  @override
  State<SwitchDemoPage> createState() => _SwitchDemoPageState();
}

class _SwitchDemoPageState extends State<SwitchDemoPage> {
  bool _basicSwitchValue = true;
  bool _coloredSwitchValue = true;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Switch')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                Text('Basic ${_basicSwitchValue ? 'ON' : 'OFF'}'),
                Spacer(),
                CNSwitch(
                  value: _basicSwitchValue,
                  onChanged: (v) => setState(() => _basicSwitchValue = v),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                Text('Colored ${_coloredSwitchValue ? 'ON' : 'OFF'}'),
                Spacer(),
                CNSwitch(
                  value: _coloredSwitchValue,
                  color: CupertinoColors.systemPink,
                  onChanged: (v) => setState(() => _coloredSwitchValue = v),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                Text('Disabled'),
                Spacer(),
                CNSwitch(value: false, enabled: false, onChanged: (_) {}),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
