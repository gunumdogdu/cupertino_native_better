import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// CNSearchBar: an expandable bar, an always open one with recent searches
/// (macOS) and a tint, and the controller's methods, with every callback
/// logged on the page.
///
/// On macOS the bar is an NSSearchField: type into it, press Return, then
/// Esc, and the Flutter text field below takes the keyboard again.
class SearchBarDemoPage extends StatefulWidget {
  const SearchBarDemoPage({super.key});

  @override
  State<SearchBarDemoPage> createState() => _SearchBarDemoPageState();
}

class _SearchBarDemoPageState extends State<SearchBarDemoPage> {
  final _controller = CNSearchBarController();
  final _log = <String>[];
  bool _pink = false;

  void _record(String event) {
    // Printed too, so a run can be checked from its log.
    debugPrint('SEARCH_EVENT $event');
    setState(() {
      _log.insert(0, event);
      if (_log.length > 8) _log.removeLast();
    });
  }

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );

  Widget _button(String label, VoidCallback onPressed) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    minimumSize: const Size(0, 32),
    onPressed: onPressed,
    child: Text(label, style: const TextStyle(fontSize: 14)),
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Search Bar')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          children: [
            _caption('Expandable: a button that opens into the field'),
            CNSearchBar(
              placeholder: 'Search messages',
              controller: _controller,
              autofocus: true,
              onChanged: (text) => _record('changed "$text"'),
              onSubmitted: (text) => _record('submitted "$text"'),
              onCancelTap: () => _record('cancel'),
              onExpandStateChanged: (open) =>
                  _record(open ? 'expanded' : 'collapsed'),
            ),
            Wrap(
              children: [
                _button('Expand', () => _controller.expand()),
                _button('Collapse', () => _controller.collapse()),
                _button('Set "flutter"', () => _controller.setText('flutter')),
                _button('Clear', () => _controller.clear()),
                _button('Focus', () => _controller.focus()),
                _button('Unfocus', () => _controller.unfocus()),
              ],
            ),
            _caption('Always open, tinted, recent searches (macOS)'),
            CNSearchBar(
              key: const ValueKey('open'),
              placeholder: 'Search files',
              expandable: false,
              tint: _pink
                  ? CupertinoColors.systemPink
                  : CupertinoColors.systemGreen,
              recentsAutosaveName: 'cnb_example_files',
              onChanged: (text) => _record('files changed "$text"'),
              onSubmitted: (text) => _record('files submitted "$text"'),
              onCancelTap: () => _record('files cancel'),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _button(
                'Tint: ${_pink ? 'pink' : 'green'}',
                () => setState(() => _pink = !_pink),
              ),
            ),
            _caption('A Flutter text field, to check the keyboard comes back'),
            const CupertinoTextField(placeholder: 'Flutter text field'),
            _caption('Events, newest first'),
            for (final event in _log)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(event, style: const TextStyle(fontSize: 14)),
              ),
          ],
        ),
      ),
    );
  }
}
