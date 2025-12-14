import Flutter
import UIKit

/// iOS 26+ Native Search Scaffold using UITab and UISearchTab APIs
/// This enables the true liquid glass morphing effect for search tabs.
@available(iOS 26.0, *)
class CNSearchScaffoldController: UITabBarController, UISearchResultsUpdating, UISearchBarDelegate {

    private let channel: FlutterMethodChannel
    private var searchTabIndex: Int = -1
    private var tabConfigurations: [TabConfig] = []
    private var tintColor: UIColor?
    private var unselectedTintColor: UIColor?
    private var searchPlaceholder: String = "Search"
    private var automaticallyActivatesSearch: Bool = true
    private weak var internalSearchController: UISearchController?

    struct TabConfig {
        let title: String?
        let sfSymbol: String?
        let activeSfSymbol: String?
        let isSearch: Bool
        let index: Int
    }

    init(viewId: Int64, args: [String: Any]?, messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(
            name: "CNSearchScaffold_\(viewId)",
            binaryMessenger: messenger
        )

        super.init(nibName: nil, bundle: nil)

        // Parse configuration
        if let args = args {
            setupFromArgs(args)
        }

        // Setup method call handler
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup tabs using the new UITab API
        setupTabs()

        // Set tint colors
        if let tint = tintColor {
            tabBar.tintColor = tint
        }
        if let unselTint = unselectedTintColor {
            tabBar.unselectedItemTintColor = unselTint
        }
    }

    private func setupFromArgs(_ args: [String: Any]) {
        let labels = (args["labels"] as? [String]) ?? []
        let symbols = (args["sfSymbols"] as? [String]) ?? []
        let activeSymbols = (args["activeSfSymbols"] as? [String]) ?? []
        let searchFlags = (args["searchFlags"] as? [Bool]) ?? []
        let selectedIndex = (args["selectedIndex"] as? Int) ?? 0

        // Parse search config
        if let placeholder = args["searchPlaceholder"] as? String {
            searchPlaceholder = placeholder
        }
        if let autoActivate = args["automaticallyActivatesSearch"] as? Bool {
            automaticallyActivatesSearch = autoActivate
        }

        // Parse colors
        if let style = args["style"] as? [String: Any] {
            if let n = style["tint"] as? NSNumber {
                tintColor = ImageUtils.colorFromARGB(n.intValue)
            }
            if let n = style["unselectedTint"] as? NSNumber {
                unselectedTintColor = ImageUtils.colorFromARGB(n.intValue)
            }
        }

        // Parse dark mode
        if let isDark = args["isDark"] as? Bool {
            view.overrideUserInterfaceStyle = isDark ? .dark : .light
        }

        let count = max(labels.count, symbols.count)
        tabConfigurations = (0..<count).map { i in
            let isSearch = (i < searchFlags.count) && searchFlags[i]
            if isSearch {
                searchTabIndex = i
            }
            return TabConfig(
                title: i < labels.count ? labels[i] : nil,
                sfSymbol: i < symbols.count ? symbols[i] : nil,
                activeSfSymbol: i < activeSymbols.count ? activeSymbols[i] : nil,
                isSearch: isSearch,
                index: i
            )
        }

        self.selectedIndex = selectedIndex
    }

    private func setupTabs() {
        var tabItems: [UITab] = []

        for config in tabConfigurations {
            if config.isSearch {
                // Use UISearchTab for native liquid glass morphing
                let searchTab = UISearchTab(viewControllerProvider: { [weak self] tab in
                    guard let self = self else {
                        return UIViewController()
                    }

                    // Configure UISearchTab properties
                    if let searchTab = tab as? UISearchTab {
                        searchTab.automaticallyActivatesSearch = self.automaticallyActivatesSearch
                    }

                    // Create search view controller with UISearchController
                    let searchVC = SearchContentViewController()
                    searchVC.channel = self.channel
                    searchVC.tabIndex = config.index
                    searchVC.view.backgroundColor = .clear

                    // Setup UISearchController
                    let searchController = UISearchController(searchResultsController: nil)
                    searchController.searchResultsUpdater = self
                    searchController.searchBar.delegate = self
                    searchController.obscuresBackgroundDuringPresentation = false
                    searchController.searchBar.placeholder = self.searchPlaceholder
                    searchController.hidesNavigationBarDuringPresentation = false

                    // Store reference
                    self.internalSearchController = searchController

                    // Attach to navigation item
                    searchVC.navigationItem.searchController = searchController
                    searchVC.navigationItem.hidesSearchBarWhenScrolling = false

                    // Wrap in navigation controller (required for search bar)
                    let navController = UINavigationController(rootViewController: searchVC)
                    navController.navigationBar.prefersLargeTitles = false

                    return navController
                })

                tabItems.append(searchTab)
            } else {
                // Create regular UITab
                let identifier = "tab_\(config.index)"
                let title = config.title ?? "Tab \(config.index + 1)"
                var image: UIImage?

                if let symbol = config.sfSymbol, !symbol.isEmpty {
                    image = UIImage(systemName: symbol)
                }

                let tab = UITab(title: title, image: image, identifier: identifier) { [weak self] tab in
                    guard let self = self else {
                        return UIViewController()
                    }

                    let vc = TabContentViewController()
                    vc.tabIndex = config.index
                    vc.channel = self.channel
                    vc.view.backgroundColor = .clear

                    return vc
                }

                tabItems.append(tab)
            }
        }

        // Assign tabs using new iOS 18+ API
        self.tabs = tabItems
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setSelectedIndex":
            guard let args = call.arguments as? [String: Any],
                  let index = args["index"] as? Int else {
                result(FlutterError(code: "invalid_args", message: "Invalid index", details: nil))
                return
            }
            self.selectedIndex = index
            result(nil)

        case "activateSearch":
            if let searchController = self.internalSearchController {
                searchController.isActive = true
            }
            result(nil)

        case "deactivateSearch":
            if let searchController = self.internalSearchController {
                searchController.isActive = false
            }
            result(nil)

        case "setSearchText":
            guard let args = call.arguments as? [String: Any],
                  let text = args["text"] as? String else {
                result(FlutterError(code: "invalid_args", message: "Invalid text", details: nil))
                return
            }
            internalSearchController?.searchBar.text = text
            result(nil)

        case "setBrightness":
            if let args = call.arguments as? [String: Any],
               let isDark = args["isDark"] as? Bool {
                view.overrideUserInterfaceStyle = isDark ? .dark : .light
                result(nil)
            } else {
                result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil))
            }

        case "setStyle":
            if let args = call.arguments as? [String: Any] {
                if let n = args["tint"] as? NSNumber {
                    let color = ImageUtils.colorFromARGB(n.intValue)
                    tabBar.tintColor = color
                    tintColor = color
                }
                if let n = args["unselectedTint"] as? NSNumber {
                    let color = ImageUtils.colorFromARGB(n.intValue)
                    tabBar.unselectedItemTintColor = color
                    unselectedTintColor = color
                }
                result(nil)
            } else {
                result(FlutterError(code: "bad_args", message: "Missing style", details: nil))
            }

        case "getIntrinsicSize":
            let size = tabBar.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
            result(["width": Double(view.bounds.width), "height": Double(size.height)])

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - UISearchResultsUpdating

    func updateSearchResults(for searchController: UISearchController) {
        guard let query = searchController.searchBar.text else { return }
        channel.invokeMethod("searchTextChanged", arguments: ["text": query])
    }

    // MARK: - UISearchBarDelegate

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text else { return }
        channel.invokeMethod("searchSubmitted", arguments: ["text": query])
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        channel.invokeMethod("searchActiveChanged", arguments: ["isActive": false])
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        channel.invokeMethod("searchActiveChanged", arguments: ["isActive": true])
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        channel.invokeMethod("searchActiveChanged", arguments: ["isActive": false])
    }
}

// MARK: - Tab Content View Controller

@available(iOS 26.0, *)
private class TabContentViewController: UIViewController {
    var tabIndex: Int = 0
    weak var channel: FlutterMethodChannel?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        channel?.invokeMethod("tabDidAppear", arguments: ["index": tabIndex])
    }
}

// MARK: - Search Content View Controller

@available(iOS 26.0, *)
private class SearchContentViewController: UIViewController {
    var tabIndex: Int = 0
    weak var channel: FlutterMethodChannel?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        channel?.invokeMethod("tabDidAppear", arguments: ["index": tabIndex])
    }
}

// MARK: - Platform View Wrapper (available on all iOS, runtime check inside)

class CNSearchScaffoldPlatformView: NSObject, FlutterPlatformView {
    private let containerView: UIView
    // IMPORTANT: Must retain the controller to prevent deallocation
    private var controller: AnyObject?

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        self.containerView = UIView(frame: frame)
        containerView.backgroundColor = .clear

        super.init()

        // Only create the controller on iOS 26+
        if #available(iOS 26.0, *) {
            var argsDict: [String: Any]?
            if let args = args as? [String: Any] {
                argsDict = args
            }

            let ctrl = CNSearchScaffoldController(
                viewId: viewId,
                args: argsDict,
                messenger: messenger
            )

            // Retain the controller
            self.controller = ctrl

            // Add controller's view as subview
            if let view = ctrl.view {
                view.translatesAutoresizingMaskIntoConstraints = false
                containerView.addSubview(view)
                NSLayoutConstraint.activate([
                    view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    view.topAnchor.constraint(equalTo: containerView.topAnchor),
                    view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                ])
            }
        } else {
            // Fallback: show empty view (Flutter will use fallback)
            let label = UILabel()
            label.text = "iOS 26+ required"
            label.textColor = .secondaryLabel
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
            ])
        }
    }

    func view() -> UIView {
        return containerView
    }
}

// MARK: - Platform View Factory (available on all iOS)

class CNSearchScaffoldViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return CNSearchScaffoldPlatformView(
            frame: frame,
            viewId: viewId,
            args: args,
            messenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
