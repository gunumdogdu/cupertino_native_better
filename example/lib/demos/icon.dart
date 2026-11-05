import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

class IconDemoPage extends StatefulWidget {
  const IconDemoPage({super.key});

  @override
  State<IconDemoPage> createState() => _IconDemoPageState();
}

class _IconDemoPageState extends State<IconDemoPage> {
  bool _useAlternateSvgIcons = false;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Icon')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Symbol effects (iOS 17+, animate on their own)'),
            const SizedBox(height: 12),
            const SymbolEffectsGallery(),
            const SizedBox(height: 24),
            const Text('Basic'),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                CNIcon(symbol: CNSymbol('heart'), size: 24),
                CNIcon(symbol: CNSymbol('star'), size: 24),
                CNIcon(symbol: CNSymbol('bell'), size: 24),
                CNIcon(symbol: CNSymbol('figure.walk'), size: 24),
                CNIcon(symbol: CNSymbol('paperplane'), size: 24),
              ],
            ),

            const SizedBox(height: 24),

            const Text('Sizes'),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                CNIcon(symbol: CNSymbol('heart'), size: 12),
                CNIcon(symbol: CNSymbol('star'), size: 16),
                CNIcon(symbol: CNSymbol('bell'), size: 24),
                CNIcon(symbol: CNSymbol('figure.walk'), size: 32),
                CNIcon(symbol: CNSymbol('paperplane'), size: 40),
              ],
            ),

            const SizedBox(height: 24),

            const Text('Monochrome colors'),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                CNIcon(
                  symbol: CNSymbol('star.fill'),
                  color: CupertinoColors.systemPink,
                  mode: CNSymbolRenderingMode.monochrome,
                ),
                CNIcon(
                  symbol: CNSymbol('star.fill'),
                  color: CupertinoColors.systemBlue,
                  mode: CNSymbolRenderingMode.monochrome,
                ),
                CNIcon(
                  symbol: CNSymbol('star.fill'),
                  color: CupertinoColors.systemGreen,
                  mode: CNSymbolRenderingMode.monochrome,
                ),
                CNIcon(
                  symbol: CNSymbol('star.fill'),
                  color: CupertinoColors.systemOrange,
                  mode: CNSymbolRenderingMode.monochrome,
                ),
                CNIcon(
                  symbol: CNSymbol('star.fill'),
                  color: CupertinoColors.systemPurple,
                  mode: CNSymbolRenderingMode.monochrome,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Hierarchical'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                CNIcon(
                  symbol: CNSymbol('rectangle.and.pencil.and.ellipsis'),
                  size: 32,
                  color: CupertinoColors.systemBlue,
                  mode: CNSymbolRenderingMode.hierarchical,
                ),
                CNIcon(
                  symbol: CNSymbol('person.3.sequence'),
                  size: 32,
                  color: CupertinoColors.systemBlue,
                  mode: CNSymbolRenderingMode.hierarchical,
                ),
                CNIcon(
                  symbol: CNSymbol('speaker.wave.2.bubble'),
                  size: 32,
                  color: CupertinoColors.systemBlue,
                  mode: CNSymbolRenderingMode.hierarchical,
                ),
                CNIcon(
                  symbol: CNSymbol('ear.badge.waveform'),
                  size: 32,
                  color: CupertinoColors.systemBlue,
                  mode: CNSymbolRenderingMode.hierarchical,
                ),
                CNIcon(
                  symbol: CNSymbol('square.stack.3d.up'),
                  size: 32,
                  color: CupertinoColors.systemBlue,
                  mode: CNSymbolRenderingMode.hierarchical,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Multicolor'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                CNIcon(
                  symbol: CNSymbol('paintpalette.fill'),
                  size: 28,
                  mode: CNSymbolRenderingMode.multicolor,
                ),
                CNIcon(
                  symbol: CNSymbol('sun.rain.fill'),
                  size: 28,
                  mode: CNSymbolRenderingMode.multicolor,
                ),
                CNIcon(
                  symbol: CNSymbol('rainbow'),
                  size: 28,
                  mode: CNSymbolRenderingMode.multicolor,
                ),
                CNIcon(
                  symbol: CNSymbol('pc'),
                  size: 28,
                  mode: CNSymbolRenderingMode.multicolor,
                ),
                CNIcon(
                  symbol: CNSymbol('lightspectrum.horizontal'),
                  size: 28,
                  mode: CNSymbolRenderingMode.multicolor,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SVG Image Assets'),
                CupertinoButton(
                  onPressed: () {
                    setState(() {
                      _useAlternateSvgIcons = !_useAlternateSvgIcons;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: CupertinoColors.systemBlue.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Text(
                      _useAlternateSvgIcons ? 'Reset' : 'Switch',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CNIcon(
                  imageAsset: CNImageAsset(
                    _useAlternateSvgIcons
                        ? 'assets/icons/profile.svg'
                        : 'assets/icons/home.svg',
                  ),
                  size: 24,
                ),
                CNIcon(
                  imageAsset: CNImageAsset(
                    _useAlternateSvgIcons
                        ? 'assets/icons/chat.svg'
                        : 'assets/icons/search.svg',
                  ),
                  size: 32,
                ),
                CNIcon(
                  imageAsset: CNImageAsset(
                    _useAlternateSvgIcons
                        ? 'assets/icons/home.svg'
                        : 'assets/icons/profile.svg',
                  ),
                  size: 40,
                ),
                CNIcon(
                  imageAsset: CNImageAsset(
                    _useAlternateSvgIcons
                        ? 'assets/icons/search.svg'
                        : 'assets/icons/chat.svg',
                  ),
                  size: 48,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Debug: Testing with SF Symbol fallback',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CNIcon(
                  symbol: const CNSymbol('house.fill'),
                  imageAsset: CNImageAsset(
                    _useAlternateSvgIcons
                        ? 'assets/icons/profile.svg'
                        : 'assets/icons/home.svg',
                  ),
                  size: 24,
                ),
                const SizedBox(width: 16),
                CNIcon(
                  symbol: const CNSymbol('magnifyingglass'),
                  imageAsset: CNImageAsset(
                    _useAlternateSvgIcons
                        ? 'assets/icons/chat.svg'
                        : 'assets/icons/search.svg',
                  ),
                  size: 32,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Custom Icons (IconData)'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                CNIcon(
                  symbol: CNSymbol('house.fill'), // Fallback if not provided
                  customIcon: CupertinoIcons.home, // Custom IconData!
                  size: 24,
                ),
                CNIcon(
                  symbol: CNSymbol('house.fill'),
                  customIcon: CupertinoIcons.home,
                  size: 32,
                ),
                CNIcon(
                  symbol: CNSymbol('house.fill'),
                  customIcon: CupertinoIcons.home,
                  size: 40,
                ),
                CNIcon(
                  symbol: CNSymbol('house.fill'),
                  customIcon: CupertinoIcons.home,
                  size: 48,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Every symbol effect, triggered effect and replace transition, driven by a
/// timer so they can be seen without tapping. Used by the icon demo and by
/// `PROBE=symboleffects`.
class SymbolEffectsGallery extends StatefulWidget {
  const SymbolEffectsGallery({super.key});

  @override
  State<SymbolEffectsGallery> createState() => _SymbolEffectsGalleryState();
}

class _SymbolEffectsGalleryState extends State<SymbolEffectsGallery> {
  Timer? _timer;
  int _tick = 0;

  bool get _on => _tick.isEven;

  /// Changes every other tick, leaving each triggered effect time to finish:
  /// one triggered again while it plays is queued behind the running play.
  int get _trigger => _tick ~/ 2;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Caption('Running — effect:'),
        _Grid(
          children: [
            const _Tile(
              'pulse',
              CNIcon(
                symbol: CNSymbol('record.circle'),
                size: 34,
                color: CupertinoColors.systemRed,
                effect: CNSymbolEffect.pulse(),
              ),
            ),
            const _Tile(
              'variableColor',
              CNIcon(
                symbol: CNSymbol('wifi'),
                size: 34,
                color: CupertinoColors.systemBlue,
                effect: CNSymbolEffect.variableColor(),
              ),
            ),
            const _Tile(
              'cumulative\nreversing',
              CNIcon(
                symbol: CNSymbol('speaker.wave.3.fill'),
                size: 34,
                color: CupertinoColors.systemIndigo,
                effect: CNSymbolEffect.variableColor(
                  cumulative: true,
                  reversing: true,
                ),
              ),
            ),
            _Tile(
              'pulse while\ncolour changes',
              CNIcon(
                symbol: const CNSymbol('heart.fill'),
                size: 34,
                color: _on
                    ? CupertinoColors.systemPink
                    : CupertinoColors.systemPurple,
                effect: const CNSymbolEffect.pulse(
                  scope: CNSymbolEffectScope.wholeSymbol,
                ),
              ),
            ),
            _Tile(
              'scale up\n(toggled)',
              CNIcon(
                symbol: const CNSymbol('magnifyingglass'),
                size: 34,
                color: CupertinoColors.systemTeal,
                effect: _on
                    ? const CNSymbolEffect.scale(
                        direction: CNSymbolEffectDirection.up,
                      )
                    : null,
              ),
            ),
            const _Tile(
              'bounce\n(iOS 18)',
              CNIcon(
                symbol: CNSymbol('arrow.down.circle.fill'),
                size: 34,
                color: CupertinoColors.systemGreen,
                effect: CNSymbolEffect.bounce(
                  repeat: CNSymbolEffectRepeat.periodic(
                    delay: Duration(milliseconds: 400),
                  ),
                ),
              ),
            ),
            const _Tile(
              'wiggle\n(iOS 18)',
              CNIcon(
                symbol: CNSymbol('phone.fill'),
                size: 34,
                color: CupertinoColors.systemGreen,
                effect: CNSymbolEffect.wiggle(
                  repeat: CNSymbolEffectRepeat.continuous,
                ),
              ),
            ),
            const _Tile(
              'breathe\n(iOS 18)',
              CNIcon(
                symbol: CNSymbol('heart.fill'),
                size: 34,
                color: CupertinoColors.systemPink,
                effect: CNSymbolEffect.breathe(pulse: true),
              ),
            ),
            const _Tile(
              'rotate\n(iOS 18)',
              CNIcon(
                symbol: CNSymbol('gearshape.fill'),
                size: 34,
                color: CupertinoColors.systemGrey,
                effect: CNSymbolEffect.rotate(
                  scope: CNSymbolEffectScope.wholeSymbol,
                ),
              ),
            ),
            _Tile(
              'drawOff ⇄ drawOn\n(iOS 26)',
              CNIcon(
                symbol: const CNSymbol('signature'),
                size: 34,
                color: CupertinoColors.systemOrange,
                effect: _on
                    ? const CNSymbolEffect.drawOn()
                    : const CNSymbolEffect.drawOff(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _Caption('Triggered every 3.2 s — triggeredEffect:'),
        _Grid(
          children: [
            _Tile(
              'bounce',
              CNIcon(
                symbol: const CNSymbol('bell.fill'),
                size: 34,
                color: CupertinoColors.systemYellow,
                effectTrigger: _trigger,
              ),
            ),
            _Tile(
              'pulse',
              CNIcon(
                symbol: const CNSymbol('message.fill'),
                size: 34,
                color: CupertinoColors.systemGreen,
                triggeredEffect: const CNSymbolEffect.pulse(),
                effectTrigger: _trigger,
              ),
            ),
            _Tile(
              'variableColor',
              CNIcon(
                symbol: const CNSymbol('cellularbars'),
                size: 34,
                color: CupertinoColors.systemBlue,
                triggeredEffect: const CNSymbolEffect.variableColor(),
                effectTrigger: _trigger,
              ),
            ),
            _Tile(
              'wiggle\n(iOS 18)',
              CNIcon(
                symbol: const CNSymbol('bell.badge.fill'),
                size: 34,
                color: CupertinoColors.systemRed,
                triggeredEffect: const CNSymbolEffect.wiggle(),
                effectTrigger: _trigger,
              ),
            ),
            _Tile(
              'rotate\n(iOS 18)',
              CNIcon(
                symbol: const CNSymbol('arrow.clockwise'),
                size: 34,
                color: CupertinoColors.systemPurple,
                triggeredEffect: const CNSymbolEffect.rotate(),
                effectTrigger: _trigger,
              ),
            ),
            _Tile(
              'drawOn\n(iOS 26)',
              CNIcon(
                symbol: const CNSymbol('checkmark.circle'),
                size: 34,
                color: CupertinoColors.systemGreen,
                triggeredEffect: const CNSymbolEffect.drawOn(),
                effectTrigger: _trigger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _Caption('Symbol change — replaceTransition:'),
        _Grid(
          children: [
            _Tile(
              'magic\n(iOS 18)',
              CNIcon(
                symbol: CNSymbol(_on ? 'bell.fill' : 'bell.slash.fill'),
                size: 34,
                color: CupertinoColors.systemOrange,
                replaceTransition: CNSymbolReplaceTransition.magic,
              ),
            ),
            _Tile(
              'replace',
              CNIcon(
                symbol: CNSymbol(_on ? 'play.fill' : 'pause.fill'),
                size: 34,
                color: CupertinoColors.systemBlue,
                replaceTransition: CNSymbolReplaceTransition.replace,
              ),
            ),
            _Tile(
              'downUp',
              CNIcon(
                symbol: CNSymbol(_on ? 'sun.max.fill' : 'moon.fill'),
                size: 34,
                color: CupertinoColors.systemIndigo,
                replaceTransition: CNSymbolReplaceTransition.downUp,
              ),
            ),
            _Tile(
              'replace while\nvariableColor',
              CNIcon(
                symbol: CNSymbol(_on ? 'wifi' : 'cellularbars'),
                size: 34,
                color: CupertinoColors.systemTeal,
                effect: const CNSymbolEffect.variableColor(),
                replaceTransition: CNSymbolReplaceTransition.replace,
              ),
            ),
            _Tile(
              'none\n(default)',
              CNIcon(
                symbol: CNSymbol(_on ? 'sun.max.fill' : 'moon.fill'),
                size: 34,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 12, children: children);
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.icon);

  final String label;
  final Widget icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 80,
    child: Column(
      children: [
        SizedBox(height: 44, child: Center(child: icon)),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
}
