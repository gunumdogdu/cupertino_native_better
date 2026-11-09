import Cocoa
import FlutterMacOS

/// Presents a native `NSAlert` as a sheet on the Flutter window on request
/// from Dart over the `cn_alert` channel: the macOS side of `CNAlert`.
///
/// Same channel protocol as the iOS `CNAlertManager` (`show` with the payload
/// of `debugBuildAlertPayload`, answered with `{index, textFields}` or nil),
/// so the Dart API is unchanged.
///
/// - Buttons are added most prominent first, which is how `NSAlert` orders
///   them: the default action (`isDefault`) at the trailing edge with Return,
///   the cancel action next to it with Escape, the rest after. Without an
///   `isDefault` action the first action that is not cancel leads and gets
///   Return, as AppKit's own first button does, unless it is destructive: a
///   destructive button is never pressed by Return unless it asked for it.
/// - A destructive action sets `NSButton.hasDestructiveAction` (macOS 11+).
/// - Text fields are `NSTextField` / `NSSecureTextField` in the accessory
///   view, the first one focused.
/// - `isDark` (sent only when the app's theme sets a brightness, #118) pins
///   the sheet's appearance; without it the sheet follows the window.
final class CNAlertManager: NSObject {
  static let shared = CNAlertManager()

  private var channel: FlutterMethodChannel?
  private let presenter = MacAlertPresenter()

  func setup(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "cn_alert", binaryMessenger: messenger)
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

  private func show(args: [String: Any], result: @escaping FlutterResult) {
    let rawActions = args["actions"] as? [[String: Any]] ?? []
    // Mirrors the guard in `CNAlert.show`: an alert can't be dismissed
    // without a button, so one with no enabled button could never answer.
    guard rawActions.contains(where: { ($0["enabled"] as? Bool) ?? true }) else {
      presenter.dismiss()
      result(FlutterError(code: "no_enabled_action",
                          message: "An alert needs at least one enabled action to be answerable",
                          details: nil))
      return
    }

    var cancelUsed = false
    var buttons: [MacAlertButton] = rawActions.map { entry in
      var role: MacAlertButton.Role
      switch entry["style"] as? String {
      case "cancel": role = .cancel
      case "destructive": role = .destructive
      default: role = .normal
      }
      // One cancel button, like UIKit: a second one is a normal button.
      if role == .cancel {
        if cancelUsed { role = .normal } else { cancelUsed = true }
      }
      return MacAlertButton(
        label: entry["label"] as? String ?? "",
        role: role,
        enabled: entry["enabled"] as? Bool ?? true,
        isDefault: entry["preferred"] as? Bool ?? false)
    }
    if !buttons.contains(where: { $0.isDefault }),
       let lead = MacAlertPresenter.order(of: buttons).first,
       buttons[lead].role != .destructive {
      let b = buttons[lead]
      buttons[lead] = MacAlertButton(label: b.label, role: b.role, enabled: b.enabled, isDefault: true)
    }
    // At most one Return button.
    var defaultSeen = false
    buttons = buttons.map { b in
      guard b.isDefault else { return b }
      if defaultSeen {
        return MacAlertButton(label: b.label, role: b.role, enabled: b.enabled, isDefault: false)
      }
      defaultSeen = true
      return b
    }

    let fields = (args["textFields"] as? [[String: Any]] ?? []).map { entry in
      MacAlertTextField(
        placeholder: entry["placeholder"] as? String,
        initialText: entry["initialText"] as? String,
        obscure: entry["obscure"] as? Bool ?? false)
    }

    let presented = presenter.present(
      title: args["title"] as? String,
      message: args["message"] as? String,
      buttons: buttons,
      textFields: fields,
      appearance: MacFlutterWindow.appearance(isDark: args["isDark"] as? Bool),
      textStyle: args["textStyle"] as? [String: Any],
      rtl: CNLayoutDirection.read(args)
    ) { answer in
      guard let answer else {
        result(nil)
        return
      }
      result(["index": answer.button, "textFields": answer.textFields])
    }
    if !presented {
      result(FlutterError(code: "no_window",
                          message: "No window to attach the alert sheet to",
                          details: nil))
    }
  }
}
