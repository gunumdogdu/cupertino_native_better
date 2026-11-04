import FlutterMacOS
import Cocoa

/// `CNPopupMenuButton` on macOS: an `NSButton` in the bezel of its
/// `CNButtonStyle` (see `NativeButtonHost`) that opens an `NSMenu`.
class CupertinoPopupMenuButtonNSView: NSView {
  private let channel: FlutterMethodChannel
  private let host: NativeButtonHost
  private var popupMenu: NSMenu = NSMenu()
  /// The top level of the menu, from the creation parameters or the last
  /// `setItems`.
  private var rootLevel = PopupMenuLevel()
  private var icon = IconSource()
  private var isInteractive = true

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativePopupMenuButton_\(viewId)", binaryMessenger: messenger)
    self.host = NativeButtonHost(target: nil, action: nil)
    super.init(frame: .zero)

    let dict = (args as? [String: Any]) ?? [:]
    let isDark = (dict["isDark"] as? NSNumber)?.boolValue ?? false
    icon.read(dict)
    rootLevel = PopupMenuLevel(dict: dict)

    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    host.frame = bounds
    host.autoresizingMask = [.width, .height]
    addSubview(host)
    host.button.target = self
    host.button.action = #selector(onButtonPressed(_:))
    let image = icon.makeImage()
    host.update {
      $0.title = dict["buttonTitle"] as? String
      $0.image = image
      $0.style = (dict["buttonStyle"] as? String) ?? "plain"
      $0.tint = ((dict["style"] as? [String: Any])?["tint"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
      // Icon buttons are `size` square (44 by default), text ones 32 high.
      $0.expectedHeight = (dict["height"] as? NSNumber).map { CGFloat(truncating: $0) }
        ?? ((dict["round"] as? NSNumber)?.boolValue == true ? 44 : 32)
      $0.accessibilityText = (dict["semanticLabel"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }
    rebuildMenu()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      self.handle(call, result: result)
    }
  }

  required init?(coder: NSCoder) { return nil }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard isInteractive else { return nil }
    return super.hitTest(point)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "getIntrinsicSize":
      let s = host.preferredSize()
      result(["width": Double(s.width), "height": Double(s.height)])
    case "setItems":
      guard let args = args else {
        result(FlutterError(code: "bad_args", message: "Missing items", details: nil)); return
      }
      var level = PopupMenuLevel(dict: args)
      // `setItems` leaves out the top level's custom icons: the view keeps
      // the ones it was created with.
      if args["customIconBytes"] == nil {
        level.customIconBytes = rootLevel.customIconBytes
        level.customIconColors = rootLevel.customIconColors
      }
      rootLevel = level
      rebuildMenu()
      result(nil)
    case "setStyle":
      guard let args = args else {
        result(FlutterError(code: "bad_args", message: "Missing style", details: nil)); return
      }
      host.update {
        if let n = args["tint"] as? NSNumber { $0.tint = ImageUtils.colorFromARGB(n.intValue) }
        if let bs = args["buttonStyle"] as? String { $0.style = bs }
      }
      result(nil)
    case "setButtonIcon":
      guard let args = args else {
        result(FlutterError(code: "bad_args", message: "Missing icon args", details: nil)); return
      }
      icon.update(args)
      host.image = icon.makeImage()
      result(nil)
    case "setBrightness":
      guard let isDark = (args?["isDark"] as? NSNumber)?.boolValue else {
        result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)); return
      }
      appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
      result(nil)
    case "setButtonTitle":
      guard let t = args?["title"] as? String else {
        result(FlutterError(code: "bad_args", message: "Missing title", details: nil)); return
      }
      host.title = t
      result(nil)
    case "setSemanticLabel":
      let label = args?["label"] as? String
      host.accessibilityText = (label?.isEmpty ?? true) ? nil : label
      result(nil)
    case "setInteractive":
      isInteractive = (args?["interactive"] as? NSNumber)?.boolValue ?? true
      result(nil)
    case "setTransitioning":
      layer?.masksToBounds = (args?["active"] as? NSNumber)?.boolValue ?? false
      result(nil)
    case "setPressed":
      // NSButton draws its own pressed state.
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @objc private func onButtonPressed(_ sender: NSButton) {
    // Below the button, aligned to its leading edge, as a pull-down menu.
    let location = NSPoint(x: 0, y: sender.isFlipped ? sender.bounds.height + 4 : -4)
    popupMenu.popUp(positioning: nil, at: location, in: sender)
  }

  private func rebuildMenu() {
    popupMenu = buildMenu(level: rootLevel)
  }

  /// Builds the menu of one [level]. [path] is the level's own path from the
  /// top: empty for the top level, then one index per submenu.
  private func buildMenu(level: PopupMenuLevel, path: [Int] = []) -> NSMenu {
    let menu = NSMenu()
    let count = max(level.labels.count, max(level.symbols.count, level.dividers.count))
    for i in 0..<count {
      if i < level.dividers.count, level.dividers[i] {
        menu.addItem(.separator())
        continue
      }
      let title = i < level.labels.count ? level.labels[i] : ""
      let itemPath = path + [i]
      let isEnabled = i < level.enabled.count ? level.enabled[i] : true
      let mi: NSMenuItem
      if i < level.isSubmenu.count, level.isSubmenu[i] {
        mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        // The menu auto-enables any item with a submenu, so a disabled
        // submenu gets none: an item without action or submenu is disabled.
        if isEnabled {
          let childLevel = (i < level.submenus.count ? level.submenus[i] : nil)
            .map { PopupMenuLevel(dict: $0) } ?? PopupMenuLevel()
          let submenu = buildMenu(level: childLevel, path: itemPath)
          // Inline and palette submenus show their items in place, under a
          // section header (macOS 14+). NSMenu has no palette of this kind.
          if i < level.submenuStyles.count, level.submenuStyles[i] != nil {
            if #available(macOS 14.0, *) {
              menu.addItem(.sectionHeader(title: title))
            } else {
              let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
              header.isEnabled = false
              menu.addItem(header)
            }
            for item in submenu.items {
              submenu.removeItem(item)
              menu.addItem(item)
            }
            continue
          }
          submenu.title = title
          mi.submenu = submenu
        }
      } else {
        mi = NSMenuItem(title: title, action: #selector(onSelectMenuItem(_:)), keyEquivalent: "")
        mi.target = self
        mi.tag = i
        mi.representedObject = itemPath
        mi.isEnabled = isEnabled
        if i < level.checked.count, level.checked[i] { mi.state = .on }
      }
      if #available(macOS 14.4, *), i < level.subtitles.count, !level.subtitles[i].isEmpty {
        mi.subtitle = level.subtitles[i]
      }
      if let image = level.image(at: i) {
        mi.image = image
        Self.keepImageVisible(mi)
      }
      menu.addItem(mi)
    }
    return menu
  }

  /// macOS 27 hides menu item images unless the item asks to show them.
  static func keepImageVisible(_ item: NSMenuItem) {
    #if compiler(>=6.4)
    if #available(macOS 27.0, *) { item.preferredImageVisibility = .visible }
    #else
    // Built with an SDK older than macOS 27's: the property exists at run
    // time on macOS 27 even though this SDK does not declare it.
    let selector = NSSelectorFromString("setPreferredImageVisibility:")
    if item.responds(to: selector) { item.setValue(1, forKey: "preferredImageVisibility") }
    #endif
  }

  @objc private func onSelectMenuItem(_ sender: NSMenuItem) {
    // `index` is the top-level entry, as before; `path` the full path.
    let path = (sender.representedObject as? [Int]) ?? [sender.tag]
    channel.invokeMethod("itemSelected", arguments: ["index": path[0], "path": path])
  }
}

/// One level of the popup menu: the parallel arrays Flutter sends for a list
/// of entries (one slot per item, submenu or divider), and each submenu's own
/// level in `submenus`.
private struct PopupMenuLevel {
  var labels: [String] = []
  var symbols: [String] = []
  var customIconBytes: [Data?] = []
  var customIconColors: [NSColor?] = []
  var imageAssetPaths: [String] = []
  var imageAssetData: [Data?] = []
  var imageAssetFormats: [String] = []
  var dividers: [Bool] = []
  var enabled: [Bool] = []
  var checked: [Bool] = []
  var sizes: [CGFloat?] = []
  var colors: [NSColor?] = []
  var modes: [String?] = []
  var palettes: [[NSColor]] = []
  var subtitles: [String] = []
  var isSubmenu: [Bool] = []
  var submenus: [[String: Any]?] = []
  var submenuStyles: [String?] = []

  init() {}

  /// Reads a level encoded by `encodePopupMenuEntries`, with the same keys
  /// and types as the top level. Lists of optional values carry NSNull for
  /// the entries without one, so they are read entry by entry.
  init(dict: [String: Any]) {
    labels = (dict["labels"] as? [String]) ?? []
    symbols = (dict["sfSymbols"] as? [String]) ?? []
    customIconBytes = Self.list(dict["customIconBytes"]).map { ($0 as? FlutterStandardTypedData)?.data }
    customIconColors = Self.list(dict["customIconColors"]).map(Self.color)
    imageAssetPaths = Self.list(dict["imageAssetPaths"]).map { ($0 as? String) ?? "" }
    imageAssetData = Self.list(dict["imageAssetData"]).map { ($0 as? FlutterStandardTypedData)?.data }
    imageAssetFormats = Self.list(dict["imageAssetFormats"]).map { ($0 as? String) ?? "" }
    dividers = Self.list(dict["isDivider"]).map { ($0 as? NSNumber)?.boolValue ?? false }
    enabled = Self.list(dict["enabled"]).map { ($0 as? NSNumber)?.boolValue ?? true }
    checked = Self.list(dict["checked"]).map { ($0 as? NSNumber)?.boolValue ?? false }
    sizes = Self.list(dict["sfSymbolSizes"]).map { ($0 as? NSNumber).map { CGFloat(truncating: $0) } }
    colors = Self.list(dict["sfSymbolColors"]).map(Self.color)
    modes = Self.list(dict["sfSymbolRenderingModes"]).map { $0 as? String }
    palettes = Self.list(dict["sfSymbolPaletteColors"]).map { Self.list($0).compactMap(Self.color) }
    subtitles = Self.list(dict["subtitles"]).map { ($0 as? String) ?? "" }
    isSubmenu = Self.list(dict["isSubmenu"]).map { ($0 as? NSNumber)?.boolValue ?? false }
    submenus = Self.list(dict["submenus"]).map { $0 as? [String: Any] }
    submenuStyles = Self.list(dict["submenuStyles"]).map { $0 as? String }
  }

  private static func list(_ value: Any?) -> [Any] { (value as? [Any]) ?? [] }

  private static func color(_ value: Any) -> NSColor? {
    (value as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
  }

  /// Menu images larger than the menu's text would stretch the row; the
  /// system's own menu symbols are about this size.
  private static let maxImageSize: CGFloat = 16

  /// The image of entry `i`, by the iOS priority: image asset, custom icon,
  /// SF Symbol.
  func image(at i: Int) -> NSImage? {
    let size = min((i < sizes.count ? sizes[i] : nil) ?? Self.maxImageSize, Self.maxImageSize)
    let color = i < colors.count ? colors[i] : nil
    let path = i < imageAssetPaths.count ? imageAssetPaths[i] : ""
    let data = i < imageAssetData.count ? imageAssetData[i] : nil
    let format = i < imageAssetFormats.count ? imageAssetFormats[i] : ""
    if !path.isEmpty || data != nil {
      if let image = ImageUtils.image(
        assetPath: path.isEmpty ? nil : path,
        imageData: data,
        format: format.isEmpty ? nil : format,
        customIconBytes: nil,
        size: size,
        color: color
      ) {
        return image
      }
    }
    if i < customIconBytes.count, let bytes = customIconBytes[i] {
      let custom = i < customIconColors.count ? customIconColors[i] : nil
      if let image = ImageUtils.image(
        assetPath: nil, imageData: nil, format: nil,
        customIconBytes: bytes, size: size, color: custom
      ) {
        return image
      }
    }
    guard i < symbols.count, !symbols[i].isEmpty else { return nil }
    return ImageUtils.symbolImage(
      name: symbols[i],
      size: size,
      color: color,
      mode: i < modes.count ? modes[i] : nil,
      palette: i < palettes.count ? palettes[i] : []
    )
  }
}
