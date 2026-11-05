import 'dart:typed_data';

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      // Issue #31 fix: register the observer that powers CNTabBar's
      // auto-hide-on-modal behavior. Without this, CNTabBar still works
      // but won't auto-hide and the TextField inside the modal sheet
      // will be invisible (the original bug).
      navigatorObservers: [CNTabBarRouteObserver()],
      home: _AlbumsPage(onPop: () => Navigator.of(context).pop()),
    );
  }
}

class NewAlbumSheet extends StatefulWidget {
  final String? oldAlbum;
  const NewAlbumSheet({super.key, this.oldAlbum});

  @override
  State<NewAlbumSheet> createState() => _NewAlbumSheetState();
}

class _NewAlbumSheetState extends State<NewAlbumSheet> {
  bool enableCreate = false;
  final ValueNotifier<List<String>> selectedPaths = ValueNotifier([]);
  final ValueNotifier<int> countSelected = ValueNotifier(0);
  final ValueNotifier<Uint8List?> coverThumb = ValueNotifier(null);
  late TextEditingController albumNameController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    albumNameController = TextEditingController();
    albumNameController.text = widget.oldAlbum ?? "";
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
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
        title: Text(
          widget.oldAlbum != null ? "Edit album" : "New Album",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          CNButton(
            label: widget.oldAlbum != null ? "Edit" : "Create",
            enabled:
                (enableCreate && countSelected.value > 0) ||
                widget.oldAlbum != null,
            tint: Colors.blue.withAlpha(230),
            onPressed: () {
              if (widget.oldAlbum != null) {
              } else {}

              Navigator.pop(context);
            },
          ),
          SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: size.height * 0.01),
            Center(
              child: ValueListenableBuilder<Uint8List?>(
                valueListenable: coverThumb,
                builder: (context, bytes, _) {
                  return Container(
                    decoration: BoxDecoration(
                      color: primary.withAlpha(24),
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    width: size.width * 0.5,
                    height: size.height * 0.2,
                    clipBehavior: Clip.antiAlias,
                    child: Icon(
                      CupertinoIcons.photo_fill,
                      size: 40,
                      color: primary.withAlpha(100),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 120),
              child: CNButton(
                label: "Add photos",
                tint: primary,
                onPressed: () {
                  showModalBottomSheet(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.9,
                    ),
                    backgroundColor: Colors.black,
                    isScrollControlled: true,
                    context: context,
                    builder: (context) {
                      return Material(
                        child: Scaffold(
                          appBar: AppBar(
                            leading: Transform.scale(
                              scale: 0.9,
                              child: CNButton.icon(
                                icon: CNSymbol('xmark', size: 16),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            title: Text(
                              "Select photos",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            actionsPadding: EdgeInsets.only(left: 10),
                            actions: [
                              ValueListenableBuilder<int>(
                                valueListenable: countSelected,
                                builder: (context, value, _) {
                                  return CNButton.icon(
                                    enabled: value > 0,
                                    onPressed: () => Navigator.pop(context),
                                    icon: CNSymbol('xmark', size: 16),
                                    tint: Colors.blue,
                                  );
                                },
                              ),
                            ],
                          ),
                          body: SizedBox(),
                          // body: LibraryPage(
                          //   onlySelect: true,
                          //   onSelectedChanged: (paths, thumbBytes) {
                          //     selectedPaths.value = paths;
                          //     coverThumb.value = thumbBytes;
                          //     countSelected.value = paths.length;
                          //   },
                          // ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 25),
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 20),
              child: TextField(
                controller: albumNameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  filled: true,
                  hint: Text(
                    "Album name",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: primary.withAlpha(100),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(25)),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() => enableCreate = value.isNotEmpty);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Material bar is kept for comparison; set this to true to see it.
bool _materialBar = false;

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
        title: const Text('Albums'),
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
                    child: NewAlbumSheet(),
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
                    'Repro: TextField inside modal sheet disappears '
                    'when CNTabBar is in bottomNavigationBar.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      bottomNavigationBar: _materialBar
          ? BottomNavigationBar(
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 13,
              unselectedFontSize: 13,
              currentIndex: _currentIndex,
              onTap: (value) {
                setState(() {
                  _currentIndex = value;
                });
              },
              items: [
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.photo),
                  label: "Library",
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.collections),
                  label: "Albums",
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.search),
                  label: "Search",
                ),
              ],
            )
          : SafeArea(
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
