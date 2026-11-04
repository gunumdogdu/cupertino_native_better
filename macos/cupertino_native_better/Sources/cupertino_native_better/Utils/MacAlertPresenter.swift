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
    alert.layout()
    if let first = fields.first {
      alert.window.initialFirstResponder = first
    }

    self.alert = alert
    self.completion = completion
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
