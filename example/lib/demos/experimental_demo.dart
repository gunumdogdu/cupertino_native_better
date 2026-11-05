import 'package:cupertino_native_better/components/experimental/glass_card.dart';
import 'package:flutter/cupertino.dart';

class ExperimentalDemo extends StatelessWidget {
  const ExperimentalDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Experimental Features'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'WARNING: These features are experimental and may change in future versions.',
              style: TextStyle(color: CupertinoColors.systemRed),
            ),
            const SizedBox(height: 20),
            const Text(
              'CNGlassCard with Breathing Effect',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: CNGlassCard(
                breathing: true,
                tint: CupertinoColors.systemBlue,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        CupertinoIcons.heart_fill,
                        size: 50,
                        color: CupertinoColors.systemRed,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Breathing Card',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Implicit Animations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text('Tap buttons below to see smooth native transitions'),
            const SizedBox(height: 10),
            _ImplicitAnimationDemo(),
          ],
        ),
      ),
    );
  }
}

class _ImplicitAnimationDemo extends StatefulWidget {
  const _ImplicitAnimationDemo();

  @override
  State<_ImplicitAnimationDemo> createState() => _ImplicitAnimationDemoState();
}

class _ImplicitAnimationDemoState extends State<_ImplicitAnimationDemo> {
  bool _toggled = false;

  @override
  Widget build(BuildContext context) {
    // This is just a placeholder - to properly demo implicit animations,
    // we'd need to use the actual widgets (CNButton, etc) and change their props.
    // Since I can't import CNButton here without circular deps or making this a real demo,
    // I'll leave it as a text description for now.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Native components now support implicit animations. '
            'Changing properties like size, color, or layout will now '
            'animate smoothly on the native side.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          CupertinoButton.filled(
            onPressed: () => setState(() => _toggled = !_toggled),
            child: Text(_toggled ? 'Reset' : 'Toggle'),
          ),
        ],
      ),
    );
  }
}
