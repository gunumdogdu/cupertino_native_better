// Presses a control in Device Hub's iPhone Duo window through accessibility,
// e.g. the pose buttons below the bezel.
//   swift duo_control.swift "Open" | "Partially Open" | "Closed" | "Rotate Right" | "Record"
//   swift duo_control.swift --list      (prints every pressable control)
import AppKit
import ApplicationServices

let bundleID = "com.apple.dt.Devices"
let args = Array(CommandLine.arguments.dropFirst())
guard let target = args.first else { print("usage: duo_control.swift <control name> | --list"); exit(64) }

guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
    print("Device Hub is not running"); exit(1)
}
guard AXIsProcessTrusted() else { print("this process is not trusted for accessibility"); exit(2) }

func attr(_ el: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(el, name as CFString, &value) == .success ? value : nil
}

func label(_ el: AXUIElement) -> String? {
    for key in [kAXDescriptionAttribute, kAXTitleAttribute, kAXHelpAttribute, kAXIdentifierAttribute] {
        if let s = attr(el, key) as? String, !s.isEmpty { return s }
    }
    return nil
}

func pressables(in el: AXUIElement, into out: inout [(String, AXUIElement)], depth: Int = 0) {
    if depth > 60 { return }
    var names: CFArray?
    if AXUIElementCopyActionNames(el, &names) == .success,
       let list = names as? [String], list.contains(kAXPressAction as String),
       ["AXButton", "AXCheckBox", "AXSwitch", "AXRadioButton", "AXCell", "AXStaticText", "AXGroup", "AXGenericElement"]
           .contains(attr(el, kAXRoleAttribute) as? String ?? ""),
       let name = label(el) {
        out.append((name, el))
    }
    for child in (attr(el, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
        pressables(in: child, into: &out, depth: depth + 1)
    }
}

// Device Hub only exposes its full menus (and keeps its device window
// reachable) while it is the active app.
if !app.isActive {
    app.activate()
    Thread.sleep(forTimeInterval: 0.6)
}

let root = AXUIElementCreateApplication(app.processIdentifier)

func duoWindow() -> AXUIElement? {
    let windows = (attr(root, kAXWindowsAttribute) as? [AXUIElement]) ?? []
    return windows.first(where: { (attr($0, kAXTitleAttribute) as? String ?? "").contains("iPhone Duo") })
}

/// Device Hub keeps the device window in its Window menu even when it is not
/// on screen; pressing that item brings it back.
func reopenFromWindowMenu() -> Bool {
    let children = (attr(root, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    guard let bar = children.first(where: { (attr($0, kAXRoleAttribute) as? String) == "AXMenuBar" }) else {
        return false
    }
    for barItem in (attr(bar, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
        guard (attr(barItem, kAXTitleAttribute) as? String) == "Window" else { continue }
        for menu in (attr(barItem, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
            for item in (attr(menu, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
                if (attr(item, kAXTitleAttribute) as? String ?? "").contains("iPhone Duo") {
                    return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
                }
            }
        }
    }
    return false
}

func menuItem(_ barTitle: String, _ itemTitle: String) -> AXUIElement? {
    let children = (attr(root, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    guard let bar = children.first(where: { (attr($0, kAXRoleAttribute) as? String) == "AXMenuBar" }) else { return nil }
    for barItem in (attr(bar, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    where (attr(barItem, kAXTitleAttribute) as? String) == barTitle {
        for menu in (attr(barItem, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
            for item in (attr(menu, kAXChildrenAttribute) as? [AXUIElement]) ?? []
            where (attr(item, kAXTitleAttribute) as? String) == itemTitle {
                return item
            }
        }
    }
    return nil
}

/// The sidebar row for the iPhone Duo simulator, found by its accessibility
/// identifier `TableRow.Device.<UDID>`.
func deviceRow(in el: AXUIElement, depth: Int = 0) -> AXUIElement? {
    if depth > 30 { return nil }
    if (attr(el, kAXRoleAttribute) as? String) == "AXRow" {
        for cell in (attr(el, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
            for item in (attr(cell, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
                let id = attr(item, kAXIdentifierAttribute) as? String ?? ""
                let value = attr(item, kAXValueAttribute) as? String ?? ""
                if id.hasPrefix("TableRow.Device."), value == "iPhone Duo" { return el }
            }
        }
    }
    for child in (attr(el, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
        if let found = deviceRow(in: child, depth: depth + 1) { return found }
    }
    return nil
}

/// Last resort when the device window is gone: open a new Device Hub window
/// and select the iPhone Duo in its sidebar.
func openFreshWindow() {
    guard let newWindow = menuItem("File", "New Window") else { return }
    AXUIElementPerformAction(newWindow, kAXPressAction as CFString)
    for _ in 0..<20 {
        Thread.sleep(forTimeInterval: 0.2)
        let windows = (attr(root, kAXWindowsAttribute) as? [AXUIElement]) ?? []
        for window in windows {
            if let row = deviceRow(in: window) {
                AXUIElementSetAttributeValue(row, kAXSelectedAttribute as CFString, kCFBooleanTrue)
                return
            }
        }
    }
}

func waitForWindow() -> AXUIElement? {
    for _ in 0..<25 {
        if let w = duoWindow() { return w }
        Thread.sleep(forTimeInterval: 0.2)
    }
    return nil
}

var found = duoWindow()
if found == nil, reopenFromWindowMenu() { found = waitForWindow() }
if found == nil { openFreshWindow(); found = waitForWindow() }
guard let window = found else {
    print("no iPhone Duo window in Device Hub, and the Window menu has none to reopen"); exit(3)
}

var controls: [(String, AXUIElement)] = []
pressables(in: window, into: &controls)

if target == "--list" {
    for (name, _) in controls { print(name) }
    exit(0)
}

guard let match = controls.first(where: { $0.0 == target }) ?? controls.first(where: { $0.0.localizedCaseInsensitiveContains(target) }) else {
    print("no control named \"\(target)\"; available: \(controls.map(\.0).joined(separator: ", "))"); exit(4)
}
let result = AXUIElementPerformAction(match.1, kAXPressAction as CFString)
print(result == .success ? "pressed \(match.0)" : "press failed: \(result.rawValue)")
exit(result == .success ? 0 : 5)
