import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
      theme: ThemeData.dark(),
      home: _AlbumsPage(onPop: () => Navigator.of(context).pop()),
    );
  }
}

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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onPop,
        ),
        title: const Text('Albums'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openNewAlbumSheet,
            tooltip: 'New Album',
          ),
        ],
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
                    'Repro: TextField inside modal sheet disappears '
                    'when CNTabBar is in bottomNavigationBar.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap "+" in the AppBar. A "New Album" sheet opens '
                    'with two TextFields (Material + Cupertino). The '
                    'reporter says the Material TextField is invisible '
                    'when CNTabBar is present.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
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
            onSearchActiveChanged: (_) {},
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
