import Cocoa
import FlutterMacOS

/// The window toolbar of `CNToolbar` on macOS: an `NSToolbar` on the Flutter
/// window, driven over the `cn_toolbar` channel. No platform view: the
/// toolbar belongs to the window, above the Flutter view.
///
/// Calls from Dart:
/// - `setToolbar {token, items, title, subtitle, showsTitle, style, isDark}`
///   installs the toolbar, or updates the installed one in place: items are
///   inserted, removed and moved by identifier, and the others keep their
///   `NSToolbarItem` and get the new values.
/// - `removeToolbar` puts back the window's own toolbar, toolbar style,
///   title, subtitle, title visibility and appearance.
/// - `focusSearch {id}` / `endSearch {id}` start and end a search item's
///   search.
///
/// Events to Dart, each with the `token` of the configuration and the item
/// `id`: `onButtonPressed`, `onSegmentSelected {index, selected}`,
/// `onMenuSelected {path}`, `onSearchChanged {text}`,
/// `onSearchSubmitted {text}`, `onSearchActiveChanged {active}`.
///
/// Geometry: the window keeps its frame when the toolbar comes and goes, so
/// AppKit resizes the content view, and the Flutter view with it, to the
/// area under the toolbar. Nothing covers Flutter content and no gap is left.
/// A window with a full-size content view (a split view controller with a
/// sidebar) keeps its content pinned below the toolbar itself.
///
/// The window's content view controller is not touched here. The sidebar
/// and inspector items appear only while the content view controller is an
/// `NSSplitViewController` with a sidebar (inspector) item; the toolbar
/// checks again when the content view controller changes and when
/// `CNWindowContentDidChange` is posted for the window.
final class CNToolbarManager: NSObject, NSToolbarDelegate, NSSearchFieldDelegate {
  static let shared = CNToolbarManager()

  /// Posted, with the window as its object, after a window's content view
  /// controller or its split view items change.
  static let windowContentDidChange = Notification.Name("CNWindowContentDidChange")

  private var channel: FlutterMethodChannel?

  // MARK: Installed state

  private var toolbar: NSToolbar?
  private weak var window: NSWindow?
  private var saved: SavedWindow?
  private var contentObservation: NSKeyValueObservation?
  private var windowObserver: NSObjectProtocol?
  private var pendingConfig: [String: Any]?

  /// The window state the toolbar replaced.
  private struct SavedWindow {
    let toolbar: NSToolbar?
    let toolbarStyle: NSWindow.ToolbarStyle
    let title: String
    let subtitle: String
    let titleVisibility: NSWindow.TitleVisibility
    let appearance: NSAppearance?

    init(_ window: NSWindow) {
      toolbar = window.toolbar
      toolbarStyle = window.toolbarStyle
      title = window.title
      subtitle = window.subtitle
      titleVisibility = window.titleVisibility
      appearance = window.appearance
    }
  }

  // MARK: Configuration from Dart

  private var token = 0
  private var items: [Item] = []
  private var style = "unified"
  private var title: String?
  private var subtitle: String?
  private var showsTitle = true
  private var isDark: Bool?

  /// The values last applied to each item, to skip unchanged ones.
  private var applied: [NSToolbarItem.Identifier: NSDictionary] = [:]
  /// Per search field id: the text and editing state last reported to Dart.
  private var reportedText: [String: String] = [:]
  private var reportedActive: [String: Bool] = [:]
  /// The search field to keep typing in through a toolbar change, until
  /// when (see `refocus`).
  private var keepTyping: (id: String, range: NSRange, until: CFTimeInterval)?
  /// Per segmented group id: the selection last shown.
  private var groupSelection: [String: Set<Int>] = [:]

  /// One item of the configuration.
  private struct Item {
    let kind: String
    let id: String
    let dict: [String: Any]
    let identifier: NSToolbarItem.Identifier

    init(dict: [String: Any], token: Int) {
      self.dict = dict
      kind = dict["kind"] as? String ?? ""
      id = dict["id"] as? String ?? ""
      switch kind {
      case "flexibleSpace": identifier = .flexibleSpace
      case "fixedSpace": identifier = .space
      case "sidebarToggle": identifier = .toggleSidebar
      case "sidebarTrackingSeparator": identifier = .sidebarTrackingSeparator
      case "inspectorToggle":
        if #available(macOS 14.0, *) {
          identifier = .toggleInspector
        } else {
          identifier = .init("cnb.unavailable.inspectorToggle")
        }
      case "inspectorTrackingSeparator":
        if #available(macOS 14.0, *) {
          identifier = .inspectorTrackingSeparator
        } else {
          identifier = .init("cnb.unavailable.inspectorTrackingSeparator")
        }
      case "segmented":
        // A group's segments are fixed when it is made: a change to them
        // makes a new group.
        identifier = .init("cnb.\(token).segmented.\(id).\(Item.signature(of: dict))")
      default:
        // Each configuration (token) gets its own items, so one CNToolbar
        // never inherits the state of another's search field.
        identifier = .init("cnb.\(token).\(kind).\(id)")
      }
    }

    var isCustom: Bool { identifier.rawValue.hasPrefix("cnb.") }

    var centered: Bool { (dict["centered"] as? NSNumber)?.boolValue ?? false }

    /// What a segmented group is made from, as a short stable string.
    static func signature(of dict: [String: Any]) -> String {
      let parts: [Any] = [
        dict["segments"].map { segments -> [Any] in
          ((segments as? [[String: Any]]) ?? []).map { segment -> Any in
            [segment["label"] ?? "", segment["image"] ?? ""]
          }
        } ?? [],
        dict["usesImages"] ?? false,
        dict["selectionMode"] ?? "",
        dict["role"] ?? "",
      ]
      var hash: UInt64 = 0xcbf2_9ce4_8422_2325
      for byte in canonical(parts).utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x0000_0100_0000_01b3
      }
      return String(hash, radix: 36)
    }

    /// A description that does not depend on dictionary order.
    private static func canonical(_ value: Any) -> String {
      switch value {
      case let dict as [String: Any]:
        return "{" + dict.keys.sorted().map { "\($0):\(canonical(dict[$0]!))" }.joined(separator: ",") + "}"
      case let array as [Any]:
        return "[" + array.map(canonical).joined(separator: ",") + "]"
      case let data as FlutterStandardTypedData:
        var hash: UInt64 = 0
        for byte in data.data { hash = hash &* 31 &+ UInt64(byte) }
        return "<\(data.data.count):\(hash)>"
      case is NSNull:
        return "null"
      default:
        return "\(value)"
      }
    }
  }

  // MARK: Channel

  func setup(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "cn_toolbar", binaryMessenger: messenger)
    channel = ch
    ch.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    NotificationCenter.default.addObserver(
      self, selector: #selector(windowContentDidChange(_:)),
      name: Self.windowContentDidChange, object: nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    // Each call is answered first and carried out on the next turn of the
    // main queue, in the order the calls came. Installing a toolbar resizes
    // the Flutter view, and with the merged platform and UI threads a resize
    // made while Dart waits on this call cannot get its frame ("Resize timed
    // out").
    switch call.method {
    case "setToolbar":
      result(nil)
      enqueue { $0.apply(config: args) }
    case "removeToolbar":
      result(nil)
      enqueue {
        $0.pendingConfig = nil
        $0.uninstall()
      }
    case "focusSearch":
      result(nil)
      enqueue { manager in
        manager.searchItem(id: args["id"] as? String)?.beginSearchInteraction()
      }
    case "endSearch":
      result(nil)
      enqueue { manager in
        guard let item = manager.searchItem(id: args["id"] as? String) else { return }
        item.endSearchInteraction()
        manager.returnFocusToFlutter()
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func enqueue(_ work: @escaping (CNToolbarManager) -> Void) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      work(self)
    }
  }

  private func send(_ method: String, id: String, _ extra: [String: Any] = [:]) {
    var args = extra
    args["token"] = token
    args["id"] = id
    channel?.invokeMethod(method, arguments: args)
  }

  // MARK: Install, update, remove

  private func apply(config: [String: Any]) {
    let newToken = (config["token"] as? NSNumber)?.intValue ?? 0
    if newToken != token {
      applied = [:]
      reportedText = [:]
      reportedActive = [:]
      groupSelection = [:]
    }
    token = newToken
    items = ((config["items"] as? [Any]) ?? []).compactMap { $0 as? [String: Any] }
      .map { Item(dict: $0, token: newToken) }
    style = config["style"] as? String ?? "unified"
    title = config["title"] as? String
    subtitle = config["subtitle"] as? String
    showsTitle = (config["showsTitle"] as? NSNumber)?.boolValue ?? true
    isDark = (config["isDark"] as? NSNumber)?.boolValue

    guard let window = MacFlutterWindow.window else {
      // Not in a window yet (the app is still launching): install when one
      // shows up.
      pendingConfig = config
      waitForWindow()
      return
    }
    pendingConfig = nil
    if let current = self.window, current !== window || toolbar == nil || current.toolbar !== toolbar {
      // The toolbar was replaced by someone else, or the Flutter view moved
      // to another window: start again from that window's own state.
      uninstall()
    }
    if toolbar == nil { install(on: window) }
    applyWindowState()
    syncItems()
  }

  private var toolbarStyle: NSWindow.ToolbarStyle {
    switch style {
    case "unifiedCompact": return .unifiedCompact
    case "expanded": return .expanded
    default: return .unified
    }
  }

  private var displayMode: NSToolbar.DisplayMode {
    style == "expanded" ? .iconAndLabel : .iconOnly
  }

  private func install(on window: NSWindow) {
    saved = SavedWindow(window)
    let toolbar = NSToolbar(identifier: "cnb.toolbar.\(UUID().uuidString)")
    toolbar.delegate = self
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    toolbar.displayMode = displayMode
    self.toolbar = toolbar
    self.window = window
    applied = [:]
    keepingFrame(of: window) {
      window.toolbarStyle = toolbarStyle
      window.toolbar = toolbar
    }
    contentObservation = window.observe(\.contentViewController, options: []) { [weak self] _, _ in
      DispatchQueue.main.async { self?.syncItems() }
    }
  }

  private func applyWindowState() {
    guard let window, let saved, let toolbar else { return }
    keepingFrame(of: window) {
      if window.toolbarStyle != toolbarStyle { window.toolbarStyle = toolbarStyle }
      if toolbar.displayMode != displayMode { toolbar.displayMode = displayMode }
      let visibility: NSWindow.TitleVisibility = showsTitle ? .visible : .hidden
      if window.titleVisibility != visibility { window.titleVisibility = visibility }
    }
    let newTitle = title ?? saved.title
    if window.title != newTitle { window.title = newTitle }
    let newSubtitle = subtitle ?? saved.subtitle
    if window.subtitle != newSubtitle { window.subtitle = newSubtitle }
    let appearance = isDark.map { NSAppearance(named: $0 ? .darkAqua : .aqua) } ?? saved.appearance
    if window.appearance?.name != appearance?.name { window.appearance = appearance }
  }

  private func uninstall() {
    defer {
      toolbar = nil
      saved = nil
      contentObservation = nil
      applied = [:]
      reportedText = [:]
      reportedActive = [:]
      groupSelection = [:]
    }
    guard let window, let saved, let toolbar else { return }
    let hadFocus = toolbarHasKeyboardFocus(in: window)
    // Only put back what is still ours: an app that set its own toolbar
    // meanwhile keeps it.
    if window.toolbar === toolbar {
      keepingFrame(of: window) {
        window.toolbar = saved.toolbar
        window.toolbarStyle = saved.toolbarStyle
        window.titleVisibility = saved.titleVisibility
      }
    }
    toolbar.delegate = nil
    window.title = saved.title
    window.subtitle = saved.subtitle
    window.appearance = saved.appearance
    if hadFocus { returnFocusToFlutter(in: window) }
  }

  /// Runs [change] and gives the window its frame back, so the toolbar
  /// takes its height from the content area rather than growing the window.
  private func keepingFrame(of window: NSWindow, _ change: () -> Void) {
    let frame = window.frame
    change()
    if !window.styleMask.contains(.fullScreen), window.frame != frame {
      window.setFrame(frame, display: true)
    }
  }

  private func waitForWindow() {
    guard windowObserver == nil else { return }
    windowObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didBecomeMainNotification, object: nil, queue: .main
    ) { [weak self] _ in
      guard let self, let config = self.pendingConfig, MacFlutterWindow.window != nil else { return }
      if let observer = self.windowObserver {
        NotificationCenter.default.removeObserver(observer)
        self.windowObserver = nil
      }
      self.apply(config: config)
    }
  }

  @objc private func windowContentDidChange(_ note: Notification) {
    guard let window, (note.object as? NSWindow) === window else { return }
    syncItems()
  }

  // MARK: Items

  /// Whether the window has a split view controller with a sidebar or an
  /// inspector, which the sidebar and inspector items need.
  private func splitItems() -> (sidebar: Bool, inspector: Bool) {
    guard let split = Self.splitViewController(in: window?.contentViewController) else {
      return (false, false)
    }
    let behaviors = split.splitViewItems.map(\.behavior)
    return (behaviors.contains(.sidebar), behaviors.contains(.inspector))
  }

  private static func splitViewController(in controller: NSViewController?) -> NSSplitViewController? {
    guard let controller else { return nil }
    if let split = controller as? NSSplitViewController { return split }
    for child in controller.children {
      if let split = splitViewController(in: child) { return split }
    }
    return nil
  }

  /// The identifiers the toolbar should show, in order.
  private func desiredIdentifiers() -> [NSToolbarItem.Identifier] {
    let split = splitItems()
    return items.compactMap { item in
      switch item.kind {
      case "sidebarToggle", "sidebarTrackingSeparator":
        return split.sidebar ? item.identifier : nil
      case "inspectorToggle", "inspectorTrackingSeparator":
        if #available(macOS 14.0, *) { return split.inspector ? item.identifier : nil }
        return nil
      case "search", "button", "menu", "segmented", "flexibleSpace", "fixedSpace":
        return item.identifier
      default:
        return nil
      }
    }
  }

  /// Brings the toolbar's items to the configuration: removes, inserts and
  /// moves items by identifier, then updates every item in place.
  private func syncItems() {
    guard let toolbar, window?.toolbar === toolbar else { return }
    let desired = desiredIdentifiers()
    // Set before the changes: they may end the field's editing at once.
    let typing = editingSearch()
    if let typing { keepTyping = (typing.id, typing.range, CACurrentMediaTime() + 0.6) }

    // Remove what is not wanted (counting duplicates, such as spaces).
    var wanted: [NSToolbarItem.Identifier: Int] = [:]
    for id in desired { wanted[id, default: 0] += 1 }
    let current = toolbar.items.map(\.itemIdentifier)
    var keep = [Bool](repeating: false, count: current.count)
    for (i, id) in current.enumerated() where wanted[id, default: 0] > 0 {
      wanted[id]! -= 1
      keep[i] = true
    }
    for i in stride(from: current.count - 1, through: 0, by: -1) where !keep[i] {
      toolbar.removeItem(at: i)
    }

    // Insert and move into the wanted order.
    for (i, id) in desired.enumerated() {
      let ids = toolbar.items.map(\.itemIdentifier)
      if i < ids.count, ids[i] == id { continue }
      if i + 1 < ids.count, let j = ids[(i + 1)...].firstIndex(of: id) {
        toolbar.removeItem(at: j)
      }
      toolbar.insertItem(withItemIdentifier: id, at: i)
    }
    while toolbar.items.count > desired.count {
      toolbar.removeItem(at: toolbar.items.count - 1)
    }
    if let typing { refocus(typing.id, typing.range) }

    for toolbarItem in toolbar.items {
      guard let item = item(for: toolbarItem.itemIdentifier) else { continue }
      update(toolbarItem, with: item)
    }
    if #available(macOS 13.0, *) {
      let centered = Set(items.filter { $0.centered && $0.isCustom }.map(\.identifier))
      if toolbar.centeredItemIdentifiers != centered { toolbar.centeredItemIdentifiers = centered }
    }
  }

  /// The search field being typed into, and its selection.
  private func editingSearch() -> (id: String, range: NSRange)? {
    for case let search as NSSearchToolbarItem in toolbar?.items ?? [] {
      if let editor = search.searchField.currentEditor() as? NSTextView,
         let id = search.searchField.identifier?.rawValue {
        return (id, editor.selectedRange())
      }
    }
    return nil
  }

  /// Replacing items (a segmented group whose segments changed) can end
  /// the editing of the toolbar's search field, during the change or when
  /// its animation ends. For a moment after a change (`keepTyping`), an end
  /// of editing that no key or click asked for gives the field the keyboard
  /// back where the user was typing.
  private func refocus(_ id: String, _ range: NSRange) {
    guard let search = searchItem(id: id), search.searchField.currentEditor() == nil else { return }
    // As a click would: the item knows its search goes on.
    search.beginSearchInteraction()
    (search.searchField.currentEditor() as? NSTextView)?.setSelectedRange(range)
  }

  private func item(for identifier: NSToolbarItem.Identifier) -> Item? {
    items.first { $0.identifier == identifier && $0.isCustom }
  }

  private func searchItem(id: String?) -> NSSearchToolbarItem? {
    guard let id else { return nil }
    return toolbar?.items.first {
      ($0 as? NSSearchToolbarItem)?.searchField.identifier?.rawValue == id
    } as? NSSearchToolbarItem
  }

  // MARK: NSToolbarDelegate

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    desiredIdentifiers()
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    items.map(\.identifier) + [.flexibleSpace, .space]
  }

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    guard let item = item(for: itemIdentifier) else { return nil }
    let toolbarItem: NSToolbarItem
    switch item.kind {
    case "button":
      toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
      toolbarItem.target = self
      toolbarItem.action = #selector(buttonPressed(_:))
      toolbarItem.isBordered = true
    case "menu":
      toolbarItem = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
    case "segmented":
      toolbarItem = makeGroup(item)
    case "search":
      let search = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
      search.searchField.delegate = self
      search.searchField.target = self
      search.searchField.action = #selector(searchFieldAction(_:))
      search.searchField.identifier = NSUserInterfaceItemIdentifier(item.id)
      search.resignsFirstResponderWithCancel = true
      // A new field starts empty: only a change from that is reported.
      reportedText[item.id] = ""
      reportedActive[item.id] = false
      toolbarItem = search
    default:
      return nil
    }
    // The enabled state is the configuration's, not the target's answer.
    toolbarItem.autovalidates = false
    applied[itemIdentifier] = nil
    update(toolbarItem, with: item)
    return toolbarItem
  }

  // MARK: Updating one item

  private func update(_ toolbarItem: NSToolbarItem, with item: Item) {
    let values = item.dict as NSDictionary
    let previous = applied[item.identifier]
    if previous == values { return }
    applied[item.identifier] = values
    let d = item.dict
    let label = string(d["label"]) ?? ""
    toolbarItem.label = label
    toolbarItem.paletteLabel = label
    switch item.kind {
    case "button":
      toolbarItem.toolTip = string(d["tooltip"])
      let image = Self.image(d["image"], label: label)
      toolbarItem.image = image
      // A button without an icon shows its label.
      toolbarItem.title = image == nil ? label : ""
      toolbarItem.isEnabled = bool(d["enabled"], true)
      toolbarItem.isNavigational = bool(d["navigational"], false)
      #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        toolbarItem.style = string(d["style"]) == "prominent" ? .prominent : .plain
        toolbarItem.backgroundTintColor = Self.color(d["tint"])
        toolbarItem.badge = Self.badge(d["badge"])
      }
      #endif
    case "menu":
      guard let menuItem = toolbarItem as? NSMenuToolbarItem else { return }
      menuItem.toolTip = string(d["tooltip"])
      let image = Self.image(d["image"], label: label)
      menuItem.image = image
      menuItem.title = image == nil ? label : ""
      menuItem.showsIndicator = bool(d["showsIndicator"], true)
      menuItem.isEnabled = bool(d["enabled"], true)
      let menu = d["menu"] as? [String: Any] ?? [:]
      // Rebuilt only when its entries change: not while it may be open.
      if previous?["menu"] as? NSDictionary != menu as NSDictionary || menuItem.menu.items.isEmpty {
        let id = item.id
        menuItem.menu = MacMenuBuilder.menu(level: MacMenuLevel(dict: menu)) { [weak self] path in
          self?.send("onMenuSelected", id: id, ["path": path])
        }
      }
    case "segmented":
      guard let group = toolbarItem as? NSToolbarItemGroup else { return }
      updateGroup(group, item: item)
    case "search":
      guard let search = toolbarItem as? NSSearchToolbarItem else { return }
      let field = search.searchField
      let placeholder = string(d["placeholder"]) ?? label
      field.placeholderString = placeholder
      // VoiceOver reads the label, then the placeholder.
      field.setAccessibilityLabel(label)
      field.cell?.setAccessibilityLabel(label)
      if let width = (d["width"] as? NSNumber).map({ CGFloat(truncating: $0) }), width > 0 {
        search.preferredWidthForSearchField = width
      }
      if let text = d["text"] as? String, text != field.stringValue {
        // A text set from Dart is reported back, as a click on the clear
        // button would be, so Dart knows the field's text.
        field.stringValue = text
        reportText(of: field)
      }
    default:
      break
    }
  }

  // MARK: Segmented groups

  private func selectionMode(_ name: String?) -> NSToolbarItemGroup.SelectionMode {
    switch name {
    case "selectAny": return .selectAny
    case "momentary": return .momentary
    default: return .selectOne
    }
  }

  private func makeGroup(_ item: Item) -> NSToolbarItemGroup {
    let d = item.dict
    let segments = (d["segments"] as? [[String: Any]]) ?? []
    let labels = segments.map { string($0["label"]) ?? "" }
    let mode = selectionMode(string(d["selectionMode"]))
    let images = segments.enumerated().compactMap { i, segment in
      Self.image(segment["image"], label: labels[i])
    }
    let group: NSToolbarItemGroup
    if bool(d["usesImages"], false), images.count == segments.count, !segments.isEmpty {
      group = NSToolbarItemGroup(
        itemIdentifier: item.identifier, images: images, selectionMode: mode,
        labels: labels, target: self, action: #selector(segmentPressed(_:)))
    } else {
      group = NSToolbarItemGroup(
        itemIdentifier: item.identifier, titles: labels, selectionMode: mode,
        labels: labels, target: self, action: #selector(segmentPressed(_:)))
    }
    #if canImport(AppKit, _version: 2775)
    if #available(macOS 27.0, *) {
      switch string(d["role"]) {
      case "tabs": group.role = .tabs
      case "valueSelection": group.role = .valueSelection
      default: break
      }
    }
    #endif
    return group
  }

  private func updateGroup(_ group: NSToolbarItemGroup, item: Item) {
    let d = item.dict
    let segments = (d["segments"] as? [[String: Any]]) ?? []
    let enabled = bool(d["enabled"], true)
    let selected = Set(((d["selected"] as? [Any]) ?? []).compactMap { ($0 as? NSNumber)?.intValue })
    // The group draws its own control (its `view` is nil): each segment is
    // set through its subitem, which VoiceOver reads by its label.
    for (i, segment) in segments.enumerated() where i < group.subitems.count {
      let sub = group.subitems[i]
      sub.autovalidates = false
      sub.isEnabled = enabled && bool(segment["enabled"], true)
      sub.toolTip = string(segment["tooltip"])
      if group.selectionMode != .momentary {
        group.setSelected(selected.contains(i), at: i)
      }
    }
    if group.selectionMode == .selectOne, selected.isEmpty,
       (0..<group.subitems.count).contains(where: { group.isSelected(at: $0) }) {
      // A select-one group keeps its segment through a deselection or
      // `selectedIndex = -1`; as a select-any group for a moment it lets go
      // (a scaffold's tabs while its search is shown).
      group.selectionMode = .selectAny
      for i in 0..<group.subitems.count { group.setSelected(false, at: i) }
      group.selectionMode = .selectOne
    }

    group.isEnabled = enabled
    groupSelection[item.id] = currentSelection(of: group)
  }

  private func currentSelection(of group: NSToolbarItemGroup) -> Set<Int> {
    Set((0..<group.subitems.count).filter { group.isSelected(at: $0) })
  }

  @objc private func segmentPressed(_ sender: Any) {
    let group = (sender as? NSToolbarItemGroup)
      ?? toolbar?.items.compactMap({ $0 as? NSToolbarItemGroup }).first {
        $0.view === (sender as AnyObject) || $0.subitems.contains { $0 === (sender as AnyObject) }
      }
    guard let group, let item = item(for: group.itemIdentifier) else { return }
    let before = groupSelection[item.id] ?? []
    let after = group.selectionMode == .momentary ? [] : currentSelection(of: group)
    let clicked = ((sender as? NSSegmentedControl)?.selectedSegment).flatMap { $0 >= 0 ? $0 : nil }
      ?? group.selectedIndex
    // The segment that was clicked: the selected one of a selectOne group;
    // the one that changed in a selectAny group, which may have been
    // deselected; the one pressed in a momentary group.
    let index: Int
    switch group.selectionMode {
    case .selectAny:
      index = before.symmetricDifference(after).sorted().first ?? clicked
    default:
      index = clicked
    }
    groupSelection[item.id] = after
    // Dart's next configuration sets the selection again, even if unchanged.
    applied[item.identifier] = nil
    guard index >= 0 else { return }
    send("onSegmentSelected", id: item.id, ["index": index, "selected": after.sorted()])
  }

  // MARK: Buttons

  @objc private func buttonPressed(_ sender: NSToolbarItem) {
    guard let item = item(for: sender.itemIdentifier) else { return }
    send("onButtonPressed", id: item.id)
  }

  // MARK: Search fields

  private func searchId(_ field: NSSearchField) -> String? {
    field.identifier?.rawValue
  }

  private func reportText(of field: NSSearchField) {
    guard let id = searchId(field) else { return }
    let text = field.stringValue
    guard reportedText[id] != text else { return }
    reportedText[id] = text
    send("onSearchChanged", id: id, ["text": text])
  }

  @objc private func searchFieldAction(_ sender: NSSearchField) {
    // Also sent by the clear button and after a pause in typing.
    reportText(of: sender)
  }

  func controlTextDidChange(_ obj: Notification) {
    guard let field = obj.object as? NSSearchField else { return }
    reportText(of: field)
  }

  func controlTextDidBeginEditing(_ obj: Notification) {
    guard let field = obj.object as? NSSearchField else { return }
    reportActive(of: field)
  }

  func controlTextDidEndEditing(_ obj: Notification) {
    guard let field = obj.object as? NSSearchField else { return }
    let movement = (obj.userInfo?["NSTextMovement"] as? NSNumber)?.intValue ?? NSTextMovement.other.rawValue
    if movement == NSTextMovement.other.rawValue, let keep = keepTyping,
       keep.id == searchId(field), CACurrentMediaTime() < keep.until {
      // Ended by the toolbar's layout, not by the user: not reported.
      DispatchQueue.main.async { [weak self] in self?.refocus(keep.id, keep.range) }
      return
    }
    reportText(of: field)
    // Return ends editing and starts it again at once: the search is over
    // only if the field is still not being edited on the next turn.
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.reportActive(of: field)
      // Nobody took the keyboard (Esc, or Return with nowhere to go): give
      // it back to Flutter. A click into another control keeps its focus.
      if let window = self.window, field.currentEditor() == nil,
         window.firstResponder == nil || window.firstResponder === window {
        self.returnFocusToFlutter(in: window)
      }
    }
  }

  /// Reports whether [field] is being edited, when that changed.
  private func reportActive(of field: NSSearchField) {
    guard let id = searchId(field) else { return }
    let active = field.currentEditor() != nil
    guard reportedActive[id] != active else { return }
    reportedActive[id] = active
    send("onSearchActiveChanged", id: id, ["active": active])
  }

  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    guard let field = control as? NSSearchField, let id = searchId(field) else { return false }
    switch commandSelector {
    case #selector(NSResponder.insertNewline(_:)):
      reportText(of: field)
      send("onSearchSubmitted", id: id, ["text": field.stringValue])
      return false
    case #selector(NSResponder.cancelOperation(_:)) where field.stringValue.isEmpty:
      // Esc in an empty field ends the search, as Esc ends a search in a
      // window toolbar; the first Esc clears the text (AppKit's own).
      searchItem(id: id)?.endSearchInteraction()
      if let window { returnFocusToFlutter(in: window) }
      return true
    default:
      return false
    }
  }

  private func toolbarHasKeyboardFocus(in window: NSWindow) -> Bool {
    guard let editor = window.firstResponder as? NSTextView, editor.isFieldEditor else { return false }
    return toolbar?.items.contains {
      ($0 as? NSSearchToolbarItem)?.searchField.currentEditor() === editor
    } ?? false
  }

  private func returnFocusToFlutter(in window: NSWindow? = nil) {
    guard let window = window ?? self.window else { return }
    window.makeFirstResponder(MacFlutterWindow.flutterView ?? window.contentView)
  }

  // MARK: Values

  private func string(_ value: Any?) -> String? {
    guard let s = value as? String, !s.isEmpty else { return nil }
    return s
  }

  private func bool(_ value: Any?, _ fallback: Bool) -> Bool {
    (value as? NSNumber)?.boolValue ?? fallback
  }

  static func color(_ value: Any?) -> NSColor? {
    (value as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
  }

  /// The icon of an item, from an image description of `_encodeImage`
  /// (toolbar.dart): image asset or bytes, then a custom icon Flutter
  /// rendered, then an SF Symbol. The toolbar sizes symbols itself; VoiceOver
  /// reads [label] for the image.
  static func image(_ value: Any?, label: String) -> NSImage? {
    guard let d = value as? [String: Any] else { return nil }
    let color = color(d["color"])
    var image: NSImage?
    let path = d["assetPath"] as? String
    let data = (d["imageData"] as? FlutterStandardTypedData)?.data
    if (path?.isEmpty == false) || data != nil {
      image = ImageUtils.image(
        assetPath: path, imageData: data, format: d["format"] as? String,
        customIconBytes: nil, size: 18, color: color)
    } else if let bytes = (d["customIconBytes"] as? FlutterStandardTypedData)?.data {
      image = ImageUtils.image(
        assetPath: nil, imageData: nil, format: nil,
        customIconBytes: bytes, size: 18, color: color)
    } else if let name = d["symbol"] as? String, !name.isEmpty {
      let palette = ((d["palette"] as? [Any]) ?? []).compactMap { $0 as? NSNumber }
        .map { ImageUtils.colorFromARGB($0.intValue) }
      image = ImageUtils.symbolImage(
        name: name, size: nil, color: color, mode: d["mode"] as? String,
        palette: palette, accessibilityDescription: label)
    }
    image?.accessibilityDescription = label
    return image
  }

  #if compiler(>=6.2)
  @available(macOS 26.0, *)
  static func badge(_ value: Any?) -> NSItemBadge? {
    guard let d = value as? [String: Any] else { return nil }
    switch d["type"] as? String {
    case "count": return .count((d["value"] as? NSNumber)?.intValue ?? 0)
    case "text": return .text(d["value"] as? String ?? "")
    case "indicator": return .indicator
    default: return nil
    }
  }
  #endif
}
