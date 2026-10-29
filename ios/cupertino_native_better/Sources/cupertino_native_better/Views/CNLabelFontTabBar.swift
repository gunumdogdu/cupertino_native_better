import UIKit

/// A `UITabBar` that draws its titles in the font its appearance asks for.
///
/// Since iOS 26.2 the Liquid Glass tab bar ignores the `.font` in
/// `UITabBarItemAppearance.titleTextAttributes` and in
/// `UITabBarItem.setTitleTextAttributes(_:for:)`, so `labelFontFamily` had no
/// effect (Issue #82; Apple Developer Forums thread 809225, FB21291879). Each
/// tab's title is a `UILabel` inside its `_UITabButton` — two of them on
/// iOS 26, one under the selection lens and one in the content — and the bar
/// sets their font itself. After every layout this bar puts the appearance's
/// font back on those labels, then lets the buttons lay out again so each
/// title is measured in that font.
///
/// Only bars whose appearance carries a font are touched; otherwise the
/// labels keep whatever the system gives them.
final class CNLabelFontTabBar: UITabBar {

  override var standardAppearance: UITabBarAppearance {
    didSet { setNeedsLayout() }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard #available(iOS 26.0, *), let font = appearanceFont else { return }
    if applyFont(font, in: self) {
      // A title measured in the same pass as its font change can keep the
      // old size; one more pass, once this one is done, measures it again.
      DispatchQueue.main.async { [weak self] in self?.setNeedsLayout() }
    }
  }

  /// The font the appearance asks for: the stacked layout's, which is the
  /// one iPhone uses, falling back to the inline layouts'.
  private var appearanceFont: UIFont? {
    let ap = standardAppearance
    for layout in [ap.stackedLayoutAppearance, ap.inlineLayoutAppearance, ap.compactInlineLayoutAppearance] {
      if let font = layout.normal.titleTextAttributes[.font] as? UIFont { return font }
    }
    return nil
  }

  /// Returns whether any title's font changed.
  @discardableResult
  private func applyFont(_ font: UIFont, in view: UIView) -> Bool {
    var changed = false
    for subview in view.subviews {
      // Badges are labels too; they keep the system's font.
      if NSStringFromClass(type(of: subview)).contains("Badge") { continue }
      guard let label = subview as? UILabel else {
        changed = applyFont(font, in: subview) || changed
        continue
      }
      if label.font != font {
        label.font = font
        changed = true
        remeasure(label)
      } else if isClipped(label) {
        remeasure(label)
      }
      // A custom font is often wider than the system's, and a button sized
      // for its icon (a lone tab in split mode) cannot grow: shrink the title
      // a little rather than truncate it. iOS 26.0 resets this on its own.
      if !label.adjustsFontSizeToFitWidth {
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.setNeedsDisplay()
      }
    }
    return changed
  }

  /// A title narrower than both its text and its button was measured for
  /// another font.
  private func isClipped(_ label: UILabel) -> Bool {
    guard let text = label.text, !text.isEmpty, let wrapper = label.superview else { return false }
    let needed = min(label.intrinsicContentSize.width, wrapper.bounds.width)
    return label.bounds.width + 1 < needed
  }

  /// The button sized the title for the old font; measure it again.
  private func remeasure(_ label: UILabel) {
    label.invalidateIntrinsicContentSize()
    label.superview?.setNeedsLayout()
    label.superview?.superview?.setNeedsLayout()
  }
}
