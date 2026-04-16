import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #29 regression test - one widget per slow-transition push, AND
/// every button on the destination page also pushes another slow page so
/// you can observe the widget itself during the transition it triggered.
///
/// Procedure for each entry:
///  1. Tap the entry to push the slow widget page.
///  2. Watch the widget while sliding in (1s).
///  3. Tap the widget itself — it pushes another copy of the page on a
///     1s slow transition. Watch the widget while sliding OUT (it's now
///     the source page) AND while the new copy slides IN.
///  4. Swipe back to test reverse transitions.
///  5. Tell me which entries showed any halo / artifact.
class Issue29ArtifactTestPage extends StatelessWidget {
  const Issue29ArtifactTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <_Entry>[
      _Entry(
        title: 'CNButton (label, glass)',
        widgetBuilder: (onAction) => _CNButtonGlass(onAction: onAction),
      ),
      _Entry(
        title: 'CNButton (label, prominentGlass)',
        widgetBuilder: (onAction) =>
            _CNButtonProminentGlass(onAction: onAction),
      ),
      _Entry(
        title: 'CNButton.icon (default = glass)',
        widgetBuilder: (onAction) => _CNButtonIcon(onAction: onAction),
      ),
      _Entry(
        title: 'CNPopupMenuButton',
        widgetBuilder: (onAction) => _CNPopupMenu(onAction: onAction),
      ),
      _Entry(
        title: 'CNSearchBar',
        widgetBuilder: (onAction) => _CNSearchBarDemo(onAction: onAction),
      ),
      _Entry(
        title: 'CNTabBar',
        widgetBuilder: (onAction) => _CNTabBarDemo(onAction: onAction),
      ),
      _Entry(
        title: 'CNGlassButtonGroup',
        widgetBuilder: (onAction) =>
            _CNGlassButtonGroupDemo(onAction: onAction),
      ),
      _Entry(
        title: 'CNGlassButtonGroup with badges (verify badges still visible)',
        widgetBuilder: (onAction) =>
            _CNGlassButtonGroupBadgesDemo(onAction: onAction),
      ),
    ];

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#29: Per-widget halo test'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Each row pushes a 1-second slow page with ONE widget. The '
                'widget itself also pushes another slow page when tapped, '
                'so you can watch it transition both ways. Tell me which '
                'widget shows a halo / artifact.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            CupertinoListSection.insetGrouped(
              children: [
                for (final e in entries)
                  CupertinoListTile(
                    title: Text(e.title),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _push(context, e),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _push(BuildContext context, _Entry entry) {
  Navigator.of(context).push(
    _SlowCupertinoPageRoute(
      builder: (_) => _SingleWidgetPage(entry: entry),
    ),
  );
}

class _Entry {
  final String title;
  final Widget Function(VoidCallback onAction) widgetBuilder;
  _Entry({required this.title, required this.widgetBuilder});
}

class _SingleWidgetPage extends StatelessWidget {
  final _Entry entry;
  const _SingleWidgetPage({required this.entry});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(entry.title)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Widget under test: ${entry.title}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the widget below — it triggers another slow push so you '
                'can watch it transition out and back in.',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 32),
              Center(child: entry.widgetBuilder(() => _push(context, entry))),
              const Spacer(),
              const Text(
                'Tap back (or swipe) to test the reverse transition too.',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-widget demos - each pushes via onAction to trigger another slow page
// ---------------------------------------------------------------------------

class _CNButtonGlass extends StatelessWidget {
  final VoidCallback onAction;
  const _CNButtonGlass({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return CNButton(
      config: const CNButtonConfig(style: CNButtonStyle.glass),
      label: 'Push slow page',
      onPressed: onAction,
    );
  }
}

class _CNButtonProminentGlass extends StatelessWidget {
  final VoidCallback onAction;
  const _CNButtonProminentGlass({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return CNButton(
      config: const CNButtonConfig(style: CNButtonStyle.prominentGlass),
      label: 'Push slow page',
      onPressed: onAction,
    );
  }
}

class _CNButtonIcon extends StatelessWidget {
  final VoidCallback onAction;
  const _CNButtonIcon({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return CNButton.icon(
      icon: const CNSymbol('star.fill', size: 18),
      onPressed: onAction,
    );
  }
}

class _CNPopupMenu extends StatelessWidget {
  final VoidCallback onAction;
  const _CNPopupMenu({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return CNPopupMenuButton.icon(
      buttonIcon: const CNSymbol('ellipsis.circle.fill'),
      items: const [
        CNPopupMenuItem(label: 'First (push)'),
        CNPopupMenuItem(label: 'Second (push)'),
        CNPopupMenuItem(label: 'Third (push)'),
      ],
      onSelected: (_) => onAction(),
    );
  }
}

class _CNSearchBarDemo extends StatelessWidget {
  final VoidCallback onAction;
  const _CNSearchBarDemo({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 320,
          child: CNSearchBar(
            placeholder: 'Type and submit to push...',
            onSubmitted: (_) => onAction(),
          ),
        ),
        const SizedBox(height: 12),
        CNButton(
          config: const CNButtonConfig(style: CNButtonStyle.glass),
          label: 'Push slow page',
          onPressed: onAction,
        ),
      ],
    );
  }
}

class _CNTabBarDemo extends StatelessWidget {
  final VoidCallback onAction;
  const _CNTabBarDemo({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      width: 320,
      child: CNTabBar(
        items: const [
          CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
          CNTabBarItem(label: 'Browse', icon: CNSymbol('square.grid.2x2')),
          CNTabBarItem(label: 'Profile', icon: CNSymbol('person')),
        ],
        currentIndex: 0,
        onTap: (_) => onAction(),
      ),
    );
  }
}

class _CNGlassButtonGroupDemo extends StatelessWidget {
  final VoidCallback onAction;
  const _CNGlassButtonGroupDemo({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return CNGlassButtonGroup(
      axis: Axis.horizontal,
      spacing: 8.0,
      spacingForGlass: 40.0,
      buttons: [
        CNButtonData.icon(
          icon: const CNSymbol('house.fill', size: 18),
          onPressed: onAction,
          config: const CNButtonDataConfig(
            style: CNButtonStyle.glass,
            glassEffectUnionId: 'halo-test-group',
            glassEffectId: 'halo-test-home',
          ),
        ),
        CNButtonData.icon(
          icon: const CNSymbol('magnifyingglass', size: 18),
          onPressed: onAction,
          config: const CNButtonDataConfig(
            style: CNButtonStyle.glass,
            glassEffectUnionId: 'halo-test-group',
            glassEffectId: 'halo-test-search',
          ),
        ),
        CNButtonData.icon(
          icon: const CNSymbol('person.fill', size: 18),
          onPressed: onAction,
          config: const CNButtonDataConfig(
            style: CNButtonStyle.glass,
            glassEffectUnionId: 'halo-test-group',
            glassEffectId: 'halo-test-profile',
          ),
        ),
      ],
    );
  }
}

class _CNGlassButtonGroupBadgesDemo extends StatelessWidget {
  final VoidCallback onAction;
  const _CNGlassButtonGroupBadgesDemo({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return CNGlassButtonGroup(
      axis: Axis.horizontal,
      spacing: 8.0,
      spacingForGlass: 40.0,
      buttons: [
        CNButtonData.icon(
          icon: const CNSymbol('envelope.fill', size: 18),
          badgeCount: 3,
          onPressed: onAction,
          config: const CNButtonDataConfig(style: CNButtonStyle.glass),
        ),
        CNButtonData.icon(
          icon: const CNSymbol('bell.fill', size: 18),
          badgeCount: 12,
          onPressed: onAction,
          config: const CNButtonDataConfig(style: CNButtonStyle.glass),
        ),
        CNButtonData.icon(
          icon: const CNSymbol('exclamationmark.bubble.fill', size: 18),
          badgeCount: 150,
          onPressed: onAction,
          config: const CNButtonDataConfig(style: CNButtonStyle.glass),
        ),
      ],
    );
  }
}

/// CupertinoPageRoute with 1-second slow transition so any halo is easy to see.
class _SlowCupertinoPageRoute extends CupertinoPageRoute {
  _SlowCupertinoPageRoute({required super.builder});

  @override
  Duration get transitionDuration => const Duration(seconds: 1);

  @override
  Duration get reverseTransitionDuration => const Duration(seconds: 1);
}
