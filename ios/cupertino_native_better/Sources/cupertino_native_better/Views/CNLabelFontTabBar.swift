import UIKit

/// A `UITabBar` whose custom-font titles shrink to fit a narrow tab instead of
/// truncating.
///
/// The bar draws `labelFontFamily` / `labelFontSize` itself once its
/// appearance carries the font before the items exist and the items are set
/// again after a font change (PR #100). A custom font is often wider than the
/// system's, though, and a tab sized for its icon cannot grow — the lone tab
/// in split mode is a fixed capsule — so "Profile" became "Pr…". Each tab's
/// title is a `UILabel` inside its `_UITabButton` (two of them on iOS 26, one
/// under the selection lens and one in the content); after every layout this
/// bar lets them shrink a little to fit. iOS 26.0 resets the setting on its
/// own, so it is put back each time.
///
/// Only bars whose appearance carries a font are touched; otherwise the
/// labels keep whatever the system gives them.
///
/// iOS 26 also sizes each title for the width the bar has when it builds the
/// item views and keeps that size when the bar later gets wider, so a bar laid
/// out narrow or at 0x0 before Flutter gives the platform view its size kept
/// "…" titles. This bar builds the item views again whenever its width changes.
class CNLabelFontTabBar: UITabBar {

  /// The width the item views were last built for.
  private var itemsBuiltForWidth: CGFloat = 0

  override var standardAppearance: UITabBarAppearance {
    didSet { setNeedsLayout() }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard #available(iOS 26.0, *) else { return }
    if bounds.width > 0, abs(bounds.width - itemsBuiltForWidth) > 0.5 {
      itemsBuiltForWidth = bounds.width
      reloadItemViews()
    }
    if hasCustomFont { allowShrinking(in: self) }
  }

  /// Whether the appearance asks for a font of its own: the stacked layout's,
  /// which is the one iPhone uses, or the inline layouts'.
  private var hasCustomFont: Bool {
    let ap = standardAppearance
    return [ap.stackedLayoutAppearance, ap.inlineLayoutAppearance, ap.compactInlineLayoutAppearance]
      .contains { $0.normal.titleTextAttributes[.font] != nil }
  }

  private func allowShrinking(in view: UIView) {
    for subview in view.subviews {
      // Badges are labels too; they keep the system's behaviour.
      if NSStringFromClass(type(of: subview)).contains("Badge") { continue }
      guard let label = subview as? UILabel else {
        allowShrinking(in: subview)
        continue
      }
      if !label.adjustsFontSizeToFitWidth {
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.setNeedsDisplay()
      }
    }
  }
}

extension UITabBar {
  /// Sets the items again so the bar builds their views anew, laid out for its
  /// current width and appearance, and keeps the selected item. The delegate
  /// is detached meanwhile, as in `refresh`, so no selection reaches Flutter.
  func reloadItemViews() {
    guard let items = items, !items.isEmpty else { return }
    let selected = selectedItem
    let barDelegate = delegate
    delegate = nil
    UIView.performWithoutAnimation {
      self.items = nil
      self.items = items
      selectedItem = selected
    }
    delegate = barDelegate
  }
}
