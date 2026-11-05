import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// Issues Test Page - Testing popup menu and switch issues
class IssuesTestPage extends StatefulWidget {
  const IssuesTestPage({super.key});

  @override
  State<IssuesTestPage> createState() => _IssuesTestPageState();
}

class _IssuesTestPageState extends State<IssuesTestPage> {
  bool _switchValue = false;
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Issues Test')),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                'Issue #3: Popup menu order',
                'Test popup that opens upward - items should be in correct order',
                _buildIssue3Test(),
              ),
              _buildSection(
                'Issue #4: CNSwitch + keyboard',
                'Type in field to show keyboard - switch should not move',
                _buildIssue4Test(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String subtitle, Widget child) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildIssue3Test() {
    final items = [
      CNPopupMenuItem(label: '1. First Item', icon: CNSymbol('1.circle')),
      CNPopupMenuItem(label: '2. Second Item', icon: CNSymbol('2.circle')),
      CNPopupMenuItem(label: '3. Third Item', icon: CNSymbol('3.circle')),
      CNPopupMenuItem(label: '4. Fourth Item', icon: CNSymbol('4.circle')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CNPopupMenuButton.icon(
              buttonIcon: CNSymbol('ellipsis.circle.fill'),
              items: items,
              onSelected: (index) {
                debugPrint('Native behavior - Selected item $index');
              },
            ),
            const SizedBox(width: 8),
            const Text('Native (reversed when upward)'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            CNPopupMenuButton.icon(
              buttonIcon: CNSymbol('ellipsis.circle.fill'),
              items: items,
              preserveTopToBottomOrder: true,
              onSelected: (index) {
                debugPrint('Preserved order - Selected item $index');
              },
            ),
            const SizedBox(width: 8),
            const Text('preserveTopToBottomOrder: true'),
          ],
        ),
      ],
    );
  }

  Widget _buildIssue4Test() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('CNSwitch: '),
            CNSwitch(
              value: _switchValue,
              onChanged: (v) => setState(() => _switchValue = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CupertinoTextField(
          controller: _textController,
          placeholder: 'Type here to show keyboard',
        ),
      ],
    );
  }
}
