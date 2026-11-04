import Cocoa
import FlutterMacOS

/// Shows a native context menu (`NSMenu`) at a point of the Flutter view on
/// request from Dart over the `cn_context_menu` channel: the macOS side of
/// `CNContextMenu` and of `CNPopupGesture`'s secondary click.
///
/// `show` takes `{menu, x, y, isDark?}`: `menu` is a level encoded by
/// `encodePopupMenuEntries`, `x`/`y` the pointer in Flutter's global logical
/// coordinates. It answers the chosen item's path, or nil when the menu was
/// closed without a choice. It opens as AppKit opens a context menu for a
/// secondary click (`NSMenu.popUpContextMenu`), at the pointer, which works in
/// a window of an app that is not active too, as a right click there does.
final class CNContextMenuManager: NSObject {
  static let shared = CNContextMenuManager()

  private var channel: FlutterMethodChannel?
  private let presenter = MacMenuPresenter()

  func setup(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "cn_context_menu", binaryMessenger: messenger)
    channel = ch
    ch.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "show":
      guard let args = call.arguments as? [String: Any],
            let menu = args["menu"] as? [String: Any],
            let x = (args["x"] as? NSNumber)?.doubleValue,
            let y = (args["y"] as? NSNumber)?.doubleValue
      else {
        result(FlutterError(code: "invalid_args", message: "Expected {menu, x, y}", details: nil))
        return
      }
      guard let view = MacFlutterWindow.flutterView else {
        result(FlutterError(code: "no_view", message: "No Flutter view to show the menu in", details: nil))
        return
      }
      let appearance = MacFlutterWindow.appearance(isDark: args["isDark"] as? Bool)
      let point = MacFlutterWindow.point(x: x, y: y, in: view)
      presenter.present(at: point, in: view, style: .context, build: { onSelect in
        MacMenuBuilder.menu(level: MacMenuLevel(dict: menu), appearance: appearance, onSelect: onSelect)
      }) { path in
        result(path)
      }
    case "dismiss":
      presenter.dismiss()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
