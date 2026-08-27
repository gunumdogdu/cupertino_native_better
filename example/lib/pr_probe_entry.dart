// Headless-ish probe entrypoint for PR verification.
//
// The simulator has no tap automation available here, so instead of driving
// the demo list by hand this entrypoint boots straight into one PR test page
// in one configuration, chosen by --dart-define. Screenshot with
// `xcrun simctl io booted screenshot`.
//
//   flutter run -t lib/pr_probe_entry.dart \
//     --dart-define=PROBE=pr66 --dart-define=BACKDROP=split --dart-define=BRIGHTNESS=light
//
//   flutter run -t lib/pr_probe_entry.dart \
//     --dart-define=PROBE=pr67 --dart-define=ICON=chevron --dart-define=SIZE=20
//
// PROBE=pr67report additionally dumps the MAE/cost table to the run log.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;

import 'demos/pr66_glass_image_asset_tint_test.dart';
import 'demos/pr67_icon_supersample_test.dart';

const String _probe = String.fromEnvironment('PROBE', defaultValue: 'pr67');
const String _backdrop = String.fromEnvironment(
  'BACKDROP',
  defaultValue: 'split',
);
const String _brightness = String.fromEnvironment(
  'BRIGHTNESS',
  defaultValue: 'light',
);
const String _icon = String.fromEnvironment('ICON', defaultValue: 'chevron');
const String _size = String.fromEnvironment('SIZE', defaultValue: '20');
const String _accent = String.fromEnvironment('ACCENT', defaultValue: 'blue');

/// Stamped into the nav bar so a before/after screenshot pair can't be mixed up.
const String _label = String.fromEnvironment('LABEL', defaultValue: '');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (_probe == 'pr67report') {
    WidgetsBinding.instance.addPostFrameCallback((_) => pr67PrintReport());
  }
  runApp(const _ProbeApp());
}

class _ProbeApp extends StatelessWidget {
  const _ProbeApp();

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      theme: CupertinoThemeData(
        brightness: _brightness == 'dark' ? Brightness.dark : Brightness.light,
        primaryColor: _accent == 'pink'
            ? CupertinoColors.systemPink
            : CupertinoColors.systemBlue,
      ),
      home: _home(),
    );
  }

  Widget _home() {
    if (_probe.startsWith('pr66')) {
      return Pr66GlassImageAssetTintTestPage(
        initialBackdrop: _backdrop,
        initialBrightness: _brightness,
      );
    }
    if (_probe == 'pr67native') {
      return Pr67NativeStripPage(label: _label);
    }
    return Pr67IconSupersampleTestPage(
      initialIcon: _icon,
      initialSize: double.tryParse(_size),
    );
  }
}
