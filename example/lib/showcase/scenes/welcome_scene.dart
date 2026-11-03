import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

import '../ios_kit.dart';

/// A welcome pager: each page's symbol plays an SF Symbol effect, the native
/// page dots follow the pages, and a prominent glass button continues.
///
/// The pages turn by themselves until the user swipes.
class WelcomeScene extends StatefulWidget {
  const WelcomeScene({super.key});

  @override
  State<WelcomeScene> createState() => _WelcomeSceneState();
}

class _Page {
  const _Page(this.symbol, this.color, this.title, this.body, this.effect);

  final String symbol;
  final Color color;
  final String title;
  final String body;
  final CNSymbolEffect effect;
}

class _WelcomeSceneState extends State<WelcomeScene> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  static const _pages = [
    _Page(
      'sparkles',
      CupertinoColors.systemIndigo,
      'Welcome to Field Notes',
      'Capture ideas the moment they happen, on every device you own.',
      CNSymbolEffect.breathe(),
    ),
    _Page(
      'waveform',
      CupertinoColors.systemPink,
      'Talk, Don’t Type',
      'Record a voice note and it is transcribed as you speak.',
      CNSymbolEffect.variableColor(reversing: true),
    ),
    _Page(
      'bell.badge.fill',
      CupertinoColors.systemOrange,
      'Never Miss a Thing',
      'Reminders arrive right when and where you need them.',
      CNSymbolEffect.wiggle(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!_controller.hasClients) return;
      final next = (_page + 1) % _pages.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final insets = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Padding(
        padding: EdgeInsets.only(top: insets.top, bottom: insets.bottom + 12),
        child: Column(
          children: [
            Expanded(
              child: NotificationListener<ScrollStartNotification>(
                onNotification: (n) {
                  // A swipe takes over from the timer.
                  if (n.dragDetails != null) _timer?.cancel();
                  return false;
                },
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final page = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CNIcon(
                            symbol: CNSymbol(
                              page.symbol,
                              size: 96,
                              color: page.color,
                            ),
                            size: 140,
                            // Runs while its page is the one shown.
                            effect: i == _page ? page.effect : null,
                          ),
                          const SizedBox(height: 36),
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: IOS.largeTitle.copyWith(color: label),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            page.body,
                            textAlign: TextAlign.center,
                            style: IOS.body.copyWith(color: secondary),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            CNPageControl(
              numberOfPages: _pages.length,
              controller: _controller,
              currentPageIndicatorColor: _pages[_page].color,
              semanticLabel: 'Page',
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: CNButton(
                  label: 'Continue',
                  tint: CupertinoColors.systemBlue,
                  config: const CNButtonConfig(
                    style: CNButtonStyle.prominentGlass,
                    minHeight: 52,
                  ),
                  onPressed: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
