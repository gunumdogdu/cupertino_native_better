// Dumps the accessibility tree of Device Hub (com.apple.dt.Devices) so the
// pose controls (Closed / Partially Open / Open, hinge slider) can be found.
//   swift ax_dump.swift [maxDepth]
import AppKit
import ApplicationServices

let bundleID = "com.apple.dt.Devices"
let maxDepth = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 40 : 40

guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
    print("Device Hub is not running"); exit(1)
}
guard AXIsProcessTrusted() else { print("not AX trusted"); exit(2) }

// Device Hub only exposes its windows and full menus while it is active.
if !app.isActive {
    app.activate()
    Thread.sleep(forTimeInterval: 0.6)
}

let root = AXUIElementCreateApplication(app.processIdentifier)

func attr(_ el: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(el, name as CFString, &value) == .success ? value : nil
}

func str(_ v: AnyObject?) -> String? {
    guard let v else { return nil }
    if let s = v as? String { return s.isEmpty ? nil : s }
    if let n = v as? NSNumber { return n.stringValue }
    return nil
}

func actions(_ el: AXUIElement) -> [String] {
    var names: CFArray?
    guard AXUIElementCopyActionNames(el, &names) == .success, let list = names as? [String] else { return [] }
    return list
}

var count = 0
func dump(_ el: AXUIElement, _ depth: Int) {
    count += 1
    let role = str(attr(el, kAXRoleAttribute)) ?? "?"
    var parts = [role]
    if let s = str(attr(el, kAXSubroleAttribute)) { parts.append("sub=\(s)") }
    if let s = str(attr(el, kAXIdentifierAttribute)) { parts.append("id=\(s)") }
    if let s = str(attr(el, kAXTitleAttribute)) { parts.append("title=\"\(s)\"") }
    if let s = str(attr(el, kAXDescriptionAttribute)) { parts.append("desc=\"\(s)\"") }
    if let s = str(attr(el, kAXValueAttribute)) { parts.append("value=\(s.prefix(60))") }
    if let s = str(attr(el, kAXHelpAttribute)) { parts.append("help=\"\(s.prefix(60))\"") }
    let acts = actions(el).filter { $0 != "AXShowMenu" && $0 != "AXScrollToVisible" }
    if !acts.isEmpty { parts.append("actions=\(acts.joined(separator: ","))") }
    print(String(repeating: "  ", count: depth) + parts.joined(separator: " "))
    guard depth < maxDepth, let children = attr(el, kAXChildrenAttribute) as? [AXUIElement] else { return }
    for child in children { dump(child, depth + 1) }
}

dump(root, 0)
print("elements: \(count)")
