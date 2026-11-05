import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// A mail-style Mac window (2.3.0): `CNTabBarNative` as the window's
/// sidebar, `CNToolbar` as its toolbar, `CNNativeSheet` as its inspector,
/// and the message list in Flutter between them. Every name and message is
/// made up.
///
///   flutter run -d macos -t lib/showcase/showcase_app.dart --dart-define=SCENE=mailbox
class MailboxScene extends StatefulWidget {
  const MailboxScene({super.key});

  @override
  State<MailboxScene> createState() => _MailboxSceneState();
}

class _Message {
  const _Message(this.from, this.subject, this.preview, this.time, this.color);
  final String from;
  final String subject;
  final String preview;
  final String time;
  final Color color;
}

const _messages = [
  _Message(
    'Design Team',
    'New icon set for review',
    'The sidebar and toolbar symbols are ready. Comments by Friday?',
    '09:41',
    CupertinoColors.systemIndigo,
  ),
  _Message(
    'Alex Rivera',
    'Trip plan',
    'Train at 8:05, hotel near the old town, dinner booked for seven.',
    '08:12',
    CupertinoColors.systemOrange,
  ),
  _Message(
    'Mira Chen',
    'Photos from Saturday',
    'Twelve new photos in the shared album. The sunset ones came out great.',
    'Yesterday',
    CupertinoColors.systemPink,
  ),
  _Message(
    'Calendar',
    'Weekly sync moved',
    'Thursday 15:00 is now Thursday 16:00, same room.',
    'Yesterday',
    CupertinoColors.systemRed,
  ),
  _Message(
    'Jonas Berg',
    'Re: Garden bench',
    'Oak or teak? I can bring the samples on Sunday.',
    'Tuesday',
    CupertinoColors.systemGreen,
  ),
  _Message(
    'Book Club',
    'Next month’s pick',
    'Three votes for the sci-fi one, two for the memoir.',
    'Monday',
    CupertinoColors.systemTeal,
  ),
];

class _MailboxSceneState extends State<MailboxScene> {
  int _selected = 0;
  int _mailbox = 0;

  bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    if (_isMac) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWindowParts());
    }
  }

  @override
  void dispose() {
    if (_isMac) {
      CNNativeSheet.dismiss();
      CNTabBarNative.disable();
    }
    super.dispose();
  }

  Future<void> _showWindowParts() async {
    if (!mounted) return;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    await CNTabBarNative.enable(
      tabs: const [
        CNTab(title: 'Inbox', sfSymbol: CNSymbol('tray'), badgeCount: 3),
        CNTab(title: 'Drafts', sfSymbol: CNSymbol('doc')),
        CNTab(title: 'Sent', sfSymbol: CNSymbol('paperplane')),
        CNTab(title: 'Junk', sfSymbol: CNSymbol('xmark.bin')),
        CNTab(title: 'Archive', sfSymbol: CNSymbol('archivebox')),
      ],
      selectedIndex: _mailbox,
      isDark: dark,
      asRoot: true,
      showCloseButton: false,
      onTabSelected: (i) => setState(() => _mailbox = i),
    );
    if (!mounted) return;
    await CNNativeSheet.show(
      isDark: dark,
      dismissible: false,
      pages: const [
        CNSheetPage(
          title: 'Details',
          sfSymbol: CNSymbol('info.circle'),
          items: [
            CNListItem(
              title: 'From',
              subtitle: 'Design Team',
              leadingSymbol: CNSymbol('person.crop.circle'),
            ),
            CNListItem(
              title: 'Received',
              subtitle: 'Today at 09:41',
              leadingSymbol: CNSymbol('clock'),
            ),
            CNListItem(
              title: 'Attachments',
              subtitle: '24 symbols, 1 preview',
              leadingSymbol: CNSymbol('paperclip'),
              trailingText: '3.2 MB',
            ),
            CNListItem(
              title: 'Labels',
              subtitle: 'Work, Review',
              leadingSymbol: CNSymbol('tag'),
              showChevron: true,
            ),
          ],
        ),
        CNSheetPage(
          title: 'Thread',
          sfSymbol: CNSymbol('bubble.left.and.bubble.right'),
          badgeCount: 2,
          items: [
            CNListItem(
              title: 'Design Team',
              subtitle: 'New icon set for review',
            ),
            CNListItem(title: 'You', subtitle: 'Looks great, two notes inline'),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMac) {
      return const Center(child: Text('The Mailbox scene is a Mac window.'));
    }
    return Stack(
      children: [
        CNToolbar(
          title: 'Inbox',
          subtitle: '3 unread',
          items: [
            const CNToolbarSidebarToggle(),
            const CNToolbarSidebarTrackingSeparator(),
            CNToolbarButton(
              label: 'Filter',
              icon: const CNSymbol('line.3.horizontal.decrease.circle'),
              onPressed: () {},
            ),
            const CNToolbarSpace.flexible(),
            CNToolbarButton(
              label: 'Archive',
              icon: const CNSymbol('archivebox'),
              onPressed: () {},
            ),
            CNToolbarButton(
              label: 'Delete',
              icon: const CNSymbol('trash'),
              onPressed: () {},
            ),
            const CNToolbarMenu(
              label: 'Move',
              icon: CNSymbol('folder'),
              items: [
                CNPopupMenuItem(label: 'Work', icon: CNSymbol('briefcase')),
                CNPopupMenuItem(label: 'Travel', icon: CNSymbol('airplane')),
                CNPopupMenuItem(label: 'Receipts', icon: CNSymbol('doc.text')),
              ],
            ),
            CNToolbarButton(
              label: 'New Message',
              icon: const CNSymbol('square.and.pencil'),
              style: CNToolbarItemStyle.prominent,
              onPressed: () {},
            ),
            const CNToolbarSearch(placeholder: 'Search'),
            const CNToolbarInspectorTrackingSeparator(),
            const CNToolbarInspectorToggle(),
          ],
        ),
        ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _messages.length,
          separatorBuilder: (_, _) => const Padding(
            padding: EdgeInsets.only(left: 64),
            child: SizedBox(
              height: 0.5,
              child: ColoredBox(color: CupertinoColors.separator),
            ),
          ),
          itemBuilder: (context, i) => _row(context, i),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, int i) {
    final m = _messages[i];
    final selected = i == _selected;
    final primary = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    final secondary = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = i),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: selected
              ? CupertinoColors.systemBlue.withValues(alpha: 0.16)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(color: m.color, initial: m.from[0]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.from,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: primary,
                          ),
                        ),
                      ),
                      Text(
                        m.time,
                        style: TextStyle(fontSize: 12, color: secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.subject,
                    style: TextStyle(fontSize: 13, color: primary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.color, required this.initial});
  final Color color;
  final String initial;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Text(
      initial,
      style: const TextStyle(
        color: CupertinoColors.white,
        fontWeight: FontWeight.w600,
        fontSize: 17,
      ),
    ),
  );
}
