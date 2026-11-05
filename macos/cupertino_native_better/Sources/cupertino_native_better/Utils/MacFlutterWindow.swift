import Cocoa
import FlutterMacOS

/// Finds the Flutter view and its window for the window-level presenters
/// (alerts, action sheets, menus), and converts Flutter's coordinates into
/// that view's.
///
/// Flutter's logical pixels are the view's points (the device pixel ratio is
/// the window's backing scale factor), measured from the view's top-left
/// corner. The view is not flipped, so y is mirrored against its current
/// height, read at the moment of the conversion: a resized window converts
/// correctly.
enum MacFlutterWindow {
  /// Set from `CupertinoNativePlugin.register`. The registrar's view is read
  /// on every call rather than kept: it can be attached after registration.
  static var registrar: FlutterPluginRegistrar?

  /// The view showing Flutter content, or nil when there is none yet.
  static var flutterView: NSView? {
    if let view = registrar?.view { return view }
    // While the split view is installed the content view controller is the
    // split view controller; the Flutter view is inside its content item.
    if let view = MacSplitWindow.shared.flutterContentView { return view }
    let window = NSApp.keyWindow ?? NSApp.mainWindow
    return window?.contentViewController?.view ?? window?.contentView
  }

  /// The window a sheet or a menu belongs to.
  static var window: NSWindow? {
    flutterView?.window ?? NSApp.keyWindow ?? NSApp.mainWindow
  }

  /// A point in Flutter's global logical coordinates, in [view]'s.
  static func point(x: Double, y: Double, in view: NSView) -> NSPoint {
    NSPoint(x: x, y: view.isFlipped ? y : Double(view.bounds.height) - y)
  }

  static func appearance(isDark: Bool?) -> NSAppearance? {
    guard let isDark else { return nil }
    return NSAppearance(named: isDark ? .darkAqua : .aqua)
  }
}

/// Shows one `NSMenu` at a time at a point of the Flutter view and reports
/// what was chosen exactly once: the path of the chosen item, or nil when
/// the menu closed without a choice.
///
/// AppKit tracks a menu in a nested event loop, as it does every menu;
/// Flutter keeps running meanwhile (its run loop sources are in the common
/// modes). Tracking is started from the main queue, not from the method call
/// handler, so the call returns first.
final class MacMenuPresenter {
  /// Identifies the menu on screen; answers from any other are dropped.
  private var token: MenuToken?
  private var completion: (([Int]?) -> Void)?

  /// How a menu opens.
  enum Style {
    /// Drops down from [point], its top-left corner there: the menu of a
    /// pull-down button.
    case dropDown
    /// A context menu at [point], as AppKit opens one for a secondary click,
    /// also in a window of an app that is not active.
    case context
  }

  /// Opens the menu [build] makes at [point] of [view]. [build] gets the
  /// callback its items report their path to. A menu already open is closed
  /// first and answers nil.
  func present(
    at point: NSPoint,
    in view: NSView,
    style: Style = .dropDown,
    build: (@escaping ([Int]) -> Void) -> NSMenu,
    completion: @escaping ([Int]?) -> Void
  ) {
    dismiss()
    let token = MenuToken()
    let menu = build { [weak self] path in
      self?.finish(path, from: token)
    }
    token.menu = menu
    self.token = token
    self.completion = completion
    DispatchQueue.main.async { [weak self] in
      guard let self, self.token === token else { return }
      switch style {
      case .dropDown:
        _ = menu.popUp(positioning: nil, at: point, in: view)
      case .context:
        let event = NSEvent.mouseEvent(
          with: .rightMouseDown,
          location: view.convert(point, to: nil),
          modifierFlags: [],
          timestamp: ProcessInfo.processInfo.systemUptime,
          windowNumber: view.window?.windowNumber ?? 0,
          context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
        if let event {
          NSMenu.popUpContextMenu(menu, with: event, for: view)
        } else {
          _ = menu.popUp(positioning: nil, at: point, in: view)
        }
      }
      // AppKit sends the chosen item's action before tracking returns (seen
      // on macOS 27 for both calls), so a menu that has not answered by the
      // next turn was closed without a choice.
      DispatchQueue.main.async { [weak self] in
        self?.finish(nil, from: token)
      }
    }
  }

  /// Closes the open menu, if any; it answers nil.
  func dismiss() {
    guard let token else { return }
    let menu = token.menu
    finish(nil, from: token)
    menu?.cancelTrackingWithoutAnimation()
  }

  private func finish(_ path: [Int]?, from token: MenuToken) {
    guard token === self.token, let completion else { return }
    // The menu was kept until now: AppKit sends the action after `popUp`.
    token.menu = nil
    self.token = nil
    self.completion = nil
    completion(path)
  }
}

/// The menu a `MacMenuPresenter` call belongs to, kept alive until it has
/// answered.
private final class MenuToken {
  var menu: NSMenu?
}
