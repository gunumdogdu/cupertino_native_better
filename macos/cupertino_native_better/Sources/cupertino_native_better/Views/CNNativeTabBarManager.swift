import Cocoa
import FlutterMacOS
import SwiftUI

/// `CNTabBarNative` on macOS: the tabs become the rows of the window's
/// native sidebar (`MacSplitWindow`), with their symbols, badges and
/// selection, and the search tab becomes the sidebar's search field. Driven
/// over `cn_native_tab_bar` with the same calls and events as on iOS.
///
/// The Flutter view stays in the window, in the split view's content item,
/// so a tab without a native list shows the app's own Flutter content (iOS
/// does that in root mode). A tab with a native list shows that list in
/// place of the Flutter content, titled like the tab, as iOS shows it in the
/// tab. The bottom accessory and the minimize behavior have no Mac
/// counterpart and are accepted and ignored.
final class CNNativeTabBarManager: NSObject {
  static let shared = CNNativeTabBarManager()

  private var channel: FlutterMethodChannel?
  private var store: MacTabStore?
  private var sidebarModel: MacSidebarModel?
  private var sidebarHost: NSHostingController<MacSidebarList>?
  private var contentHost: NSHostingView<MacTabContentView>?

  func setup(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "cn_native_tab_bar", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "enable":
      guard let args else {
        result(FlutterError(code: "invalid_args", message: "Expected a map", details: nil))
        return
      }
      if present(MacTabConfig(args: args)) {
        result(nil)
      } else {
        result(FlutterError(code: "no_window", message: "No Flutter window for the sidebar", details: nil))
      }

    case "disable":
      teardown(notify: false)
      result(nil)

    case "setSelectedIndex":
      if let index = args?["index"] as? Int { store?.select(index, byUser: false) }
      result(nil)

    case "setItems":
      if let tab = args?["tabIndex"] as? Int, let items = args?["items"] as? [[String: Any]] {
        store?.setItems(tab: tab, items: MacListItem.parse(items))
      }
      result(nil)

    case "setBadgeCounts":
      if let badges = args?["badgeCounts"] as? [Any?] {
        store?.setBadges(badges.map { $0 as? Int })
      }
      result(nil)

    case "setStyle":
      if let argb = args?["tint"] as? Int { store?.tint = Color(ImageUtils.colorFromARGB(argb)) }
      syncSidebar()
      result(nil)

    case "setBrightness":
      if let isDark = args?["isDark"] as? Bool { applyAppearance(isDark: isDark) }
      result(nil)

    case "setSearchText":
      if let text = args?["text"] as? String { store?.setQuery(text, byUser: false) }
      result(nil)

    case "activateSearch":
      store?.activateSearch()
      focusSearchField()
      result(nil)

    case "deactivateSearch":
      store?.setQuery("", byUser: false)
      result(nil)

    case "setBottomAccessory", "setMinimizeBehavior":
      // A Mac window has no bottom accessory and no minimizing tab bar.
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Presenting

  private func present(_ config: MacTabConfig) -> Bool {
    // enable() again (or after a hot restart, whose Dart side forgot the
    // bar) replaces the configuration in place: no flicker, no second split.
    let store = MacTabStore(config: config)
    store.onEvent = { [weak self] name, payload in
      self?.channel?.invokeMethod(name, arguments: payload)
    }
    store.onChange = { [weak self] in self?.syncSidebar() }

    let model = sidebarModel ?? MacSidebarModel()
    model.onSelect = { [weak self] index in self?.store?.select(index, byUser: true) }
    model.onQuery = { [weak self] text in self?.store?.setQuery(text, byUser: true) }
    // The native views are kept from one enable() to the next: building
    // them again would make every enable() slower.
    let sidebar = sidebarHost ?? NSHostingController(rootView: MacSidebarList(model: model))
    // The split view sizes the sidebar, not the list's ideal size.
    if #available(macOS 13.0, *) { sidebar.sizingOptions = [] }
    let contentView = MacTabContentView(store: store, onClose: { [weak self] in
      self?.teardown(notify: true)
    })
    let content = contentHost ?? NSHostingView(rootView: contentView)
    content.rootView = contentView

    guard MacSplitWindow.shared.setSidebar(sidebar) else { return false }
    self.store = store
    self.sidebarModel = model
    self.sidebarHost = sidebar
    self.contentHost = content
    MacSplitWindow.shared.setOverlay(content)
    applyAppearance(isDark: config.isDark)
    syncSidebar()
    return true
  }

  private func teardown(notify: Bool) {
    let wasShown = store != nil
    store = nil
    sidebarModel?.onSelect = nil
    sidebarModel?.onQuery = nil
    MacSplitWindow.shared.setOverlay(nil)
    MacSplitWindow.shared.setSidebar(nil)
    if notify && wasShown { channel?.invokeMethod("onDismissed", arguments: nil) }
  }

  /// Copies the tabs, selection and search state to the sidebar, and shows
  /// the selected tab's native list over the Flutter content when it has one.
  private func syncSidebar() {
    guard let store, let model = sidebarModel else { return }
    let rows = store.tabs.enumerated().compactMap { index, tab -> MacSidebarRow? in
      if tab.isSearch { return nil }
      let badge = (tab.badge ?? 0) > 0 ? "\(tab.badge!)" : nil
      return MacSidebarRow(
        id: index, title: tab.title.isEmpty ? "Tab \(index + 1)" : tab.title,
        symbol: tab.symbol ?? "circle", activeSymbol: tab.activeSymbol,
        image: nil, activeImage: nil, badge: badge)
    }
    let sections = [MacSidebarSection(id: 0, title: nil, rows: rows)]
    if model.sections.map({ $0.rows.map(\.title) }) != sections.map({ $0.rows.map(\.title) })
      || model.sections.first?.rows.map(\.badge) != rows.map(\.badge)
      || model.sections.first?.rows.map(\.symbol) != rows.map(\.symbol)
      || model.sections.first?.rows.map(\.id) != rows.map(\.id) {
      model.sections = sections
    }
    let searchTab = store.tabs.firstIndex(where: \.isSearch)
    let selected: Int? = store.selection == searchTab ? nil : store.selection
    if model.selection != selected { model.selection = selected }
    if model.hasSearch != (searchTab != nil) { model.hasSearch = searchTab != nil }
    if let searchTab {
      let title = store.tabs[searchTab].title
      model.searchPrompt = title.isEmpty ? "Search" : title
    }
    if model.query != store.query { model.query = store.query }
    model.tint = store.tint
    MacSplitWindow.shared.setOverlayVisible(store.showsList)
  }

  private func applyAppearance(isDark: Bool?) {
    MacSplitWindow.shared.setAppearance(MacFlutterWindow.appearance(isDark: isDark), for: .sidebar)
  }

  /// Puts the keyboard in the sidebar's search field.
  private func focusSearchField() {
    guard let root = sidebarHost?.view, let window = root.window else { return }
    func find(_ view: NSView) -> NSSearchField? {
      if let field = view as? NSSearchField { return field }
      for sub in view.subviews { if let found = find(sub) { return found } }
      return nil
    }
    if let field = find(root) as? MacSidebarSearchField {
      field.focus()
    } else if let field = find(root) {
      window.makeFirstResponder(field)
    }
  }
}

// MARK: - Configuration

/// A row of a native list (`CNListItem`).
struct MacListItem {
  let title: String
  let subtitle: String?
  let trailing: String?
  let symbol: String?
  let image: NSImage?
  let chevron: Bool

  static func parse(_ data: [[String: Any]]) -> [MacListItem] {
    data.map { i in
      MacListItem(
        title: i["title"] as? String ?? "",
        subtitle: i["subtitle"] as? String,
        trailing: i["trailingText"] as? String,
        symbol: i["leadingSfSymbol"] as? String,
        image: loadImage(i["leadingImage"] as? [String: Any]),
        chevron: i["showChevron"] as? Bool ?? false)
    }
  }

  private static func loadImage(_ data: [String: Any]?) -> NSImage? {
    guard let data else { return nil }
    let format = data["format"] as? String
    if let bytes = data["data"] as? FlutterStandardTypedData {
      return ImageUtils.createImageFromData(bytes.data, format: format)
    }
    if let path = data["path"] as? String, !path.isEmpty {
      return ImageUtils.loadFlutterAsset(path, format: format)
    }
    return nil
  }
}

struct MacTabConfig {
  struct Tab {
    let title: String
    let symbol: String?
    let activeSymbol: String?
    let isSearch: Bool
    var badge: Int?
    var items: [MacListItem]?
  }

  let tabs: [Tab]
  let selectedIndex: Int
  let tint: Color?
  let isDark: Bool?
  let nativeSearchFilter: Bool
  let showCloseButton: Bool

  init(args: [String: Any]) {
    tabs = (args["tabs"] as? [[String: Any]] ?? []).map { d in
      let items = (d["nativeList"] as? [String: Any]).flatMap { $0["items"] as? [[String: Any]] }
      return Tab(
        title: d["title"] as? String ?? "",
        symbol: d["sfSymbol"] as? String,
        activeSymbol: d["activeSfSymbol"] as? String,
        isSearch: d["isSearch"] as? Bool ?? false,
        badge: d["badgeCount"] as? Int,
        items: items.map { MacListItem.parse($0) })
    }
    selectedIndex = args["selectedIndex"] as? Int ?? 0
    tint = (args["tint"] as? Int).map { Color(ImageUtils.colorFromARGB($0)) }
    isDark = args["isDark"] as? Bool
    nativeSearchFilter = args["nativeSearchFilter"] as? Bool ?? true
    showCloseButton = args["showCloseButton"] as? Bool ?? true
  }
}

// MARK: - Store

/// The tabs, the selected one and the search text. Changes made by the user
/// and programmatic ones are both reported to Dart when they change a value,
/// as the iOS bar reports them.
final class MacTabStore: ObservableObject {
  @Published var tabs: [MacTabConfig.Tab]
  @Published var selection: Int
  @Published var query = ""
  @Published var tint: Color?
  let nativeSearchFilter: Bool
  let showCloseButton: Bool
  /// The tab to go back to when the search is cleared.
  private var beforeSearch: Int

  var onEvent: ((String, [String: Any]?) -> Void)?
  var onChange: (() -> Void)?

  init(config: MacTabConfig) {
    tabs = config.tabs
    let first = config.tabs.firstIndex { !$0.isSearch } ?? 0
    var selected = min(max(config.selectedIndex, 0), max(config.tabs.count - 1, 0))
    if config.tabs.indices.contains(selected), config.tabs[selected].isSearch { selected = first }
    selection = selected
    beforeSearch = selected
    tint = config.tint
    nativeSearchFilter = config.nativeSearchFilter
    showCloseButton = config.showCloseButton
  }

  var searchIndex: Int? { tabs.firstIndex(where: \.isSearch) }

  /// Whether the selected tab shows its native list over the Flutter view.
  var showsList: Bool {
    guard tabs.indices.contains(selection) else { return false }
    return !(tabs[selection].items ?? []).isEmpty
  }

  func select(_ index: Int, byUser: Bool) {
    guard tabs.indices.contains(index) else { return }
    if index != searchIndex {
      beforeSearch = index
      if !query.isEmpty {
        // Picking a tab ends the search, as in Mac apps.
        query = ""
        onEvent?("onSearchChanged", ["query": ""])
      }
    }
    if selection != index {
      selection = index
      onEvent?("onTabSelected", ["index": index])
    }
    onChange?()
  }

  /// Typing in the search field shows the search tab's results; clearing it
  /// goes back to the tab selected before.
  func setQuery(_ text: String, byUser: Bool) {
    guard text != query else { return }
    query = text
    onEvent?("onSearchChanged", ["query": text])
    if let search = searchIndex {
      if !text.isEmpty, selection != search {
        selection = search
        onEvent?("onTabSelected", ["index": search])
      } else if text.isEmpty, selection == search, beforeSearch != search {
        selection = beforeSearch
        onEvent?("onTabSelected", ["index": beforeSearch])
      }
    }
    onChange?()
  }

  func activateSearch() {
    guard let search = searchIndex, selection != search else { return }
    selection = search
    onEvent?("onTabSelected", ["index": search])
    onChange?()
  }

  func setItems(tab: Int, items: [MacListItem]) {
    guard tabs.indices.contains(tab) else { return }
    tabs[tab].items = items
    onChange?()
  }

  func setBadges(_ badges: [Int?]) {
    var updated = tabs
    for (i, badge) in badges.enumerated() where i < updated.count {
      updated[i].badge = badge
    }
    tabs = updated
    onChange?()
  }
}

// MARK: - The selected tab's native list

/// The native list of the selected tab, over the Flutter content: the tab's
/// title, an optional close button, and its rows; for the search tab, the
/// rows matching the search text.
struct MacTabContentView: View {
  @ObservedObject var store: MacTabStore
  let onClose: () -> Void

  var body: some View {
    let index = store.selection
    if store.tabs.indices.contains(index) {
      let tab = store.tabs[index]
      VStack(alignment: .leading, spacing: 0) {
        header(tab)
        content(tab, index: index)
      }
      .tint(store.tint)
      .accentColor(store.tint)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(Color(nsColor: .windowBackgroundColor))
    } else {
      Color(nsColor: .windowBackgroundColor)
    }
  }

  private func header(_ tab: MacTabConfig.Tab) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(tab.title.isEmpty ? (tab.isSearch ? "Search" : "") : tab.title)
        .font(.title.bold())
        .accessibilityAddTraits(.isHeader)
      Spacer(minLength: 8)
      if store.showCloseButton {
        Button(action: onClose) {
          Image(systemName: "xmark")
        }
        .buttonStyle(.borderless)
        .help("Close")
        .accessibilityLabel(Text("Close"))
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 14)
    .padding(.bottom, 8)
  }

  @ViewBuilder
  private func content(_ tab: MacTabConfig.Tab, index: Int) -> some View {
    let items = tab.items ?? []
    let filter = tab.isSearch && store.nativeSearchFilter && !store.query.isEmpty
    let rows = items.enumerated().filter { entry in
      !filter
        || entry.element.title.localizedCaseInsensitiveContains(store.query)
        || (entry.element.subtitle?.localizedCaseInsensitiveContains(store.query) ?? false)
    }
    if rows.isEmpty {
      Text("No Results for \u{201C}\(store.query)\u{201D}")
        .font(.title3)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      List {
        ForEach(rows, id: \.offset) { entry in
          Button {
            store.onEvent?("onListItemTap", ["tabIndex": index, "itemIndex": entry.offset])
          } label: {
            MacListRow(item: entry.element)
          }
          .buttonStyle(.plain)
        }
      }
      .listStyle(.inset)
    }
  }
}

/// A `CNListItem` row on macOS: the leading photo or symbol, the title and
/// subtitle, trailing text and a chevron.
struct MacListRow: View {
  let item: MacListItem
  var photoSize: CGFloat = 32

  var body: some View {
    HStack(spacing: 10) {
      if let image = item.image {
        Image(nsImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: photoSize, height: photoSize)
          .clipShape(Circle())
          .accessibilityHidden(true)
      } else if let symbol = item.symbol {
        Image(systemName: symbol)
          .font(.system(size: 14))
          .foregroundColor(.secondary)
          .frame(width: photoSize, height: photoSize)
          .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
              .fill(Color(nsColor: .quaternaryLabelColor)))
          .accessibilityHidden(true)
      }
      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline) {
          Text(item.title).font(.headline)
          Spacer(minLength: 8)
          if let trailing = item.trailing {
            Text(trailing).font(.subheadline).foregroundColor(.secondary)
          }
        }
        if let subtitle = item.subtitle {
          Text(subtitle).font(.subheadline).foregroundColor(.secondary)
        }
      }
      if item.chevron {
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundColor(Color(nsColor: .tertiaryLabelColor))
          .accessibilityHidden(true)
      }
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
  }
}
