import UIKit

/// Applies Flutter's text direction to a native view or controller (#142).
///
/// UIKit lays views out by the app's language, which an app that picks its
/// language in Dart (an in-app switch to Arabic) never tells it about. The
/// widgets send `rtl` from `Directionality` (or their `textDirection`), and
/// this forces it on the view and everything in it: the layout direction
/// trait (iOS 17+), which every subview inherits, and the view's semantic
/// content attribute. Nil leaves the system's direction.
enum CNLayoutDirection {
  static func apply(_ rtl: Bool?, to view: UIView) {
    guard let rtl else { return }
    view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
    if #available(iOS 17.0, *) {
      view.traitOverrides.layoutDirection = rtl ? .rightToLeft : .leftToRight
    }
    view.setNeedsLayout()
  }

  static func apply(_ rtl: Bool?, to controller: UIViewController) {
    guard let rtl else { return }
    if #available(iOS 17.0, *) {
      controller.traitOverrides.layoutDirection = rtl ? .rightToLeft : .leftToRight
    }
    controller.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
  }

  /// `rtl` from creation params or a `setLayoutDirection` call.
  static func read(_ dict: [String: Any]?) -> Bool? {
    dict?["rtl"] as? Bool
  }
}
