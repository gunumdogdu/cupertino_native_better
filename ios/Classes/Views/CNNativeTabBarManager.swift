import Flutter
import UIKit

/// Manager for iOS 26+ Native Tab Bar with Search Support
///
/// Architecture: a single `NativeTabBarContainerVC` holds the Flutter view **permanently**
/// inside a `FlutterContentHostViewController` nested under a `UINavigationController`.
/// A `UITabBar` is overlaid at the bottom. Tab changes only update chrome (nav bar +
/// `UISearchController` when the selected tab is a search tab) — the Flutter view is
/// **never** reparented between child view controllers, fixing Issue #7 (double-tap).
///
/// `UISearchController` remains attached to the navigation item when `isSearchTab` is true,
/// preserving the native search integration expected by `CNTabBarNative` users.
class CNNativeTabBarManager: NSObject {

    static let shared = CNNativeTabBarManager()

    private var containerVC: NativeTabBarContainerVC?
    private var flutterViewController: FlutterViewController?
    private var methodChannel: FlutterMethodChannel?
    private var searchController: UISearchController?
    private var isEnabled: Bool = false
    private var tintColor: UIColor?
    private var unselectedTintColor: UIColor?
    private var tabConfigurations: [TabConfig] = []
    private var searchTabIndex: Int = -1
    private var ignoreInitialSearchUpdate = true

    struct TabConfig {
        let title: String
        let sfSymbol: String?
        let activeSfSymbol: String?
        let isSearchTab: Bool
        let badgeCount: Int?
    }

    private override init() {
        super.init()
    }

    func setup(messenger: FlutterBinaryMessenger) {
        guard #available(iOS 26.0, *) else {
            NSLog("⚠️ CNNativeTabBarManager: Requires iOS 26+")
            return
        }

        self.methodChannel = FlutterMethodChannel(
            name: "cn_native_tab_bar",
            binaryMessenger: messenger
        )
        methodChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }

    private func getFlutterViewController() -> FlutterViewController? {
        if let vc = flutterViewController { return vc }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let vc = window.rootViewController as? FlutterViewController {
            self.flutterViewController = vc
            return vc
        }
        return nil
    }

    // MARK: - Enable / Disable

    private func enableNativeTabBar(tabs: [TabConfig], selectedIndex: Int, isDark: Bool) {
        guard let flutterVC = getFlutterViewController() else {
            NSLog("❌ CNNativeTabBarManager: Could not find FlutterViewController")
            return
        }

        self.tabConfigurations = tabs
        self.searchTabIndex = tabs.firstIndex(where: { $0.isSearchTab }) ?? -1

        let isSearchOnlyMode = tabs.count == 1 && tabs[0].isSearchTab

        if isSearchOnlyMode {
            enableSearchOnlyMode(flutterVC: flutterVC, config: tabs[0], isDark: isDark)
            return
        }

        // Build UISearchController once if any tab is a search tab (delegate = self)
        if searchTabIndex >= 0 {
            let search = UISearchController(searchResultsController: nil)
            search.searchResultsUpdater = self
            search.searchBar.delegate = self
            search.obscuresBackgroundDuringPresentation = false
            search.hidesNavigationBarDuringPresentation = false
            search.showsSearchResultsController = false
            self.searchController = search
        }

        let vc = NativeTabBarContainerVC()
        vc.methodChannel = methodChannel
        vc.tintColor = tintColor
        vc.unselectedTintColor = unselectedTintColor
        vc.overrideUserInterfaceStyle = isDark ? .dark : .light
        vc.searchController = searchController
        vc.configure(tabs: tabs, selectedIndex: selectedIndex, searchOnlyMode: false)

        self.containerVC = vc

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return
        }

        // 1) Attacher le container comme racine pour que la hiérarchie ait une taille valide.
        // 2) Puis intégrer le FlutterViewController en enfant (addChild) — reparentage de la
        //    seule UIView cassait souvent le rendu (surface vide).
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            window.rootViewController = vc
        }, completion: { _ in
            vc.view.setNeedsLayout()
            vc.view.layoutIfNeeded()
            vc.embedFlutterView(flutterVC)
        })

        self.isEnabled = true
        // Allow searchResultsUpdater to forward queries (same pattern as search-only mode).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.ignoreInitialSearchUpdate = false
        }
        NSLog("✅ CNNativeTabBarManager: Native tab bar enabled (container + UISearchController)")
    }

    private func enableSearchOnlyMode(flutterVC: FlutterViewController, config: TabConfig, isDark: Bool) {
        ignoreInitialSearchUpdate = true

        let search = UISearchController(searchResultsController: nil)
        search.searchResultsUpdater = self
        search.searchBar.delegate = self
        search.obscuresBackgroundDuringPresentation = false
        search.hidesNavigationBarDuringPresentation = false
        search.showsSearchResultsController = false
        search.searchBar.placeholder = config.title.isEmpty ? "Search" : config.title
        self.searchController = search

        let vc = NativeTabBarContainerVC()
        vc.methodChannel = methodChannel
        vc.tintColor = tintColor
        vc.unselectedTintColor = unselectedTintColor
        vc.overrideUserInterfaceStyle = isDark ? .dark : .light
        vc.searchController = searchController
        vc.configure(
            tabs: [config],
            selectedIndex: 0,
            searchOnlyMode: true
        )

        self.containerVC = vc

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return
        }

        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            window.rootViewController = vc
        }, completion: { _ in
            vc.view.setNeedsLayout()
            vc.view.layoutIfNeeded()
            vc.embedFlutterView(flutterVC)
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            search.isActive = false
            self?.ignoreInitialSearchUpdate = false
        }

        self.isEnabled = true
        NSLog("✅ CNNativeTabBarManager: Search-only mode (container + UISearchController)")
    }

    private func disableNativeTabBar() {
        guard let flutterVC = flutterViewController else { return }

        containerVC?.removeFlutterView()
        searchController = nil

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return
        }

        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = flutterVC
        }

        self.containerVC = nil
        self.isEnabled = false
        NSLog("✅ CNNativeTabBarManager: Native tab bar disabled")
    }

    // MARK: - Method channel

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "enable":
            guard let args = call.arguments as? [String: Any],
                  let tabsData = args["tabs"] as? [[String: Any]] else {
                result(FlutterError(code: "invalid_args", message: "Invalid tabs data", details: nil))
                return
            }

            let tabs = tabsData.compactMap { data -> TabConfig? in
                guard let title = data["title"] as? String else { return nil }
                return TabConfig(
                    title: title,
                    sfSymbol: data["sfSymbol"] as? String,
                    activeSfSymbol: data["activeSfSymbol"] as? String,
                    isSearchTab: (data["isSearch"] as? Bool) ?? false,
                    badgeCount: data["badgeCount"] as? Int
                )
            }

            let selectedIndex = (args["selectedIndex"] as? Int) ?? 0
            let isDark = (args["isDark"] as? Bool) ?? false

            if let tint = args["tint"] as? Int { tintColor = ImageUtils.colorFromARGB(tint) }
            if let unsel = args["unselectedTint"] as? Int { unselectedTintColor = ImageUtils.colorFromARGB(unsel) }

            enableNativeTabBar(tabs: tabs, selectedIndex: selectedIndex, isDark: isDark)
            result(nil)

        case "disable":
            disableNativeTabBar()
            result(nil)

        case "setSelectedIndex":
            guard let args = call.arguments as? [String: Any],
                  let index = args["index"] as? Int else {
                result(FlutterError(code: "invalid_args", message: "Invalid index", details: nil))
                return
            }
            containerVC?.selectTab(at: index)
            result(nil)

        case "activateSearch":
            if searchTabIndex >= 0 {
                containerVC?.selectTab(at: searchTabIndex)
            }
            searchController?.isActive = true
            result(nil)

        case "deactivateSearch":
            searchController?.isActive = false
            result(nil)

        case "setSearchText":
            if let args = call.arguments as? [String: Any],
               let text = args["text"] as? String {
                searchController?.searchBar.text = text
            }
            result(nil)

        case "isEnabled":
            result(isEnabled)

        case "setBadgeCounts":
            guard let args = call.arguments as? [String: Any],
                  let raw = args["badgeCounts"] as? [Any] else {
                result(FlutterError(code: "invalid_args", message: "Invalid badge counts", details: nil))
                return
            }
            let badgeCounts: [Int?] = raw.map { any in
                if any is NSNull { return nil }
                if let i = any as? Int { return i }
                if let n = any as? NSNumber { return n.intValue }
                return nil
            }
            containerVC?.updateBadges(badgeCounts)
            result(nil)

        case "setStyle":
            if let args = call.arguments as? [String: Any] {
                if let tint = args["tint"] as? Int {
                    let color = ImageUtils.colorFromARGB(tint)
                    tintColor = color
                    containerVC?.applyTint(color)
                }
                if let unsel = args["unselectedTint"] as? Int {
                    let color = ImageUtils.colorFromARGB(unsel)
                    unselectedTintColor = color
                    containerVC?.applyUnselectedTint(color)
                }
            }
            result(nil)

        case "setBrightness":
            if let args = call.arguments as? [String: Any],
               let isDark = args["isDark"] as? Bool {
                containerVC?.overrideUserInterfaceStyle = isDark ? .dark : .light
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - UISearchResultsUpdating & UISearchBarDelegate

extension CNNativeTabBarManager: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        if ignoreInitialSearchUpdate { return }
        guard let query = searchController.searchBar.text else { return }
        methodChannel?.invokeMethod("onSearchChanged", arguments: ["query": query])
    }
}

extension CNNativeTabBarManager: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text else { return }
        methodChannel?.invokeMethod("onSearchSubmitted", arguments: ["query": query])
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        methodChannel?.invokeMethod("onSearchCancelled", arguments: nil)
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        methodChannel?.invokeMethod("onSearchActiveChanged", arguments: ["isActive": true])
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        methodChannel?.invokeMethod("onSearchActiveChanged", arguments: ["isActive": false])
    }
}

// MARK: - NativeTabBarContainerVC

/// Root container: `UINavigationController` + bottom `UITabBar`. The navigation stack has a
/// single root that permanently hosts the Flutter view; search UI is toggled via
/// `navigationItem.searchController` without moving the Flutter view.
private class NativeTabBarContainerVC: UIViewController, UITabBarDelegate {

    weak var methodChannel: FlutterMethodChannel?
    var tintColor: UIColor?
    var unselectedTintColor: UIColor?
    /// Owned by [CNNativeTabBarManager]; same instance used when search tab is active.
    var searchController: UISearchController?

    private var navController: UINavigationController!
    private var contentHost: FlutterContentHostViewController!
    private var nativeTabBar: UITabBar!

    private var tabConfigurations: [CNNativeTabBarManager.TabConfig] = []
    private var currentIndex: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        contentHost = FlutterContentHostViewController()
        navController = UINavigationController(rootViewController: contentHost)
        navController.navigationBar.prefersLargeTitles = true

        addChild(navController)
        navController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navController.view)
        navController.didMove(toParent: self)

        // Plein écran derrière la tab bar (effet type iOS : contenu visible sous la barre translucide).
        NSLayoutConstraint.activate([
            navController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navController.view.topAnchor.constraint(equalTo: view.topAnchor),
            navController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        buildTabBar()
    }

    private func buildTabBar() {
        let bar = UITabBar()
        bar.delegate = self
        bar.isTranslucent = true
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.layer.shadowOpacity = 0

        if let tint = tintColor { bar.tintColor = tint }
        if let unsel = unselectedTintColor { bar.unselectedItemTintColor = unsel }

        if #available(iOS 13.0, *) {
            let ap = UITabBarAppearance()
            ap.configureWithTransparentBackground()
            ap.shadowColor = .clear
            ap.shadowImage = UIImage()
            bar.standardAppearance = ap
            if #available(iOS 15.0, *) { bar.scrollEdgeAppearance = ap }
        }

        view.addSubview(bar)
        // Au-dessus du contenu Flutter (z-order) pour interaction + flou.
        view.bringSubviewToFront(bar)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        nativeTabBar = bar
    }

    func configure(tabs: [CNNativeTabBarManager.TabConfig], selectedIndex: Int, searchOnlyMode: Bool) {
        self.tabConfigurations = tabs
        self.currentIndex = min(max(0, selectedIndex), max(0, tabs.count - 1))

        _ = view

        if searchOnlyMode {
            nativeTabBar.removeFromSuperview()
        } else if nativeTabBar.superview == nil {
            view.addSubview(nativeTabBar)
            nativeTabBar.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                nativeTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                nativeTabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                nativeTabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            view.bringSubviewToFront(nativeTabBar)
        }

        let items: [UITabBarItem] = tabs.enumerated().map { (i, config) in
            if config.isSearchTab {
                let item = UITabBarItem(tabBarSystemItem: .search, tag: i)
                if !config.title.isEmpty { item.title = config.title }
                if let count = config.badgeCount, count > 0 {
                    item.badgeValue = count > 99 ? "99+" : String(count)
                }
                return item
            }

            var image: UIImage?
            var selectedImage: UIImage?

            if let symbol = config.sfSymbol, !symbol.isEmpty {
                if let unsel = unselectedTintColor {
                    image = UIImage(systemName: symbol)?.withTintColor(unsel, renderingMode: .alwaysOriginal)
                } else {
                    image = UIImage(systemName: symbol)?.withRenderingMode(.alwaysTemplate)
                }
            }
            if let activeSymbol = config.activeSfSymbol, !activeSymbol.isEmpty {
                selectedImage = UIImage(systemName: activeSymbol)?.withRenderingMode(.alwaysTemplate)
            }

            let item = UITabBarItem(title: config.title, image: image, selectedImage: selectedImage ?? image)
            item.tag = i
            if let count = config.badgeCount, count > 0 {
                item.badgeValue = count > 99 ? "99+" : String(count)
            }
            return item
        }

        nativeTabBar.items = items
        if currentIndex < items.count {
            nativeTabBar.selectedItem = items[currentIndex]
        }

        applySearchChrome(animated: false)
        methodChannel?.invokeMethod("onTabSelected", arguments: ["index": currentIndex])
    }

    func embedFlutterView(_ flutterVC: FlutterViewController) {
        contentHost.embedFlutterViewController(flutterVC)
    }

    func removeFlutterView() {
        contentHost.removeFlutterView()
    }

    func selectTab(at index: Int) {
        guard index >= 0, index < tabConfigurations.count else { return }
        currentIndex = index
        if let items = nativeTabBar.items, index < items.count {
            nativeTabBar.selectedItem = items[index]
        }
        applySearchChrome(animated: true)
        methodChannel?.invokeMethod("onTabSelected", arguments: ["index": index])
    }

    private func applySearchChrome(animated: Bool) {
        guard !tabConfigurations.isEmpty else { return }
        let config = tabConfigurations[currentIndex]

        if config.isSearchTab, let search = searchController {
            search.searchBar.placeholder = config.title.isEmpty ? "Search" : config.title
            contentHost.title = config.title.isEmpty ? "Search" : config.title
            contentHost.navigationItem.searchController = search
            contentHost.navigationItem.hidesSearchBarWhenScrolling = false
            contentHost.definesPresentationContext = true
            navController.setNavigationBarHidden(false, animated: animated)
        } else {
            contentHost.navigationItem.searchController = nil
            contentHost.title = config.title.isEmpty ? nil : config.title
            navController.setNavigationBarHidden(true, animated: animated)
        }
    }

    func updateBadges(_ badgeCounts: [Int?]) {
        guard let items = nativeTabBar.items else { return }
        for (i, item) in items.enumerated() {
            if i < badgeCounts.count {
                if let count = badgeCounts[i], count > 0 {
                    item.badgeValue = count > 99 ? "99+" : String(count)
                } else {
                    item.badgeValue = nil
                }
            }
        }
    }

    func applyTint(_ color: UIColor) {
        nativeTabBar.tintColor = color
    }

    func applyUnselectedTint(_ color: UIColor) {
        nativeTabBar.unselectedItemTintColor = color
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let items = tabBar.items,
              let index = items.firstIndex(of: item) else { return }
        currentIndex = index
        applySearchChrome(animated: true)
        methodChannel?.invokeMethod("onTabSelected", arguments: ["index": index])
    }
}

// MARK: - FlutterContentHostViewController

/// Single VC that hosts the [FlutterViewController] as enfant pour un cycle de vie correct.
private class FlutterContentHostViewController: UIViewController {

    private var embeddedFlutterVC: FlutterViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    func embedFlutterViewController(_ flutterVC: FlutterViewController) {
        if let old = embeddedFlutterVC {
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
            embeddedFlutterVC = nil
        }

        addChild(flutterVC)
        flutterVC.view.translatesAutoresizingMaskIntoConstraints = false
        flutterVC.view.isHidden = false
        flutterVC.view.alpha = 1.0
        view.addSubview(flutterVC.view)
        NSLayoutConstraint.activate([
            flutterVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            flutterVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            flutterVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            flutterVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        flutterVC.didMove(toParent: self)
        embeddedFlutterVC = flutterVC
        view.layoutIfNeeded()
        NSLog("✅ FlutterContentHostViewController: FlutterViewController embedded (child VC)")
    }

    func removeFlutterView() {
        embeddedFlutterVC?.willMove(toParent: nil)
        embeddedFlutterVC?.view.removeFromSuperview()
        embeddedFlutterVC?.removeFromParent()
        embeddedFlutterVC = nil
    }
}
