import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

import '../ios_kit.dart';

/// An account page whose actions open the native alert and action sheet.
class AccountScene extends StatefulWidget {
  const AccountScene({super.key});

  @override
  State<AccountScene> createState() => _AccountSceneState();
}

class _AccountSceneState extends State<AccountScene> {
  final _deleteKey = GlobalKey();

  Future<void> _signOut() async {
    await CNAlert.show<String>(
      context: context,
      title: 'Sign Out?',
      message:
          'Your documents and photos stay in iCloud. You can sign back '
          'in at any time.',
      actions: const [
        CNAlertAction(label: 'Cancel', isCancel: true),
        CNAlertAction(label: 'Sign Out', value: 'out', isDestructive: true),
      ],
    );
  }

  Future<void> _delete() async {
    final box = _deleteKey.currentContext!.findRenderObject()! as RenderBox;
    await CNActionSheet.show<String>(
      context: context,
      title: 'Delete this account?',
      message: 'Everything stored with it is removed from all your devices.',
      actions: const [
        CNActionSheetAction(
          label: 'Delete Account',
          value: 'delete',
          isDestructive: true,
        ),
        CNActionSheetAction(label: 'Download My Data', value: 'download'),
      ],
      cancelLabel: 'Cancel',
      anchorRect: box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return IOSPage(
      title: 'Account',
      leading: const GlassCircleButton(symbol: 'chevron.left', label: 'Back'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFA5A9B4), Color(0xFF858A96)],
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'MS',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Maya Sato',
                style: IOS.largeTitle.copyWith(
                  fontSize: 28,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'maya.sato@icloud.com',
                style: IOS.footnote.copyWith(color: secondary),
              ),
            ],
          ),
        ),
        const IOSSection(
          rows: [
            IOSRow(
              title: 'Personal Information',
              icon: 'person.text.rectangle.fill',
              iconColor: CupertinoColors.systemGrey,
              chevron: true,
            ),
            IOSRow(
              title: 'Sign-In & Security',
              icon: 'lock.shield.fill',
              iconColor: CupertinoColors.systemGrey,
              chevron: true,
            ),
            IOSRow(
              title: 'Payment & Shipping',
              icon: 'creditcard.fill',
              iconColor: CupertinoColors.systemGrey,
              value: 'Visa',
              chevron: true,
            ),
            IOSRow(
              title: 'Subscriptions',
              icon: 'arrow.clockwise.circle.fill',
              iconColor: CupertinoColors.systemGrey,
              chevron: true,
            ),
          ],
        ),
        const IOSSection(
          rows: [
            IOSRow(
              title: 'iCloud',
              icon: 'icloud.fill',
              iconColor: CupertinoColors.systemBlue,
              value: '50 GB',
              chevron: true,
            ),
            IOSRow(
              title: 'Family',
              icon: 'person.2.fill',
              iconColor: CupertinoColors.systemBlue,
              value: '4 Members',
              chevron: true,
            ),
            IOSRow(
              title: 'Find My',
              icon: 'location.fill',
              iconColor: CupertinoColors.systemGreen,
              chevron: true,
            ),
          ],
        ),
        IOSSection(
          rows: [
            IOSRow(
              title: 'Sign Out',
              destructive: true,
              centered: true,
              onTap: _signOut,
            ),
          ],
        ),
        IOSSection(
          rows: [
            IOSRow(
              key: _deleteKey,
              title: 'Delete Account…',
              destructive: true,
              centered: true,
              onTap: _delete,
            ),
          ],
        ),
      ],
    );
  }
}
