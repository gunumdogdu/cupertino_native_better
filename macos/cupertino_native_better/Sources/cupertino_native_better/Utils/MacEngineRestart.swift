import Cocoa
import FlutterMacOS

/// Tells the window-level managers (popover, toolbar, split window) that a
/// hot restart replaced the Dart isolate, so what Dart put on the window is
/// stale.
///
/// The engine announces every new root isolate on the `flutter/isolate`
/// channel (debug and profile builds; the macOS embedder does not listen to
/// it). A channel has one handler, so this owns it and posts
/// [notification] to every observer. The first launch posts it too, before
/// any Dart code has asked for anything, so observers only clean up what
/// they hold.
enum MacEngineRestart {
  static let notification = Notification.Name("CNFlutterIsolateRestarted")

  private static var observedMessengers: [ObjectIdentifier] = []

  /// Installs the handler once per messenger. Safe to call from every
  /// manager's setup.
  static func observe(_ messenger: FlutterBinaryMessenger) {
    let id = ObjectIdentifier(messenger as AnyObject)
    guard !observedMessengers.contains(id) else { return }
    observedMessengers.append(id)
    _ = messenger.setMessageHandlerOnChannel("flutter/isolate") { _, reply in
      reply(nil)
      NotificationCenter.default.post(name: notification, object: nil)
    }
  }
}
