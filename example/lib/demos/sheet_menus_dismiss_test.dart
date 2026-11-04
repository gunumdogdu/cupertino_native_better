import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/material.dart';

/// Report (email, 2026-11-04, iOS 27.0.1, iPhone 17 Pro, 1.9.1): a
/// `CNPopupMenuButton` menu opened inside a bottom sheet does not close on a
/// tap outside it, the taps reach the sheet behind the open menu (a section
/// expands, the sheet scrolls and its drag handle moves off screen), and the
/// menu only goes away when an item is chosen. Pages are fine; only sheets.
///
/// ### The app's shape, mirrored here
///
///  * A host page with a native `CNTabBar` (`CNTabBarRouteObserver`
///    registered: run with `OBSERVER=true`).
///  * Sheet 1: dark, rounded, drag handle, scrollable content with an
///    expandable section, and a floating "+" `CNPopupMenuButton.icon` at the
///    bottom right over the content.
///  * Sheet 2, opened from a row of sheet 1 and stacked on it: a list whose
///    rows each have a "…" `CNPopupMenuButton.icon`.
///
/// ### How this screen proves it
///
/// Open a menu, then tap an empty part of the sheet.
///
///  * **Bug present:** the menu stays open, and the counter "Taps behind an
///    open menu" goes up (or the section expands / the sheet scrolls).
///  * **Fixed:** the first tap closes the menu and the counter does not move.
class SheetMenusDismissTestPage extends StatefulWidget {
  const SheetMenusDismissTestPage({super.key});

  @override
  State<SheetMenusDismissTestPage> createState() =>
      _SheetMenusDismissTestPageState();
}

/// Taps that reached Flutter while a menu was (probably) open: counted from
/// the moment a menu button is pressed until an item is chosen.
final ValueNotifier<int> _tapsBehindMenu = ValueNotifier<int>(0);
bool _menuMaybeOpen = false;

void _noteTap(String where) {
  if (_menuMaybeOpen) {
    _tapsBehindMenu.value++;
    debugPrint('SHEETDISMISS tap behind open menu: $where');
  }
}

void _menuPressed() => _menuMaybeOpen = true;

void _menuChose(String what) {
  _menuMaybeOpen = false;
  debugPrint('SHEETDISMISS chose $what');
}

class _SheetMenusDismissTestPageState extends State<SheetMenusDismissTestPage> {
  int _tab = 0;

  Future<void> _openTemplates() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TemplatesSheet(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hello',
                    style: TextStyle(color: Colors.white, fontSize: 28),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _openTemplates,
                    child: const Text('My Workouts'),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<int>(
                    valueListenable: _tapsBehindMenu,
                    builder: (_, n, _) => Text(
                      'Taps behind an open menu: $n',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CNTabBar(
              items: const [
                CNTabBarItem(icon: CNSymbol('house.fill')),
                CNTabBarItem(icon: CNSymbol('bag.fill')),
                CNTabBarItem(icon: CNSymbol('flame.fill')),
              ],
              currentIndex: _tab,
              onTap: (i) => setState(() => _tab = i),
            ),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      width: 40,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.white38,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

class _TemplatesSheet extends StatefulWidget {
  const _TemplatesSheet();

  @override
  State<_TemplatesSheet> createState() => _TemplatesSheetState();
}

class _TemplatesSheetState extends State<_TemplatesSheet> {
  bool _examples = false;

  Future<void> _openGroup() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _GroupSheet(),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _noteTap('sheet 1 background');
        FocusScope.of(context).unfocus();
      },
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.9,
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              children: [
                const _Handle(),
                const Text(
                  'My Workout Templates',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 12),
                for (final name in ['Main Split', 'Winter Arc'])
                  Card(
                    color: const Color(0xFF2C2C2E),
                    child: ListTile(
                      title: Text(
                        name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white54,
                      ),
                      onTap: _openGroup,
                    ),
                  ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text(
                    'Example Workout Templates',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: Icon(
                    _examples ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white54,
                  ),
                  onTap: () {
                    _noteTap('examples header');
                    setState(() => _examples = !_examples);
                  },
                ),
                if (_examples)
                  for (final name in ['Legs', 'Back', 'Chest | Triceps'])
                    ListTile(
                      title: Text(
                        name,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                const SizedBox(height: 600),
              ],
            ),
            Positioned(
              right: 24,
              bottom: 48,
              child: Listener(
                onPointerDown: (_) => _menuPressed(),
                child: CNPopupMenuButton.icon(
                  buttonIcon: const CNSymbol('plus'),
                  buttonStyle: CNButtonStyle.prominentGlass,
                  items: const [
                    CNPopupMenuItem(
                      label: 'Quickstart',
                      subtitle: 'New Workout',
                      icon: CNSymbol('bolt'),
                    ),
                    CNPopupMenuItem(
                      label: 'New Group',
                      icon: CNSymbol('folder'),
                    ),
                    CNPopupMenuItem(
                      label: 'New Template',
                      icon: CNSymbol('doc'),
                    ),
                  ],
                  onSelected: (i) => _menuChose('sheet 1 item $i'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSheet extends StatelessWidget {
  const _GroupSheet();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _noteTap('sheet 2 background'),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            const _Handle(),
            const Text(
              'Main Split',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 12),
            for (final name in ['Back', 'Chest | Triceps', 'Shoulders', 'Legs'])
              Card(
                color: const Color(0xFF2C2C2E),
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: Listener(
                    onPointerDown: (_) => _menuPressed(),
                    child: CNPopupMenuButton.icon(
                      buttonIcon: const CNSymbol('ellipsis'),
                      buttonStyle: CNButtonStyle.plain,
                      size: 32,
                      items: const [
                        CNPopupMenuItem(
                          label: 'Start Workout',
                          icon: CNSymbol('play'),
                        ),
                        CNPopupMenuItem(
                          label: 'Duplicate',
                          icon: CNSymbol('plus.square.on.square'),
                        ),
                        CNPopupMenuItem(
                          label: 'Remove from group',
                          icon: CNSymbol('trash'),
                          isDestructive: true,
                        ),
                      ],
                      onSelected: (i) => _menuChose('$name item $i'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
