import Flutter
import UIKit

/// `CNPopUpButton` on iOS: a `UIButton` whose `UIMenu` opens on a tap
/// (`showsMenuAsPrimaryAction`) and selects one of its actions
/// (`changesSelectionAsPrimaryAction`, iOS 15): the selected action has the
/// checkmark and its title is the button's. The menu is built by
/// `PopupMenuBuilder` from the same level format as `CNPopupMenuButton`'s,
/// with sections as inline menus. The button uses the configurations
/// `CNPopupMenuButton` and `CNButton` use, glass on iOS 26.
final class CupertinoPopUpButtonPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let container: UIView
  private let button = UIButton(type: .system)

  /// The menu's top level as Flutter sent it (`encodePopupMenuEntries`).
  private var level: [String: Any] = [:]
  /// The selected item's path: `[i]`, or `[i, j]` inside a section.
  private var selectedPath: [Int]?
  /// `CNButtonStyle` name; nil for the plain pop-up button.
  private var style: String?
  private var tint: UIColor?
  /// The height Flutter was given, or nil for the button's own.
  private var height: CGFloat?
  private var semanticLabel: String?
  private var isTransitioning = false
  private var lastReportedSize: CGSize = .zero

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "CupertinoNativePopUpButton_\(viewId)", binaryMessenger: messenger)
    container = UIView(frame: frame)
    super.init()

    let dict = args as? [String: Any] ?? [:]
    container.backgroundColor = .clear
    let isDark = (dict["isDark"] as? NSNumber)?.boolValue ?? false
    container.overrideUserInterfaceStyle = isDark ? .dark : .light

    button.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(button)
    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      button.topAnchor.constraint(equalTo: container.topAnchor),
      button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    button.showsMenuAsPrimaryAction = true
    if #available(iOS 15.0, *) {
      button.changesSelectionAsPrimaryAction = true
    }

    level = dict["items"] as? [String: Any] ?? [:]
    selectedPath = Self.path(dict["selectedPath"])
    button.isEnabled = (dict["enabled"] as? NSNumber)?.boolValue ?? true
    semanticLabel = Self.nonEmpty(dict["semanticLabel"] as? String)
    readStyle(dict)
    applyStyle()
    rebuildMenu()

    NotificationCenter.default.addObserver(
      self, selector: #selector(contentSizeCategoryChanged),
      name: UIContentSizeCategory.didChangeNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(transitionStateChanged(_:)),
      name: CNTransitionObserver.transitionStateChangedNotification, object: nil)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      self.handle(call, result: result)
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  func view() -> UIView { container }

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
      result(nil)
    case "setSelectedPath":
      selectedPath = Self.path(args?["path"])
      rebuildMenu()
      result(nil)
    case "setEnabled":
      button.isEnabled = (args?["enabled"] as? NSNumber)?.boolValue ?? true
      result(nil)
    case "setStyle":
      readStyle(args ?? [:])
      applyStyle()
      result(nil)
    case "setBrightness":
      guard let isDark = (args?["isDark"] as? NSNumber)?.boolValue else {
        result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)); return
      }
      container.overrideUserInterfaceStyle = isDark ? .dark : .light
      result(nil)
    case "setSemanticLabel":
      semanticLabel = Self.nonEmpty(args?["label"] as? String)
      applyAccessibility()
      result(nil)
    case "setInteractive":
      container.isUserInteractionEnabled = (args?["interactive"] as? NSNumber)?.boolValue ?? true
      result(nil)
    case "setTransitioning":
      // Clip the glass halo while the route animates (#29).
      let active = (args?["active"] as? NSNumber)?.boolValue ?? false
      container.clipsToBounds = active
      button.clipsToBounds = active
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

  private static func nonEmpty(_ s: String?) -> String? {
    (s?.isEmpty ?? true) ? nil : s
  }

  // MARK: - Menu and selection

  /// [level] with the checkmark on the selected item, which
  /// `changesSelectionAsPrimaryAction` reads as the selection.
  private func levelWithSelection() -> [String: Any] {
    var top = level
    guard let path = selectedPath, let first = path.first else { return top }
    let count = (top["labels"] as? [Any])?.count ?? 0
    if path.count == 1 {
      top["checked"] = (0..<count).map { NSNumber(value: $0 == first) }
      return top
    }
    var submenus = (top["submenus"] as? [Any]) ?? []
    guard first < submenus.count, var section = submenus[first] as? [String: Any] else { return top }
    let sectionCount = (section["labels"] as? [Any])?.count ?? 0
    section["checked"] = (0..<sectionCount).map { NSNumber(value: $0 == path[1]) }
    submenus[first] = section
    top["submenus"] = submenus
    return top
  }

  /// The selected item's title, read from the level Flutter sent.
  private var selectedTitle: String? {
    guard let path = selectedPath, let first = path.first else { return nil }
    if path.count == 1 {
      let labels = (level["labels"] as? [Any]) ?? []
      return first < labels.count ? labels[first] as? String : nil
    }
    let submenus = (level["submenus"] as? [Any]) ?? []
    guard first < submenus.count, let section = submenus[first] as? [String: Any] else { return nil }
    let labels = (section["labels"] as? [Any]) ?? []
    return path[1] < labels.count ? labels[path[1]] as? String : nil
  }

  private func rebuildMenu() {
    let elements = PopupMenuBuilder.elements(
      level: PopupMenuLevel(dict: levelWithSelection()),
      iconScale: container.traitCollection.displayScale > 0
        ? container.traitCollection.displayScale : UIScreen.main.scale
    ) { [weak self] path in
      self?.userChose(path)
    }
    button.menu = UIMenu(title: "", children: elements)
    updateTitle()
  }

  /// The user chose an item: UIKit shows it already. Flutter answers with
  /// the value it keeps (`setSelectedPath`).
  private func userChose(_ path: [Int]) {
    selectedPath = path
    updateTitle()
    channel.invokeMethod("valueChanged", arguments: ["path": path])
  }

  // MARK: - Style

  private func readStyle(_ dict: [String: Any]) {
    if dict.keys.contains("buttonStyle") { style = dict["buttonStyle"] as? String }
    if dict.keys.contains("tint") {
      tint = (dict["tint"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
    }
    if dict.keys.contains("height") {
      height = (dict["height"] as? NSNumber).map { CGFloat(truncating: $0) }
    }
  }

  private static let prominentStyles: Set<String> = [
    "filled", "borderedProminent", "prominentGlass", "prominentClearGlass",
  ]

  private func applyStyle() {
    button.tintColor = tint
    if #available(iOS 15.0, *) {
      button.configuration = makeConfiguration()
    }
    updateTitle()
  }

  @available(iOS 15.0, *)
  private func makeConfiguration() -> UIButton.Configuration {
    var config: UIButton.Configuration
    switch style {
    case "gray": config = .gray()
    case "tinted": config = .tinted()
    case "bordered": config = .bordered()
    case "borderedProminent": config = .borderedProminent()
    case "filled": config = .filled()
    case "glass", "prominentGlass", "clearGlass", "prominentClearGlass":
      config = glassConfiguration() ?? (Self.prominentStyles.contains(style ?? "") ? .filled() : .tinted())
    default: config = .plain()
    }
    if let tint = tint {
      if Self.prominentStyles.contains(style ?? "") {
        config.baseBackgroundColor = tint
      } else {
        config.baseForegroundColor = tint
      }
    }
    // The chevrons of a pop-up button; `changesSelectionAsPrimaryAction`
    // asks for them, stated so a configuration change keeps them.
    if #available(iOS 16.0, *) {
      config.indicator = .popup
    }
    config.title = selectedTitle
    config.titleLineBreakMode = .byTruncatingTail
    // The title and insets follow a height Flutter sets, as the control
    // size does on macOS.
    if let h = height {
      config.buttonSize = h < 24 ? .mini : h < 30 ? .small : h < 40 ? .medium : .large
    }
    return config
  }

  /// The iOS 26 glass configurations; nil before iOS 26 and while a route
  /// transition runs, when glass sampling leaves artifacts (as for
  /// `CNPopupMenuButton`).
  @available(iOS 15.0, *)
  private func glassConfiguration() -> UIButton.Configuration? {
    #if compiler(>=6.2)
    if #available(iOS 26.0, *), !isTransitioning {
      switch style {
      case "glass": return .glass()
      case "prominentGlass": return .prominentGlass()
      case "clearGlass": return .clearGlass()
      case "prominentClearGlass": return .prominentClearGlass()
      default: return nil
      }
    }
    #endif
    return nil
  }

  /// Keeps the configuration's title on the selected item (a configuration
  /// set again would otherwise drop it) and VoiceOver's value with it.
  private func updateTitle() {
    if #available(iOS 15.0, *), var config = button.configuration {
      if config.title != selectedTitle {
        config.title = selectedTitle
        button.configuration = config
      }
    } else {
      button.setTitle(selectedTitle, for: .normal)
    }
    applyAccessibility()
    // UIKit lays out the new title on the next pass.
    DispatchQueue.main.async { [weak self] in self?.reportSizeIfChanged() }
  }

  private func applyAccessibility() {
    // Without a label UIKit reads the title, then "Pop up button".
    button.accessibilityLabel = semanticLabel
    button.accessibilityValue = semanticLabel == nil ? nil : selectedTitle
  }

  @objc private func contentSizeCategoryChanged() {
    DispatchQueue.main.async { [weak self] in self?.reportSizeIfChanged() }
  }

  @objc private func transitionStateChanged(_ notification: Notification) {
    guard let transitioning = notification.userInfo?["isTransitioning"] as? Bool else { return }
    isTransitioning = transitioning
    guard let style = style, style.lowercased().contains("glass") else { return }
    DispatchQueue.main.async { [weak self] in self?.applyStyle() }
  }

  // MARK: - Size

  /// The button's own size: the selected title, the indicator and the
  /// configuration's insets, at the current text size.
  private func preferredSize() -> CGSize {
    let size = button.intrinsicContentSize
    return CGSize(width: ceil(size.width), height: ceil(size.height))
  }

  private func reportSizeIfChanged() {
    let size = preferredSize()
    guard size.width > 0, size.height > 0, size != lastReportedSize else { return }
    lastReportedSize = size
    channel.invokeMethod(
      "sizeChanged", arguments: ["width": Double(size.width), "height": Double(size.height)])
  }
}
