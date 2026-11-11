import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The global bounds of what a modal route paints (its sheet, popup or
/// dialog, not its barrier), for position-aware hiding and halo containment
/// of the CN widgets under it (#149). [Rect.zero] when it paints nothing,
/// null when that can't be told.
///
/// The route's render tree is walked from the root of its page, through
/// render objects known to paint only their children (padding, alignment,
/// clips, transforms, semantics, flex and stack layouts...), down to the
/// first ones that may paint themselves: the sheet's `Material`, a
/// `DecoratedBox`, a text, and so on. Their bounds make up the result. A
/// render object of any other kind counts as painting its whole box, so an
/// unknown tree errs on the side of covering more.
Rect? modalRouteContentRect(ModalRoute<dynamic> route) {
  final root = route.subtreeContext?.findRenderObject();
  if (root is! RenderBox || !root.attached || !root.hasSize) return null;
  final walk = _ContentWalk();
  final rect = walk.bounds(root);
  if (walk.unknown) return null;
  return rect ?? Rect.zero;
}

class _ContentWalk {
  static const int _budget = 600;

  bool unknown = false;
  int _visited = 0;

  /// The global bounds of what [ro] paints, or null when it paints nothing.
  Rect? bounds(RenderObject ro) {
    if (unknown) return null;
    if (++_visited > _budget || ro is! RenderBox) {
      unknown = true;
      return null;
    }
    if (!ro.hasSize || ro.size.isEmpty) return null;
    if (ro is RenderOffstage && ro.offstage) return null;
    if (ro is RenderOpacity && ro.opacity == 0) return null;
    final rect = MatrixUtils.transformRect(
      ro.getTransformTo(null),
      Offset.zero & ro.size,
    );
    if (!_paintsOnlyChildren(ro)) return rect;

    Rect? union;
    void add(RenderObject child) {
      final b = bounds(child);
      if (b != null && !b.isEmpty) {
        union = union == null ? b : union!.expandToInclude(b);
      }
    }

    if (ro is RenderIndexedStack) {
      final index = ro.index;
      var i = 0;
      ro.visitChildren((child) {
        if (i++ == index) add(child);
      });
    } else {
      ro.visitChildren(add);
    }
    final u = union;
    if (u == null) return null;
    return _clips(ro) ? u.intersect(rect) : u;
  }

  static bool _clips(RenderBox ro) =>
      ro is RenderClipRect ||
      ro is RenderClipRRect ||
      ro is RenderClipOval ||
      ro is RenderClipPath;

  /// Render objects that paint nothing of their own, only their children.
  static bool _paintsOnlyChildren(RenderBox ro) =>
      // Shifted boxes (padding, alignment, custom single-child layouts such
      // as the Material bottom sheet's) paint their child at an offset.
      ro is RenderShiftedBox ||
      ro is RenderRepaintBoundary ||
      ro is RenderSemanticsAnnotations ||
      ro is RenderMergeSemantics ||
      ro is RenderBlockSemantics ||
      ro is RenderExcludeSemantics ||
      ro is RenderIndexedSemantics ||
      ro is RenderMetaData ||
      ro is RenderIgnorePointer ||
      ro is RenderAbsorbPointer ||
      ro is RenderPointerListener ||
      ro is RenderMouseRegion ||
      ro is RenderOffstage ||
      ro is RenderOpacity ||
      ro is RenderAnimatedOpacity ||
      ro is RenderTransform ||
      ro is RenderFractionalTranslation ||
      ro is RenderFittedBox ||
      ro is RenderConstrainedBox ||
      ro is RenderLimitedBox ||
      ro is RenderAspectRatio ||
      ro is RenderIntrinsicWidth ||
      ro is RenderIntrinsicHeight ||
      ro is RenderAnnotatedRegion ||
      ro is RenderClipRect ||
      ro is RenderClipRRect ||
      ro is RenderClipOval ||
      ro is RenderClipPath ||
      ro is RenderFlex ||
      ro is RenderStack ||
      ro is RenderWrap ||
      ro is RenderListBody ||
      ro is RenderCustomMultiChildLayoutBox;
}
