// Probe pages for the 2.0.0 additions, shown without tapping:
// `PROBE=symboleffects`.
import 'package:flutter/cupertino.dart';

import 'icon.dart';

/// `PROBE=symboleffects`: every CNIcon symbol effect, triggered effect and
/// replace transition, playing on timers.
class SymbolEffectsProbePage extends StatelessWidget {
  const SymbolEffectsProbePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Symbol effects'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [SymbolEffectsGallery()],
        ),
      ),
    );
  }
}
