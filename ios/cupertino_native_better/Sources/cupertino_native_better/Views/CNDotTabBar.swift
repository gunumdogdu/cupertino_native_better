import UIKit

/// The bar `CNTabBar` builds: a `CNLabelFontTabBar` that also draws a small
/// red dot on the icon of every item whose badge is
/// `CupertinoTabBarPlatformView.dotBadge` (Issue #105).
///
/// `UITabBarItem` has no dot badge (an empty value means none), and on iOS 26
/// its badge keeps one size whatever its text, so the item carries no system
/// badge and the bar draws the dot itself. The icons are found by where they
/// sit, one column per item from left to right, so nothing depends on UIKit's
/// private view classes. The dots are the bar's own subviews, above the Liquid
/// Glass platter, and are moved on every layout.
final class CNDotTabBar: CNLabelFontTabBar {
  private static let dotSize: CGFloat = 9

  /// Reused across layouts: adding or removing a subview inside
  /// `layoutSubviews` schedules another layout, so a bar that rebuilt its dots
  /// every time would lay itself out on every frame.
  private var dots: [UIView] = []

  override func layoutSubviews() {
    super.layoutSubviews()
    placeDots()
  }

  private func placeDots() {
    let frames = dotFrames()
    while dots.count < frames.count {
      let dot = UIView()
      dot.backgroundColor = .systemRed
      dot.layer.cornerRadius = CNDotTabBar.dotSize / 2
      dot.isUserInteractionEnabled = false
      addSubview(dot)
      dots.append(dot)
    }
    for (i, dot) in dots.enumerated() {
      guard i < frames.count else {
        dot.isHidden = true
        continue
      }
      dot.isHidden = false
      if dot.frame != frames[i] { dot.frame = frames[i] }
    }
    // Keep the dots above anything the bar adds later, such as a rebuilt platter.
    if let first = subviews.firstIndex(where: { dots.contains($0) }),
       subviews[first...].contains(where: { !dots.contains($0) }) {
      dots.forEach(bringSubviewToFront)
    }
  }

  /// Where each dot goes: the top-right of its item's icon.
  private func dotFrames() -> [CGRect] {
    guard let items = items, items.contains(where: { CupertinoTabBarPlatformView.isDot($0) }) else { return [] }

    // Every visible icon-sized image in the bar, in the bar's coordinates.
    var icons: [CGRect] = []
    func walk(_ view: UIView) {
      for sub in view.subviews where !sub.isHidden && sub.alpha > 0.01 && !dots.contains(sub) {
        if let image = sub as? UIImageView, image.image != nil {
          let r = image.convert(image.bounds, to: self)
          if r.width >= 12, r.width <= 60, r.height >= 12, r.height <= 60,
             bounds.insetBy(dx: -8, dy: -8).contains(r) {
            icons.append(r)
          }
        }
        walk(sub)
      }
    }
    walk(self)

    // One column per item: icons whose centres are within a few points share
    // a column (the selection lens holds a second copy of each icon).
    var columns: [[CGRect]] = []
    for r in icons.sorted(by: { $0.midX < $1.midX }) {
      if let last = columns.last?.last, abs(last.midX - r.midX) < 8 {
        columns[columns.count - 1].append(r)
      } else {
        columns.append([r])
      }
    }
    // Not one column per item: draw nothing rather than a dot in the wrong place.
    guard columns.count == items.count else { return [] }

    let d = CNDotTabBar.dotSize
    return items.enumerated().compactMap { i, item in
      guard CupertinoTabBarPlatformView.isDot(item),
            let icon = columns[i].max(by: { $0.width < $1.width }) else { return nil }
      return CGRect(x: icon.maxX - d * 0.65, y: icon.minY - d * 0.3, width: d, height: d)
    }
  }
}
