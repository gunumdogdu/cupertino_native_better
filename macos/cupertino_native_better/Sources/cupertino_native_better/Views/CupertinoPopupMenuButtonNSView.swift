import FlutterMacOS
import Cocoa

/// `CNPopupMenuButton` on macOS: an `NSButton` in the bezel of its
/// `CNButtonStyle` (see `NativeButtonHost`) that opens an `NSMenu`, built by
/// `MacMenuBuilder` like every other menu of the plugin.
class CupertinoPopupMenuButtonNSView: NSView {
  private let channel: FlutterMethodChannel
  private let host: NativeButtonHost
  private var popupMenu: NSMenu = NSMenu()
  /// The top level of the menu as `encodePopupMenuEntries` sent it, from the
  /// creation parameters or the last `setItems`.
  private var rootLevel: [String: Any] = [:]
  private var icon = IconSource()
  private var isInteractive = true

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativePopupMenuButton_\(viewId)", binaryMessenger: messenger)
    self.host = NativeButtonHost(target: nil, action: nil)
    super.init(frame: .zero)

    let dict = (args as? [String: Any]) ?? [:]
    let isDark = (dict["isDark"] as? NSNumber)?.boolValue ?? false
    icon.read(dict)
    rootLevel = dict

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
      // A title with an icon, and the label's style (#141).
      $0.imagePlacement = (dict["imagePlacement"] as? String) ?? "leading"
      $0.imagePadding = (dict["imagePadding"] as? NSNumber).map { CGFloat(truncating: $0) }
      $0.labelFontFamily = (dict["labelFontFamily"] as? String).flatMap { $0.isEmpty ? nil : $0 }
      $0.labelFontSize = (dict["labelFontSize"] as? NSNumber).map { CGFloat(truncating: $0) }
      $0.labelFontWeight = (dict["labelFontWeight"] as? NSNumber)?.intValue
      $0.labelColor = (dict["labelColor"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
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
      var level = args
      // `setItems` leaves out the top level's custom icons: the view keeps
      // the ones it was created with.
      if level["customIconBytes"] == nil {
        level["customIconBytes"] = rootLevel["customIconBytes"]
        level["customIconColors"] = rootLevel["customIconColors"]
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
    // In the view's light or dark appearance, which follows the app's theme.
    popupMenu.appearance = effectiveAppearance
    // Below the button, aligned to its leading edge, as a pull-down menu.
    let location = NSPoint(x: 0, y: sender.isFlipped ? sender.bounds.height + 4 : -4)
    // The menu is modal: popUp returns once it has closed (`onOpened`,
    // `onClosed`, #141).
    channel.invokeMethod("menuOpened", arguments: nil)
    popupMenu.popUp(positioning: nil, at: location, in: sender)
    channel.invokeMethod("menuClosed", arguments: nil)
  }

  private func rebuildMenu() {
    popupMenu = MacMenuBuilder.menu(level: MacMenuLevel(dict: rootLevel)) { [weak self] path in
      // `index` is the top-level entry, as before; `path` the full path.
      guard let self = self, let first = path.first else { return }
      self.channel.invokeMethod("itemSelected", arguments: ["index": first, "path": path])
    }
  }
}
