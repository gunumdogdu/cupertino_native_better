import UIKit

/// The text style of `CNAlert` and `CNActionSheet` (#144): a font family for
/// the title, the message and the buttons, and optional overrides of each
/// one's size, weight and colour.
struct CNDialogTextStyle {
  struct Part {
    var fontFamily: String?
    var fontSize: CGFloat?
    var fontWeight: UIFont.Weight?
    var color: UIColor?

    init(_ dict: [String: Any]?, family: String?) {
      fontFamily = (dict?["fontFamily"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? family
      fontSize = (dict?["fontSize"] as? NSNumber).map { CGFloat($0.doubleValue) }
      fontWeight = CNFontResolver.weight(fromFlutterValue: (dict?["fontWeight"] as? NSNumber)?.intValue)
      color = (dict?["color"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
    }

    var isEmpty: Bool { fontFamily == nil && fontSize == nil && fontWeight == nil && color == nil }
  }

  var title: Part
  var message: Part
  var action: Part

  /// The `textStyle` map of the show payload, or nil for the system look.
  init?(_ value: Any?) {
    guard let dict = value as? [String: Any] else { return nil }
    let family = (dict["fontFamily"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    title = Part(dict["title"] as? [String: Any], family: family)
    message = Part(dict["message"] as? [String: Any], family: family)
    action = Part(dict["action"] as? [String: Any], family: family)
    if title.isEmpty && message.isEmpty && action.isEmpty { return nil }
  }
}

/// A `UIAlertController` that draws its title, message and buttons in the
/// app's font (#144).
///
/// `UIAlertController` has no font setting, so after each layout this finds
/// its labels (the title, the message and each button's title, told apart by
/// their text) and gives them the family, keeping the size and weight the
/// system chose for each unless the style overrides them: the preferred
/// button stays bold. UIKit sets a label's font again when the label's state
/// changes, such as on a press or while the alert closes; the next layout
/// puts the family back, and a font UIKit sets is taken as the new system
/// font to derive from. A destructive button keeps the system red.
final class CNStyledAlertController: UIAlertController {
  var textStyle: CNDialogTextStyle?
  /// Flutter's text direction, when the dialog forces one. The buttons
  /// follow the layout direction trait; the title and message align by the
  /// app's localization (`.natural`), so they are aligned here (#144).
  var rtl: Bool?
  /// Button titles drawn in red, which keep their colour.
  var destructiveTitles: Set<String> = []

  /// The font this controller last gave each label, so a font UIKit sets
  /// afterwards is noticed.
  private var applied: [ObjectIdentifier: UIFont] = [:]

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    applyTextStyle()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    applyTextStyle()
  }

  func applyTextStyle() {
    guard textStyle != nil || rtl != nil, isViewLoaded else { return }
    let actionTitles = Set(actions.compactMap { $0.title })
    var labels: [UILabel] = []
    func walk(_ view: UIView) {
      for sub in view.subviews {
        if sub is UITextField { continue }
        if let label = sub as? UILabel { labels.append(label) } else { walk(sub) }
      }
    }
    walk(view)
    for label in labels {
      guard let text = label.text, !text.isEmpty else { continue }
      let part: CNDialogTextStyle.Part?
      var keepsColor = false
      if text == title || text == message {
        part = text == title ? textStyle?.title : textStyle?.message
        // A centred title (iOS before 26) stays centred.
        if let rtl, label.textAlignment != .center {
          let alignment: NSTextAlignment = rtl ? .right : .left
          if label.textAlignment != alignment { label.textAlignment = alignment }
        }
      } else if actionTitles.contains(text) {
        part = textStyle?.action
        keepsColor = destructiveTitles.contains(text)
      } else {
        continue
      }
      if let part { apply(part, to: label, keepsColor: keepsColor) }
    }
  }

  private func apply(_ part: CNDialogTextStyle.Part, to label: UILabel, keepsColor: Bool) {
    let key = ObjectIdentifier(label)
    if part.fontFamily != nil || part.fontSize != nil || part.fontWeight != nil {
      // The system's font for this label: the current one, unless it is the
      // one set here last time.
      let current = label.font ?? UIFont.preferredFont(forTextStyle: .body)
      let base = applied[key] == current ? (systemFonts[key] ?? current) : current
      systemFonts[key] = base
      let size = part.fontSize ?? base.pointSize
      let weight = part.fontWeight ?? Self.weight(of: base)
      let font: UIFont
      if let family = part.fontFamily, let resolved = CNFontResolver.font(family: family, size: size, weight: weight) {
        font = resolved
      } else {
        font = UIFont.systemFont(ofSize: size, weight: weight)
      }
      if label.font != font { label.font = font }
      applied[key] = font
    }
    if let color = part.color, !keepsColor, label.textColor != color {
      label.textColor = color
    }
  }

  /// The system font each label had before this controller changed it.
  private var systemFonts: [ObjectIdentifier: UIFont] = [:]

  private static func weight(of font: UIFont) -> UIFont.Weight {
    let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
    if let raw = traits?[.weight] as? CGFloat { return UIFont.Weight(rawValue: raw) }
    if let number = traits?[.weight] as? NSNumber { return UIFont.Weight(rawValue: CGFloat(number.doubleValue)) }
    return .regular
  }
}
