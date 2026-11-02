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

  /// The menu each item opens instead of selecting itself, by item index.
  /// Each one is shown by a clear button over the item, as a tab bar item
  /// can't carry a menu.
  var itemMenus: [Int: UIMenu] = [:] {
    didSet { setNeedsLayout() }
  }

  /// The buttons are inside the bar, so its own gestures still get their
  /// touches: the glass reacts under the finger as on any item. Those
  /// gestures also select the item, which the bar's delegate undoes.
  private var menuButtons: [Int: CNTabMenuButton] = [:]

  /// Whether item [i] opens its menu: it has one, and its button is placed.
  /// Without a button, a tap selects the item as on any other.
  func opensMenu(at i: Int) -> Bool {
    guard let button = menuButtons[i] else { return false }
    return !button.isHidden
  }

  /// Opens the menu of item [i] unless it's already shown: a finger sliding
  /// along the bar onto the item selects it without touching its button.
  func showMenu(at i: Int) {
    guard let button = menuButtons[i], !button.isHidden, !button.isMenuVisible else { return }
    if #available(iOS 17.4, *) { button.performPrimaryAction() }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    placeDots()
    placeMenuButtons()
  }

  private func placeMenuButtons() {
    for (i, button) in menuButtons where itemMenus[i] == nil {
      button.removeFromSuperview()
      menuButtons[i] = nil
    }
    guard !itemMenus.isEmpty else { return }
    let columns = iconColumns()
    for (i, menu) in itemMenus {
      let button = menuButtons[i] ?? {
        let button = CNTabMenuButton(type: .custom)
        button.showsMenuAsPrimaryAction = true
        // Keep the given order when the menu opens upward from the bar.
        if #available(iOS 16.0, *) { button.preferredMenuElementOrder = .fixed }
        // Changes held back while the menu was shown.
        button.onMenuHidden = { [weak self] in self?.setNeedsLayout() }
        addSubview(button)
        menuButtons[i] = button
        return button
      }()
      // The bar lays itself out again as the menu opens. Moving, hiding or
      // re-menuing the button then makes UIKit show the menu again, which
      // closes an open submenu.
      if button.isMenuVisible { continue }
      if button.menu !== menu { button.menu = menu }
      // VoiceOver reads the button, not the item under it.
      if let items, i < items.count {
        button.accessibilityLabel = items[i].title ?? items[i].accessibilityLabel
      }
      // Not one column per item: no button, so a tap still selects the item.
      guard let columns, i < columns.count,
            let icon = columns[i].max(by: { $0.width < $1.width }) else {
        button.isHidden = true
        continue
      }
      button.isHidden = false
      let side = bounds.height
      let frame = CGRect(x: icon.midX - side / 2, y: 0, width: side, height: side)
      if button.frame != frame { button.frame = frame }
      // Above the item's own views, which the bar may rebuild. Dots don't
      // count: they take no touches, and moving them up would move them
      // back above the buttons on every layout.
      if let at = subviews.firstIndex(of: button),
         subviews[(at + 1)...].contains(where: { !($0 is CNTabMenuButton) && !dots.contains($0) }) {
        bringSubviewToFront(button)
      }
    }
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
       subviews[first...].contains(where: { !dots.contains($0) && !($0 is CNTabMenuButton) }) {
      dots.forEach(bringSubviewToFront)
    }
  }

  /// Where each dot goes: the top-right of its item's icon.
  private func dotFrames() -> [CGRect] {
    guard let items = items, items.contains(where: { CupertinoTabBarPlatformView.isDot($0) }),
          let columns = iconColumns() else { return [] }

    let d = CNDotTabBar.dotSize
    return items.enumerated().compactMap { i, item in
      guard CupertinoTabBarPlatformView.isDot(item),
            let icon = columns[i].max(by: { $0.width < $1.width }) else { return nil }
      return CGRect(x: icon.maxX - d * 0.65, y: icon.minY - d * 0.3, width: d, height: d)
    }
  }

  /// The icons of each item, one column per item from left to right, or nil
  /// when they can't be told apart.
  private func iconColumns() -> [[CGRect]]? {
    guard let items = items else { return nil }

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
    // Not one column per item: nothing rather than something in the wrong place.
    guard columns.count == items.count else { return nil }
    // Right to left, the first item is the rightmost.
    return effectiveUserInterfaceLayoutDirection == .rightToLeft ? columns.reversed() : columns
  }
}

/// The clear button over a tab bar item that opens its menu. It tells when
/// that menu is shown, so the bar leaves it alone meanwhile.
final class CNTabMenuButton: UIButton {
  private(set) var isMenuVisible = false
  var onMenuHidden: (() -> Void)?

  override func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    willDisplayMenuFor configuration: UIContextMenuConfiguration,
    animator: UIContextMenuInteractionAnimating?
  ) {
    super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
    isMenuVisible = true
  }

  override func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    willEndFor configuration: UIContextMenuConfiguration,
    animator: UIContextMenuInteractionAnimating?
  ) {
    super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
    isMenuVisible = false
    onMenuHidden?()
  }
}
