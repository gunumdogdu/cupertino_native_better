import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #106 — custom icons in `CNPopupMenuButton` after a rebuild.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/106
/// Found while reviewing the PR's subtitles and submenus.
///
/// ### The claim
///
/// The PR finds each entry's rendered custom icon by the entry object. Items
/// built in `build()` (not `const`, for example because of
/// `checked: _sort == x`) are new objects on every build, so the lookup
/// misses after a rebuild:
///
///  * **Flat:** its `buttonLabel` changes on each rebuild, which recreates
///    the native view. On 1.8.3 the recreated view still had its icons.
///  * **Nested:** a rebuild sends `setItems`, which rebuilds the submenus
///    with their icons.
///
/// ### How this screen proves it
///
/// Both menus use non-`const` items with a custom icon on every row.
/// *Rebuild* bumps a counter in `setState`; [autoCycle] does it twice, one
/// second apart, after the first frame. Then open both menus, and Nested's
/// *Share* submenu.
///
///  * **Bug:** after a rebuild, Flat shows no icons, or Share shows no icons.
///  * **Fixed:** every row keeps its icon (mail, heart, star; house; mail,
///    phone).
class Pr106PopupMenuRebuildTestPage extends StatefulWidget {
  const Pr106PopupMenuRebuildTestPage({super.key, this.autoCycle = false});

  final bool autoCycle;

  @override
  State<Pr106PopupMenuRebuildTestPage> createState() =>
      _Pr106PopupMenuRebuildTestPageState();
}

class _Pr106PopupMenuRebuildTestPageState
    extends State<Pr106PopupMenuRebuildTestPage> {
  int _rebuilds = 0;
  String _picked = '—';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (t.tick > 2) {
          t.cancel();
          return;
        }
        _rebuild();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _rebuild() => setState(() => _rebuilds++);

  @override
  Widget build(BuildContext context) {
    final flatItems = <CNPopupMenuEntry>[
      CNPopupMenuItem(
        label: 'Mail',
        customIcon: CupertinoIcons.mail,
        checked: _rebuilds.isEven,
      ),
      const CNPopupMenuItem(label: 'Heart', customIcon: CupertinoIcons.heart),
      const CNPopupMenuDivider(),
      const CNPopupMenuItem(label: 'Star', customIcon: CupertinoIcons.star),
    ];
    final nestedItems = <CNPopupMenuEntry>[
      const CNPopupMenuItem(label: 'Home', customIcon: CupertinoIcons.house),
      CNPopupMenuSubmenu(
        label: 'Share',
        items: [
          CNPopupMenuItem(
            label: 'Mail',
            customIcon: CupertinoIcons.mail,
            checked: _rebuilds.isEven,
          ),
          const CNPopupMenuItem(
            label: 'Phone',
            customIcon: CupertinoIcons.phone,
          ),
        ],
      ),
    ];

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #106 · icons after rebuild'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rebuilds: $_rebuilds   Picked: $_picked'),
              const SizedBox(height: 8),
              const Text(
                'Every row has a custom icon. After a rebuild, a row '
                'without its icon is the bug.',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  CNPopupMenuButton(
                    buttonLabel: 'Flat $_rebuilds',
                    items: flatItems,
                    onSelected: (i) => setState(() => _picked = 'Flat [$i]'),
                  ),
                  const SizedBox(width: 24),
                  CNPopupMenuButton(
                    buttonLabel: 'Nested',
                    items: nestedItems,
                    onPathSelected: (path) =>
                        setState(() => _picked = 'Nested $path'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: _rebuild,
                child: const Text('Rebuild'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
