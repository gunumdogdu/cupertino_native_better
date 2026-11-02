import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// A Photos-style viewer: Liquid Glass buttons and a glass button group
/// over full-bleed images, which the glass picks up as you swipe.
///
/// Images: violet.jpg was made for this showcase; "New Horizons 1" by Ahmed
/// Saffu is CC0 (Unsplash, via Wikimedia Commons).
class PhotosScene extends StatefulWidget {
  const PhotosScene({super.key});

  @override
  State<PhotosScene> createState() => _PhotosSceneState();
}

class _PhotosSceneState extends State<PhotosScene> {
  static const _images = [
    'assets/showcase/violet.jpg',
    'assets/showcase/horizon.jpg',
  ];
  static const _dates = ['Today', 'Yesterday'];
  static const _times = ['9:41 AM', '6:12 PM'];

  final _favourite = [false, false];
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    const white = CupertinoColors.white;
    return ColoredBox(
      color: CupertinoColors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              itemCount: _images.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => Image.asset(_images[i], fit: BoxFit.cover),
            ),
          ),
          // A soft scrim keeps the title legible over bright photos.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 150,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x59000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: padding.top + 6,
            left: 16,
            right: 16,
            height: 44,
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CNButton.icon(
                    icon: const CNSymbol(
                      'chevron.left',
                      size: 17,
                      color: white,
                    ),
                    semanticLabel: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _dates[_page],
                        style: const TextStyle(
                          color: white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.43,
                        ),
                      ),
                      Text(
                        _times[_page],
                        style: const TextStyle(
                          color: white,
                          fontSize: 13,
                          letterSpacing: -0.08,
                        ),
                      ),
                    ],
                  ),
                ),
                CNButton(
                  label: 'Edit',
                  config: const CNButtonConfig(
                    labelColor: white,
                    labelFontWeight: FontWeight.w600,
                    minHeight: 44,
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    shrinkWrap: true,
                  ),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
                CNPopupMenuButton.icon(
                  buttonIcon: const CNSymbol(
                    'ellipsis',
                    size: 17,
                    color: white,
                  ),
                  semanticLabel: 'More',
                  items: const [
                    CNPopupMenuItem(
                      label: 'Copy',
                      icon: CNSymbol('doc.on.doc'),
                    ),
                    CNPopupMenuItem(
                      label: 'Duplicate',
                      icon: CNSymbol('plus.square.on.square'),
                    ),
                    CNPopupMenuItem(label: 'Hide', icon: CNSymbol('eye.slash')),
                    CNPopupMenuDivider(),
                    CNPopupMenuItem(
                      label: 'Slideshow',
                      icon: CNSymbol('play.rectangle'),
                    ),
                    CNPopupMenuItem(
                      label: 'Adjust Date & Time',
                      icon: CNSymbol('calendar.badge.clock'),
                    ),
                  ],
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: padding.bottom + 8,
            height: 52,
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CNButton.icon(
                    icon: const CNSymbol(
                      'square.and.arrow.up',
                      size: 19,
                      color: white,
                    ),
                    semanticLabel: 'Share',
                    onPressed: () {},
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 168,
                  height: 52,
                  child: CNGlassButtonGroup(
                    spacing: 0,
                    spacingForGlass: 40,
                    buttons: [
                      CNButtonData.icon(
                        icon: CNSymbol(
                          _favourite[_page] ? 'heart.fill' : 'heart',
                          size: 19,
                          color: _favourite[_page]
                              ? CupertinoColors.systemRed
                              : white,
                        ),
                        onPressed: () => setState(
                          () => _favourite[_page] = !_favourite[_page],
                        ),
                        config: const CNButtonDataConfig(
                          glassEffectUnionId: 'actions',
                          minHeight: 52,
                        ),
                      ),
                      CNButtonData.icon(
                        icon: const CNSymbol(
                          'info.circle',
                          size: 19,
                          color: white,
                        ),
                        onPressed: () {},
                        config: const CNButtonDataConfig(
                          glassEffectUnionId: 'actions',
                          minHeight: 52,
                        ),
                      ),
                      CNButtonData.icon(
                        icon: const CNSymbol(
                          'slider.horizontal.3',
                          size: 19,
                          color: white,
                        ),
                        onPressed: () {},
                        config: const CNButtonDataConfig(
                          glassEffectUnionId: 'actions',
                          minHeight: 52,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CNButton.icon(
                    icon: const CNSymbol('trash', size: 19, color: white),
                    semanticLabel: 'Delete',
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
