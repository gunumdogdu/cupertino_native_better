import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    #if DEBUG
    registerAuditChannel(flutterViewController)
    #endif

    super.awakeFromNib()
  }

  /// lib/mac_page_entry.dart (TAP=true) asks for a mouse click at a point of
  /// the Flutter view. The events go through the app's own event queue, so
  /// AppKit hit-tests and dispatches them like a real click.
  private func registerAuditChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "cnb_mac_audit", binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self, weak controller] call, result in
      if call.method == "resize", let self = self,
        let args = call.arguments as? [String: Any],
        let w = args["width"] as? Double, let h = args["height"] as? Double
      {
        let visible = (self.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        var frame = self.frameRect(forContentRect: NSRect(x: 0, y: 0, width: w, height: h))
        frame.origin = NSPoint(x: visible.minX + 20, y: visible.maxY - frame.height)
        self.setFrame(frame, display: true)
        result(nil)
        return
      }
      if call.method == "toScreen", let self = self, let controller = controller,
        let args = call.arguments as? [String: Any],
        let x = args["x"] as? Double, let y = args["y"] as? Double
      {
        // Global display coordinates with a top-left origin, as CGEvent uses.
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
        let view = controller.view
        let local = NSPoint(x: x, y: view.isFlipped ? y : view.bounds.height - y)
        let screenPoint = self.convertPoint(toScreen: view.convert(local, to: nil))
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        result(["x": Double(screenPoint.x), "y": Double(primaryHeight - screenPoint.y)])
        return
      }
      // Key presses for native dialogs and menus (NSAlert sheets, NSMenu
      // tracking): `keyCode` is a virtual key code (36 Return, 53 Escape,
      // 125 Down, 126 Up, 48 Tab), `text` types characters. They go to the
      // key window through the app's own event queue, like real keys.
      // Hands the focus to the app that had it before, so this window is in
      // the background.
      if call.method == "deactivate" {
        NSApp.deactivate()
        result(nil)
        return
      }
      if call.method == "key", let self = self,
        let args = call.arguments as? [String: Any]
      {
        // Keys go to the key window of the active app: take the focus back
        // from whatever app took it.
        NSApp.activate(ignoringOtherApps: true)
        let window = NSApp.keyWindow ?? self.attachedSheet ?? self
        func post(_ chars: String, _ code: UInt16) {
          for type in [NSEvent.EventType.keyDown, .keyUp] {
            if let event = NSEvent.keyEvent(
              with: type, location: .zero, modifierFlags: [],
              timestamp: ProcessInfo.processInfo.systemUptime,
              windowNumber: window.windowNumber, context: nil,
              characters: chars, charactersIgnoringModifiers: chars,
              isARepeat: false, keyCode: code)
            {
              NSApp.postEvent(event, atStart: false)
            }
          }
        }
        if let code = args["keyCode"] as? Int {
          let chars: String
          switch code {
          case 36: chars = "\r"
          case 53: chars = "\u{1b}"
          case 48: chars = "\t"
          case 125: chars = String(UnicodeScalar(NSDownArrowFunctionKey)!)
          case 126: chars = String(UnicodeScalar(NSUpArrowFunctionKey)!)
          case 124: chars = String(UnicodeScalar(NSRightArrowFunctionKey)!)
          default: chars = ""
          }
          post(chars, UInt16(code))
        }
        if let text = args["text"] as? String {
          for ch in text { post(String(ch), 0) }
        }
        result(nil)
        return
      }
      guard call.method == "click", let self = self, let controller = controller,
        let args = call.arguments as? [String: Any],
        let x = args["x"] as? Double, let y = args["y"] as? Double
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      // `activate: false` leaves another app in front, for a right click on
      // a background window.
      if (args["activate"] as? Bool) != false {
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
      }
      let view = controller.view
      let local = NSPoint(x: x, y: view.isFlipped ? y : view.bounds.height - y)
      let point = view.convert(local, to: nil)
      // `button: "right"` sends a secondary click.
      let right = (args["button"] as? String) == "right"
      let types: [NSEvent.EventType] = right
        ? [.mouseMoved, .rightMouseDown, .rightMouseUp]
        : [.mouseMoved, .leftMouseDown, .leftMouseUp]
      for type in types {
        if let event = NSEvent.mouseEvent(
          with: type, location: point, modifierFlags: [],
          timestamp: ProcessInfo.processInfo.systemUptime,
          windowNumber: self.windowNumber, context: nil, eventNumber: 0,
          clickCount: type == .mouseMoved ? 0 : 1,
          pressure: type == .leftMouseDown || type == .rightMouseDown ? 1 : 0)
        {
          NSApp.postEvent(event, atStart: false)
        }
      }
      result(nil)
    }
  }
}
