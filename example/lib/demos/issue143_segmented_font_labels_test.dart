import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #143: `CNSegmentedControl` has no label font options, and its
/// labels can't change after it is created.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/143
/// Reported by @Ashhad08.
///
/// ### The claims
///
/// 1. No font family, size, weight or colour for the segment titles; the
///    only app-side option was the global `UISegmentedControl.appearance()`.
/// 2. `labels` are read only at creation: an in-app language switch left the
///    old titles until the view was recreated.
///
/// ### How this screen proves it
///
/// Two controls with the same segments: a plain one, and one in the pubspec
/// font Tajawal, grey titles, the selected one bold and indigo.
///
///  * **Font:** **fixed:** the second control's titles are in Tajawal and the
///    plain one keeps the system font (the style is per control).
///  * **Language switch** (or AUTO): both controls change to Arabic titles
///    in place, keeping the selected segment, and in Arabic the first
///    segment is on the right. **Bug:** the English titles stayed.
class Issue143SegmentedFontLabelsTestPage extends StatefulWidget {
  const Issue143SegmentedFontLabelsTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Switches the language after a moment and prints `CNB_SHOT <step>`.
  final bool autoCycle;

  @override
  State<Issue143SegmentedFontLabelsTestPage> createState() =>
      _Issue143SegmentedFontLabelsTestPageState();
}

class _Issue143SegmentedFontLabelsTestPageState
    extends State<Issue143SegmentedFontLabelsTestPage> {
  bool _arabic = false;
  int _index = 1;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    debugPrint('CNB_SHOT 143-english');
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    setState(() => _arabic = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    debugPrint('CNB_SHOT 143-arabic');
  }

  @override
  Widget build(BuildContext context) {
    final labels = _arabic
        ? const ['الكل', 'غير مقروء', 'مُعلَّم']
        : const ['All', 'Unread', 'Flagged'];
    return Directionality(
      textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
      child: CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('#143: Segmented font, labels'),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Arabic')),
                  CupertinoSwitch(
                    value: _arabic,
                    onChanged: (v) => setState(() => _arabic = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('System font'),
              const SizedBox(height: 6),
              CNSegmentedControl(
                labels: labels,
                selectedIndex: _index,
                onValueChanged: (i) => setState(() => _index = i),
              ),
              const SizedBox(height: 20),
              const Text('Tajawal, selected bold indigo'),
              const SizedBox(height: 6),
              CNSegmentedControl(
                labels: labels,
                selectedIndex: _index,
                onValueChanged: (i) => setState(() => _index = i),
                labelFontFamily: 'Tajawal',
                labelFontSize: 15,
                labelColor: CupertinoColors.systemGrey,
                selectedLabelFontWeight: FontWeight.w700,
                selectedLabelColor: CupertinoColors.systemIndigo,
              ),
              const SizedBox(height: 20),
              Text(
                'selected: $_index (${labels[_index]})',
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
