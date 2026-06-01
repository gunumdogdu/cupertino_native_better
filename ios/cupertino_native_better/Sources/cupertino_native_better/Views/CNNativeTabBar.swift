import Flutter
import SwiftUI
import UIKit

/// Configurable native iOS 26 tab bar with minimize-on-scroll + bottom
/// accessory, driven by data sent from Dart over `cn_native_tab_bar`.
///
/// State lives in an observable `CNMinTabStore` so Dart can mutate tabs, list
/// items, badges, selection, tint, theme, behavior, and search AFTER enable().
final class CNNativeTabBarManager: NSObject {

    static let shared = CNNativeTabBarManager()

    private var channel: FlutterMethodChannel?
    private weak var hostController: UIViewController?
    private var store: CNMinTabStore?
    // Held strong while presented as root so the previous (Flutter) root VC
    // stays alive to be restored on dismiss.
    private var previousRoot: UIViewController?
    private var presentedAsRoot = false

    func setup(messenger: FlutterBinaryMessenger) {
        let ch = FlutterMethodChannel(name: "cn_native_tab_bar", binaryMessenger: messenger)
        channel = ch
        ch.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        switch call.method {
        case "enable":
            guard #available(iOS 26.0, *) else {
                result(FlutterError(code: "unsupported", message: "Requires iOS 26+", details: nil))
                return
            }
            guard let args else {
                result(FlutterError(code: "invalid_args", message: "Expected a map", details: nil))
                return
            }
            present(config: CNMinTabConfig(args: args))
            result(nil)

        case "disable":
            dismiss(notify: false)
            result(nil)

        // ── Mutators (apply after enable) ─────────────────────────────────
        case "setSelectedIndex":
            if let i = args?["index"] as? Int { store?.setSelection(i) }
            result(nil)

        case "setItems":
            if let ti = args?["tabIndex"] as? Int,
               let itemsData = args?["items"] as? [[String: Any]] {
                store?.setItems(tabIndex: ti, items: CNMinTabConfig.parseItems(itemsData))
            }
            result(nil)

        case "setBadgeCounts":
            if let badges = args?["badgeCounts"] as? [Any?] {
                store?.setBadges(badges.map { $0 as? Int })
            }
            result(nil)

        case "setStyle":
            if let argb = args?["tint"] as? Int { store?.tint = ImageUtils.colorFromARGB(argb) }
            result(nil)

        case "setBottomAccessory":
            if let acc = args?["bottomAccessory"] as? [String: Any] {
                store?.accessory = CNMinTabConfig.Accessory(
                    text: acc["text"] as? String ?? "",
                    symbol: acc["sfSymbol"] as? String)
            } else {
                store?.accessory = nil  // hide
            }
            result(nil)

        case "setBrightness":
            if let isDark = args?["isDark"] as? Bool {
                hostController?.overrideUserInterfaceStyle = isDark ? .dark : .light
            }
            result(nil)

        case "setMinimizeBehavior":
            if let b = args?["behavior"] as? String { store?.minimizeBehavior = b }
            result(nil)

        case "setSearchText":
            if let t = args?["text"] as? String { store?.query = t }
            result(nil)

        case "activateSearch":
            store?.activateSearch()
            result(nil)

        case "deactivateSearch":
            store?.query = ""
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 26.0, *)
    private func present(config: CNMinTabConfig) {
        // Clean up any prior presentation (e.g. after a Flutter hot restart, or
        // a rapid disable()/enable()) so we never stack or lose the saved root.
        if hostController != nil || presentedAsRoot {
            teardown(animated: false, notify: false)
        }
        let store = CNMinTabStore(config: config)
        // SwiftUI's TabView doesn't expose an unselected-item color, so drive it
        // via the UITabBar appearance proxy (applied before the bar is created).
        // Only unselectedItemTintColor is set, to preserve the Liquid Glass look.
        applyUnselectedAppearance(config.unselectedTint)
        // In root mode the Flutter VC is detached from the window, so a tab with
        // no native list can host the app's real Flutter content. In modal mode
        // the Flutter VC stays the root, so those tabs show a placeholder.
        let flutterVC: UIViewController? = config.asRoot ? findFlutterVC(keyWindow()?.rootViewController) : nil
        let view = CNMinimizingTabView(
            store: store,
            flutterVC: flutterVC,
            onEvent: { [weak self] name, payload in
                self?.channel?.invokeMethod(name, arguments: payload)
            },
            onClose: { [weak self] in self?.dismiss(notify: true) }
        )
        let host = UIHostingController(rootView: view)
        host.overrideUserInterfaceStyle = config.isDark ? .dark : .light

        if config.asRoot {
            // Replace the app's root with the tab bar (primary navigation).
            guard let window = keyWindow() else {
                NSLog("❌ CNNativeTabBarManager: no window for root presentation")
                channel?.invokeMethod("onDismissed", arguments: nil)
                return
            }
            self.store = store
            self.hostController = host
            self.previousRoot = window.rootViewController  // strong: keep it alive
            self.presentedAsRoot = true
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                window.rootViewController = host
            }
        } else {
            // Present over the app as a fullscreen modal.
            guard let presenter = topPresenter() else {
                NSLog("❌ CNNativeTabBarManager: no presenter found")
                channel?.invokeMethod("onDismissed", arguments: nil)
                return
            }
            self.store = store
            host.modalPresentationStyle = .fullScreen
            self.hostController = host
            presenter.present(host, animated: true)
        }
    }

    private func applyUnselectedAppearance(_ color: UIColor?) {
        if #available(iOS 10.0, *) { UITabBar.appearance().unselectedItemTintColor = color }
    }

    private func dismiss(notify: Bool) { teardown(animated: true, notify: notify) }

    private func teardown(animated: Bool, notify: Bool) {
        if presentedAsRoot, let window = keyWindow(), let previous = previousRoot {
            // The Flutter VC may currently be embedded inside a tab; detach it
            // before restoring it as the window root.
            previous.willMove(toParent: nil)
            previous.view.removeFromSuperview()
            previous.removeFromParent()
            if animated {
                UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                    window.rootViewController = previous
                }
            } else {
                window.rootViewController = previous
            }
        } else {
            hostController?.dismiss(animated: animated)
        }
        applyUnselectedAppearance(nil)  // reset the global appearance proxy
        hostController = nil
        store = nil
        previousRoot = nil
        presentedAsRoot = false
        if notify { channel?.invokeMethod("onDismissed", arguments: nil) }
    }

    private func findFlutterVC(_ vc: UIViewController?) -> UIViewController? {
        guard let vc else { return nil }
        if vc is FlutterViewController { return vc }
        for child in vc.children {
            if let found = findFlutterVC(child) { return found }
        }
        return nil
    }

    private func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = (scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene)
            ?? (scenes.first as? UIWindowScene)
        return windowScene?.windows.first(where: { $0.isKeyWindow }) ?? windowScene?.windows.first
    }

    private func topPresenter() -> UIViewController? {
        guard var vc = keyWindow()?.rootViewController else { return nil }
        while let presented = vc.presentedViewController { vc = presented }
        return vc
    }
}

// MARK: - Observable store (plain data; mutated by channel methods)

final class CNMinTabStore: ObservableObject {
    @Published var tabs: [CNMinTabConfig.Tab]
    @Published var tint: UIColor?
    @Published var minimizeBehavior: String
    @Published var selection: Int
    @Published var query: String = ""
    @Published var accessory: CNMinTabConfig.Accessory?
    let nativeSearchFilter: Bool

    init(config: CNMinTabConfig) {
        tabs = config.tabs
        tint = config.tint
        minimizeBehavior = config.minimizeBehavior
        // Clamp out-of-range selection to a valid tab.
        selection = min(max(config.selectedIndex, 0), max(config.tabs.count - 1, 0))
        accessory = config.accessory
        nativeSearchFilter = config.nativeSearchFilter
    }

    func setSelection(_ index: Int) {
        guard index >= 0, index < tabs.count else { return }
        selection = index
    }

    func setItems(tabIndex: Int, items: [CNMinTabConfig.ListItem]) {
        guard tabIndex >= 0, tabIndex < tabs.count else { return }
        tabs[tabIndex].listItems = items
    }

    func setBadges(_ badges: [Int?]) {
        var updated = tabs
        for (i, badge) in badges.enumerated() where i < updated.count {
            updated[i].badge = badge
        }
        tabs = updated
    }

    func activateSearch() {
        if let idx = tabs.firstIndex(where: { $0.isSearch }) { selection = idx }
    }
}

// MARK: - Config (parsing helpers; plain data)

struct CNMinTabConfig {
    struct Tab {
        let title: String
        let symbol: String?
        let isSearch: Bool
        var badge: Int?
        var listItems: [ListItem]?
    }
    struct ListItem {
        let title: String
        let subtitle: String?
        let symbol: String?
        let chevron: Bool
    }
    struct Accessory {
        let text: String
        let symbol: String?
    }

    let tabs: [Tab]
    let minimizeBehavior: String
    let accessory: Accessory?
    let tint: UIColor?
    let unselectedTint: UIColor?
    let isDark: Bool
    let selectedIndex: Int
    let asRoot: Bool
    let nativeSearchFilter: Bool

    init(args: [String: Any]) {
        let tabsData = args["tabs"] as? [[String: Any]] ?? []
        tabs = tabsData.map { d in
            let items = (d["nativeList"] as? [String: Any]).flatMap { $0["items"] as? [[String: Any]] }
            return Tab(
                title: d["title"] as? String ?? "",
                symbol: d["sfSymbol"] as? String,
                isSearch: d["isSearch"] as? Bool ?? false,
                badge: d["badgeCount"] as? Int,
                listItems: items.map { CNMinTabConfig.parseItems($0) }
            )
        }
        minimizeBehavior = args["minimizeBehavior"] as? String ?? "onScrollDown"
        if let acc = args["bottomAccessory"] as? [String: Any] {
            accessory = Accessory(text: acc["text"] as? String ?? "", symbol: acc["sfSymbol"] as? String)
        } else {
            accessory = nil
        }
        if let argb = args["tint"] as? Int { tint = ImageUtils.colorFromARGB(argb) } else { tint = nil }
        if let argb = args["unselectedTint"] as? Int { unselectedTint = ImageUtils.colorFromARGB(argb) } else { unselectedTint = nil }
        isDark = args["isDark"] as? Bool ?? false
        selectedIndex = args["selectedIndex"] as? Int ?? 0
        asRoot = args["asRoot"] as? Bool ?? false
        nativeSearchFilter = args["nativeSearchFilter"] as? Bool ?? true
    }

    static func parseItems(_ data: [[String: Any]]) -> [ListItem] {
        data.map { i in
            ListItem(
                title: i["title"] as? String ?? "",
                subtitle: i["subtitle"] as? String,
                symbol: i["leadingSfSymbol"] as? String,
                chevron: i["showChevron"] as? Bool ?? false
            )
        }
    }
}

// MARK: - SwiftUI view

@available(iOS 26.0, *)
struct CNMinimizingTabView: View {
    @ObservedObject var store: CNMinTabStore
    /// The app's Flutter VC, embedded in tabs that have no native list
    /// (root mode only; nil in modal mode).
    let flutterVC: UIViewController?
    let onEvent: (String, [String: Any]?) -> Void
    let onClose: () -> Void

    private var behavior: TabBarMinimizeBehavior {
        switch store.minimizeBehavior {
        case "never": return .never
        case "onScrollUp": return .onScrollUp
        case "automatic": return .automatic
        default: return .onScrollDown
        }
    }

    var body: some View {
        // Apply the accessory modifier ALWAYS so the view-tree structure is
        // stable; only the CONTENT toggles. Conditionally adding/removing the
        // modifier (the `if let … else base` form) changes the structure, which
        // rebuilds the TabView and resets its selection to tab 0 — the glitch
        // seen when entering/leaving the tab that hides its accessory.
        base.tabViewBottomAccessory {
            if let accessory = store.accessory {
                accessoryView(accessory)
            } else {
                EmptyView()
            }
        }
    }

    private var base: some View {
        TabView(selection: $store.selection) {
            ForEach(store.tabs.indices, id: \.self) { index in
                let tab = store.tabs[index]
                let badgeText: Text? = (tab.badge ?? 0) > 0 ? Text("\(tab.badge!)") : nil
                Tab(tab.title.isEmpty ? (tab.isSearch ? "Search" : "Tab \(index + 1)") : tab.title,
                    systemImage: tab.symbol ?? (tab.isSearch ? "magnifyingglass" : "circle"),
                    value: index,
                    role: tab.isSearch ? .search : nil) {
                    if tab.isSearch {
                        searchContent(items: tab.listItems ?? [],
                                      title: tab.title.isEmpty ? "Search" : tab.title,
                                      tabIndex: index)
                    } else {
                        regularContent(tab: tab, index: index)
                    }
                }
                .badge(badgeText)
            }
        }
        .tint(store.tint.map { Color($0) })
        .tabBarMinimizeBehavior(behavior)
        .onChange(of: store.selection) { _, newValue in
            onEvent("onTabSelected", ["index": newValue])
        }
        .onChange(of: store.query) { _, newValue in
            onEvent("onSearchChanged", ["query": newValue])
        }
    }

    @ViewBuilder
    private func regularContent(tab: CNMinTabConfig.Tab, index: Int) -> some View {
        if let items = tab.listItems, !items.isEmpty {
            NavigationStack {
                listView(
                    rows: items.enumerated().map { (index: $0.offset, item: $0.element) },
                    tabIndex: index
                )
                .navigationTitle(tab.title)
                .toolbar { closeToolbar() }
            }
        } else if let flutterVC {
            // Host the app's real Flutter content full-bleed (root mode).
            CNFlutterContainer(flutterVC: flutterVC)
                .ignoresSafeArea()
        } else {
            NavigationStack {
                ContentUnavailableView(tab.title,
                                       systemImage: tab.symbol ?? "square.dashed",
                                       description: Text("Flutter content needs root mode (asRoot: true)"))
                .navigationTitle(tab.title)
                .toolbar { closeToolbar() }
            }
        }
    }

    @ViewBuilder
    private func searchContent(items: [CNMinTabConfig.ListItem],
                               title: String,
                               tabIndex: Int) -> some View {
        NavigationStack {
            Group {
                // Keep original indices so onListItemTap reports the right item.
                // When nativeSearchFilter is off, show items as-is (the app
                // drives results via onSearchChanged + setItems).
                let applyFilter = store.nativeSearchFilter && !store.query.isEmpty
                let filtered = items.enumerated().filter { entry in
                    !applyFilter
                        || entry.element.title.localizedCaseInsensitiveContains(store.query)
                        || (entry.element.subtitle?.localizedCaseInsensitiveContains(store.query) ?? false)
                }.map { (index: $0.offset, item: $0.element) }
                if items.isEmpty {
                    ContentUnavailableView("Search", systemImage: "magnifyingglass",
                                           description: Text("No searchable items configured"))
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: store.query)
                } else {
                    listView(rows: filtered, tabIndex: tabIndex)
                }
            }
            .navigationTitle(title)
            .toolbar { closeToolbar() }
        }
        .searchable(text: $store.query)
    }

    private func listView(rows: [(index: Int, item: CNMinTabConfig.ListItem)],
                          tabIndex: Int) -> some View {
        List {
            ForEach(rows.indices, id: \.self) { i in
                let originalIndex = rows[i].index
                let item = rows[i].item
                if item.chevron {
                    NavigationLink {
                        detail(item)
                    } label: {
                        row(item)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        onEvent("onListItemTap", ["tabIndex": tabIndex, "itemIndex": originalIndex])
                    })
                } else {
                    Button {
                        onEvent("onListItemTap", ["tabIndex": tabIndex, "itemIndex": originalIndex])
                    } label: {
                        row(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.plain)
    }

    @ToolbarContentBuilder
    private func closeToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { onClose() } label: { Image(systemName: "xmark") }
                .accessibilityLabel("Close")
        }
    }

    private func detail(_ item: CNMinTabConfig.ListItem) -> some View {
        VStack(spacing: 12) {
            if let symbol = item.symbol {
                Image(systemName: symbol).font(.system(size: 48)).foregroundStyle(.gray)
            }
            Text(item.title).font(.title2.bold())
            if let subtitle = item.subtitle {
                Text(subtitle).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ item: CNMinTabConfig.ListItem) -> some View {
        HStack(spacing: 12) {
            if let symbol = item.symbol {
                Image(systemName: symbol)
                    .foregroundStyle(.gray)
                    .frame(width: 40, height: 40)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).foregroundStyle(.primary)
                if let subtitle = item.subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.subtitle.map { "\(item.title), \($0)" } ?? item.title)
    }

    private func accessoryView(_ accessory: CNMinTabConfig.Accessory) -> some View {
        Button {
            onEvent("onAccessoryTap", nil)
        } label: {
            HStack(spacing: 6) {
                if let symbol = accessory.symbol {
                    Image(systemName: symbol).accessibilityHidden(true)
                }
                Text(accessory.text).fontWeight(.semibold)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessory.text)
    }
}

// MARK: - Flutter content host (re-parents the app's Flutter VC into a tab)

@available(iOS 26.0, *)
struct CNFlutterContainer: UIViewControllerRepresentable {
    let flutterVC: UIViewController

    func makeUIViewController(context: Context) -> CNFlutterHostController {
        CNFlutterHostController(child: flutterVC)
    }

    func updateUIViewController(_ uiViewController: CNFlutterHostController, context: Context) {
        uiViewController.attachChildIfNeeded()
    }
}

/// Hosts the shared Flutter VC as a child, moving it into whichever tab is
/// currently visible. Plain UIViewController (no iOS-26 types).
final class CNFlutterHostController: UIViewController {
    private let child: UIViewController

    init(child: UIViewController) {
        self.child = child
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        attachChildIfNeeded()
    }

    func attachChildIfNeeded() {
        if child.parent === self {
            child.view.frame = view.bounds
            return
        }
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(child.view)
        child.didMove(toParent: self)
    }
}
