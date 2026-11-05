import 'dart:typed_data';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Investigation companion to `issue31_textfield_disappear_test.dart`.
///
/// Hypothesis we are testing:
///   The "TextField inside modal sheet disappears" bug (Issue #31) might
///   only happen when CNTabBar has a `searchItem` (which routes through
///   the iOS 26 search-tab-bar Swift class via UISearchController and may
///   be the actual source of the z-order conflict), NOT when CNTabBar is
///   used as a plain bottom bar without search.
///
/// This screen is identical to the Issue #31 reproduction page EXCEPT:
///   1. CNTabBar has NO `searchItem`
///   2. `autoHideOnModal` is set to `false` so the bar stays visible
///      when the modal opens — letting us see whether the underlying
///      TextField bug reproduces at all on this code path.
///
/// To verify:
///   1. Open this page (CNTabBar at bottom, no search button on the right).
///   2. Tap "+" → New Album sheet opens.
///   3. Is the "Album name" TextField visible inside the sheet?
///
///   - If YES → bug is search-specific. We can narrow the auto-hide
///     workaround to ONLY trigger when CNTabBar has a searchItem, and
///     leave the regular bar untouched (preserving the snappy modal
///     close animation).
///   - If NO → bug is general to any CNTabBar + Flutter modal. The
///     current global auto-hide stays.
class Issue31NoSearchTest extends StatefulWidget {
  const Issue31NoSearchTest({super.key});

  @override
  State<Issue31NoSearchTest> createState() => _Issue31NoSearchTestState();
}

class _Issue31NoSearchTestState extends State<Issue31NoSearchTest> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      // NOTE: NavigatorObserver intentionally NOT registered here. We
      // want to see the raw behaviour of CNTabBar without searchItem and
      // without the auto-hide workaround.
      home: _AlbumsPage(onPop: () => Navigator.of(context).pop()),
    );
  }
}

class NewAlbumSheetNoSearch extends StatefulWidget {
  const NewAlbumSheetNoSearch({super.key});

  @override
  State<NewAlbumSheetNoSearch> createState() => _NewAlbumSheetNoSearchState();
}

class _NewAlbumSheetNoSearchState extends State<NewAlbumSheetNoSearch> {
  late TextEditingController albumNameController;
  final ValueNotifier<Uint8List?> coverThumb = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    albumNameController = TextEditingController();
  }

  @override
  void dispose() {
    albumNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color primary = Theme.of(context).primaryColor;
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        leading: Transform.scale(
          scale: 0.8,
          child: CNButton.icon(
            icon: CNSymbol('xmark', size: 16),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'New Album',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          CNButton(
            label: 'Create',
            tint: Colors.blue.withAlpha(230),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: size.height * 0.01),
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: primary.withAlpha(24),
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
                width: size.width * 0.5,
                height: size.height * 0.2,
                clipBehavior: Clip.antiAlias,
                child: Icon(
                  CupertinoIcons.photo_fill,
                  size: 40,
                  color: primary.withAlpha(100),
                ),
              ),
            ),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: albumNameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  filled: true,
                  hint: Text(
                    'Album name',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: primary.withAlpha(100),
                    ),
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(25)),
                    borderSide: BorderSide.none,
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

class _AlbumsPage extends StatefulWidget {
  final VoidCallback onPop;
  const _AlbumsPage({required this.onPop});

  @override
  State<_AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<_AlbumsPage> {
  int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onPop,
        ),
        title: const Text('Albums (no search)'),
        actions: [
          CNButton.icon(
            icon: CNSymbol('plus', size: 20),
            onPressed: () {
              showCupertinoSheet(
                context: context,
                scrollableBuilder: (ctx, _) {
                  return Localizations(
                    locale: const Locale('en', 'US'),
                    delegates: const [
                      DefaultMaterialLocalizations.delegate,
                      DefaultWidgetsLocalizations.delegate,
                      DefaultCupertinoLocalizations.delegate,
                    ],
                    child: const NewAlbumSheetNoSearch(),
                  );
                },
              );
            },
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
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Repro: same setup as Issue #31, but CNTabBar has NO '
                    'searchItem and autoHideOnModal is OFF.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap "+" → New Album sheet. Watch whether the '
                    '"Album name" TextField is visible. If it IS, the '
                    'bug is search-specific and we can drop the global '
                    'auto-hide for plain CNTabBars.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: CNTabBar(
          tint: Colors.blue,
          iconSize: 18,
          // NO searchItem — plain bottom bar.
          // autoHideOnModal: false — let us see the raw behaviour.
          autoHideOnModal: false,
          items: const [
            CNTabBarItem(
              label: 'Library',
              icon: CNSymbol('photo.fill.on.rectangle.fill'),
            ),
            CNTabBarItem(
              label: 'Albums',
              icon: CNSymbol('rectangle.stack.fill'),
            ),
            CNTabBarItem(label: 'Profile', icon: CNSymbol('person.fill')),
          ],
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
        ),
      ),
    );
  }
}
