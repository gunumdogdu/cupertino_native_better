// Repro for the Music scene bug: pops the route of a page whose
// CNTabBarNative is presented full screen, in code, and logs what happens.
//   flutter run -t lib/music_pop_probe_entry.dart [--dart-define=ROOT=true]
// Logs lines starting with MUSICPOP.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'showcase/showcase_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // EDGE=true: the app keeps the home indicator visible (SystemUiMode.edgeToEdge).
  if (const bool.fromEnvironment('EDGE')) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  runApp(const CupertinoApp(home: _Home()));
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  String _status = 'starting';
  int _frames = 0;

  void _log(String s) {
    debugPrint('MUSICPOP ${DateTime.now().toIso8601String()} $s');
    if (mounted) setState(() => _status = s);
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPersistentFrameCallback((_) => _frames++);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final nav = Navigator.of(context);
    _log('push');
    final popped = nav.push(
      CupertinoPageRoute<void>(builder: (_) => buildShowcaseScene('music')),
    );
    unawaited(popped.then((_) => _log('route future completed')));
    await Future<void>.delayed(
      const Duration(seconds: int.fromEnvironment('DELAY', defaultValue: 10)),
    );
    _log('pop in code (frames so far $_frames)');
    nav.pop();
    for (var i = 1; i <= 8; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      _log('t+${i}s frames $_frames');
    }
  }

  @override
  Widget build(BuildContext context) =>
      CupertinoPageScaffold(child: Center(child: Text('Home · $_status')));
}
