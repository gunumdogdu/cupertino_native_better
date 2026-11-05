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
      if call.method == "toolbarAX", let self = self, let controller = controller {
        // What VoiceOver sees of the window toolbar: every accessibility
        // element above the content view, with its role, label, enabled
        // state and frame in Flutter coordinates (y negative: above the
        // Flutter view), plus the geometry of the Flutter view, for the
        // CNToolbar probe.
        let view = controller.view
        func flutterRect(_ screen: NSRect) -> [String: Double] {
          let inWindow = self.convertFromScreen(screen)
          let local = view.convert(inWindow, from: nil)
          let y = view.isFlipped ? local.minY : view.bounds.height - local.maxY
          return ["x": Double(local.minX), "y": Double(y), "w": Double(local.width), "h": Double(local.height)]
        }
        var elements: [[String: Any]] = []
        func walk(_ element: AnyObject, depth: Int) {
          guard depth < 14 else { return }
          let role = element.accessibilityRole?()?.rawValue ?? ""
          let frame = element.accessibilityFrame?() ?? .zero
          let inToolbar = self.convertFromScreen(frame).minY >= self.contentLayoutRect.maxY - 1
          if inToolbar, !role.isEmpty, !["AXGroup", "AXUnknown", "AXImage", "AXStaticText"].contains(role) {
            elements.append([
              "role": role,
              "subrole": element.accessibilitySubrole?()?.rawValue ?? "",
              "label": element.accessibilityLabel?() ?? "",
              "title": element.accessibilityTitle?() ?? "",
              "help": element.accessibilityHelp?() ?? "",
              "enabled": element.isAccessibilityEnabled?() ?? true,
              "frame": flutterRect(frame),
            ])
          }
          for child in element.accessibilityChildren?() ?? [] { walk(child as AnyObject, depth: depth + 1) }
        }
        walk(self, depth: 0)
        let content = self.contentView?.frame ?? .zero
        result([
          "elements": elements,
          "window": ["w": Double(self.frame.width), "h": Double(self.frame.height)],
          "content": ["w": Double(content.width), "h": Double(content.height)],
          "flutterView": flutterRect(self.convertToScreen(view.convert(view.bounds, to: nil))),
          "contentLayoutTop": Double(self.frame.height - self.contentLayoutRect.maxY),
          "title": self.title,
          "subtitle": self.subtitle,
          "hasToolbar": self.toolbar != nil,
          "toolbarItems": self.toolbar?.items.map { $0.itemIdentifier.rawValue } ?? [],
          "appearance": self.appearance?.name.rawValue ?? "",
        ])
        return
      }
      if call.method == "debugSplit", let self = self, let controller = controller,
        let args = call.arguments as? [String: Any]
      {
        // Stands in for the split view controller CNTabBarNative installs on
        // macOS, so the CNToolbar probe can check its sidebar items: a
        // sidebar item and the Flutter view as the content item.
        let on = (args["on"] as? Bool) ?? false
        let frame = self.frame
        if on, !(self.contentViewController is NSSplitViewController) {
          let split = NSSplitViewController()
          let sidebar = NSViewController()
          sidebar.view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 400))
          let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
          self.contentViewController = nil
          // The Flutter view below the toolbar, in the content's safe area.
          let content = NSViewController()
          content.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
          content.addChild(controller)
          controller.view.translatesAutoresizingMaskIntoConstraints = false
          content.view.addSubview(controller.view)
          NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: content.view.safeAreaLayoutGuide.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: content.view.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: content.view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: content.view.trailingAnchor),
          ])
          let contentItem = NSSplitViewItem(viewController: content)
          split.addSplitViewItem(sidebarItem)
          split.addSplitViewItem(contentItem)
          self.styleMask.insert(.fullSizeContentView)
          self.contentViewController = split
        } else if !on, let split = self.contentViewController as? NSSplitViewController {
          self.contentViewController = nil
          for item in split.splitViewItems { split.removeSplitViewItem(item) }
          controller.removeFromParent()
          controller.view.removeFromSuperview()
          controller.view.translatesAutoresizingMaskIntoConstraints = true
          self.styleMask.remove(.fullSizeContentView)
          self.contentViewController = controller
        }
        self.setFrame(frame, display: true)
        NotificationCenter.default.post(name: Notification.Name("CNWindowContentDidChange"), object: self)
        result(nil)
        return
      }
      if call.method == "scroll", let self = self, let controller = controller,
        let args = call.arguments as? [String: Any],
        let x = args["x"] as? Double, let y = args["y"] as? Double
      {
        // Wheel events at a point of the Flutter view (`dy` points each,
        // `count` of them), sent to this window. An NSEvent made from a
        // CGEvent has no window, so its location is set to the point in
        // this window's coordinates (which it then reports as its
        // locationInWindow) and the window gets it directly.
        let view = controller.view
        let local = NSPoint(x: x, y: view.isFlipped ? y : view.bounds.height - y)
        let point = view.convert(local, to: nil)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let dy = Int32((args["dy"] as? Int) ?? -12)
        for _ in 0..<((args["count"] as? Int) ?? 20) {
          if let cg = CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
            wheel1: dy, wheel2: 0, wheel3: 0)
          {
            cg.location = CGPoint(x: point.x, y: primaryHeight - point.y)
            if let event = NSEvent(cgEvent: cg) { self.sendEvent(event) }
          }
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
