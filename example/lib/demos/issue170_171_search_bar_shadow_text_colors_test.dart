import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issues #170, #171 and #173: `CNSearchBar` on iOS 26.
///
/// * https://github.com/gunumdogdu/cupertino_native_better/issues/170
/// * https://github.com/gunumdogdu/cupertino_native_better/issues/171
/// * https://github.com/gunumdogdu/cupertino_native_better/issues/173
///
/// Reported by @Ashhad08.
///
/// ### #170: glass shadow and initial text
///
/// The Liquid Glass capsule was clipped to its shape twice (SwiftUI
/// `.clipShape(Capsule())` and a Flutter `ClipRRect`), which cut off the
/// soft shadow iOS 26 glass draws around itself, so on a white page the bar
/// almost disappeared. There was also no way to open the bar with text.
///
///  * **Bug:** bars A and C look the same: a flat capsule.
///  * **Fixed:** bar A has the soft glass shadow and stands out from the
///    white page; bar C (`glassShadow: false`) is the flat capsule of
///    before. Bar B opens with "Land Cruiser" in it, and the log below does
///    not list it as a change.
///
/// ### #171: placeholder colour
///
/// The placeholder was the `TextField`'s title string, which SwiftUI always
/// draws in the system's placeholder grey; `placeholderColor` only coloured
/// the clear button.
///
///  * **Bug:** bar A's placeholder is grey.
///  * **Fixed:** bar A's placeholder is red. Bar B's clear button is green
///    (`clearIcon.color`), and bar A's clear button red once you type.
///
/// ### #173: right to left and label font
///
/// The bar took the system's direction, not Flutter's, and had no font
/// options.
///
///  * **Bug:** bar E (inside `Directionality.rtl`) has the magnifying glass
///    on the left and Cancel on the right; bar F is in the system font.
///  * **Fixed:** bar E is mirrored: magnifying glass and placeholder on the
///    right, Cancel on the left. Bar F's text, placeholder and Cancel are
///    Avenir Next, 20 pt, bold.
class Issue170171SearchBarTestPage extends StatefulWidget {
  const Issue170171SearchBarTestPage({super.key});

  @override
  State<Issue170171SearchBarTestPage> createState() =>
      _Issue170171SearchBarTestPageState();
}

class _Issue170171SearchBarTestPageState
    extends State<Issue170171SearchBarTestPage> {
  final _log = <String>[];

  void _add(String line) => setState(() => _log.insert(0, line));

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 13, color: CupertinoColors.systemGrey);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#170 / #171 / #173 CNSearchBar'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'A: default (glass shadow), placeholderColor red',
              style: label,
            ),
            const SizedBox(height: 8),
            CNSearchBar(
              expandable: false,
              showCancelButton: false,
              placeholder: 'Search cars',
              placeholderColor: CupertinoColors.systemRed,
              onChanged: (t) => _add('A changed: "$t"'),
            ),
            const SizedBox(height: 28),
            const Text(
              'B: initialText "Land Cruiser", clearIcon green',
              style: label,
            ),
            const SizedBox(height: 8),
            CNSearchBar(
              expandable: false,
              showCancelButton: false,
              initialText: 'Land Cruiser',
              clearIcon: const CNSymbol(
                'xmark.circle.fill',
                color: CupertinoColors.systemGreen,
              ),
              onChanged: (t) => _add('B changed: "$t"'),
            ),
            const SizedBox(height: 28),
            const Text('C: glassShadow: false (flat, as before)', style: label),
            const SizedBox(height: 8),
            const CNSearchBar(
              expandable: false,
              showCancelButton: false,
              glassShadow: false,
            ),
            const SizedBox(height: 28),
            const Text('D: expandable, starts collapsed', style: label),
            const SizedBox(height: 8),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: CNSearchBar(placeholder: 'Search'),
            ),
            const SizedBox(height: 28),
            const Text('E: Directionality.rtl, Arabic', style: label),
            const SizedBox(height: 8),
            const Directionality(
              textDirection: TextDirection.rtl,
              child: CNSearchBar(
                expandable: false,
                placeholder: 'ابحث عن سيارة',
                cancelText: 'إلغاء',
              ),
            ),
            const SizedBox(height: 28),
            const Text('F: labelFont Avenir Next, 20, bold', style: label),
            const SizedBox(height: 8),
            const CNSearchBar(
              expandable: false,
              placeholder: 'Search cars',
              labelFontFamily: 'Avenir Next',
              labelFontSize: 20,
              labelFontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 28),
            const Text('onChanged log (newest first):', style: label),
            for (final line in _log) Text(line),
            if (_log.isEmpty) const Text('(nothing reported)'),
          ],
        ),
      ),
    );
  }
}
