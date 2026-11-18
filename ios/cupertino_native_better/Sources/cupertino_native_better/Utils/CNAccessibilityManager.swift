import Flutter
import UIKit

/// `CNAccessibility` (#176): accessibility settings that Flutter doesn't
/// expose, for the whole app, over the `cn_accessibility` channel. There is
/// no platform view.
///
/// Reduce Transparency is `UIAccessibility.isReduceTransparencyEnabled`.
/// Dart asks for it once (`getState`); from then on every change of the
/// setting, while the app runs, is sent as `onChanged`.
final class CNAccessibilityManager: NSObject {
  static let shared = CNAccessibilityManager()

  private var channel: FlutterMethodChannel?
  private var observing = false

  func setup(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "cn_accessibility", binaryMessenger: messenger)
    channel = ch
    ch.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      switch call.method {
      case "getState":
        self.observeIfNeeded()
        result(self.snapshot())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func observeIfNeeded() {
    guard !observing else { return }
    observing = true
    NotificationCenter.default.addObserver(
      self, selector: #selector(settingChanged),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
  }

  @objc private func settingChanged() {
    channel?.invokeMethod("onChanged", arguments: snapshot())
  }

  private func snapshot() -> [String: Any] {
    ["reduceTransparency": UIAccessibility.isReduceTransparencyEnabled]
  }
}
