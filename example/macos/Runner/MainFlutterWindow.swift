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
