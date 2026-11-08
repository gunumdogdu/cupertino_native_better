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

  /// Whether item [i] opens a menu instead of being selected.
  func opensMenu(at i: Int) -> Bool {
    return itemMenus[i] != nil
  }

  /// The items that run an action instead of being selected (#131), by item
  /// index. Each gets a clear button over it that reports the tap through
  /// [onAction], and the bar's own gestures don't start there, so the item
  /// is never selected and the selection stays where it was.
  var itemActions: Set<Int> = [] {
    didSet { if itemActions != oldValue { setNeedsLayout() } }
  }

  /// Called with the item index when an action item is tapped.
  var onAction: ((Int) -> Void)?

  /// What VoiceOver reads for each action item, by item index: its button
  /// stands in for the item, as a button rather than a tab.
  var itemActionLabels: [Int: String] = [:] {
    didSet { if itemActionLabels != oldValue { setNeedsLayout() } }
  }

  private var actionButtons: [Int: CNTabActionButton] = [:]

  /// Whether item [i] runs an action instead of being selected.
  func runsAction(at i: Int) -> Bool {
    return itemActions.contains(i)
  }

  /// An action item's button takes the touches on it, and the bar's own
  /// gestures sit those touches out: the iOS 26 bar selects the item under
  /// the finger from a gesture recognizer of its own, before its button or
  /// the delegate hear of the touch, and a standalone `UITabBar` can't be
  /// asked first.
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    if let button = actionButtons.values.first(where: { !$0.isHidden && $0.frame.contains(point) }) {
      if event?.type == .touches { holdOwnGestures() }
      return button
    }
    return super.hitTest(point, with: event)
  }

  private var heldGestures: [UIGestureRecognizer] = []

  /// Switches the bar's gesture recognizers off while a touch on an action
  /// button begins, and on again right after: a recognizer takes part in
  /// the touches that begin while it is enabled, so they miss only this one.
  private func holdOwnGestures() {
    guard heldGestures.isEmpty else { return }
    heldGestures = (gestureRecognizers ?? []).filter { $0.isEnabled }
    heldGestures.forEach { $0.isEnabled = false }
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.heldGestures.forEach { $0.isEnabled = true }
      self.heldGestures = []
    }
  }

  /// Opens the menu of item [i] unless it's already shown: a finger sliding
  /// along the bar onto the item selects it without touching its button.
  /// When the icons can't be found, the button takes no touches; it is put
  /// where the item should be just to open the menu from there.
  func showMenu(at i: Int) {
    guard let button = menuButtons[i], !button.isMenuVisible, let items else { return }
    if button.isHidden {
      let slots = itemSlots(count: items.count, columns: nil)
      guard i < slots.count else { return }
      button.frame = buttonFrame(in: slots[i])
      button.isHidden = false
    }
    if #available(iOS 17.4, *) { button.performPrimaryAction() }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    placeDots()
    placeMenuButtons()
    placeActionButtons()
  }

  private func placeActionButtons() {
    for (i, button) in actionButtons where !itemActions.contains(i) {
      button.removeFromSuperview()
      actionButtons[i] = nil
    }
    guard !itemActions.isEmpty, let items else { return }
    let columns = iconColumns()
    let slots = itemSlots(count: items.count, columns: columns)
    for i in itemActions where i < items.count {
      let button = actionButtons[i] ?? {
        let button = CNTabActionButton(type: .custom)
        button.addAction(UIAction { [weak self] _ in self?.onAction?(i) }, for: .primaryActionTriggered)
        // VoiceOver reads the button in place of the item (see
        // accessibilityElements), as "Compose, button" rather than a tab.
        button.isAccessibilityElement = true
        button.accessibilityTraits = .button
        addSubview(button)
        actionButtons[i] = button
        return button
      }()
      // Icons not found: no button over the wrong item. A tap then selects
      // the item, and the delegate runs the action and puts it back.
      guard columns != nil else {
        button.isHidden = true
        continue
      }
      button.isHidden = false
      button.accessibilityLabel = itemActionLabels[i] ?? items[i].title
      let frame = buttonFrame(in: slots[i])
      if button.frame != frame { button.frame = frame }
      if let at = subviews.firstIndex(of: button),
         subviews[(at + 1)...].contains(where: { !Self.isOverlay($0) && !dots.contains($0) }) {
        bringSubviewToFront(button)
      }
    }
  }

  /// With action items, VoiceOver gets the bar's own elements except the
  /// ones under an action button, plus those buttons, in reading order. The
  /// item's own element would be read as a tab.
  override var accessibilityElements: [Any]? {
    get {
      let buttons = actionButtons.values.filter { !$0.isHidden }
      guard !buttons.isEmpty else { return super.accessibilityElements }
      var found: [UIView] = []
      func walk(_ view: UIView) {
        for sub in view.subviews where !sub.isHidden && sub.alpha > 0.01 && !Self.isOverlay(sub) {
          if sub.isAccessibilityElement { found.append(sub) } else { walk(sub) }
        }
      }
      walk(self)
      let covered = buttons.map { $0.frame }
      var elements = found.filter { element in
        let centre = element.convert(CGPoint(x: element.bounds.midX, y: element.bounds.midY), to: self)
        return !covered.contains { $0.contains(centre) }
      }
      elements.append(contentsOf: buttons)
      let rtl = effectiveUserInterfaceLayoutDirection == .rightToLeft
      elements.sort {
        let a = $0.convert($0.bounds, to: self).midX, b = $1.convert($1.bounds, to: self).midX
        return rtl ? a > b : a < b
      }
      return elements
    }
    set { super.accessibilityElements = newValue }
  }

  /// The clear buttons laid over items, which stay above the item's views.
  private static func isOverlay(_ view: UIView) -> Bool {
    return view is CNTabMenuButton || view is CNTabActionButton
  }

  private func placeMenuButtons() {
    for (i, button) in menuButtons where itemMenus[i] == nil {
      button.removeFromSuperview()
      menuButtons[i] = nil
    }
    guard !itemMenus.isEmpty, let items else { return }
    let columns = iconColumns()
    let slots = itemSlots(count: items.count, columns: columns)
    for (i, menu) in itemMenus where i < items.count {
      let button = menuButtons[i] ?? {
        let button = CNTabMenuButton(type: .custom)
        button.showsMenuAsPrimaryAction = true
        // Keep the given order when the menu opens upward from the bar.
        if #available(iOS 16.0, *) { button.preferredMenuElementOrder = .fixed }
        // VoiceOver reads the item under it, which opens the menu through
        // the bar's delegate when activated. Hiding the item instead doesn't
        // hold: UIKit keeps one of its views visible to VoiceOver.
        button.isAccessibilityElement = false
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
      // Icons not found: no touches, rather than a button over the wrong
      // item. A tap still reaches the bar, and the delegate opens the menu.
      guard columns != nil else {
        button.isHidden = true
        continue
      }
      button.isHidden = false
      let frame = buttonFrame(in: slots[i])
      if button.frame != frame { button.frame = frame }
      // Above the item's own views, which the bar may rebuild. Dots don't
      // count: they take no touches, and moving them up would move them
      // back above the buttons on every layout.
      if let at = subviews.firstIndex(of: button),
         subviews[(at + 1)...].contains(where: { !Self.isOverlay($0) && !dots.contains($0) }) {
        bringSubviewToFront(button)
      }
    }
  }

  /// A button as wide as the bar is high, but never wider than its item's
  /// slot, so it doesn't cover a neighbour.
  private func buttonFrame(in slot: CGRect) -> CGRect {
    let width = min(bounds.height, slot.width)
    return CGRect(x: slot.midX - width / 2, y: 0, width: width, height: bounds.height)
  }

  /// Each item's share of the bar, in item order: from halfway to the icon
  /// before it to halfway to the icon after it. Without [columns], the bar's
  /// width shared evenly.
  private func itemSlots(count: Int, columns: [[CGRect]]?) -> [CGRect] {
    guard count > 0 else { return [] }
    var centres: [CGFloat]
    if let columns {
      centres = columns.map { $0.max(by: { $0.width < $1.width })?.midX ?? 0 }
    } else {
      let width = bounds.width / CGFloat(count)
      centres = (0..<count).map { bounds.minX + (CGFloat($0) + 0.5) * width }
      if effectiveUserInterfaceLayoutDirection == .rightToLeft { centres.reverse() }
    }
    let byX = centres.enumerated().sorted { $0.element < $1.element }
    var slots = [CGRect](repeating: .zero, count: count)
    for (k, entry) in byX.enumerated() {
      let c = entry.element
      let low = k > 0 ? (byX[k - 1].element + c) / 2 : bounds.minX
      let high = k < count - 1 ? (c + byX[k + 1].element) / 2 : bounds.maxX
      let half = max(0, min(c - low, high - c))
      slots[entry.offset] = CGRect(x: c - half, y: 0, width: half * 2, height: bounds.height)
    }
    return slots
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
       subviews[first...].contains(where: { !dots.contains($0) && !Self.isOverlay($0) }) {
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

/// The clear button over a tab bar item that runs an action (#131).
final class CNTabActionButton: UIButton {}

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
