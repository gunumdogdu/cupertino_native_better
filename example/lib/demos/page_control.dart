import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// CNPageControl: one driving a PageView through its controller, a
/// controlled one on a prominent background, a tinted one, many pages, and
/// a disabled one, each with its page written next to it.
///
/// [autoCycle] turns the pages on a timer, so the page can be checked from
/// screenshots without tapping (`PROBE=pagecontrol`).
class PageControlDemoPage extends StatefulWidget {
  const PageControlDemoPage({super.key, this.autoCycle = false});

  /// Moves every control one page on every 1.5 s.
  final bool autoCycle;

  @override
  State<PageControlDemoPage> createState() => _PageControlDemoPageState();
}

class _PageControlDemoPageState extends State<PageControlDemoPage> {
  static const List<Color> _slides = <Color>[
    CupertinoColors.systemBlue,
    CupertinoColors.systemPurple,
    CupertinoColors.systemPink,
    CupertinoColors.systemOrange,
    CupertinoColors.systemGreen,
  ];

  final PageController _pages = PageController();
  int _pageViewPage = 0;
  int _prominent = 1;
  int _tinted = 0;
  int _many = 7;
  bool _enabled = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        // The PageView moves, and its page control follows it.
        final next = (_pageViewPage + 1) % _slides.length;
        _pages.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        setState(() {
          _prominent = (_prominent + 1) % 4;
          _tinted = (_tinted + 1) % 6;
          _many = (_many + 3) % 30;
          _enabled = !_enabled;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  Widget _label(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Page Control')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            _label(
              'With a PageView',
              'Page ${_pageViewPage + 1} of ${_slides.length}',
            ),
            SizedBox(
              height: 140,
              child: PageView(
                controller: _pages,
                onPageChanged: (p) => setState(() => _pageViewPage = p),
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _slides[i],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Slide ${i + 1}',
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            CNPageControl(
              numberOfPages: _slides.length,
              controller: _pages,
              semanticLabel: 'Slides',
            ),
            _label('Prominent background', 'Page ${_prominent + 1} of 4'),
            CNPageControl(
              numberOfPages: 4,
              currentPage: _prominent,
              backgroundStyle: CNPageControlBackgroundStyle.prominent,
              semanticLabel: 'Prominent',
              onChanged: (p) => setState(() => _prominent = p),
            ),
            _label('With colors', 'Page ${_tinted + 1} of 6'),
            CNPageControl(
              numberOfPages: 6,
              currentPage: _tinted,
              pageIndicatorColor: CupertinoColors.systemPink.withValues(
                alpha: 0.3,
              ),
              currentPageIndicatorColor: CupertinoColors.systemPink,
              semanticLabel: 'Tinted',
              onChanged: (p) => setState(() => _tinted = p),
            ),
            _label('Many pages, minimal', 'Page ${_many + 1} of 30'),
            CNPageControl(
              numberOfPages: 30,
              currentPage: _many,
              backgroundStyle: CNPageControlBackgroundStyle.minimal,
              semanticLabel: 'Many pages',
              onChanged: (p) => setState(() => _many = p),
            ),
            _label('Disabled', 'Page 2 of 5'),
            const CNPageControl(
              numberOfPages: 5,
              currentPage: 1,
              enabled: false,
              backgroundStyle: CNPageControlBackgroundStyle.prominent,
              semanticLabel: 'Disabled',
            ),
            if (widget.autoCycle) ...[
              _label('Enabled changes', _enabled ? 'enabled' : 'disabled'),
              CNPageControl(
                numberOfPages: 4,
                currentPage: _prominent,
                enabled: _enabled,
                backgroundStyle: CNPageControlBackgroundStyle.prominent,
                semanticLabel: 'Toggled',
                onChanged: (p) => setState(() => _prominent = p),
              ),
            ],
            _label('In a Row', 'sized to its dots'),
            Row(
              children: [
                const Text('Step'),
                const Spacer(),
                CNPageControl(
                  numberOfPages: 3,
                  currentPage: _prominent % 3,
                  backgroundStyle: CNPageControlBackgroundStyle.prominent,
                  semanticLabel: 'Step',
                  onChanged: (p) => setState(() => _prominent = p),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
