import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #171: `placeholderColor` is ignored by the iOS 26 `CNSearchBar`.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/171
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// The iOS 26 bar passed the placeholder as the `TextField`'s plain title,
/// so it always drew in the system grey; `placeholderColor` only coloured
/// the clear button. macOS and the bar drawn in Flutter already used it. Now
/// the placeholder is the field's `prompt`, in `placeholderColor`, and the
/// placeholder stays the field's label for VoiceOver. The new
/// `clearButtonColor` colours the clear button on its own; it defaults to
/// `placeholderColor`, so a bar that sets only that looks as before.
///
/// ### How this screen proves it
///
///  * **A**, `placeholderColor: red`. **Bug:** grey "Search cars".
///    **Fixed:** red.
///  * **B**, `placeholderColor: red`, `textColor: indigo`, with text: indigo
///    text and a red clear button (the default), as before.
///  * **C**, adds `clearButtonColor: green`: a green clear button.
///  * **D**, no colours: the system placeholder and clear button.
///
/// The probe's `FALLBACK=true` draws the same rows with the bar drawn in
/// Flutter; macOS shows its `NSSearchField`. AUTO prints
/// `CNB_SHOT 171-rest`.
class Issue171SearchBarPlaceholderColorTestPage extends StatefulWidget {
  /// Creates the #171 test page.
  const Issue171SearchBarPlaceholderColorTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Prints `CNB_SHOT 171-rest` once the bars are up.
  final bool autoCycle;

  @override
  State<Issue171SearchBarPlaceholderColorTestPage> createState() =>
      _Issue171SearchBarPlaceholderColorTestPageState();
}

class _Issue171SearchBarPlaceholderColorTestPageState
    extends State<Issue171SearchBarPlaceholderColorTestPage> {
  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      Future<void>.delayed(const Duration(seconds: 4), () {
        debugPrint('CNB_SHOT 171-rest');
        debugPrint('CNB_DONE');
      });
    }
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#171 Placeholder colour'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            _label('A. placeholderColor: red (fixed: red placeholder)'),
            const CNSearchBar(
              expandable: false,
              showCancelButton: false,
              placeholder: 'Search cars',
              placeholderColor: CupertinoColors.systemRed,
            ),
            _label('B. + textColor: indigo, text: red clear button'),
            const CNSearchBar(
              expandable: false,
              showCancelButton: false,
              placeholder: 'Search cars',
              placeholderColor: CupertinoColors.systemRed,
              textColor: CupertinoColors.systemIndigo,
              initialText: 'Hilux',
            ),
            _label('C. + clearButtonColor: green'),
            const CNSearchBar(
              expandable: false,
              showCancelButton: false,
              placeholder: 'Search cars',
              placeholderColor: CupertinoColors.systemRed,
              clearButtonColor: CupertinoColors.systemGreen,
              initialText: 'Corolla',
            ),
            _label('D. No colours: system placeholder and clear button'),
            const CNSearchBar(
              expandable: false,
              showCancelButton: false,
              placeholder: 'Search cars',
            ),
            const SizedBox(height: 12),
            const CNSearchBar(
              expandable: false,
              showCancelButton: false,
              placeholder: 'Search cars',
              initialText: 'Prado',
            ),
          ],
        ),
      ),
    );
  }
}
