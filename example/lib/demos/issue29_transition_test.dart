import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Issue #29 Test - Exact repro from the issue
class Issue29TransitionTestPage extends StatefulWidget {
  final bool isSecondPage;

  const Issue29TransitionTestPage({
    this.isSecondPage = false,
    super.key,
  });

  static Route<void> route({bool isSecondPage = false}) {
    return _SlowCupertinoPageRoute(
      builder: (_) => Issue29TransitionTestPage(isSecondPage: isSecondPage),
    );
  }

  @override
  State<Issue29TransitionTestPage> createState() =>
      _Issue29TransitionTestPageState();
}

class _Issue29TransitionTestPageState extends State<Issue29TransitionTestPage> {
  void _openNextPage() {
    Navigator.of(context).push(
      Issue29TransitionTestPage.route(
          isSecondPage: !widget.isSecondPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (widget.isSecondPage)
                    CNButton.icon(
                      icon: const CNSymbol('xmark', size: 16),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isSecondPage ? 'Repro page B' : 'Repro page A',
                      style: TextStyle(fontSize: 18, color: textColor),
                    ),
                  ),
                  CNButton.icon(
                    icon: const CNSymbol('gearshape.fill', size: 16),
                    onPressed: _openNextPage,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tap the glass button to push with 1s transition.\n'
                'If artifact exists, square placeholder appears until transition ends.',
                style: TextStyle(color: textColor),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// CupertinoPageRoute with 1s transition for testing — supports swipe-back.
class _SlowCupertinoPageRoute extends CupertinoPageRoute {
  _SlowCupertinoPageRoute({required super.builder});

  @override
  Duration get transitionDuration => const Duration(seconds: 1);

  @override
  Duration get reverseTransitionDuration => const Duration(seconds: 1);
}
