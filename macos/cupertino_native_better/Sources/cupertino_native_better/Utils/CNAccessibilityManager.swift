import AppKit
import FlutterMacOS

/// `CNAccessibility` (#176): accessibility settings that Flutter doesn't
/// expose, for the whole app, over the `cn_accessibility` channel. There is
/// no platform view.
///
/// Reduce Transparency is
/// `NSWorkspace.accessibilityDisplayShouldReduceTransparency`. Dart asks for
/// it once (`getState`); from then on every change of the setting, while the
/// app runs, is sent as `onChanged`. The display options notification also
/// comes for the other display settings, so only a change of this one is
/// sent.
final class CNAccessibilityManager: NSObject {
  static let shared = CNAccessibilityManager()

  private var channel: FlutterMethodChannel?
  private var observing = false
  private var lastSent: Bool?

  func setup(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "cn_accessibility", binaryMessenger: messenger)
    channel = ch
    ch.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      switch call.method {
      case "getState":
        self.observeIfNeeded()
        self.lastSent = Self.reduceTransparency
        result(self.snapshot())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func observeIfNeeded() {
    guard !observing else { return }
    observing = true
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(settingChanged),
      name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
  }

  @objc private func settingChanged() {
    let value = Self.reduceTransparency
    guard value != lastSent else { return }
    lastSent = value
    channel?.invokeMethod("onChanged", arguments: snapshot())
  }

  private static var reduceTransparency: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
  }

  private func snapshot() -> [String: Any] {
    ["reduceTransparency": Self.reduceTransparency]
  }
}
