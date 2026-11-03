import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// A photo editor: clear glass buttons over the photo, as Apple uses over
/// media, and an exposure slider with tick marks that fills from zero.
///
/// The slider sweeps by itself until the user drags it.
class EditorScene extends StatefulWidget {
  const EditorScene({super.key});

  @override
  State<EditorScene> createState() => _EditorSceneState();
}

class _EditorSceneState extends State<EditorScene> {
  static const _tools = [
    ('wand.and.stars', 'Auto'),
    ('crop.rotate', 'Crop'),
    ('slider.horizontal.3', 'Adjust'),
    ('camera.filters', 'Filters'),
  ];
  static const _sweep = [0.0, 20.0, 40.0, 60.0, 40.0, 0.0, -20.0, -40.0, -20.0];

  double _exposure = 0;
  int _tool = 2;
  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      setState(() {
        _step = (_step + 1) % _sweep.length;
        _exposure = _sweep[_step];
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    const white = CupertinoColors.white;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/showcase/violet.jpg', fit: BoxFit.cover),
        Positioned(
          top: insets.top + 6,
          left: 16,
          right: 16,
          child: Row(
            children: [
              SizedBox(
                height: 44,
                child: CNButton(
                  label: 'Cancel',
                  config: const CNButtonConfig(
                    style: CNButtonStyle.clearGlass,
                    minHeight: 44,
                  ),
                  onPressed: () {},
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 44,
                child: CNButton(
                  label: 'Done',
                  tint: CupertinoColors.systemYellow,
                  config: const CNButtonConfig(
                    style: CNButtonStyle.prominentClearGlass,
                    minHeight: 44,
                  ),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: insets.bottom + 16,
          child: Column(
            children: [
              Text(
                'EXPOSURE  ${_exposure.round()}',
                style: const TextStyle(
                  color: white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              CNSlider(
                value: _exposure,
                min: -100,
                max: 100,
                numberOfTicks: 21,
                allowsTickValuesOnly: false,
                neutralValue: 0,
                color: CupertinoColors.systemYellow,
                semanticLabel: 'Exposure',
                onChanged: (v) {
                  _timer?.cancel();
                  setState(() => _exposure = v);
                },
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < _tools.length; i++)
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CNButton.icon(
                        icon: CNSymbol(_tools[i].$1, size: 20),
                        tint: i == _tool ? CupertinoColors.systemYellow : null,
                        semanticLabel: _tools[i].$2,
                        config: CNButtonConfig(
                          style: i == _tool
                              ? CNButtonStyle.prominentClearGlass
                              : CNButtonStyle.clearGlass,
                        ),
                        onPressed: () => setState(() => _tool = i),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
