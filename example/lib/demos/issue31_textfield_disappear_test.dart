import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

<<<<<<< Updated upstream
/// Issue #31 reproduction (rebuilt after watching the reporter's videos
/// frame-by-frame).
///
/// What the videos actually show:
///   * Video 1 (with CNTabBar — bug present):
///     - Material Scaffold, "Albums" page, CNTabBar with searchItem in
///       bottomNavigationBar.
///     - User taps the "+" button in the AppBar.
///     - A modal sheet opens with: X close, "New Album" title, Create
///       button, image placeholder, "Add photos" button.
///     - **The "Album name" TextField that should sit below "Add photos"
///       is INVISIBLE.** The sheet has not collapsed — the field is just
///       not rendered.
///
///   * Video 2 (without CNTabBar — uses Material BottomNavigationBar):
///     - Same "+" → same sheet.
///     - **The "Album name" TextField IS visible.**
///
/// Conclusion: when a UiKitView (CNTabBar) is anywhere on the route,
/// Flutter-rendered Material TextFields inside a modal sheet on that
/// route do not render. CupertinoTextField (which uses a native
/// UITextField overlay) is included for comparison.
=======
/// Issue #31 reproduction: text fields inside a bottom sheet are not visible
/// when the bottom sheet is opened from a CNTabBar (with `searchItem`)
/// placed in a Material `Scaffold.bottomNavigationBar`.
///
/// Reporter's flow:
///  1. Material Scaffold with `CNTabBar` (containing a `searchItem`) in the
///     `bottomNavigationBar` slot.
///  2. User taps the search tab — they then present a modal bottom sheet
///     containing TextField(s).
///  3. The TextFields inside the bottom sheet disappear / aren't visible.
///
/// To verify the bug:
///  1. Open this page from "Testing → #31: TextField disappear".
///  2. Tap the magnifying-glass search tab in the bottom bar (or the
///     "Open sheet" button on the body, which does the same thing).
///  3. A bottom sheet opens containing two TextFields.
///  4. Are the TextFields visible? Editable? Or do they disappear?
>>>>>>> Stashed changes
class Issue31TextFieldDisappearTest extends StatefulWidget {
  const Issue31TextFieldDisappearTest({super.key});

  @override
  State<Issue31TextFieldDisappearTest> createState() =>
      _Issue31TextFieldDisappearTestState();
}

class _Issue31TextFieldDisappearTestState
    extends State<Issue31TextFieldDisappearTest> {
  @override
  Widget build(BuildContext context) {
    // Reporter's app is rooted in MaterialApp; this example app is rooted in
    // CupertinoApp. Wrap a MaterialApp here so Material widgets get their
    // localizations and we faithfully match the reporter's setup.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
<<<<<<< Updated upstream
      theme: ThemeData.dark(),
      home: _AlbumsPage(onPop: () => Navigator.of(context).pop()),
=======
      home: _Inner(onPop: () => Navigator.of(context).pop()),
>>>>>>> Stashed changes
    );
  }
}

<<<<<<< Updated upstream
class _AlbumsPage extends StatefulWidget {
  final VoidCallback onPop;
  const _AlbumsPage({required this.onPop});

  @override
  State<_AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<_AlbumsPage> {
  int _currentIndex = 1; // Albums tab selected by default

  void _openNewAlbumSheet() {
    // Mirror what the reporter's "+" button does — open a modal sheet
    // with an image placeholder + "Add photos" + an album-name TextField.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final inset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                      const Text('New Album',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      TextButton(
                        onPressed: null,
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.image_outlined,
                      color: Colors.grey, size: 36),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Add photos'),
                ),
                const SizedBox(height: 24),
                // The TextFields the reporter says disappear.
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    decoration: InputDecoration(
                      filled: true,
                      hintText: 'Album name (Material TextField)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: CupertinoTextField(
                    placeholder: 'Album name (CupertinoTextField)',
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
=======
class _Inner extends StatefulWidget {
  final VoidCallback onPop;
  const _Inner({required this.onPop});

  @override
  State<_Inner> createState() => _InnerState();
}

class _InnerState extends State<_Inner> {
  int _currentIndex = 0;

  void _openSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bottom sheet (opened from search tap)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reporter says these TextFields are not visible. Try tapping '
              'them — does the keyboard come up? Can you type?',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Material TextField (autofocus)',
              ),
            ),
            const SizedBox(height: 12),
            const CupertinoTextField(
              placeholder: 'CupertinoTextField',
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
>>>>>>> Stashed changes
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
<<<<<<< Updated upstream
=======
        title: const Text('#31: TextField disappear'),
>>>>>>> Stashed changes
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onPop,
        ),
<<<<<<< Updated upstream
        title: const Text('Albums'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openNewAlbumSheet,
            tooltip: 'New Album',
          ),
        ],
=======
>>>>>>> Stashed changes
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
<<<<<<< Updated upstream
                    'Repro: TextField inside modal sheet disappears '
                    'when CNTabBar is in bottomNavigationBar.',
=======
                    'Repro: TextField inside bottom sheet disappears',
>>>>>>> Stashed changes
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
<<<<<<< Updated upstream
                    'Tap "+" in the AppBar. A "New Album" sheet opens '
                    'with two TextFields (Material + Cupertino). The '
                    'reporter says the Material TextField is invisible '
                    'when CNTabBar is present.',
=======
                    'Tap the search tab (magnifying glass) at the bottom — '
                    'a bottom sheet opens with TextFields. The reporter says '
                    'those TextFields are not visible. Compare with tapping '
                    '"Open sheet" below — same sheet but opened directly, '
                    'not from the search tab.',
>>>>>>> Stashed changes
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
<<<<<<< Updated upstream
=======
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openSheet,
              child: const Text('Open sheet (without going through search)'),
            ),
            const SizedBox(height: 24),
            Text('Current tab index: $_currentIndex'),
>>>>>>> Stashed changes
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
<<<<<<< Updated upstream
=======
        // Mirror the reporter's setup: CNTabBar with searchItem and
        // automaticallyActivatesSearch: false. The bottom sheet is opened
        // from `onSearchActiveChanged`.
>>>>>>> Stashed changes
        child: CNTabBar(
          tint: Colors.blue,
          iconSize: 18,
          items: const [
            CNTabBarItem(
              label: 'Library',
              icon: CNSymbol('photo.fill.on.rectangle.fill'),
            ),
            CNTabBarItem(
              label: 'Albums',
              icon: CNSymbol('rectangle.stack.fill'),
            ),
          ],
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          searchItem: CNTabBarSearchItem(
            placeholder: 'Search',
            automaticallyActivatesSearch: false,
            onSearchChanged: (_) {},
            onSearchSubmit: (_) {},
<<<<<<< Updated upstream
            onSearchActiveChanged: (_) {},
=======
            onSearchActiveChanged: (isActive) {
              if (isActive) _openSheet();
            },
>>>>>>> Stashed changes
            style: const CNTabBarSearchStyle(
              iconSize: 20,
              animationDuration: Duration(milliseconds: 400),
            ),
          ),
        ),
      ),
    );
  }
}
