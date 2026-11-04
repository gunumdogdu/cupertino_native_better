import FlutterMacOS
import Cocoa

/// `CNSearchBar` on macOS: a native `NSSearchField`.
///
/// macOS search fields are normally always open. With `expandable` the bar
/// starts as a magnifying-glass button and opens into the field, as the
/// search item of a window toolbar does (`NSSearchToolbarItem`): a click on
/// the button opens and focuses the field, and the field closes again when
/// it loses focus while empty.
///
/// macOS has no Cancel button beside a search field. Esc is the cancel
/// gesture: the first Esc clears the text (the field's own behaviour), Esc in
/// an empty field ends the search, hands the keyboard back to Flutter,
/// closes an expandable bar and reports `cancelTapped`.
class CupertinoSearchBarNSView: NSView, NSSearchFieldDelegate {
  private let channel: FlutterMethodChannel
  private let searchField: CNMacSearchField
  private let collapsedButton: NSButton

  private let expandable: Bool
  private var isExpanded: Bool
  private var autofocus: Bool
  private var collapsedWidth: CGFloat
  private var tint: NSColor?
  private var placeholder: String
  private var placeholderColor: NSColor?
  private var searchIconName: String
  private var clearIconName: String
  /// The text Flutter last heard about, so each change is reported once.
  private var lastText = ""
  private var didAutofocus = false

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CNSearchBar_\(viewId)", binaryMessenger: messenger)

    var placeholder = "Search"
    var expandable = true
    var initiallyExpanded = false
    var collapsedWidth: CGFloat = 44
    var tint: NSColor? = nil
    var backgroundColor: NSColor? = nil
    var textColor: NSColor? = nil
    var placeholderColor: NSColor? = nil
    var autofocus = false
    var searchIconName = "magnifyingglass"
    var clearIconName = "xmark.circle.fill"
    var isDark = false
    var recentsAutosaveName: String? = nil

    if let dict = args as? [String: Any] {
      if let v = dict["placeholder"] as? String { placeholder = v }
      if let v = dict["expandable"] as? NSNumber { expandable = v.boolValue }
      if let v = dict["initiallyExpanded"] as? NSNumber { initiallyExpanded = v.boolValue }
      if let v = dict["collapsedWidth"] as? NSNumber { collapsedWidth = CGFloat(truncating: v) }
      if let v = dict["tint"] as? NSNumber { tint = Self.colorFromARGB(v.intValue) }
      if let v = dict["backgroundColor"] as? NSNumber { backgroundColor = Self.colorFromARGB(v.intValue) }
      if let v = dict["textColor"] as? NSNumber { textColor = Self.colorFromARGB(v.intValue) }
      if let v = dict["placeholderColor"] as? NSNumber { placeholderColor = Self.colorFromARGB(v.intValue) }
      if let v = dict["autofocus"] as? NSNumber { autofocus = v.boolValue }
      if let v = dict["searchIconName"] as? String, !v.isEmpty { searchIconName = v }
      if let v = dict["clearIconName"] as? String, !v.isEmpty { clearIconName = v }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let v = dict["recentsAutosaveName"] as? String, !v.isEmpty { recentsAutosaveName = v }
    }

    self.expandable = expandable
    self.isExpanded = initiallyExpanded || !expandable
    self.autofocus = autofocus
    self.collapsedWidth = collapsedWidth
    self.tint = tint
    self.placeholder = placeholder
    self.placeholderColor = placeholderColor
    self.searchIconName = searchIconName
    self.clearIconName = clearIconName

    self.searchField = CNMacSearchField(frame: .zero)
    self.collapsedButton = NSButton(frame: .zero)

    super.init(frame: .zero)

    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    searchField.delegate = self
    searchField.target = self
    searchField.action = #selector(searchFieldAction(_:))
    searchField.sendsSearchStringImmediately = false
    searchField.sendsWholeSearchString = false
    searchField.lineBreakMode = .byTruncatingTail
    searchField.setAccessibilityLabel(placeholder)
    if let textColor = textColor { searchField.textColor = textColor }
    if let backgroundColor = backgroundColor {
      searchField.drawsBackground = true
      searchField.backgroundColor = backgroundColor
    }
    if let name = recentsAutosaveName {
      searchField.recentsAutosaveName = name
      searchField.searchMenuTemplate = Self.recentsMenuTemplate()
    }
    searchField.onFocus = { [weak self] in self?.fieldDidFocus() }
    applyPlaceholder()
    applyIcons()
    addSubview(searchField)

    collapsedButton.title = ""
    collapsedButton.imagePosition = .imageOnly
    collapsedButton.target = self
    collapsedButton.action = #selector(collapsedButtonPressed(_:))
    collapsedButton.setAccessibilityLabel(placeholder)
    collapsedButton.toolTip = placeholder
    applyCollapsedButtonStyle()
    addSubview(collapsedButton)

    applyExpandedState(animated: false)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "expand":
        self.setExpanded(true, notify: true, animated: (args?["animated"] as? NSNumber)?.boolValue ?? true)
        if self.autofocus { self.focusField() }
        result(nil)
      case "collapse":
        self.collapse(notify: true, animated: (args?["animated"] as? NSNumber)?.boolValue ?? true)
        result(nil)
      case "clear":
        self.setText("", notify: true)
        result(nil)
      case "setText":
        self.setText((args?["text"] as? String) ?? "", notify: true)
        result(nil)
      case "textChanged":
        // Flutter's own copy of the text changed (it clears it when it
        // collapses the bar): take it over without reporting it back.
        self.setText((args?["text"] as? String) ?? "", notify: false)
        result(nil)
      case "focus":
        if !self.isExpanded { self.setExpanded(true, notify: true, animated: true) }
        self.focusField()
        result(nil)
      case "unfocus":
        if self.fieldHasFocus { self.returnFocusToFlutter() }
        result(nil)
      case "setBrightness":
        if let isDark = (args?["isDark"] as? NSNumber)?.boolValue {
          self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil))
        }
      case "setConfig":
        self.applyConfig(args ?? [:])
        result(nil)
      case "setInteractive":
        let interactive = (args?["interactive"] as? NSNumber)?.boolValue ?? true
        self.searchField.isEnabled = interactive
        self.collapsedButton.isEnabled = interactive
        result(nil)
      case "setTransitioning":
        // iOS halo containment (#29); AppKit views draw no halo.
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) { return nil }

  override var isFlipped: Bool { true }

  // MARK: Layout

  override func layout() {
    super.layout()
    let size = bounds.size
    let controlSize = Self.controlSize(fitting: size.height)
    if searchField.controlSize != controlSize {
      searchField.controlSize = controlSize
      searchField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: controlSize))
      // A new control size brings new default button images.
      applyPlaceholder()
      applyIcons()
    }
    let fieldHeight = min(size.height, searchField.intrinsicContentSize.height)
    searchField.frame = NSRect(
      x: 0, y: ((size.height - fieldHeight) / 2).rounded(), width: size.width, height: fieldHeight)

    collapsedButton.controlSize = searchField.controlSize
    // The button keeps its own size and sits at the leading edge, where the
    // field's magnifying glass appears, while Flutter widens the view.
    let side = min(collapsedWidth, size.height)
    let buttonWidth = min(size.width, max(side, collapsedWidth))
    collapsedButton.frame = NSRect(
      x: 0, y: ((size.height - side) / 2).rounded(), width: buttonWidth, height: side)
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard window != nil, autofocus, isExpanded, !didAutofocus else { return }
    didAutofocus = true
    DispatchQueue.main.async { [weak self] in self?.focusField() }
  }

  // MARK: Expand and collapse

  private func setExpanded(_ expanded: Bool, notify: Bool, animated: Bool) {
    guard expandable || expanded else { return }
    guard isExpanded != expanded else { return }
    isExpanded = expanded
    applyExpandedState(animated: animated)
    if notify {
      channel.invokeMethod(expanded ? "expanded" : "collapsed", arguments: nil)
    }
  }

  /// Closes an expandable bar: hands the keyboard back to Flutter and clears
  /// the text, as Cancel does on iOS.
  private func collapse(notify: Bool, animated: Bool) {
    guard expandable, isExpanded else { return }
    if fieldHasFocus { returnFocusToFlutter() }
    setText("", notify: true)
    setExpanded(false, notify: notify, animated: animated)
  }

  private func applyExpandedState(animated: Bool) {
    let showField = isExpanded
    if showField { searchField.isHidden = false } else { collapsedButton.isHidden = false }
    let apply = {
      self.searchField.animator().alphaValue = showField ? 1 : 0
      self.collapsedButton.animator().alphaValue = showField ? 0 : 1
    }
    let finish = { [weak self] in
      guard let self = self, self.isExpanded == showField else { return }
      self.searchField.isHidden = !showField
      self.collapsedButton.isHidden = showField
    }
    if animated {
      NSAnimationContext.runAnimationGroup({ ctx in
        ctx.duration = 0.2
        apply()
      }, completionHandler: finish)
    } else {
      searchField.alphaValue = showField ? 1 : 0
      collapsedButton.alphaValue = showField ? 0 : 1
      finish()
    }
  }

  @objc private func collapsedButtonPressed(_ sender: NSButton) {
    setExpanded(true, notify: true, animated: true)
    // A click on the button starts a search, as the toolbar search item does.
    focusField()
  }

  // MARK: Focus

  private var fieldHasFocus: Bool {
    guard let editor = searchField.currentEditor() else { return false }
    return window?.firstResponder === editor
  }

  private func focusField() {
    guard let window = window else { return }
    searchField.isHidden = false
    window.makeFirstResponder(searchField)
  }

  private func fieldDidFocus() {
    if let editor = searchField.currentEditor() as? NSTextView, let tint = tint {
      editor.insertionPointColor = tint
    }
  }

  /// Gives the keyboard back to the Flutter view, so Flutter's own focus,
  /// shortcuts and text fields work again after the search.
  private func returnFocusToFlutter() {
    guard let window = window else { return }
    window.makeFirstResponder(flutterView ?? window.contentView)
  }

  /// The Flutter view that hosts this platform view.
  private var flutterView: NSView? {
    var view = superview
    while let current = view {
      if NSStringFromClass(type(of: current)) == "FlutterView" { return current }
      view = current.superview
    }
    return window?.contentViewController?.view
  }

  // MARK: Text

  private func setText(_ text: String, notify: Bool) {
    if searchField.stringValue != text { searchField.stringValue = text }
    if notify {
      reportTextIfChanged()
    } else {
      lastText = text
    }
  }

  private func reportTextIfChanged() {
    let text = searchField.stringValue
    guard text != lastText else { return }
    lastText = text
    channel.invokeMethod("textChanged", arguments: ["text": text])
  }

  @objc private func searchFieldAction(_ sender: NSSearchField) {
    // Also sent by the clear button and by a recent search picked from the
    // menu, which change the text without a keystroke.
    reportTextIfChanged()
  }

  // MARK: NSSearchFieldDelegate

  func controlTextDidChange(_ obj: Notification) {
    reportTextIfChanged()
  }

  func searchFieldDidEndSearching(_ sender: NSSearchField) {
    reportTextIfChanged()
  }

  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    switch commandSelector {
    case #selector(NSResponder.insertNewline(_:)):
      reportTextIfChanged()
      channel.invokeMethod("submitted", arguments: ["text": searchField.stringValue])
      // Let the field finish too: it sends its action and records the
      // search in its recents.
      return false
    case #selector(NSResponder.cancelOperation(_:)):
      if !searchField.stringValue.isEmpty {
        // The field clears itself; that change is reported by the action.
        return false
      }
      returnFocusToFlutter()
      if expandable { setExpanded(false, notify: true, animated: true) }
      channel.invokeMethod("cancelTapped", arguments: nil)
      return true
    case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.insertBacktab(_:)):
      // Flutter moves its own focus on Tab; it needs the keyboard for that.
      returnFocusToFlutter()
      return true
    default:
      return false
    }
  }

  func controlTextDidEndEditing(_ obj: Notification) {
    reportTextIfChanged()
    // Wait for the new first responder to settle.
    DispatchQueue.main.async { [weak self] in
      guard let self = self, let window = self.window else { return }
      if self.fieldHasFocus { return }
      let responder = window.firstResponder
      if responder == nil || responder === window {
        // Nothing took the keyboard (e.g. a click on an empty area):
        // Flutter gets it back.
        self.returnFocusToFlutter()
      }
      if self.expandable, self.isExpanded, self.searchField.stringValue.isEmpty {
        self.setExpanded(false, notify: true, animated: true)
      }
    }
  }

  // MARK: Configuration

  private func applyConfig(_ dict: [String: Any]) {
    if let v = dict["placeholder"] as? String {
      placeholder = v
      searchField.setAccessibilityLabel(v)
      collapsedButton.setAccessibilityLabel(v)
      collapsedButton.toolTip = v
    }
    if dict.keys.contains("tint") {
      tint = (dict["tint"] as? NSNumber).map { Self.colorFromARGB($0.intValue) }
      if fieldHasFocus { fieldDidFocus() }
    }
    if dict.keys.contains("placeholderColor") {
      placeholderColor = (dict["placeholderColor"] as? NSNumber).map { Self.colorFromARGB($0.intValue) }
    }
    if dict.keys.contains("textColor") {
      searchField.textColor = (dict["textColor"] as? NSNumber).map { Self.colorFromARGB($0.intValue) } ?? .controlTextColor
    }
    if dict.keys.contains("backgroundColor") {
      if let n = dict["backgroundColor"] as? NSNumber {
        searchField.drawsBackground = true
        searchField.backgroundColor = Self.colorFromARGB(n.intValue)
      } else {
        searchField.drawsBackground = false
        searchField.backgroundColor = .textBackgroundColor
      }
    }
    if let v = dict["searchIconName"] as? String, !v.isEmpty { searchIconName = v }
    if let v = dict["clearIconName"] as? String, !v.isEmpty { clearIconName = v }
    if let v = dict["collapsedWidth"] as? NSNumber {
      collapsedWidth = CGFloat(truncating: v)
      needsLayout = true
    }
    if let v = dict["autofocus"] as? NSNumber { autofocus = v.boolValue }
    applyPlaceholder()
    applyIcons()
    applyCollapsedButtonStyle()
  }

  private func applyPlaceholder() {
    if let color = placeholderColor {
      searchField.placeholderAttributedString = NSAttributedString(
        string: placeholder,
        attributes: [
          .foregroundColor: color,
          .font: searchField.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
        ])
    } else {
      searchField.placeholderAttributedString = nil
      searchField.placeholderString = placeholder
    }
  }

  /// The field's magnifying glass and clear button keep the system images
  /// unless Flutter asks for other symbols or a tint. The tint goes on the
  /// system image, which keeps the recents chevron when there is a menu.
  private func applyIcons() {
    guard let cell = searchField.cell as? NSSearchFieldCell else { return }
    cell.resetSearchButtonCell()
    if searchIconName != "magnifyingglass" || tint != nil {
      var image = searchIconName == "magnifyingglass"
        ? cell.searchButtonCell?.image
        : Self.symbol(searchIconName, color: nil)
      if let tint = tint {
        image = image?.withSymbolConfiguration(.init(paletteColors: [tint])) ?? image
      }
      cell.searchButtonCell?.image = image
      cell.searchButtonCell?.alternateImage = image
    }
    cell.resetCancelButtonCell()
    if clearIconName != "xmark.circle.fill" {
      cell.cancelButtonCell?.image = Self.symbol(clearIconName, color: placeholderColor)
    }
    searchField.needsDisplay = true
  }

  private func applyCollapsedButtonStyle() {
    collapsedButton.image = Self.symbol(searchIconName, color: nil)
    collapsedButton.contentTintColor = tint
    #if compiler(>=6.2)
    if #available(macOS 26.0, *) {
      // Liquid Glass, as a window toolbar's collapsed search item.
      collapsedButton.bezelStyle = .glass
      collapsedButton.borderShape = .circle
      return
    }
    #endif
    collapsedButton.bezelStyle = .texturedRounded
  }

  // MARK: Helpers

  /// The largest control size whose search field fits [height].
  private static func controlSize(fitting height: CGFloat) -> NSControl.ControlSize {
    #if compiler(>=6.2)
    if #available(macOS 26.0, *), height >= 36 { return .extraLarge }
    #endif
    if #available(macOS 11.0, *), height >= 28 { return .large }
    if height >= 24 { return .regular }
    if height >= 20 { return .small }
    return .mini
  }

  private static func symbol(_ name: String, color: NSColor?) -> NSImage? {
    guard var image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
    if let color = color {
      let config = NSImage.SymbolConfiguration(paletteColors: [color])
      image = image.withSymbolConfiguration(config) ?? image
    } else {
      image.isTemplate = true
    }
    return image
  }

  /// The field's menu of recent searches; AppKit fills in the searches and
  /// shows or hides the items by their tags.
  private static func recentsMenuTemplate() -> NSMenu {
    let menu = NSMenu(title: "Recent Searches")
    let title = NSMenuItem(title: "Recent Searches", action: nil, keyEquivalent: "")
    title.tag = NSSearchField.recentsTitleMenuItemTag
    menu.addItem(title)
    let recents = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    recents.tag = NSSearchField.recentsMenuItemTag
    menu.addItem(recents)
    let separator = NSMenuItem.separator()
    separator.tag = NSSearchField.recentsTitleMenuItemTag
    menu.addItem(separator)
    let clear = NSMenuItem(title: "Clear Recent Searches", action: nil, keyEquivalent: "")
    clear.tag = NSSearchField.clearRecentsMenuItemTag
    menu.addItem(clear)
    let none = NSMenuItem(title: "No Recent Searches", action: nil, keyEquivalent: "")
    none.tag = NSSearchField.noRecentsMenuItemTag
    menu.addItem(none)
    return menu
  }

  private static func colorFromARGB(_ argb: Int) -> NSColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
  }
}

/// An `NSSearchField` that says when it takes the keyboard.
final class CNMacSearchField: NSSearchField {
  var onFocus: (() -> Void)?

  override func becomeFirstResponder() -> Bool {
    let became = super.becomeFirstResponder()
    if became { DispatchQueue.main.async { [weak self] in self?.onFocus?() } }
    return became
  }
}
