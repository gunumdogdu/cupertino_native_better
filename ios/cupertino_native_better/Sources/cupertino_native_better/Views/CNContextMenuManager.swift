import Flutter
import UIKit

/// Opens a native `UIMenu` at a point of the Flutter view on request from
/// Dart over the `cn_context_menu` channel: the iOS side of `CNContextMenu`.
///
/// `show` takes `{menu, x, y, isDark?}`: `menu` is a level encoded by
/// `encodePopupMenuEntries`, `x`/`y` the pressed point in Flutter's global
/// logical coordinates (UIKit points of the Flutter view). It answers the
/// chosen item's path, or nil when the menu closed without a choice.
///
/// UIKit opens a menu only from the control that owns it, so a clear button
/// is put under the finger and its menu opened with `performPrimaryAction()`
/// (iOS 17.4), as `CNDotTabBar` does for tab bar item menus. The button is
/// removed when the menu closes. Below iOS 17.4 the call answers the
/// `unavailable` error and Dart shows its action sheet fallback.
final class CNContextMenuManager: NSObject {
  static let shared = CNContextMenuManager()

  private var channel: FlutterMethodChannel?

  /// The result of the menu on screen; nil whenever none is pending. Cleared
  /// by `send` so a choice followed by the menu's closing cannot answer one
  /// call twice.
  private var pendingResult: FlutterResult?

  /// The button of the menu `pendingResult` belongs to, the identity every
  /// answer is checked against.
  private weak var activeButton: CNContextMenuButton?

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
      show(level: PopupMenuLevel(dict: menu), at: CGPoint(x: x, y: y),
           isDark: args["isDark"] as? Bool, result: result)
    case "dismiss":
      dismiss()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func show(level: PopupMenuLevel, at point: CGPoint, isDark: Bool?,
                    result: @escaping FlutterResult) {
    guard #available(iOS 17.4, *) else {
      result(FlutterError(code: "unavailable",
                          message: "Opening a menu from code needs iOS 17.4",
                          details: nil))
      return
    }
    // A menu still open belongs to an earlier call: close it, answering nil.
    dismiss()

    guard let host = flutterView() else {
      result(FlutterError(code: "no_view", message: "No Flutter view to show the menu in", details: nil))
      return
    }

    let button = CNContextMenuButton(type: .custom)
    // A point-sized source: iOS 26 outlines the source of a button menu as
    // the menu grows out of it, and a larger one left a stray outline above
    // the menu.
    let side: CGFloat = 2
    button.frame = CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)
    button.showsMenuAsPrimaryAction = true
    button.preferredMenuElementOrder = .fixed
    button.isAccessibilityElement = false
    if let isDark {
      button.overrideUserInterfaceStyle = isDark ? .dark : .light
    }
    let elements = PopupMenuBuilder.elements(
      level: level,
      iconScale: host.window?.screen.scale ?? UIScreen.main.scale
    ) { [weak self, weak button] path in
      self?.send(path, from: button)
    }
    button.menu = UIMenu(title: "", children: elements)
    button.onMenuHidden = { [weak self, weak button] in
      // A chosen item's handler runs around the end of the menu's dismissal;
      // answer nil only when none did by a moment after it.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        self?.send(nil, from: button)
        button?.removeFromSuperview()
      }
    }
    host.addSubview(button)

    pendingResult = result
    activeButton = button
    button.performPrimaryAction()
  }

  private func dismiss() {
    let stale = activeButton
    send(nil)
    if let stale {
      stale.contextMenuInteraction?.dismissMenu()
      stale.removeFromSuperview()
    }
  }

  /// Delivers [value] to the waiting call once, whichever menu it came from.
  private func send(_ value: [Int]?) {
    guard let result = pendingResult else { return }
    pendingResult = nil
    activeButton = nil
    result(value)
  }

  /// Delivers [value] only while [button]'s menu is the one the pending call
  /// belongs to.
  private func send(_ value: [Int]?, from button: CNContextMenuButton?) {
    guard let button, button === activeButton else { return }
    send(value)
  }

  // MARK: - View lookup

  // Duplicated from the alert and action sheet managers, where they are
  // private.

  private func flutterView() -> UIView? {
    let scenes = UIApplication.shared.connectedScenes
    let windowScene = (scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene)
      ?? (scenes.first as? UIWindowScene)
    let window = windowScene?.windows.first(where: { $0.isKeyWindow }) ?? windowScene?.windows.first
    return findFlutterVC(window?.rootViewController)?.view
  }

  private func findFlutterVC(_ vc: UIViewController?) -> UIViewController? {
    guard let vc else { return nil }
    if vc is FlutterViewController { return vc }
    for child in vc.children {
      if let found = findFlutterVC(child) { return found }
    }
    return nil
  }
}

/// The clear button a context menu opens from. It tells when its menu has
/// gone away.
final class CNContextMenuButton: UIButton {
  var onMenuHidden: (() -> Void)?

  override func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    willEndFor configuration: UIContextMenuConfiguration,
    animator: UIContextMenuInteractionAnimating?
  ) {
    super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
    if let animator {
      animator.addCompletion { [weak self] in self?.onMenuHidden?() }
    } else {
      onMenuHidden?()
    }
  }
}
