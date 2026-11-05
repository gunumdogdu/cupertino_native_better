import Cocoa
import FlutterMacOS

/// `CNPopUpButton` on macOS: an `NSPopUpButton` (`pullsDown` false) whose
/// menu `MacMenuBuilder` builds from the same level format as every other
/// menu of the plugin, so items have SF Symbol and image-asset images (kept
/// visible on macOS 27), sections and disabled items.
///
/// `NSPopUpButton` shows the selected item's title and image, puts the
/// checkmark on it and opens its menu over the button with that item under
/// the pointer. It draws its own bezel and ignores `NSButton`'s glass bezel
/// and bezel colours, so on macOS 26 the glass styles put the borderless
/// pop-up in an `NSGlassEffectView`, tinted for the prominent ones, as
/// `NativeButtonHost` does for clear glass.
final class CupertinoPopUpButtonNSView: NSView {
  private let channel: FlutterMethodChannel
  private let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
  private var glassView: NSView?

  /// The menu's top level as Flutter sent it (`encodePopupMenuEntries`).
  private var level: [String: Any] = [:]
  /// The selected item's path: `[i]`, or `[i, j]` inside a section.
  private var selectedPath: [Int]?
  /// `CNButtonStyle` name; nil for the default bordered pop-up.
  private var style: String?
  private var tint: NSColor?
  /// The height Flutter gives the button, before the first layout.
  private var expectedHeight: CGFloat = 24
  private var isInteractive = true
  private var lastReportedSize: CGSize = .zero

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "CupertinoNativePopUpButton_\(viewId)", binaryMessenger: messenger)
    super.init(frame: .zero)

    let dict = args as? [String: Any] ?? [:]
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    let isDark = (dict["isDark"] as? NSNumber)?.boolValue ?? false
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    popUp.autoenablesItems = false
    addSubview(popUp)

    level = dict["items"] as? [String: Any] ?? [:]
    selectedPath = Self.path(dict["selectedPath"])
    popUp.isEnabled = (dict["enabled"] as? NSNumber)?.boolValue ?? true
    setSemanticLabel(dict["semanticLabel"] as? String)
    readStyle(dict)
    rebuildMenu()
    applyStyle()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      self.handle(call, result: result)
    }
  }

  required init?(coder: NSCoder) { return nil }

  override var isFlipped: Bool { true }

  /// The whole glass capsule opens the menu, not only the title inside it.
  override func hitTest(_ point: NSPoint) -> NSView? {
    guard isInteractive, !isHidden else { return nil }
    let local = convert(point, from: superview)
    guard bounds.contains(local) else { return nil }
    if glassView != nil { return popUp }
    return super.hitTest(point)
  }

  override func setFrameSize(_ newSize: NSSize) {
    let heightChanged = abs(newSize.height - frame.height) > 0.5
    super.setFrameSize(newSize)
    if heightChanged { applyStyle() } else { layoutPopUp() }
  }

  // MARK: - Channel

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "getIntrinsicSize":
      let size = preferredSize()
      lastReportedSize = size
      result(["width": Double(size.width), "height": Double(size.height)])
    case "setItems":
      level = args?["items"] as? [String: Any] ?? [:]
      selectedPath = Self.path(args?["selectedPath"])
      rebuildMenu()
      layoutPopUp()
      reportSizeIfChanged()
      result(nil)
    case "setSelectedPath":
      selectedPath = Self.path(args?["path"])
      applySelection()
      reportSizeIfChanged()
      result(nil)
    case "setEnabled":
      popUp.isEnabled = (args?["enabled"] as? NSNumber)?.boolValue ?? true
      result(nil)
    case "setStyle":
      readStyle(args ?? [:])
      applyStyle()
      result(nil)
    case "setBrightness":
      guard let isDark = (args?["isDark"] as? NSNumber)?.boolValue else {
        result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)); return
      }
      appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
      popUp.menu?.appearance = appearance
      result(nil)
    case "setSemanticLabel":
      setSemanticLabel(args?["label"] as? String)
      result(nil)
    case "setInteractive":
      isInteractive = (args?["interactive"] as? NSNumber)?.boolValue ?? true
      result(nil)
    case "setTransitioning":
      layer?.masksToBounds = (args?["active"] as? NSNumber)?.boolValue ?? false
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func path(_ value: Any?) -> [Int]? {
    guard let list = value as? [Any] else { return nil }
    let path = list.compactMap { ($0 as? NSNumber)?.intValue }
    return path.isEmpty ? nil : path
  }

  private func setSemanticLabel(_ label: String?) {
    // VoiceOver reads the label, then the selected title as the value.
    popUp.setAccessibilityLabel((label?.isEmpty ?? true) ? nil : label)
  }

  // MARK: - Menu and selection

  private func rebuildMenu() {
    let menu = MacMenuBuilder.menu(level: MacMenuLevel(dict: level), appearance: appearance) {
      [weak self] path in
      self?.userChose(path)
    }
    popUp.menu = menu
    applySelection()
  }

  /// The item at [path], found by the path its `MacMenuAction` reports.
  private func item(at path: [Int]?) -> NSMenuItem? {
    guard let path = path else { return nil }
    return popUp.menu?.items.first { ($0.representedObject as? MacMenuAction)?.path == path }
  }

  private func applySelection() {
    popUp.select(item(at: selectedPath))
  }

  /// The user chose an item: `NSPopUpButton` shows it already. Flutter
  /// answers with the value it keeps (`setSelectedPath`).
  private func userChose(_ path: [Int]) {
    selectedPath = path
    if popUp.selectedItem.flatMap({ ($0.representedObject as? MacMenuAction)?.path }) != path {
      applySelection()
    }
    channel.invokeMethod("valueChanged", arguments: ["path": path])
    reportSizeIfChanged()
  }

  // MARK: - Style

  private func readStyle(_ dict: [String: Any]) {
    if dict.keys.contains("buttonStyle") { style = dict["buttonStyle"] as? String }
    if dict.keys.contains("tint") {
      tint = (dict["tint"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
    }
    if let h = dict["height"] as? NSNumber { expectedHeight = CGFloat(truncating: h) }
  }

  private var height: CGFloat { bounds.height > 0 ? bounds.height : expectedHeight }

  /// The size class for the height Flutter gives the button, as for
  /// `CNButton` (`NativeButtonHost`).
  private var controlSize: NSControl.ControlSize {
    let h = height
    #if compiler(>=6.2)
    if #available(macOS 26.0, *), h >= 40 { return .extraLarge }
    #endif
    if h >= 28 { return .large }
    if h >= 22 { return .regular }
    if h >= 18 { return .small }
    return .mini
  }

  private static let prominentStyles: Set<String> = [
    "prominentGlass", "prominentClearGlass", "filled", "borderedProminent",
  ]
  private static let glassStyles: Set<String> =
    Set(["glass", "clearGlass", "tinted"]).union(prominentStyles)

  /// Whether this build and this macOS draw the style in glass.
  private var usesGlass: Bool {
    guard let style = style, Self.glassStyles.contains(style) else { return false }
    return NativeButtonHost.hasGlass
  }

  private var accent: NSColor { tint ?? .controlAccentColor }

  private func applyStyle() {
    popUp.controlSize = controlSize
    installGlassIfNeeded()
    if style == "plain" {
      popUp.isBordered = false
      popUp.contentTintColor = tint
    } else if usesGlass {
      popUp.isBordered = false
      if Self.prominentStyles.contains(style ?? "") {
        popUp.contentTintColor = .white
      } else if style == "tinted" {
        popUp.contentTintColor = accent
      } else {
        popUp.contentTintColor = tint
      }
    } else {
      popUp.isBordered = true
      // A prominent style without glass keeps the bordered pop-up's own
      // title colour: white on its grey bezel would not read.
      popUp.contentTintColor = Self.prominentStyles.contains(style ?? "") ? nil : tint
    }
    layoutPopUp()
    reportSizeIfChanged()
  }

  /// Puts the borderless pop-up in an `NSGlassEffectView` for the glass
  /// styles, and back out of it for the others.
  private func installGlassIfNeeded() {
    #if compiler(>=6.2)
    if #available(macOS 26.0, *), usesGlass {
      let glass = (glassView as? NSGlassEffectView) ?? NSGlassEffectView()
      let prominent = Self.prominentStyles.contains(style ?? "")
      glass.style = (style == "clearGlass" || style == "prominentClearGlass") ? .clear : .regular
      if prominent {
        glass.tintColor = accent
      } else if style == "tinted" {
        glass.tintColor = accent.withAlphaComponent(0.22)
      } else {
        glass.tintColor = nil
      }
      glass.cornerRadius = height / 2
      if glassView == nil {
        let content = NSView()
        popUp.removeFromSuperview()
        content.addSubview(popUp)
        glass.contentView = content
        glass.frame = bounds
        addSubview(glass)
        glassView = glass
      }
      return
    }
    #endif
    if let glass = glassView {
      popUp.removeFromSuperview()
      glass.removeFromSuperview()
      glassView = nil
      addSubview(popUp)
    }
  }

  /// Room between the glass capsule's ends and the title or chevrons.
  private var glassPadding: CGFloat { max(6, (height * 0.3).rounded()) }

  /// The pop-up keeps its bezel height, centred; in glass it sits inside the
  /// capsule's padding.
  private func layoutPopUp() {
    let natural = popUp.intrinsicContentSize.height
    if let glass = glassView {
      glass.frame = bounds
      glass.subviews.first?.frame = glass.bounds
      #if compiler(>=6.2)
      if #available(macOS 26.0, *), let g = glass as? NSGlassEffectView {
        g.cornerRadius = bounds.height / 2
      }
      #endif
      let h = min(natural, bounds.height)
      popUp.frame = NSRect(
        x: glassPadding, y: ((bounds.height - h) / 2).rounded(),
        width: max(0, bounds.width - 2 * glassPadding), height: h)
      return
    }
    let h = min(natural, bounds.height)
    popUp.frame = NSRect(x: 0, y: ((bounds.height - h) / 2).rounded(), width: bounds.width, height: h)
  }

  // MARK: - Size

  /// The width `NSPopUpButton` asks for (that of its widest item), plus the
  /// capsule's padding in glass; the height of the bezel, or in glass the
  /// height Flutter gives it.
  private func preferredSize() -> CGSize {
    let natural = popUp.intrinsicContentSize
    if glassView != nil {
      return CGSize(width: ceil(natural.width + 2 * glassPadding), height: height)
    }
    return CGSize(width: ceil(natural.width), height: ceil(natural.height))
  }

  private func reportSizeIfChanged() {
    let size = preferredSize()
    guard size != lastReportedSize else { return }
    lastReportedSize = size
    channel.invokeMethod(
      "sizeChanged", arguments: ["width": Double(size.width), "height": Double(size.height)])
  }
}
