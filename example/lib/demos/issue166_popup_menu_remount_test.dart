import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #166: a `CNPopupMenuButton` that is mounted again is blank for a
/// few frames.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/166
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// A list header with a sort button is swapped for a loading placeholder
/// while the list reloads, and swapped back. Each time it comes back, a new
/// `CNPopupMenuButton` is mounted, and its place stays empty for about
/// three frames while the Flutter text next to it is already drawn. With a
/// reload after every sort change, the button blinks.
///
/// ### How this screen proves it
///
/// Row **A** swaps its header for a placeholder on every reload, so the
/// button is mounted again. Row **B** keeps its header mounted and hides it
/// with `Visibility(maintainState: true)`. Each reload also picks the next
/// sort label, as a sort change does. AUTO reloads every 1.5 s and prints
/// `CNB_RELOAD <n>` when the header comes back. Record the screen and step
/// through the frames after each reload:
///
///  * **Bug:** in row A, "A · 1,234 results" is back a few frames before the
///    sort button on its right.
///  * **Fixed:** the sort button is back in the same frame as the text, as
///    in row B.
class Issue166PopupMenuRemountTestPage extends StatefulWidget {
  /// Creates the #166 test page.
  const Issue166PopupMenuRemountTestPage({super.key, this.autoCycle = false});

  /// Reloads every 1.5 s and prints `CNB_RELOAD <n>`.
  final bool autoCycle;

  @override
  State<Issue166PopupMenuRemountTestPage> createState() =>
      _Issue166PopupMenuRemountTestPageState();
}

class _Issue166PopupMenuRemountTestPageState
    extends State<Issue166PopupMenuRemountTestPage> {
  static const _labels = ['Newest', 'Price: low to high', 'Price: high to low'];
  bool _loading = false;
  String _sort = _labels.first;
  Timer? _timer;
  int _reloads = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        debugPrint('CNB_READY 166');
        _toggleAuto();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Picks the next sort and reloads, as a sort change does.
  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _sort = _labels[(_labels.indexOf(_sort) + 1) % _labels.length];
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _loading = false);
    _reloads++;
    debugPrint('CNB_RELOAD $_reloads label="$_sort"');
    if (widget.autoCycle && _reloads >= 6) {
      _timer?.cancel();
      _timer = null;
      debugPrint('CNB_DONE 166');
    }
  }

  void _toggleAuto() {
    setState(() {
      if (_timer == null) {
        _timer = Timer.periodic(
          const Duration(milliseconds: 1500),
          (_) => _reload(),
        );
      } else {
        _timer!.cancel();
        _timer = null;
      }
    });
  }

  Widget _header(String title) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          CNPopupMenuButton(
            buttonLabel: _sort,
            height: 32,
            shrinkWrap: true,
            items: [
              for (final l in _labels)
                CNPopupMenuItem(label: l, checked: l == _sort),
            ],
            onSelected: (i) async {
              setState(() {
                _sort = _labels[i];
                _loading = true;
              });
              await Future<void>.delayed(const Duration(milliseconds: 500));
              if (mounted) setState(() => _loading = false);
            },
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 44,
      alignment: Alignment.centerLeft,
      child: Container(
        width: 120,
        height: 16,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caption = TextStyle(
      fontSize: 13,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#166 Popup menu remount'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'A: header swapped for a placeholder (remount)',
                style: caption,
              ),
              _loading ? _placeholder() : _header('A · 1,234 results'),
              const SizedBox(height: 32),
              Text('B: header kept mounted (Visibility)', style: caption),
              Stack(
                children: [
                  Visibility(
                    visible: !_loading,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: _header('B · 1,234 results'),
                  ),
                  if (_loading) _placeholder(),
                ],
              ),
              const SizedBox(height: 40),
              CupertinoButton.filled(
                onPressed: _reload,
                child: const Text('Reload'),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                onPressed: _toggleAuto,
                child: Text(
                  _timer == null ? 'Reload every 1.5 s' : 'Stop reloading',
                ),
              ),
              const SizedBox(height: 12),
              Text('Reloads: $_reloads', style: caption),
            ],
          ),
        ),
      ),
    );
  }
}
