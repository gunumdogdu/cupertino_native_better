import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold, ScaffoldState;

/// Modal halo test for CNButton (Issue #29 follow-up).
///
/// v1.4.3 (the revert + dynamic `setTransitioning` approach) leaves the
/// button UNCLIPPED at rest, so the iOS 26 Liquid Glass capsule stretches
/// and renders its full soft-edge glow. Clipping is re-applied only while
/// the enclosing route is animating.
///
/// Open question: does the soft-edge glow of a stretched CNButton bleed
/// through the top edge of a modal sheet pushed over this page? If it
/// does, we also need to toggle containment while a modal is presented
/// (observer-based, same pattern as `CNTabBar.autoHideOnModal`).
///
/// Test each of the three modal types below and watch the area where the
/// stretched CNButton sits relative to the modal's top edge.
class CNButtonModalHaloTest extends StatefulWidget {
  const CNButtonModalHaloTest({super.key});

  @override
  State<CNButtonModalHaloTest> createState() => _CNButtonModalHaloTestState();
}

class _CNButtonModalHaloTestState extends State<CNButtonModalHaloTest> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _showCupertinoSheet() {
    // CNBottomSheet.showCupertino injects the geometry probe → host-page
    // CN-widgets above the sheet stay visible.
    CNBottomSheet.showCupertino<void>(
      context: context,
      pageBuilder: (ctx) => _SheetBody(
        title: 'showCupertinoSheet (via CNBottomSheet)',
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showCupertinoModalPopup() {
    final screenH = MediaQuery.of(context).size.height;
    CNBottomSheet.showModalPopup<void>(
      context: context,
      builder: (ctx) => _SheetBody(
        title: 'showCupertinoModalPopup (via CNBottomSheet)',
        height: screenH * 0.75,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showMaterialBottomSheet() {
    final screenH = MediaQuery.of(context).size.height;
    CNBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SheetBody(
        title: 'showModalBottomSheet (via CNBottomSheet)',
        height: screenH * 0.75,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showPersistentBottomSheet() {
    // `showBottomSheet` is a PERSISTENT Material bottom sheet — it is not
    // modal, does not block underlying content, and is anchored to a
    // `ScaffoldState` rather than pushed onto the Navigator. Because the
    // NavigatorObserver never sees it, we manually mark the modal-depth
    // counter active/inactive around it. We ALSO wrap the body with
    // CNSheetGeometryProbe so position-aware host-page hiding kicks in.
    final state = _scaffoldKey.currentState;
    if (state == null) return;
    final screenH = MediaQuery.of(context).size.height;
    final controller = state.showBottomSheet(
      (ctx) => CNSheetGeometryProbe(
        child: _SheetBody(
          title: 'showBottomSheet (persistent, manual probe)',
          height: screenH * 0.75,
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
    CNTabBarRouteObserver.markAnyModalActive();
    controller.closed.whenComplete(CNTabBarRouteObserver.markAnyModalInactive);
  }

  @override
  Widget build(BuildContext context) {
    // Material `Scaffold` wrap so `showBottomSheet` has an anchor; the
    // CupertinoPageScaffold underneath keeps the nav bar + background.
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: CupertinoColors.systemTeal,
      body: CupertinoPageScaffold(
        // Bright teal so any halo leak on the dark glass button is obvious.
        backgroundColor: CupertinoColors.systemTeal,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: CupertinoColors.systemTeal,
          middle: const Text('CNButton modal halo test'),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Stretched CNButtons below. Open each modal and watch the '
                  'top edge of the sheet for a Liquid Glass halo leaking '
                  'through from the buttons underneath.',
                  style: TextStyle(fontSize: 13, color: CupertinoColors.black),
                ),
                const SizedBox(height: 24),
                Center(
                  child: SizedBox(
                    width: 240,
                    height: 72,
                    child: CNButton.icon(
                      icon: const CNSymbol('gearshape.fill', size: 20),
                      onPressed: () {},
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 200,
                    height: 56,
                    child: CNButton(
                      label: 'Stretched label button',
                      icon: const CNSymbol('sparkles', size: 16),
                      onPressed: () {},
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: CNButton.icon(
                    icon: const CNSymbol('bell.fill', size: 22),
                    onPressed: () {},
                  ),
                ),
                const Spacer(),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    CupertinoButton.filled(
                      onPressed: _showCupertinoSheet,
                      child: const Text('showCupertinoSheet'),
                    ),
                    CupertinoButton.filled(
                      onPressed: _showCupertinoModalPopup,
                      child: const Text('showCupertinoModalPopup'),
                    ),
                    CupertinoButton.filled(
                      onPressed: _showMaterialBottomSheet,
                      child: const Text('showModalBottomSheet'),
                    ),
                    CupertinoButton.filled(
                      onPressed: _showPersistentBottomSheet,
                      child: const Text('showBottomSheet'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({
    required this.title,
    required this.onClose,
    this.height = 320,
  });

  final String title;
  final VoidCallback onClose;
  final double height;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> {
  bool _switchValue = false;

  @override
  Widget build(BuildContext context) {
    // Hard-size via a SizedBox so sheet routes that hand us unbounded
    // constraints (e.g. `showCupertinoModalPopup`) don't let the Spacer
    // stretch us beyond the intended height.
    return SizedBox(
      height: widget.height,
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'CNSwitch inside the sheet (mount-depth gate test — the '
                  'switch should render normally and stay tappable even '
                  'though it is a CN-widget inside a modal).',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'CNSwitch in sheet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  CNSwitch(
                    value: _switchValue,
                    onChanged: (v) => setState(() => _switchValue = v),
                  ),
                ],
              ),
              const Spacer(),
              CupertinoButton.filled(
                onPressed: widget.onClose,
                child: const Text('Close'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
