import Cocoa
import FlutterMacOS

/// The macOS side of `CNActionSheet`, over the `cn_action_sheet` channel
/// with the iOS payload (`debugBuildActionSheetPayload`), answered with the
/// chosen action's index or nil.
///
/// macOS has no action sheet. The two system controls that do its job are
/// used instead:
///
/// - **With `anchorRect`**: an `NSMenu` dropping down from the anchor, as a
///   pull-down button's menu does. The title is a section header, the
///   message a line under it, destructive actions are drawn in the system
///   red. Closing the menu (Escape, a click outside) is the cancel: it
///   answers nil, so `cancelLabel` adds no item.
/// - **Without an anchor**: an `NSAlert` sheet on the window with one button
///   per action, plus the cancel button (Escape) when `cancelLabel` is set.
///   An action sheet has no preferred action, so no button takes Return.
final class CNActionSheetManager: NSObject {
  static let shared = CNActionSheetManager()

  private var channel: FlutterMethodChannel?
  private let alerts = MacAlertPresenter()
  private let menus = MacMenuPresenter()

  func setup(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "cn_action_sheet", binaryMessenger: messenger)
    channel = ch
    ch.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "show":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "Expected a map", details: nil))
        return
      }
      show(args: args, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private struct Action {
    let label: String
    let destructive: Bool
    let enabled: Bool
  }

  private func show(args: [String: Any], result: @escaping FlutterResult) {
    // A new sheet replaces the one on screen, whichever form it took; the
    // replaced call answers nil.
    alerts.dismiss()
    menus.dismiss()

    let title = (args["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    let message = (args["message"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    let cancelLabel = args["cancelLabel"] as? String
    let actions = (args["actions"] as? [[String: Any]] ?? []).map { entry in
      Action(label: entry["label"] as? String ?? "",
             destructive: entry["destructive"] as? Bool ?? false,
             enabled: entry["enabled"] as? Bool ?? true)
    }
    let appearance = MacFlutterWindow.appearance(isDark: args["isDark"] as? Bool)

    if let rect = args["anchorRect"] as? [String: Any],
       let x = (rect["x"] as? NSNumber)?.doubleValue,
       let y = (rect["y"] as? NSNumber)?.doubleValue,
       let height = (rect["height"] as? NSNumber)?.doubleValue,
       let view = MacFlutterWindow.flutterView {
      // The menu's top-left corner at the anchor's bottom-left one. AppKit
      // moves it up when there is no room below.
      let point = MacFlutterWindow.point(x: x, y: y + height, in: view)
      menus.present(at: point, in: view, build: { onSelect in
        self.menu(title: title, message: message, actions: actions,
                  appearance: appearance, onSelect: onSelect)
      }) { path in
        result(path?.first)
      }
      return
    }

    var buttons = actions.map {
      MacAlertButton(label: $0.label, role: $0.destructive ? .destructive : .normal,
                     enabled: $0.enabled, isDefault: false)
    }
    if let cancelLabel {
      buttons.append(MacAlertButton(label: cancelLabel, role: .cancel, enabled: true, isDefault: false))
    }
    let presented = alerts.present(
      title: title, message: message, buttons: buttons, appearance: appearance,
      textStyle: args["textStyle"] as? [String: Any], rtl: CNLayoutDirection.read(args)
    ) { answer in
      // The cancel button, and a sheet closed without a button, answer nil.
      guard let index = answer?.button, index < actions.count else {
        result(nil)
        return
      }
      result(index)
    }
    if !presented {
      result(FlutterError(code: "no_window",
                          message: "No window to attach the action sheet to",
                          details: nil))
    }
  }

  /// The anchored form: the header, then one item per action. Built through
  /// `MacMenuBuilder` so the actions look like every other menu item of the
  /// plugin; an action's path is its index.
  private func menu(title: String?, message: String?, actions: [Action],
                    appearance: NSAppearance?,
                    onSelect: @escaping ([Int]) -> Void) -> NSMenu {
    let level = MacMenuLevel(dict: [
      "labels": actions.map { $0.label },
      "isDivider": actions.map { _ in false },
      "enabled": actions.map { $0.enabled },
      "isDestructive": actions.map { $0.destructive },
    ])
    let menu = MacMenuBuilder.menu(level: level, appearance: appearance, onSelect: onSelect)
    var header: [NSMenuItem] = []
    if let title { header.append(MacMenuBuilder.sectionHeader(title)) }
    if let message { header.append(Self.messageItem(message)) }
    if !header.isEmpty, !menu.items.isEmpty { header.append(.separator()) }
    for (i, item) in header.enumerated() { menu.insertItem(item, at: i) }
    return menu
  }

  /// The message under the title: secondary text that wraps instead of
  /// widening the menu, and that cannot be chosen.
  private static func messageItem(_ message: String) -> NSMenuItem {
    let item = NSMenuItem(title: message, action: nil, keyEquivalent: "")
    item.isEnabled = false
    let label = NSTextField(wrappingLabelWithString: message)
    label.font = NSFont.menuFont(ofSize: NSFont.smallSystemFontSize)
    label.textColor = .secondaryLabelColor
    label.preferredMaxLayoutWidth = 240
    let size = label.fittingSize
    let inset: CGFloat = 14
    let container = NSView(frame: NSRect(x: 0, y: 0,
                                         width: min(size.width, 240) + inset * 2,
                                         height: size.height + 4))
    label.frame = NSRect(x: inset, y: 2, width: min(size.width, 240), height: size.height)
    container.addSubview(label)
    item.view = container
    return item
  }
}
