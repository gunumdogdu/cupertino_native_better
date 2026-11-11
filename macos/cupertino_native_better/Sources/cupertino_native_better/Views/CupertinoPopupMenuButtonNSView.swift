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
  /// Changes held until the view has a given width: a new title with the
  /// width it needs, or the first appearance at the measured width (#147).
  private var widthActions: [(id: Int, width: CGFloat, run: () -> Void)] = []
  private var nextWidthActionId = 0

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
    // Not measured yet: shown by `reveal` once Flutter has given the view
    // the measured width (#147).
    if (dict["hiddenUntilSized"] as? NSNumber)?.boolValue == true { host.alphaValue = 0 }

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      self.handle(call, result: result)
    }
  }

  required init?(coder: NSCoder) { return nil }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    runDueWidthActions()
  }

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
    case "measureTitle":
      // The size the button would take with this title, without showing
      // it, so Flutter can lay out the new width first (#147).
      let current = host.title
      host.title = args?["title"] as? String
      let s = host.preferredSize()
      host.title = current
      result(["width": Double(s.width), "height": Double(s.height)])
    case "reveal":
      let width = (args?["atWidth"] as? NSNumber).map { CGFloat(truncating: $0) }
      whenWidth(width) { [weak self] in
        self?.host.alphaValue = 1
        result(nil)
      }
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
      // With `atWidth`, once the view has that width, so the title isn't
      // drawn for a frame at the old width (#147).
      let width = (args?["atWidth"] as? NSNumber).map { CGFloat(truncating: $0) }
      whenWidth(width) { [weak self] in
        self?.host.title = t
        result(nil)
      }
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

  /// Runs `action` once the view is `width` wide: now if it is (or `width`
  /// is nil), otherwise when Flutter resizes it. Runs anyway after 0.3 s,
  /// in case that width never comes.
  private func whenWidth(_ width: CGFloat?, _ action: @escaping () -> Void) {
    guard let width = width, abs(bounds.width - width) > 0.5 else {
      action()
      return
    }
    nextWidthActionId += 1
    let id = nextWidthActionId
    widthActions.append((id: id, width: width, run: action))
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      guard let self = self, let index = self.widthActions.firstIndex(where: { $0.id == id }) else { return }
      self.runWidthActions(through: index)
    }
  }

  /// Runs the held actions up to the newest one the current width is due
  /// for, in order.
  private func runDueWidthActions() {
    let width = bounds.width
    guard let index = widthActions.lastIndex(where: { abs($0.width - width) <= 0.5 }) else { return }
    runWidthActions(through: index)
  }

  private func runWidthActions(through index: Int) {
    let due = widthActions[0...index]
    widthActions.removeFirst(index + 1)
    for entry in due { entry.run() }
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
