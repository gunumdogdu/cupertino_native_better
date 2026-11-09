import Cocoa

/// One button of an `NSAlert` built by `MacAlertPresenter`.
struct MacAlertButton {
  enum Role { case normal, cancel, destructive }

  let label: String
  let role: Role
  let enabled: Bool
  /// Whether Return presses this button.
  let isDefault: Bool
}

/// One text field in an alert's accessory view.
struct MacAlertTextField {
  let placeholder: String?
  let initialText: String?
  let obscure: Bool
}

/// Presents one `NSAlert` at a time as a sheet on the Flutter window, and
/// reports the pressed button exactly once.
///
/// Always `beginSheetModal(for:)`, never `runModal`: the platform and UI
/// threads are one on macOS, so a modal loop would stop Flutter. A sheet
/// keeps the rest of the app running and only blocks its own window.
final class MacAlertPresenter {
  struct Answer {
    /// Index of the pressed button in the `buttons` passed to `present`.
    let button: Int
    let textFields: [String]
  }

  private var alert: NSAlert?
  private var completion: ((Answer?) -> Void)?

  /// Whether an alert of this presenter is on screen.
  var isPresenting: Bool { alert != nil }

  /// Builds and shows the alert. [buttons] are in the caller's order and are
  /// added most prominent first: the default button, then cancel, then the
  /// rest in order, so AppKit puts the default at the trailing edge with
  /// cancel next to it. An alert already on screen is closed first and
  /// answers nil.
  ///
  /// Fails (returns false, [completion] not called) when there is no window
  /// to attach the sheet to.
  func present(
    title: String?,
    message: String?,
    buttons: [MacAlertButton],
    textFields: [MacAlertTextField] = [],
    appearance: NSAppearance?,
    textStyle: [String: Any]? = nil,
    rtl: Bool? = nil,
    completion: @escaping (Answer?) -> Void
  ) -> Bool {
    dismiss()
    guard let window = MacFlutterWindow.window else { return false }

    let alert = NSAlert()
    // NSAlert always shows its message text in bold. An alert with only a
    // message shows it there rather than under an empty title.
    if let title, !title.isEmpty {
      alert.messageText = title
      alert.informativeText = message ?? ""
    } else {
      alert.messageText = message ?? ""
      alert.informativeText = ""
    }

    let order = Self.order(of: buttons)
    for index in order {
      let spec = buttons[index]
      let button = alert.addButton(withTitle: spec.label)
      button.isEnabled = spec.enabled
      // AppKit gives the first button Return and any button titled "Cancel"
      // Escape. Set both from the roles instead of the titles.
      if spec.isDefault {
        button.keyEquivalent = "\r"
      } else if spec.role == .cancel {
        button.keyEquivalent = "\u{1b}"
      } else if button.keyEquivalent == "\r" || button.keyEquivalent == "\u{1b}" {
        button.keyEquivalent = ""
      }
      if #available(macOS 11.0, *), spec.role == .destructive {
        button.hasDestructiveAction = true
      }
    }

    var fields: [NSTextField] = []
    if !textFields.isEmpty {
      let width: CGFloat = 220
      let height: CGFloat = 22
      let spacing: CGFloat = 8
      let total = CGFloat(textFields.count) * height + CGFloat(textFields.count - 1) * spacing
      let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: total))
      for (i, spec) in textFields.enumerated() {
        let field: NSTextField = spec.obscure ? NSSecureTextField() : NSTextField()
        field.placeholderString = spec.placeholder
        field.stringValue = spec.initialText ?? ""
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        // Laid out top to bottom in a non-flipped container.
        let y = total - CGFloat(i + 1) * height - CGFloat(i) * spacing
        field.frame = NSRect(x: 0, y: y, width: width, height: height)
        field.autoresizingMask = [.width]
        container.addSubview(field)
        fields.append(field)
      }
      for (a, b) in zip(fields, fields.dropFirst()) { a.nextKeyView = b }
      alert.accessoryView = container
    }

    if let appearance { alert.window.appearance = appearance }
    // The app's text direction and font (#144), before the alert lays
    // itself out and again once the sheet is up, as AppKit lays it out anew.
    let destructive = Set(buttons.filter { $0.role == .destructive }.map { $0.label })
    let styleAlert: () -> Void = { [weak alert] in
      guard let alert, let content = alert.window.contentView else { return }
      CNLayoutDirection.apply(rtl, to: content)
      if let textStyle {
        Self.applyTextStyle(textStyle, to: content, alert: alert, destructive: destructive)
      }
      if let rtl { Self.alignTexts(rtl, in: content, alert: alert) }
    }
    if let content = alert.window.contentView { CNLayoutDirection.apply(rtl, to: content) }
    alert.layout()
    styleAlert()
    if let first = fields.first {
      alert.window.initialFirstResponder = first
    }

    self.alert = alert
    self.completion = completion
    defer { DispatchQueue.main.async(execute: styleAlert) }
    alert.beginSheetModal(for: window) { [weak self, weak alert] response in
      guard let self, let alert, alert === self.alert else { return }
      let position = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
      let answer: Answer? = position >= 0 && position < order.count
        ? Answer(button: order[position], textFields: fields.map { $0.stringValue })
        : nil
      self.alert = nil
      self.finish(answer)
    }
    return true
  }

  /// Gives the alert's title, message and buttons the family of `textStyle`
  /// (`CNAlert.fontFamily` and the part styles), keeping AppKit's sizes and
  /// weights unless a part overrides them. A destructive button keeps its
  /// colour.
  private static func applyTextStyle(_ style: [String: Any], to root: NSView, alert: NSAlert,
                                     destructive: Set<String>) {
    let family = (style["fontFamily"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    func font(_ base: NSFont?, _ part: [String: Any]?) -> NSFont? {
      let partFamily = (part?["fontFamily"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? family
      let size = (part?["fontSize"] as? NSNumber).map { CGFloat($0.doubleValue) }
      let weightValue = (part?["fontWeight"] as? NSNumber)?.intValue
      guard partFamily != nil || size != nil || weightValue != nil else { return nil }
      let base = base ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
      let pointSize = size ?? base.pointSize
      let traits = base.fontDescriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any]
      let baseWeight = (traits?[.weight] as? NSNumber).map { NSFont.Weight(rawValue: CGFloat($0.doubleValue)) } ?? .regular
      let weight = weightValue.map { NativeButtonHost.fontWeight($0) } ?? baseWeight
      if let partFamily, let resolved = CNFontResolver.font(family: partFamily, size: pointSize, weight: weight) {
        return resolved
      }
      return NSFont.systemFont(ofSize: pointSize, weight: weight)
    }
    func color(_ part: [String: Any]?) -> NSColor? {
      (part?["color"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
    }
    let title = style["title"] as? [String: Any]
    let message = style["message"] as? [String: Any]
    let action = style["action"] as? [String: Any]
    func walk(_ view: NSView) {
      for sub in view.subviews {
        if let button = sub as? NSButton, !(sub is NSPopUpButton) {
          let text = button.title
          guard !text.isEmpty, alert.buttons.contains(button) else { continue }
          var attributes: [NSAttributedString.Key: Any] = [:]
          if let f = font(button.font, action) { attributes[.font] = f }
          if let c = color(action), !destructive.contains(text) { attributes[.foregroundColor] = c }
          if !attributes.isEmpty {
            if attributes[.font] != nil { button.font = attributes[.font] as? NSFont }
            button.attributedTitle = NSAttributedString(string: text, attributes: attributes)
          }
        } else if let field = sub as? NSTextField, !field.isEditable {
          let part: [String: Any]?
          if field.stringValue == alert.messageText, !alert.messageText.isEmpty {
            part = alert.informativeText.isEmpty ? message : title
          } else if field.stringValue == alert.informativeText, !alert.informativeText.isEmpty {
            part = message
          } else {
            continue
          }
          if let f = font(field.font, part) { field.font = f }
          if let c = color(part) { field.textColor = c }
          Self.redraw(field)
        } else {
          walk(sub)
        }
      }
    }
    walk(root)
  }

  /// Aligns the title and message to the reading edge of [rtl]. NSAlert
  /// lays out by the app's language, which an app that picks its language
  /// in Dart never sets.
  private static func alignTexts(_ rtl: Bool, in root: NSView, alert: NSAlert) {
    func walk(_ view: NSView) {
      for sub in view.subviews {
        if let field = sub as? NSTextField, !field.isEditable,
           !field.stringValue.isEmpty,
           field.stringValue == alert.messageText || field.stringValue == alert.informativeText {
          field.alignment = rtl ? .right : .left
          field.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
          Self.redraw(field)
        } else {
          walk(sub)
        }
      }
    }
    walk(root)
  }

  /// Draws [field] again from its font, colour and alignment: on macOS 26 a
  /// label keeps the text it first laid out until its string is set again.
  private static func redraw(_ field: NSTextField) {
    let style = NSMutableParagraphStyle()
    style.alignment = field.alignment
    style.baseWritingDirection = field.baseWritingDirection
    var attributes: [NSAttributedString.Key: Any] = [.paragraphStyle: style]
    if let font = field.font { attributes[.font] = font }
    if let color = field.textColor { attributes[.foregroundColor] = color }
    field.attributedStringValue = NSAttributedString(string: field.stringValue, attributes: attributes)
    field.invalidateIntrinsicContentSize()
    field.needsLayout = true
    field.needsDisplay = true
  }

  /// Closes the alert on screen, if any; it answers nil.
  func dismiss() {
    guard let alert else { return }
    self.alert = nil
    finish(nil)
    if let parent = alert.window.sheetParent {
      parent.endSheet(alert.window, returnCode: .abort)
    } else {
      alert.window.orderOut(nil)
    }
  }

  private func finish(_ answer: Answer?) {
    guard let completion else { return }
    self.completion = nil
    completion(answer)
  }

  /// Button indices in the order they are added: the default first, then
  /// cancel, then the rest as given. Without a default, the first button
  /// that is not cancel leads, so it sits at the trailing edge.
  static func order(of buttons: [MacAlertButton]) -> [Int] {
    guard !buttons.isEmpty else { return [] }
    let lead = buttons.firstIndex(where: { $0.isDefault })
      ?? buttons.firstIndex(where: { $0.role != .cancel })
      ?? 0
    var order = [lead]
    if let cancel = buttons.firstIndex(where: { $0.role == .cancel }), cancel != lead {
      order.append(cancel)
    }
    for i in buttons.indices where !order.contains(i) { order.append(i) }
    return order
  }
}
