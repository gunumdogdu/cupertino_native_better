import AppKit

/// Applies Flutter's text direction to a native view (#142, macOS): an app
/// that picks its language in Dart never tells AppKit about it. Nil leaves
/// the system's direction.
enum CNLayoutDirection {
  static func apply(_ rtl: Bool?, to view: NSView) {
    guard let rtl else { return }
    view.userInterfaceLayoutDirection = rtl ? .rightToLeft : .leftToRight
    for sub in view.subviews { apply(rtl, to: sub) }
    view.needsLayout = true
  }

  /// `rtl` from creation params or a `setLayoutDirection` call.
  static func read(_ dict: [String: Any]?) -> Bool? {
    dict?["rtl"] as? Bool
  }
}
