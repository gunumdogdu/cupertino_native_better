import Flutter
import UIKit

/// Manager for iOS 26+ Native Tab Bar with Search Support
/// This class manages a native UITabBarController at the app level
/// and coordinates with Flutter for content display
class CNNativeTabBarManager: NSObject {

    static let shared = CNNativeTabBarManager()

    private var tabBarController: UITabBarController?
    private var flutterViewController: FlutterViewController?
    private var searchController: UISearchController?
    private var methodChannel: FlutterMethodChannel?

    private var tabConfigurations: [TabConfig] = []
    private var searchTabIndex: Int = -1
    private var isEnabled: Bool = false
    private var tintColor: UIColor?
    private var unselectedTintColor: UIColor?

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

    /// Setup native tab bar with Flutter
    func setup(messenger: FlutterBinaryMessenger) {
        // Only setup on iOS 26+
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

    /// Find Flutter view controller
    private func getFlutterViewController() -> FlutterViewController? {
        if let flutterVC = flutterViewController {
            return flutterVC
        }

        // Try to find it from windows
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            if let flutterVC = window.rootViewController as? FlutterViewController {
                self.flutterViewController = flutterVC
                return flutterVC
            }
        }

        return nil
    }

    private var searchOnlyNavController: UINavigationController?

    /// Enable native tab bar mode
    private func enableNativeTabBar(tabs: [TabConfig], selectedIndex: Int, isDark: Bool) {
        guard let flutterVC = getFlutterViewController() else {
            NSLog("❌ CNNativeTabBarManager: Could not find FlutterViewController")
            return
        }

        // Store configuration
        self.tabConfigurations = tabs
        self.searchTabIndex = tabs.firstIndex(where: { $0.isSearchTab }) ?? -1

        // Check if this is search-only mode (single search tab)
        let isSearchOnlyMode = tabs.count == 1 && tabs[0].isSearchTab

        if isSearchOnlyMode {
            // Search-only mode: Use UINavigationController with UISearchController directly
            enableSearchOnlyMode(flutterVC: flutterVC, config: tabs[0], isDark: isDark)
            return
        }

        // Create tab bar controller if needed
        if tabBarController == nil {
            let tabBar = UITabBarController()
            tabBarController = tabBar

            // Setup iOS 26 appearance
            setupTabBarAppearance(tabBar)
        }

        guard let tabBar = tabBarController else { return }

        // Apply dark mode
        tabBar.overrideUserInterfaceStyle = isDark ? .dark : .light

        // Create view controllers for each tab
        var viewControllers: [UIViewController] = []

        for (index, config) in tabs.enumerated() {
            if config.isSearchTab {
                // Create search tab with Flutter content embedded
                let searchVC = FlutterTabViewController()
                searchVC.tabIndex = index
                searchVC.isSearchTab = true
                searchVC.methodChannel = self.methodChannel

                let navController = UINavigationController(rootViewController: searchVC)
                navController.navigationBar.prefersLargeTitles = true

                // Setup search controller
                let search = UISearchController(searchResultsController: nil)
                search.searchResultsUpdater = self
                search.searchBar.delegate = self
                search.obscuresBackgroundDuringPresentation = false
                search.searchBar.placeholder = config.title.isEmpty ? "Search" : config.title
                search.hidesNavigationBarDuringPresentation = false

                searchVC.navigationItem.searchController = search
                searchVC.navigationItem.hidesSearchBarWhenScrolling = false
                searchVC.definesPresentationContext = true
                searchVC.title = "Search"

                self.searchController = search

                // Setup tab bar item with search system item
                navController.tabBarItem = UITabBarItem(tabBarSystemItem: .search, tag: index)
                if !config.title.isEmpty {
                    navController.tabBarItem.title = config.title
                }

                viewControllers.append(navController)
            } else {
                // Regular tab - use Flutter view
                let tabVC = FlutterTabViewController()
                tabVC.tabIndex = index
                tabVC.methodChannel = self.methodChannel

                // Setup tab bar item
                var image: UIImage?
                var selectedImage: UIImage?

                if let symbol = config.sfSymbol, !symbol.isEmpty {
                    if let unselTint = unselectedTintColor {
                        image = UIImage(systemName: symbol)?.withTintColor(unselTint, renderingMode: .alwaysOriginal)
                    } else {
                        image = UIImage(systemName: symbol)?.withRenderingMode(.alwaysTemplate)
                    }
                }

                if let activeSymbol = config.activeSfSymbol, !activeSymbol.isEmpty {
                    selectedImage = UIImage(systemName: activeSymbol)?.withRenderingMode(.alwaysTemplate)
                } else {
                    selectedImage = image
                }

                tabVC.tabBarItem = UITabBarItem(
                    title: config.title,
                    image: image,
                    selectedImage: selectedImage
                )
                tabVC.tabBarItem.tag = index

                // Set badge value if provided
                if let count = config.badgeCount, count > 0 {
                    tabVC.tabBarItem.badgeValue = count > 99 ? "99+" : String(count)
                }

                viewControllers.append(tabVC)
            }
        }

        tabBar.viewControllers = viewControllers
        tabBar.selectedIndex = selectedIndex
        tabBar.delegate = self

        // Apply tint colors
        if let tint = tintColor {
            tabBar.tabBar.tintColor = tint
        }
        if let unselTint = unselectedTintColor {
            tabBar.tabBar.unselectedItemTintColor = unselTint
        }

        // Replace root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            // Embed Flutter view in the selected tab
            let selectedVC = viewControllers[selectedIndex]
            if let navController = selectedVC as? UINavigationController,
               let rootVC = navController.topViewController as? FlutterTabViewController {
                rootVC.embedFlutterView(flutterVC.view)
            } else if let flutterTabVC = selectedVC as? FlutterTabViewController {
                flutterTabVC.embedFlutterView(flutterVC.view)
            }

            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                window.rootViewController = tabBar
            }

            self.isEnabled = true
            NSLog("✅ CNNativeTabBarManager: Native tab bar enabled")
        }
    }

    private var ignoreInitialSearchUpdate = true

    /// Enable search-only mode (single search tab, no tab bar)
    private func enableSearchOnlyMode(flutterVC: FlutterViewController, config: TabConfig, isDark: Bool) {
        // Reset flag
        ignoreInitialSearchUpdate = true

        // Create Flutter container view controller
        let searchVC = FlutterTabViewController()
        searchVC.tabIndex = 0
        searchVC.isSearchTab = true
        searchVC.methodChannel = self.methodChannel

        // Create navigation controller
        let navController = UINavigationController(rootViewController: searchVC)
        navController.navigationBar.prefersLargeTitles = true
        navController.overrideUserInterfaceStyle = isDark ? .dark : .light

        // Setup search controller - NOT active by default
        let search = UISearchController(searchResultsController: nil)
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = config.title.isEmpty ? "Search" : config.title
        search.hidesNavigationBarDuringPresentation = false
        // Don't show separate results controller - show results in same view
        search.showsSearchResultsController = false

        // Set delegates
        search.searchResultsUpdater = self
        search.searchBar.delegate = self

        searchVC.navigationItem.searchController = search
        searchVC.navigationItem.hidesSearchBarWhenScrolling = false
        searchVC.definesPresentationContext = true
        searchVC.title = config.title.isEmpty ? "Search" : config.title

        self.searchController = search
        self.searchOnlyNavController = navController

        // Embed Flutter view FIRST
        searchVC.embedFlutterView(flutterVC.view)

        // Replace root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            window.rootViewController = navController
            window.makeKeyAndVisible()

            // Deactivate search after a short delay to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                search.isActive = false
                self.ignoreInitialSearchUpdate = false
            }

            self.isEnabled = true
            NSLog("✅ CNNativeTabBarManager: Search-only mode enabled")
        }
    }

    /// Disable native tab bar and return to Flutter-only mode
    private func disableNativeTabBar() {
        guard let flutterVC = flutterViewController else {
            return
        }

        // Remove Flutter view from search-only nav controller if present
        if let navController = searchOnlyNavController,
           let searchVC = navController.topViewController as? FlutterTabViewController {
            searchVC.removeFlutterView()
        }

        // Remove Flutter view from tab if embedded
        if let tabBar = tabBarController,
           let selectedVC = tabBar.selectedViewController as? FlutterTabViewController {
            selectedVC.removeFlutterView()
        }

        // Restore Flutter as root
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                window.rootViewController = flutterVC
            }
        }

        self.searchOnlyNavController = nil

        self.isEnabled = false
        self.tabBarController = nil
        NSLog("✅ CNNativeTabBarManager: Native tab bar disabled")
    }

    private func setupTabBarAppearance(_ tabBar: UITabBarController) {
        // iOS 26 - use direct properties for liquid glass effect
        tabBar.tabBar.isTranslucent = true
        tabBar.tabBar.backgroundImage = UIImage()
        tabBar.tabBar.shadowImage = UIImage()
        tabBar.tabBar.backgroundColor = .clear
    }

    /// Notify Flutter of tab change and embed the Flutter view into the *newly selected* view controller.
    /// Passing the selected VC explicitly avoids timing issues where tabBar.selectedViewController
    /// might not yet reflect the new selection (fixes Issue #7: double-tap to switch tab).
    private func notifyTabSelected(_ index: Int, selectedViewController: UIViewController) {
        methodChannel?.invokeMethod("onTabSelected", arguments: ["index": index])

        guard let flutterView = flutterViewController?.view else { return }

        // Resolve FlutterTabViewController from the VC that was just selected (not from tabBar.selectedViewController)
        var targetVC: FlutterTabViewController?
        if let navController = selectedViewController as? UINavigationController,
           let rootVC = navController.topViewController as? FlutterTabViewController {
            targetVC = rootVC
        } else if let flutterTabVC = selectedViewController as? FlutterTabViewController {
            targetVC = flutterTabVC
        }

        if let vc = targetVC {
            vc.embedFlutterView(flutterView)
        }
    }

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
                let symbol = data["sfSymbol"] as? String
                let activeSymbol = data["activeSfSymbol"] as? String
                let isSearch = (data["isSearch"] as? Bool) ?? false
                let badgeCount = data["badgeCount"] as? Int
                return TabConfig(title: title, sfSymbol: symbol, activeSfSymbol: activeSymbol, isSearchTab: isSearch, badgeCount: badgeCount)
            }

            let selectedIndex = (args["selectedIndex"] as? Int) ?? 0
            let isDark = (args["isDark"] as? Bool) ?? false

            // Parse colors
            if let tint = args["tint"] as? Int {
                tintColor = ImageUtils.colorFromARGB(tint)
            }
            if let unselTint = args["unselectedTint"] as? Int {
                unselectedTintColor = ImageUtils.colorFromARGB(unselTint)
            }

            enableNativeTabBar(tabs: tabs, selectedIndex: selectedIndex, isDark: isDark)
            result(nil)

        case "disable":
            disableNativeTabBar()
            result(nil)

        case "setSelectedIndex":
            guard let args = call.arguments as? [String: Any],
                  let index = args["index"] as? Int,
                  let tabBar = tabBarController,
                  let vcs = tabBar.viewControllers,
                  index >= 0, index < vcs.count else {
                result(FlutterError(code: "invalid_args", message: "Invalid index", details: nil))
                return
            }
            tabBar.selectedIndex = index
            notifyTabSelected(index, selectedViewController: vcs[index])
            result(nil)

        case "activateSearch":
            if searchTabIndex >= 0 {
                tabBarController?.selectedIndex = searchTabIndex
                searchController?.isActive = true
            }
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
                  let badgeCounts = args["badgeCounts"] as? [Int?] else {
                result(FlutterError(code: "invalid_args", message: "Invalid badge counts", details: nil))
                return
            }

            if let tabBar = tabBarController, let viewControllers = tabBar.viewControllers {
                for (index, viewController) in viewControllers.enumerated() {
                    if index < badgeCounts.count {
                        let count = badgeCounts[index]
                        if let count = count, count > 0 {
                            viewController.tabBarItem.badgeValue = count > 99 ? "99+" : String(count)
                        } else {
                            viewController.tabBarItem.badgeValue = nil
                        }
                    }
                }
            }
            result(nil)

        case "setStyle":
            if let args = call.arguments as? [String: Any] {
                if let tint = args["tint"] as? Int {
                    let color = ImageUtils.colorFromARGB(tint)
                    tabBarController?.tabBar.tintColor = color
                    tintColor = color
                }
                if let unselTint = args["unselectedTint"] as? Int {
                    let color = ImageUtils.colorFromARGB(unselTint)
                    tabBarController?.tabBar.unselectedItemTintColor = color
                    unselectedTintColor = color
                }
            }
            result(nil)

        case "setBrightness":
            if let args = call.arguments as? [String: Any],
               let isDark = args["isDark"] as? Bool {
                tabBarController?.overrideUserInterfaceStyle = isDark ? .dark : .light
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension CNNativeTabBarManager: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let index = tabBarController.viewControllers?.firstIndex(of: viewController) ?? 0
        notifyTabSelected(index, selectedViewController: viewController)
    }
}

// MARK: - UISearchResultsUpdating

extension CNNativeTabBarManager: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        // Ignore initial auto-triggered updates
        if ignoreInitialSearchUpdate { return }

        guard let query = searchController.searchBar.text else { return }
        methodChannel?.invokeMethod("onSearchChanged", arguments: ["query": query])
    }
}

// MARK: - UISearchBarDelegate

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

// MARK: - Tab View Controllers

private class FlutterTabViewController: UIViewController {
    var tabIndex: Int = 0
    var isSearchTab: Bool = false
    weak var methodChannel: FlutterMethodChannel?
    private var embeddedFlutterView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        methodChannel?.invokeMethod("onTabAppeared", arguments: ["index": tabIndex])
    }

    func embedFlutterView(_ flutterView: UIView) {
        // Remove any existing embedded view
        embeddedFlutterView?.removeFromSuperview()

        // Remove from previous parent
        flutterView.removeFromSuperview()

        // Ensure Flutter view is visible
        flutterView.isHidden = false
        flutterView.alpha = 1.0
        flutterView.translatesAutoresizingMaskIntoConstraints = false

        // Add to this view controller
        view.addSubview(flutterView)
        view.bringSubviewToFront(flutterView)

        // Fill entire view - Flutter handles its own safe area
        NSLayoutConstraint.activate([
            flutterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            flutterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            flutterView.topAnchor.constraint(equalTo: view.topAnchor),
            flutterView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        embeddedFlutterView = flutterView

        // Force layout update
        view.setNeedsLayout()
        view.layoutIfNeeded()

        NSLog("✅ FlutterTabViewController: Embedded Flutter view, frame: \(flutterView.frame)")
    }

    func removeFlutterView() {
        embeddedFlutterView?.removeFromSuperview()
        embeddedFlutterView = nil
    }
}

private class SearchTabViewController: UIViewController {
    var tabIndex: Int = 0
    weak var methodChannel: FlutterMethodChannel?
    var searchPlaceholderText: String = "Search results will appear here"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Add placeholder content for search results area
        let label = UILabel()
        label.text = searchPlaceholderText
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 17)
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        methodChannel?.invokeMethod("onTabAppeared", arguments: ["index": tabIndex])
    }
}
