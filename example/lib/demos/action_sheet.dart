import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Demo for `CNActionSheet`.
///
/// On iOS every trigger presents a real `UIAlertController` in
/// `.actionSheet` style, so what you see is the system control: destructive
/// labels in the system red, cancel in its own detached row, and — on iOS 26 —
/// the Liquid Glass appearance the system applies with no opt-in.
///
/// The "anchored" trigger is the one that shows the iOS 26 behaviour change:
/// passing `anchorRect` makes the sheet appear over the button it came from on
/// iPhone, not just iPad.
class ActionSheetDemoPage extends StatefulWidget {
  const ActionSheetDemoPage({super.key, this.autoScenario});

  /// When set, the named scenario fires on the first frame instead of waiting
  /// for a tap.
  ///
  /// The simulator here has no tap automation (see `lib/pr_probe_entry.dart`),
  /// so screenshot verification drives the page through this instead. One of:
  /// `destructive`, `nocancel`, `titleonly`, `disabled`, `longlist`,
  /// `anchored`.
  final String? autoScenario;

  @override
  State<ActionSheetDemoPage> createState() => _ActionSheetDemoPageState();
}

class _ActionSheetDemoPageState extends State<ActionSheetDemoPage> {
  String _lastResult = '—';

  final GlobalKey _anchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final scenario = widget.autoScenario;
    if (scenario == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (scenario) {
        case 'destructive':
          _showDestructive();
        case 'nocancel':
          _showWithoutCancel();
        case 'titleonly':
          _showTitleAndMessageOnly();
        case 'disabled':
          _showWithDisabledAction();
        case 'longlist':
          _showLongList();
        case 'anchored':
          _showAnchored();
      }
    });
  }

  void _record(String? value) {
    // Every caller awaits `CNActionSheet.show` first, and a superseded sheet
    // resolves its caller as soon as the next one is requested, so the page can
    // be gone by the time the result lands.
    if (!mounted) return;
    setState(() => _lastResult = value ?? '(cancelled)');
  }

  Future<void> _showDestructive() async {
    final choice = await CNActionSheet.show<String>(
      context: context,
      title: 'Delete photo?',
      message: 'This cannot be undone.',
      actions: const [
        CNActionSheetAction(
          label: 'Delete',
          value: 'delete',
          isDestructive: true,
        ),
        CNActionSheetAction(label: 'Duplicate', value: 'duplicate'),
      ],
      cancelLabel: 'Cancel',
    );
    _record(choice);
  }

  Future<void> _showWithoutCancel() async {
    final choice = await CNActionSheet.show<String>(
      context: context,
      title: 'Sort by',
      actions: const [
        CNActionSheetAction(label: 'Name', value: 'name'),
        CNActionSheetAction(label: 'Date', value: 'date'),
        CNActionSheetAction(label: 'Size', value: 'size'),
      ],
    );
    _record(choice);
  }

  Future<void> _showTitleAndMessageOnly() async {
    final choice = await CNActionSheet.show<String>(
      context: context,
      title: 'Unsaved changes',
      message: 'Your draft will be kept until you close the app.',
      actions: const [
        CNActionSheetAction(label: 'Discard', value: 'discard'),
      ],
      cancelLabel: 'Keep editing',
    );
    _record(choice);
  }

  Future<void> _showWithDisabledAction() async {
    final choice = await CNActionSheet.show<String>(
      context: context,
      title: 'Export',
      message: 'PDF export needs a paid plan.',
      actions: const [
        CNActionSheetAction(label: 'Export as PNG', value: 'png'),
        CNActionSheetAction(label: 'Export as PDF', value: 'pdf', enabled: false),
      ],
      cancelLabel: 'Cancel',
    );
    _record(choice);
  }

  /// Deliberately exceeds the four-button ceiling the HIG recommends, so the
  /// scrolling behaviour is visible.
  Future<void> _showLongList() async {
    final choice = await CNActionSheet.show<String>(
      context: context,
      title: 'Move to album',
      actions: const [
        CNActionSheetAction(label: 'Favourites', value: 'favourites'),
        CNActionSheetAction(label: 'Travel', value: 'travel'),
        CNActionSheetAction(label: 'Screenshots', value: 'screenshots'),
        CNActionSheetAction(label: 'Receipts', value: 'receipts'),
        CNActionSheetAction(label: 'Family', value: 'family'),
        CNActionSheetAction(label: 'Recently deleted', value: 'deleted'),
      ],
      cancelLabel: 'Cancel',
    );
    _record(choice);
  }

  /// Passes the trigger button's own global rect, which is what gives the
  /// iOS 26 anchored presentation on iPhone as well as iPad.
  Future<void> _showAnchored() async {
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final anchorRect = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    final choice = await CNActionSheet.show<String>(
      context: context,
      actions: const [
        CNActionSheetAction(label: 'Share', value: 'share'),
        CNActionSheetAction(label: 'Copy link', value: 'copy'),
        CNActionSheetAction(
          label: 'Remove',
          value: 'remove',
          isDestructive: true,
        ),
      ],
      cancelLabel: 'Cancel',
      anchorRect: anchorRect,
    );
    _record(choice);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Action Sheet')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Every trigger below presents a native UIAlertController on iOS. '
              'Destructive labels should be the system red, disabled actions '
              'greyed out, and the sheet drawn in the system material. On '
              'iOS 26 an unanchored sheet is centred and groups the cancel '
              'button with the actions (side by side when there is only one), '
              'rather than putting it in the detached bottom row older iOS '
              'used.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text(
                    'Last result: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Expanded(
                    child: Text(
                      _lastResult,
                      style: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _trigger('Destructive + cancel', _showDestructive),
            _trigger('No cancel button', _showWithoutCancel),
            _trigger('Title and message only', _showTitleAndMessageOnly),
            _trigger('Disabled action', _showWithDisabledAction),
            _trigger('Long list (6 actions)', _showLongList),

            const SizedBox(height: 8),
            const Text(
              'Anchored — passes this button\'s rect as anchorRect. On iOS 26 '
              'the sheet appears over the button instead of at the bottom of '
              'the screen.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            CNButton(
              key: _anchorKey,
              label: 'Anchored to this button',
              onPressed: _showAnchored,
            ),
          ],
        ),
      ),
    );
  }

  Widget _trigger(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: CNButton(label: label, onPressed: onPressed),
      ),
    );
  }
}
