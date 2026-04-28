import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        AnimationStyle,
        CalendarDatePicker,
        DatePickerMode,
        Durations,
        Material,
        MaterialType,
        RoundedRectangleBorder,
        Scaffold,
        ScaffoldState,
        kToolbarHeight,
        showModalBottomSheet;

/// Issue #36 reproduction: a card-shaped `LiquidGlassContainer`'s border
/// remains visible behind a modal sheet pushed over it. Mirrors the
/// reporter's layout — card at the top with partner info inside.
class Issue36LiquidGlassModalTest extends StatefulWidget {
  const Issue36LiquidGlassModalTest({super.key});

  @override
  State<Issue36LiquidGlassModalTest> createState() =>
      _Issue36LiquidGlassModalTestState();
}

class _Issue36LiquidGlassModalTestState
    extends State<Issue36LiquidGlassModalTest> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _showCupertinoSheet() {
    showCupertinoSheet<void>(
      context: context,
      builder: (ctx) => _SheetBody(
        title: 'showCupertinoSheet',
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showCupertinoModalPopup() {
    final h = MediaQuery.of(context).size.height;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _SheetBody(
        title: 'showCupertinoModalPopup',
        height: h * 0.8,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showMaterialBottomSheet() {
    // Mirror the issue reporter's exact `showModalBottomSheet` invocation
    // so we hit the same modal configuration: rounded top, custom
    // constraints, scaffold-bg matching, antiAlias clip, bounce
    // animation, root navigator, etc. This is the closest visual repro
    // of their live bug we can construct.
    final media = MediaQuery.of(context);
    final maxH = media.size.height - media.padding.top - kToolbarHeight;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: false,
      constraints: BoxConstraints(maxHeight: maxH),
      backgroundColor: CupertinoColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      sheetAnimationStyle: AnimationStyle(
        curve: Curves.bounceIn,
        reverseCurve: Curves.bounceOut,
        duration: Durations.medium3,
        reverseDuration: Durations.medium1,
      ),
      builder: (ctx) => _SheetBody(
        title: 'showModalBottomSheet (issue setup)',
        height: maxH,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showPersistentBottomSheet() {
    final state = _scaffoldKey.currentState;
    if (state == null) return;
    final h = MediaQuery.of(context).size.height;
    final controller = state.showBottomSheet(
      (ctx) => _SheetBody(
        title: 'showBottomSheet (persistent)',
        height: h * 0.8,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
    CNTabBarRouteObserver.markAnyModalActive();
    controller.closed.whenComplete(CNTabBarRouteObserver.markAnyModalInactive);
  }

  @override
  Widget build(BuildContext context) {
    // Match the issue reporter's app: white background, black pill
    // buttons, white card. Helps visually compare against image #19.
    const scaffoldBg = CupertinoColors.white;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: scaffoldBg,
      body: CupertinoPageScaffold(
        backgroundColor: scaffoldBg,
        navigationBar: const CupertinoNavigationBar(
          backgroundColor: scaffoldBg,
          middle: Text('#36'),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Open a sheet — the card BELOW the buttons should be '
                  'fully covered by the modal. If you can still see the '
                  "card's glass border / shape behind the sheet's scrim, "
                  'the z-order is leaking.',
                  style: TextStyle(fontSize: 13, color: CupertinoColors.black),
                ),
                const SizedBox(height: 12),
                _PillButton(
                  label: 'showCupertinoSheet',
                  filled: true,
                  onPressed: _showCupertinoSheet,
                ),
                const SizedBox(height: 8),
                _PillButton(
                  label: 'showCupertinoModalPopup',
                  filled: true,
                  onPressed: _showCupertinoModalPopup,
                ),
                const SizedBox(height: 8),
                _PillButton(
                  label: 'showModalBottomSheet',
                  filled: false,
                  onPressed: _showMaterialBottomSheet,
                ),
                const SizedBox(height: 8),
                _PillButton(
                  label: 'showBottomSheet',
                  filled: false,
                  onPressed: _showPersistentBottomSheet,
                ),
                const SizedBox(height: 16),
                // Mirror the issue reporter's `_AdaptiveGlassContainer`
                // exactly — no tint, no effect override, just rect shape
                // with cornerRadius: 15 and EdgeInsets.all(13) padding.
                LiquidGlassContainer(
                  config: const LiquidGlassConfig(
                    cornerRadius: 15,
                    shape: CNGlassEffectShape.rect,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'test partner 111',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: const [
                                  Icon(CupertinoIcons.location, size: 16),
                                  SizedBox(width: 6),
                                  Icon(CupertinoIcons.phone, size: 16),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemRed.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      CupertinoIcons.clock,
                                      size: 12,
                                      color: CupertinoColors.systemRed,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Closed',
                                      style: TextStyle(
                                        color: CupertinoColors.systemRed,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          CupertinoIcons.location_north_fill,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? CupertinoColors.black : CupertinoColors.white,
          borderRadius: BorderRadius.circular(28),
          border: filled
              ? null
              : Border.all(color: CupertinoColors.systemGrey4, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? CupertinoColors.white : CupertinoColors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.onClose,
    this.height = 320,
  });

  final String title;
  final VoidCallback onClose;
  final double height;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SizedBox(
      height: height,
      // Material ancestor needed by `CalendarDatePicker`. Type=transparency
      // keeps the sheet's own background visible (no extra surface paint).
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'test partner 111',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: CalendarDatePicker(
                      initialDate: now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 1),
                      initialCalendarMode: DatePickerMode.day,
                      onDateChanged: (_) {},
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PillButton(
                    label: 'Select Day',
                    filled: true,
                    onPressed: onClose,
                  ),
                  const SizedBox(height: 8),
                  _PillButton(
                    label: 'Cancel',
                    filled: false,
                    onPressed: onClose,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '($title)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
