import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// CNProgressIndicator: determinate and indeterminate bars and spinners in
/// every size, tinted ones, and a bar the page fills on a timer so the
/// native value animation can be watched.
class ProgressIndicatorDemoPage extends StatefulWidget {
  const ProgressIndicatorDemoPage({super.key});

  @override
  State<ProgressIndicatorDemoPage> createState() =>
      _ProgressIndicatorDemoPageState();
}

class _ProgressIndicatorDemoPageState extends State<ProgressIndicatorDemoPage> {
  double _progress = 0.1;
  bool _running = true;
  bool _known = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!_running) return;
      setState(() => _progress = _progress >= 1 ? 0 : _progress + 0.15);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );

  Widget _labelled(String label, Widget indicator) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(height: 40, child: Center(child: indicator)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final percent = (_progress.clamp(0.0, 1.0) * 100).round();
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Progress Indicator'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          children: [
            _caption('Bar, $percent% (fills on a timer, animates natively)'),
            CNProgressIndicator(
              value: _known ? _progress : null,
              semanticLabel: 'Download',
            ),
            const SizedBox(height: 12),
            CNProgressIndicator(
              value: _known ? _progress : null,
              tint: CupertinoColors.systemPink,
              semanticLabel: 'Upload',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: () => setState(() => _running = !_running),
                  child: Text(_running ? 'Pause' : 'Resume'),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: () => setState(() => _known = !_known),
                  child: Text(_known ? 'Indeterminate' : 'Determinate'),
                ),
              ],
            ),
            _caption('Bar without a known value'),
            const CNProgressIndicator(semanticLabel: 'Preparing'),
            _caption('Bar sizes: mini, small, regular, large'),
            for (final size in [
              CNControlSize.mini,
              CNControlSize.small,
              CNControlSize.regular,
              CNControlSize.large,
            ]) ...[
              CNProgressIndicator(value: 0.6, size: size),
              const SizedBox(height: 6),
            ],
            _caption('Spinners: mini, small, regular, large'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final size in [
                  CNControlSize.mini,
                  CNControlSize.small,
                  CNControlSize.regular,
                  CNControlSize.large,
                ])
                  _labelled(
                    size.name,
                    CNProgressIndicator(
                      style: CNProgressStyle.spinner,
                      size: size,
                      semanticLabel: 'Loading',
                    ),
                  ),
              ],
            ),
            _caption('Spinners with a value (a filling circle on macOS)'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _labelled(
                  '$percent%',
                  CNProgressIndicator(
                    style: CNProgressStyle.spinner,
                    value: _progress,
                    size: CNControlSize.small,
                  ),
                ),
                _labelled(
                  'tinted',
                  CNProgressIndicator(
                    style: CNProgressStyle.spinner,
                    value: _progress,
                    tint: CupertinoColors.systemGreen,
                  ),
                ),
                _labelled(
                  'tinted, no value',
                  const CNProgressIndicator(
                    style: CNProgressStyle.spinner,
                    tint: CupertinoColors.systemOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
