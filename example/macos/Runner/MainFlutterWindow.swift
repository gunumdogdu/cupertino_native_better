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
      if call.method == "type", let self = self,
        let args = call.arguments as? [String: Any]
      {
        // Key presses through the app's own event queue, to the first
        // responder: `text` types each character, `keyCodes` presses keys
        // (36 Return, 53 Esc, 48 Tab, 125 Down). `delayMs` posts them later,
        // e.g. into a menu that a click is about to open.
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
        var keys: [(String, UInt16)] = []
        if let text = args["text"] as? String {
          keys += text.map { (String($0), UInt16(0)) }
        }
        let chars: [Int: String] = [36: "\r", 53: "\u{1b}", 48: "\t", 125: "\u{F701}"]
        for code in (args["keyCodes"] as? [Int]) ?? [] {
          keys.append((chars[code] ?? "", UInt16(code)))
        }
        let windowNumber = self.windowNumber
        let post = {
          for (chars, code) in keys {
            for type in [NSEvent.EventType.keyDown, .keyUp] {
              if let event = NSEvent.keyEvent(
                with: type, location: .zero, modifierFlags: code == 125 ? [.function, .numericPad] : [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: windowNumber, context: nil, characters: chars,
                charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code)
              {
                NSApp.postEvent(event, atStart: false)
              }
            }
          }
        }
        if let delay = args["delayMs"] as? Int {
          DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay), execute: post)
        } else {
          post()
        }
        result(nil)
        return
      }
      if call.method == "firstResponder", let self = self {
        // The class of the window's first responder, to check who has the
        // keyboard.
        result(self.firstResponder.map { NSStringFromClass(type(of: $0)) } ?? "nil")
        return
      }
      guard call.method == "click", let self = self, let controller = controller,
        let args = call.arguments as? [String: Any],
        let x = args["x"] as? Double, let y = args["y"] as? Double
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      NSApp.activate(ignoringOtherApps: true)
      self.makeKeyAndOrderFront(nil)
      let view = controller.view
      let local = NSPoint(x: x, y: view.isFlipped ? y : view.bounds.height - y)
      let point = view.convert(local, to: nil)
      for type in [NSEvent.EventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
        if let event = NSEvent.mouseEvent(
          with: type, location: point, modifierFlags: [],
          timestamp: ProcessInfo.processInfo.systemUptime,
          windowNumber: self.windowNumber, context: nil, eventNumber: 0,
          clickCount: type == .mouseMoved ? 0 : 1,
          pressure: type == .leftMouseDown ? 1 : 0)
        {
          NSApp.postEvent(event, atStart: false)
        }
      }
      result(nil)
    }
  }
}
