import UIKit

/// Hides the parts of a Liquid Glass view's glow and shadow that a Flutter
/// sheet, popup, dialog or page lies over (#156, #159).
///
/// Flutter draws what lies over a platform view inside the view's bounds
/// above it, but the glow draws past the bounds, over whatever Flutter
/// painted there. Clipping the view to its bounds stops that, and leaves the
/// glass flat. Masking out only the covered parts, outside the bounds, keeps
/// the full glass and shadow everywhere else.
///
/// The `cuts` of a `setTransitioning` call are `[left, top, right, bottom]`
/// rects in the view's own coordinates, outside its bounds and not
/// overlapping. None removes the mask.
enum CNHaloMask {
  /// Far enough past any view's bounds that nothing the view draws is lost.
  private static let extent = CGRect(x: -4000, y: -4000, width: 8000, height: 8000)

  static func apply(_ view: UIView, arguments: Any?) {
    let raw = ((arguments as? [String: Any])?["cuts"] as? [Any]) ?? []
    var cuts: [CGRect] = []
    for item in raw {
      guard let n = item as? [NSNumber], n.count == 4 else { continue }
      let rect = CGRect(
        x: CGFloat(n[0].doubleValue),
        y: CGFloat(n[1].doubleValue),
        width: CGFloat(n[2].doubleValue - n[0].doubleValue),
        height: CGFloat(n[3].doubleValue - n[1].doubleValue)
      ).intersection(extent)
      if !rect.isNull, rect.width > 0, rect.height > 0 { cuts.append(rect) }
    }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    defer { CATransaction.commit() }
    guard !cuts.isEmpty else {
      if view.layer.mask is CNHaloMaskLayer { view.layer.mask = nil }
      return
    }
    let mask = (view.layer.mask as? CNHaloMaskLayer) ?? CNHaloMaskLayer()
    let path = CGMutablePath()
    path.addRect(extent)
    for cut in cuts { path.addRect(cut) }
    mask.fillRule = .evenOdd
    mask.fillColor = UIColor.black.cgColor
    mask.frame = view.layer.bounds
    mask.path = path
    if view.layer.mask !== mask { view.layer.mask = mask }
  }
}

/// The mask [CNHaloMask] sets, so it never removes a mask set by anything
/// else.
final class CNHaloMaskLayer: CAShapeLayer {
  override func action(forKey event: String) -> CAAction? { nil }
}
