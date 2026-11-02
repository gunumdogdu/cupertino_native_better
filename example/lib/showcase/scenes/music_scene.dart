import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

import '../ios_kit.dart';

/// A Music-style app on `CNTabBarNative`: a SwiftUI TabView whose bar
/// minimises on scroll, with a now-playing accessory and a search tab.
class MusicScene extends StatefulWidget {
  const MusicScene({super.key, this.autoLaunch = true, this.rootMode = true});

  /// Presents the native tab bar on the first frame.
  final bool autoLaunch;

  /// Root mode with no close button, as an app whose tab bar is the whole
  /// app. False presents it modally with a close button, for the example
  /// app's showcase list.
  final bool rootMode;

  @override
  State<MusicScene> createState() => _MusicSceneState();
}

class _MusicSceneState extends State<MusicScene> {
  @override
  void initState() {
    super.initState();
    if (widget.autoLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _launch());
    }
  }

  @override
  void dispose() {
    CNTabBarNative.disable();
    super.dispose();
  }

  static CNListItem _row(String title, String symbol, [String? subtitle]) =>
      CNListItem(
        title: title,
        subtitle: subtitle,
        leadingSymbol: CNSymbol(symbol),
        showChevron: true,
      );

  Future<void> _launch() async {
    await CNTabBarNative.enable(
      asRoot: widget.rootMode,
      showCloseButton: !widget.rootMode,
      onDismissed: widget.rootMode ? null : () => Navigator.maybePop(context),
      tintColor: CupertinoColors.systemRed,
      isDark: CupertinoTheme.brightnessOf(context) == Brightness.dark,
      minimizeBehavior: CNTabMinimizeBehavior.onScrollDown,
      bottomAccessory: const CNTabAccessory(
        text: 'Morning Run Mix',
        sfSymbol: CNSymbol('play.fill'),
      ),
      tabs: [
        CNTab(
          title: 'Home',
          sfSymbol: const CNSymbol('house.fill'),
          nativeList: CNNativeList(
            items: [
              _row('Top Picks for You', 'star.fill', 'Updated today'),
              _row('Recently Played', 'clock.fill', '12 albums'),
              _row('Made for You', 'person.crop.square.fill', '6 mixes'),
              _row('Your Favorites', 'heart.fill', '248 songs'),
              _row('New Releases', 'sparkles', 'This week'),
              _row('Friends Are Listening To', 'person.2.fill'),
              _row('Chill', 'leaf.fill', 'Playlist · 32 songs'),
              _row('Focus', 'brain.head.profile', 'Playlist · 48 songs'),
              _row('Workout', 'figure.run', 'Playlist · 40 songs'),
              _row('Late Night', 'moon.stars.fill', 'Playlist · 27 songs'),
              _row('Road Trip', 'car.fill', 'Playlist · 61 songs'),
              _row('Acoustic Mornings', 'guitars.fill', 'Playlist · 22 songs'),
              _row('Spatial Audio', 'airpodspro', 'Hear it all around you'),
              _row('Live Radio', 'dot.radiowaves.left.and.right'),
            ],
          ),
        ),
        CNTab(title: 'New', sfSymbol: const CNSymbol('square.grid.2x2.fill')),
        CNTab(
          title: 'Library',
          sfSymbol: const CNSymbol('square.stack.fill'),
          badgeCount: 3,
          nativeList: CNNativeList(
            items: [
              _row('Playlists', 'music.note.list'),
              _row('Artists', 'music.mic'),
              _row('Albums', 'square.stack'),
              _row('Songs', 'music.note'),
              _row('Made for You', 'person.crop.square'),
              _row('Music Videos', 'tv'),
              _row('Genres', 'guitars'),
              _row('Compilations', 'person.2.crop.square.stack'),
              _row('Downloaded', 'arrow.down.circle'),
            ],
          ),
        ),
        CNTab(
          title: 'Search',
          isSearchTab: true,
          nativeList: CNNativeList(
            items: [
              _row('Pop', 'music.note'),
              _row('Hip-Hop', 'music.quarternote.3'),
              _row('Electronic', 'waveform'),
              _row('Classical', 'pianokeys'),
              _row('Jazz', 'music.note.house'),
            ],
          ),
        ),
      ],
    );
  }

  /// The New tab hosts this Flutter content (root mode).
  @override
  Widget build(BuildContext context) {
    return const IOSPage(
      largeTitle: 'New',
      children: [
        IOSSection(
          header: 'Browse by Category',
          rows: [
            IOSRow(
              title: 'New Music',
              icon: 'sparkles',
              iconColor: CupertinoColors.systemPink,
              chevron: true,
            ),
            IOSRow(
              title: 'Charts',
              icon: 'chart.bar.fill',
              iconColor: CupertinoColors.systemOrange,
              chevron: true,
            ),
            IOSRow(
              title: 'Radio Shows',
              icon: 'dot.radiowaves.left.and.right',
              iconColor: CupertinoColors.systemRed,
              chevron: true,
            ),
            IOSRow(
              title: 'Spatial Audio',
              icon: 'airpodspro',
              iconColor: CupertinoColors.systemIndigo,
              chevron: true,
            ),
          ],
        ),
      ],
    );
  }
}
