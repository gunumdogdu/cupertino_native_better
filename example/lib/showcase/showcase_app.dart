import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;

import 'scenes/account_scene.dart';
import 'scenes/display_scene.dart';
import 'scenes/duo_scene.dart';
import 'scenes/editor_scene.dart';
import 'scenes/event_scene.dart';
import 'scenes/files_scene.dart';
import 'scenes/music_scene.dart';
import 'scenes/notes_scene.dart';
import 'scenes/photos_scene.dart';
import 'scenes/welcome_scene.dart';

/// Opens one showcase scene full screen, for recording the pub.dev media:
///
///   flutter run -t lib/showcase/showcase_app.dart --dart-define=SCENE=display
///
/// `BRIGHTNESS=dark` starts in dark mode.
const _scene = String.fromEnvironment('SCENE', defaultValue: 'display');
const _dark = String.fromEnvironment('BRIGHTNESS') == 'dark';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShowcaseApp(scene: _scene, dark: _dark));
}

class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({super.key, required this.scene, this.dark = false});

  final String scene;
  final bool dark;

  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> {
  late bool _dark = widget.dark;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [CNTabBarRouteObserver()],
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      theme: CupertinoThemeData(
        brightness: _dark ? Brightness.dark : Brightness.light,
      ),
      home: buildShowcaseScene(
        widget.scene,
        onBrightnessChanged: (dark) => setState(() => _dark = dark),
      ),
    );
  }
}

/// The scene for [id], shared by this entry point and the example app.
///
/// Without [onBrightnessChanged] the Display scene switches the brightness of
/// its own page, and Music opens modally with a close button.
Widget buildShowcaseScene(
  String id, {
  ValueChanged<bool>? onBrightnessChanged,
}) {
  final inApp = onBrightnessChanged == null;
  final Widget scene = switch (id) {
    'files' => const FilesScene(),
    'photos' => const PhotosScene(),
    'account' => const AccountScene(),
    'music' => MusicScene(rootMode: !inApp),
    'duo' => const DuoScene(),
    'event' => const EventScene(),
    'welcome' => const WelcomeScene(),
    'editor' => const EditorScene(),
    'notes' => const NotesScene(),
    _ when inApp => const _LocalBrightness(),
    _ => DisplayScene(onBrightnessChanged: onBrightnessChanged),
  };
  return CupertinoPageScaffold(child: scene);
}

/// The Display scene with its Appearance control driving its own page.
class _LocalBrightness extends StatefulWidget {
  const _LocalBrightness();

  @override
  State<_LocalBrightness> createState() => _LocalBrightnessState();
}

class _LocalBrightnessState extends State<_LocalBrightness> {
  bool? _dark;

  @override
  Widget build(BuildContext context) {
    final dark =
        _dark ?? CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return CupertinoTheme(
      data: CupertinoTheme.of(
        context,
      ).copyWith(brightness: dark ? Brightness.dark : Brightness.light),
      child: DisplayScene(
        onBrightnessChanged: (d) => setState(() => _dark = d),
      ),
    );
  }
}
