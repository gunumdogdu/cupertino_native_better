import Cocoa
import FlutterMacOS

/// Puts the Flutter window's content into an `NSSplitViewController`, with a
/// native sidebar before it (`CNTabBarNative`) and an inspector after it
/// (`CNNativeSheet`), and puts the window back as it was when neither is
/// wanted.
///
/// The window's own content view controller (the `FlutterViewController` of
/// the app template, or whatever the app put there) is moved into the
/// content item, never recreated: the engine, its view, the text input and
/// the platform views stay as they are. Only the view's superview changes,
/// and the window keeps its frame and its first responder.
///
/// While the split view is installed the window has a full-size content
/// view, so the sidebar and the inspector reach the top of the window as in
/// system apps (and a toolbar's sidebar tracking separator works). The
/// Flutter view stays inside the content's safe area: below the titlebar or
/// toolbar, beside the sidebar and the inspector, never under them.
///
/// The content is not extended under the sidebar (no
/// `automaticallyAdjustsSafeAreaInsets`, no `NSBackgroundExtensionView`):
/// the sidebar and the inspector keep their standard material, whatever the
/// app draws at the edge of its Flutter view. An extension view would tint
/// the sidebar with the content's edge, which suits a map or a photo but not
/// an arbitrary app whose edge changes from page to page.
///
/// The changes are made on the next turn of the main queue, after the
/// method call that asked for them has returned. Each one resizes the
/// Flutter view, and Flutter waits for a frame of the new size before it
/// shows the window again; on macOS the Dart code runs on the main thread,
/// so it can only draw that frame once the call has returned. Changes asked
/// for in a row are applied together.
///
/// After each change it posts `CNWindowContentDidChange` (object: the
/// window), on which `CNToolbar` re-checks whether its sidebar and inspector
/// items apply. It never touches the window's toolbar.
final class MacSplitWindow: NSObject {
  static let shared = MacSplitWindow()

  /// Posted with the window as object after the split view is installed,
  /// changed or removed. A plain name, shared with the toolbar code by value.
  static let contentDidChange = Notification.Name("CNWindowContentDidChange")

  /// The sidebar's width when it appears.
  static let sidebarWidth: CGFloat = 220

  /// The part of the split view a manager owns.
  enum Part { case sidebar, inspector }

  private struct InspectorRequest {
    let controller: NSViewController
    let canCollapse: Bool
    let onCollapse: (() -> Void)?
  }

  // What the managers asked for.
  private var wantedSidebar: NSViewController?
  private var wantedInspector: InspectorRequest?
  private var wantedOverlay: NSView?
  private var overlayVisible = false
  private var appearances: [Part: NSAppearance] = [:]
  private var applyScheduled = false

  // What the window shows.
  private weak var window: NSWindow?
  private var split: NSSplitViewController?
  private var content: CNSplitContentController?
  /// The window's content view controller before the split view; held here
  /// while it lives in the content item, as the window no longer holds it.
  private var original: NSViewController?
  private var addedFullSizeContentView = false
  /// The last window the split view was installed in, and whether it had a
  /// full-size content view of its own, for the full screen fix below.
  private weak var lastWindow: NSWindow?
  private var lastWindowHadFullSize = false
  private var observingFullScreen = false
  private var savedAppearance: NSAppearance?
  private weak var savedInitialFirstResponder: NSView?
  private var sidebarItem: NSSplitViewItem?
  private var inspectorItem: NSSplitViewItem?
  private var inspectorCollapse: NSKeyValueObservation?
  private var sidebarMenuItems: [NSMenuItem] = []

  /// Whether the window currently shows the split view.
  var isInstalled: Bool { split != nil }

  /// The view showing Flutter content while the split view is installed.
  var flutterContentView: NSView? { original?.view }

  /// Whether there is a window whose content can go into a split view.
  var canInstall: Bool {
    if split != nil { return true }
    guard let controller = MacFlutterWindow.window?.contentViewController else { return false }
    return !(controller is NSSplitViewController)
  }

  // MARK: - Requests

  /// Shows [controller] as the window's sidebar, or removes the sidebar when
  /// nil. Returns false when there is no window to put it in.
  @discardableResult
  func setSidebar(_ controller: NSViewController?) -> Bool {
    if controller != nil, !canInstall {
      NSLog("cupertino_native_better: no Flutter window for the sidebar")
      return false
    }
    wantedSidebar = controller
    if controller == nil { appearances[.sidebar] = nil }
    scheduleApply()
    return true
  }

  /// Shows [controller] as the window's inspector, or removes it when nil.
  /// With [canCollapse] the user may close it by dragging its divider (or
  /// with `toggleInspector:`), which calls [onCollapse]; without it the
  /// inspector stays. Returns false when there is no window.
  @discardableResult
  func setInspector(
    _ controller: NSViewController?,
    canCollapse: Bool = true,
    onCollapse: (() -> Void)? = nil
  ) -> Bool {
    if controller != nil, !canInstall {
      NSLog("cupertino_native_better: no Flutter window for the inspector")
      return false
    }
    wantedInspector = controller.map {
      InspectorRequest(controller: $0, canCollapse: canCollapse, onCollapse: onCollapse)
    }
    if controller == nil { appearances[.inspector] = nil }
    scheduleApply()
    return true
  }

  /// Draws the window light or dark while [part] is shown; nil follows the
  /// app. The window, not only the part, takes the appearance: the material
  /// of the sidebar and the inspector belongs to the split view, and the
  /// titlebar above them to the window. The sidebar's choice wins over the
  /// inspector's. Flutter's own brightness is not affected.
  func setAppearance(_ appearance: NSAppearance?, for part: Part) {
    appearances[part] = appearance
    applyAppearance()
  }

  /// A native view drawn over the Flutter content, in the same frame, such
  /// as the list of a `CNTabBarNative` tab.
  func setOverlay(_ view: NSView?) {
    wantedOverlay = view
    if view == nil { overlayVisible = false }
    content?.setOverlay(view, visible: overlayVisible)
  }

  /// Shows the overlay and hides the Flutter view under it, or the reverse.
  func setOverlayVisible(_ visible: Bool) {
    overlayVisible = visible
    content?.setOverlayVisible(visible)
  }

  // MARK: - Applying

  private func scheduleApply() {
    guard !applyScheduled else { return }
    applyScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.applyScheduled = false
      self.apply()
    }
  }

  private func apply() {
    guard wantedSidebar != nil || wantedInspector != nil else {
      if split != nil { uninstall() }
      return
    }
    if split == nil {
      if install() { notify() }
      return
    }
    if syncItems() { notify() }
    if sidebarItem != nil { addSidebarMenuItem() } else { removeSidebarMenuItem() }
    applyAppearance()
  }

  /// Adds, replaces or removes the sidebar and inspector items to match
  /// what was asked for. Returns whether anything changed.
  @discardableResult
  private func syncItems() -> Bool {
    guard let split else { return false }
    var changed = false

    if sidebarItem?.viewController !== wantedSidebar {
      if let old = sidebarItem {
        split.removeSplitViewItem(old)
        sidebarItem = nil
      }
      if let controller = wantedSidebar {
        // A standard width to start with; the user can drag it.
        controller.view.setFrameSize(NSSize(width: Self.sidebarWidth, height: controller.view.frame.height))
        let item = NSSplitViewItem(sidebarWithViewController: controller)
        item.minimumThickness = 180
        item.maximumThickness = 400
        split.insertSplitViewItem(item, at: 0)
        sidebarItem = item
      }
      changed = true
    }

    if inspectorItem?.viewController !== wantedInspector?.controller {
      if let old = inspectorItem {
        inspectorCollapse = nil
        split.removeSplitViewItem(old)
        inspectorItem = nil
      }
      if let request = wantedInspector {
        let item = NSSplitViewItem(inspectorWithViewController: request.controller)
        // macOS 14 gives inspectors standard widths; earlier ones get these.
        if #unavailable(macOS 14.0) {
          item.minimumThickness = 250
          item.maximumThickness = 400
        }
        split.addSplitViewItem(item)
        inspectorItem = item
        inspectorCollapse = item.observe(\.isCollapsed, options: [.new]) { [weak self] item, _ in
          guard item.isCollapsed else { return }
          DispatchQueue.main.async { self?.inspectorDidCollapse(item) }
        }
      }
      changed = true
    }
    if let item = inspectorItem, let request = wantedInspector, item.canCollapse != request.canCollapse {
      item.canCollapse = request.canCollapse
    }
    return changed
  }

  private func inspectorDidCollapse(_ item: NSSplitViewItem) {
    guard item === inspectorItem, item.isCollapsed else { return }
    wantedInspector?.onCollapse?()
  }

  private func applyAppearance() {
    guard let window, split != nil else { return }
    let wanted = appearances[.sidebar] ?? appearances[.inspector] ?? savedAppearance
    if window.appearance !== wanted { window.appearance = wanted }
  }

  // MARK: - Install / uninstall

  /// Moves the window's content into a new split view with the items asked
  /// for. The Flutter view is resized once, straight to its final size:
  /// Flutter waits for a frame of every size its view takes (up to a second
  /// when it cannot draw one, such as at an empty size), so every
  /// intermediate size would be a pause. It is out of the window while the
  /// window grows a full-size content view, and goes into a content item
  /// that is already laid out beside the sidebar and the inspector.
  private func install() -> Bool {
    guard let window = MacFlutterWindow.window,
          let original = window.contentViewController,
          !(original is NSSplitViewController) else {
      NSLog("cupertino_native_better: no Flutter window for the split view")
      return false
    }
    let frame = window.frame
    let responder = savedResponder(in: window, under: original.view)

    let split = NSSplitViewController()
    let content = CNSplitContentController()
    let contentItem = NSSplitViewItem(viewController: content)
    contentItem.minimumThickness = 200
    split.addSplitViewItem(contentItem)
    self.window = window
    self.split = split
    self.content = content
    self.original = original
    savedAppearance = window.appearance
    syncItems()
    // Sized as the content view, so the window keeps its frame.
    split.view.frame = window.contentView?.frame ?? NSRect(origin: .zero, size: frame.size)

    // While the Flutter view is out of the window, AppKit gives the
    // keyboard to the window's initial first responder, by default the
    // first view in the key view loop: the sidebar's search field. It
    // belongs to Flutter, as before the move.
    savedInitialFirstResponder = window.initialFirstResponder
    window.initialFirstResponder = flutterResponder(in: original.view)
    window.contentViewController = split
    addedFullSizeContentView = !window.styleMask.contains(.fullSizeContentView)
    if addedFullSizeContentView { window.styleMask.insert(.fullSizeContentView) }
    lastWindow = window
    lastWindowHadFullSize = !addedFullSizeContentView
    observeFullScreen()
    if !window.styleMask.contains(.fullScreen) && window.frame != frame {
      window.setFrame(frame, display: false)
    }
    split.view.layoutSubtreeIfNeeded()
    content.embed(original)
    content.setOverlay(wantedOverlay, visible: overlayVisible)
    restore(responder, in: window, fallback: original.view)
    // AppKit settles the key view loop on a later turn; the keyboard stays
    // where it was unless the user moved it meanwhile.
    DispatchQueue.main.async { [weak self, weak window] in
      guard let self, let window, let original = self.original else { return }
      let current = window.firstResponder
      let inFlutter = (current as? NSView)?.isDescendant(of: original.view) ?? false
      if !inFlutter, !self.userMovedKeyboard {
        self.restore(responder, in: window, fallback: original.view, force: true)
      }
    }
    if sidebarItem != nil { addSidebarMenuItem() }
    applyAppearance()
    return true
  }

  /// Puts the window's content back. The Flutter view is resized once: it
  /// keeps its size while the window drops the full-size content view
  /// (the titlebar's safe area goes with it), then takes the window's
  /// content size.
  private func uninstall() {
    removeSidebarMenuItem()
    let window = self.window
    if let window, let content, let original {
      if window.appearance !== savedAppearance { window.appearance = savedAppearance }
      let frame = window.frame
      let responder = savedResponder(in: window, under: original.view)
      if addedFullSizeContentView { window.styleMask.remove(.fullSizeContentView) }
      content.release(original)
      window.contentViewController = original
      window.initialFirstResponder = savedInitialFirstResponder
      if !window.styleMask.contains(.fullScreen) && window.frame != frame {
        window.setFrame(frame, display: true)
      }
      restore(responder, in: window, fallback: original.view)
    }
    split = nil
    content = nil
    original = nil
    sidebarItem = nil
    inspectorItem = nil
    inspectorCollapse = nil
    addedFullSizeContentView = false
    savedAppearance = nil
    savedInitialFirstResponder = nil
    appearances = [:]
    if let window {
      NotificationCenter.default.post(name: Self.contentDidChange, object: window)
    }
    self.window = nil
  }

  /// Leaving full screen, AppKit puts back the style mask the window had
  /// when it entered, which undoes a full-size content view added or
  /// removed meanwhile (the split view shown or hidden in full screen). It
  /// is set again to what the window needs now.
  private func observeFullScreen() {
    guard !observingFullScreen else { return }
    observingFullScreen = true
    NotificationCenter.default.addObserver(
      self, selector: #selector(windowDidExitFullScreen(_:)),
      name: NSWindow.didExitFullScreenNotification, object: nil)
  }

  @objc private func windowDidExitFullScreen(_ notification: Notification) {
    guard let window = notification.object as? NSWindow, window === lastWindow else { return }
    let wanted = split != nil || lastWindowHadFullSize
    if window.styleMask.contains(.fullSizeContentView) != wanted {
      if wanted {
        window.styleMask.insert(.fullSizeContentView)
      } else {
        window.styleMask.remove(.fullSizeContentView)
      }
    }
  }

  /// Tells `CNToolbar` the items changed: the window posts no KVO for its
  /// content view controller when only the split view's items change.
  private func notify() {
    guard let window else { return }
    NotificationCenter.default.post(name: Self.contentDidChange, object: window)
  }

  // MARK: - First responder

  /// The first responder to give back after the move: a view inside the
  /// Flutter content (the Flutter view, or the text input view of a focused
  /// text field), or nil when the keyboard was elsewhere.
  private func savedResponder(in window: NSWindow, under root: NSView) -> NSView? {
    guard let view = window.firstResponder as? NSView else { return nil }
    return view.isDescendant(of: root) ? view : nil
  }

  /// Gives the keyboard back to [responder] (inside the Flutter content),
  /// or to the Flutter view when nothing has it ([force]: when anything
  /// outside the Flutter content has it).
  private func restore(_ responder: NSView?, in window: NSWindow, fallback: NSView, force: Bool = false) {
    let current = window.firstResponder
    if let responder, responder.window === window {
      if current !== responder { window.makeFirstResponder(responder) }
    } else if force || current == nil || current === window {
      // Flutter takes the keys when nothing else does, as before the move.
      window.makeFirstResponder(flutterResponder(in: fallback))
    }
  }

  /// The Flutter view inside the content view controller's view.
  private func flutterResponder(in root: NSView) -> NSView {
    root.subviews.first { NSStringFromClass(type(of: $0)) == "FlutterView" }
      ?? root.subviews.first { $0.acceptsFirstResponder } ?? root
  }

  /// Whether the user clicked or typed since the last install, which would
  /// make a moved keyboard focus deliberate.
  private var userMovedKeyboard: Bool {
    guard let event = NSApp.currentEvent else { return false }
    switch event.type {
    case .leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown: return true
    default: return false
    }
  }

  // MARK: - View menu

  /// Adds the standard Show Sidebar command (Control-Command-S) to the View
  /// menu when the app's menu has none. AppKit titles it Show or Hide
  /// Sidebar and sends `toggleSidebar:` to the split view controller.
  private func addSidebarMenuItem() {
    guard sidebarMenuItems.isEmpty, let menu = viewMenu() else { return }
    let action = #selector(NSSplitViewController.toggleSidebar(_:))
    if menu.items.contains(where: { $0.action == action }) { return }
    let item = NSMenuItem(title: "Show Sidebar", action: action, keyEquivalent: "s")
    item.keyEquivalentModifierMask = [.control, .command]
    let separator = NSMenuItem.separator()
    menu.insertItem(item, at: 0)
    menu.insertItem(separator, at: 1)
    sidebarMenuItems = [item, separator]
  }

  private func removeSidebarMenuItem() {
    for item in sidebarMenuItems {
      item.menu?.removeItem(item)
    }
    sidebarMenuItems = []
  }

  /// The menu holding Enter Full Screen, which is the View menu of the
  /// Flutter app template, or the one titled View.
  private func viewMenu() -> NSMenu? {
    let full = #selector(NSWindow.toggleFullScreen(_:))
    let menus = NSApp.mainMenu?.items.compactMap { $0.submenu } ?? []
    return menus.first { $0.items.contains { $0.action == full } }
      ?? menus.first { $0.title == "View" }
  }
}

/// The split view's content item: the window's former content view
/// controller (normally the `FlutterViewController`) as a child, its view in
/// the safe area, and an optional native overlay in the same frame.
final class CNSplitContentController: NSViewController {
  // A plain view, not an `NSBackgroundExtensionView`: see `MacSplitWindow`.
  /// Holds the Flutter view and the overlay, in the safe area.
  private let container = NSView()
  private weak var embedded: NSViewController?
  private var embeddedAutoresizes = true
  private var embeddedMask: NSView.AutoresizingMask = [.width, .height]
  private var overlay: NSView?

  override func loadView() {
    container.translatesAutoresizingMaskIntoConstraints = false
    let root = NSView()
    root.addSubview(container)
    let guide = root.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      container.topAnchor.constraint(equalTo: guide.topAnchor),
      container.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
      container.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
      container.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
    ])
    view = root
  }

  func embed(_ child: NSViewController) {
    _ = view
    addChild(child)
    let childView = child.view
    embeddedAutoresizes = childView.translatesAutoresizingMaskIntoConstraints
    embeddedMask = childView.autoresizingMask
    childView.translatesAutoresizingMaskIntoConstraints = false
    childView.isHidden = false
    container.addSubview(childView, positioned: .below, relativeTo: overlay)
    pin(childView)
    // Takes its new size now, in the window.
    container.layoutSubtreeIfNeeded()
    embedded = child
  }

  /// Takes [child] out again, as it was before [embed].
  func release(_ child: NSViewController) {
    setOverlay(nil, visible: false)
    let childView = child.view
    childView.removeFromSuperview()
    child.removeFromParent()
    childView.isHidden = false
    childView.translatesAutoresizingMaskIntoConstraints = embeddedAutoresizes
    childView.autoresizingMask = embeddedMask
    embedded = nil
  }

  func setOverlay(_ view: NSView?, visible: Bool) {
    if overlay !== view {
      if let old = overlay {
        moveKeyboard(from: old, toFlutter: true)
        old.removeFromSuperview()
      }
      overlay = view
      if let view {
        _ = self.view
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        container.addSubview(view, positioned: .above, relativeTo: embedded?.view)
        pin(view)
      }
    }
    setOverlayVisible(view != nil && visible)
  }

  func setOverlayVisible(_ visible: Bool) {
    let flutter = embedded?.view
    guard let overlay else {
      if flutter?.isHidden == true { flutter?.isHidden = false }
      return
    }
    if overlay.isHidden == !visible, flutter?.isHidden == visible { return }
    if visible, let flutter { moveKeyboard(from: flutter, toFlutter: false) }
    if !visible { moveKeyboard(from: overlay, toFlutter: true) }
    overlay.isHidden = !visible
    flutter?.isHidden = visible
  }

  /// A view about to be hidden gives up the keyboard: to the overlay over
  /// the Flutter view, or back to the Flutter view.
  private func moveKeyboard(from view: NSView, toFlutter: Bool) {
    guard let window = self.view.window,
          let responder = window.firstResponder as? NSView,
          responder.isDescendant(of: view) else { return }
    if toFlutter, let flutter = embedded?.view {
      window.makeFirstResponder(flutter.subviews.first { $0.acceptsFirstResponder } ?? flutter)
    } else if let overlay {
      window.makeFirstResponder(overlay)
    }
  }

  private func pin(_ subview: NSView) {
    NSLayoutConstraint.activate([
      subview.topAnchor.constraint(equalTo: container.topAnchor),
      subview.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      subview.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      subview.trailingAnchor.constraint(equalTo: container.trailingAnchor),
    ])
  }
}
