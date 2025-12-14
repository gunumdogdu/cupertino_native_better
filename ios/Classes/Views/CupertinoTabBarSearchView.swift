import Flutter
import UIKit

/// iOS 26+ native tab bar with search support.
/// Uses UITabBar with UITabBarSystemItem.search for native liquid glass morphing effect.
@available(iOS 26.0, *)
class CupertinoTabBarSearchPlatformView: NSObject, FlutterPlatformView, UITabBarDelegate {
    private let channel: FlutterMethodChannel
    private let container: UIView
    private var tabBar: UITabBar?

    // State
    private var currentLabels: [String] = []
    private var currentSymbols: [String] = []
    private var currentActiveSymbols: [String] = []
    private var currentBadgeCounts: [Int?] = []
    private var selectedIndex: Int = 0
    private var tintColor: UIColor?
    private var unselectedTintColor: UIColor?
    private var searchPlaceholder: String = "Search"
    private var searchLabel: String = "Search"

    // Search tab is always the last item
    private var searchItemIndex: Int = -1

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(name: "CupertinoNativeTabBar_\(viewId)", binaryMessenger: messenger)
        self.container = UIView(frame: frame)

        super.init()

        // Parse creation params
        if let dict = args as? [String: Any] {
            currentLabels = (dict["labels"] as? [String]) ?? []
            currentSymbols = (dict["sfSymbols"] as? [String]) ?? []
            currentActiveSymbols = (dict["activeSfSymbols"] as? [String]) ?? []
            if let badgeData = dict["badgeCounts"] as? [NSNumber?] {
                currentBadgeCounts = badgeData.map { $0?.intValue }
            }
            if let v = dict["selectedIndex"] as? NSNumber {
                selectedIndex = v.intValue
            }
            if let v = dict["isDark"] as? NSNumber {
                container.overrideUserInterfaceStyle = v.boolValue ? .dark : .light
            }
            if let style = dict["style"] as? [String: Any] {
                if let n = style["tint"] as? NSNumber {
                    tintColor = ImageUtils.colorFromARGB(n.intValue)
                }
                if let n = style["unselectedTint"] as? NSNumber {
                    unselectedTintColor = ImageUtils.colorFromARGB(n.intValue)
                }
            }
            searchPlaceholder = (dict["searchPlaceholder"] as? String) ?? "Search"
            searchLabel = (dict["searchLabel"] as? String) ?? "Search"
        }

        container.backgroundColor = .clear
        container.clipsToBounds = true
        container.layer.shadowOpacity = 0

        setupUI()
        setupMethodChannel()
    }

    private func setupUI() {
        // Create native UITabBar - gets liquid glass morphing effect on iOS 26+
        let bar = UITabBar(frame: .zero)
        tabBar = bar
        bar.delegate = self
        bar.translatesAutoresizingMaskIntoConstraints = false

        // iOS 26+ - use direct properties for liquid glass effect
        // Skip UITabBarAppearance as it interferes with iOS 26 styling
        bar.isTranslucent = true
        bar.backgroundImage = UIImage()
        bar.shadowImage = UIImage()
        bar.backgroundColor = .clear
        bar.clipsToBounds = true
        bar.layer.shadowOpacity = 0

        // Set tint colors
        if let tint = tintColor {
            bar.tintColor = tint
        }
        if let unselTint = unselectedTintColor {
            bar.unselectedItemTintColor = unselTint
        }

        // Build tab items including search
        bar.items = buildTabItems()

        // Set selected item (not the search item)
        if let items = bar.items, selectedIndex >= 0, selectedIndex < items.count {
            if selectedIndex != searchItemIndex {
                bar.selectedItem = items[selectedIndex]
            } else if items.count > 1 {
                bar.selectedItem = items[0]
                selectedIndex = 0
            }
        }

        container.addSubview(bar)

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bar.topAnchor.constraint(equalTo: container.topAnchor),
            bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    private func buildTabItems() -> [UITabBarItem] {
        var items: [UITabBarItem] = []
        let count = max(currentLabels.count, currentSymbols.count)

        for i in 0..<count {
            let title = i < currentLabels.count ? currentLabels[i] : nil
            let symbol = i < currentSymbols.count ? currentSymbols[i] : "circle"
            let activeSymbol = i < currentActiveSymbols.count && !currentActiveSymbols[i].isEmpty
                ? currentActiveSymbols[i] : symbol
            let badgeCount = i < currentBadgeCounts.count ? currentBadgeCounts[i] : nil

            var image: UIImage? = nil
            var selectedImage: UIImage? = nil

            // iOS 26+: Use different rendering modes for selected/unselected
            if let unselTint = unselectedTintColor {
                // Unselected: Apply custom color
                if let originalImage = UIImage(systemName: symbol) {
                    image = originalImage.withTintColor(unselTint, renderingMode: .alwaysOriginal)
                }
            } else {
                // No custom color - use template mode to respect theme
                image = UIImage(systemName: symbol)?.withRenderingMode(.alwaysTemplate)
            }

            // Selected: Use template rendering so tintColor applies
            selectedImage = UIImage(systemName: activeSymbol)?.withRenderingMode(.alwaysTemplate)

            let item = UITabBarItem(title: title, image: image, selectedImage: selectedImage)
            item.tag = i

            // Set badge value if provided
            if let count = badgeCount, count > 0 {
                item.badgeValue = count > 99 ? "99+" : String(count)
            } else {
                item.badgeValue = nil
            }

            items.append(item)
        }

        // Add search tab using UITabBarSystemItem.search for native iOS 26 liquid glass styling
        let searchItem = UITabBarItem(tabBarSystemItem: .search, tag: 9999)
        if !searchLabel.isEmpty {
            searchItem.title = searchLabel
        }
        items.append(searchItem)
        searchItemIndex = items.count - 1

        return items
    }

    private func setupMethodChannel() {
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { result(nil); return }

            switch call.method {
            case "getIntrinsicSize":
                if let bar = self.tabBar {
                    let size = bar.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
                    result(["width": Double(self.container.bounds.width), "height": Double(size.height)])
                } else {
                    result(["width": Double(self.container.bounds.width), "height": 50.0])
                }

            case "setSelectedIndex":
                if let args = call.arguments as? [String: Any],
                   let idx = (args["index"] as? NSNumber)?.intValue,
                   let bar = self.tabBar,
                   let items = bar.items,
                   idx >= 0, idx < items.count {
                    if idx != self.searchItemIndex {
                        bar.selectedItem = items[idx]
                        self.selectedIndex = idx
                    }
                    result(nil)
                } else {
                    result(FlutterError(code: "bad_args", message: "Missing or invalid index", details: nil))
                }

            case "activateSearch":
                // Notify Flutter to show search UI
                self.channel.invokeMethod("searchActiveChanged", arguments: ["isActive": true])
                result(nil)

            case "deactivateSearch":
                // Restore previous selection
                if let bar = self.tabBar,
                   let items = bar.items,
                   self.selectedIndex >= 0,
                   self.selectedIndex < items.count,
                   self.selectedIndex != self.searchItemIndex {
                    bar.selectedItem = items[self.selectedIndex]
                }
                self.channel.invokeMethod("searchActiveChanged", arguments: ["isActive": false])
                result(nil)

            case "setSearchText":
                // Search text is handled by Flutter
                result(nil)

            case "setBrightness":
                if let args = call.arguments as? [String: Any],
                   let isDark = (args["isDark"] as? NSNumber)?.boolValue {
                    self.container.overrideUserInterfaceStyle = isDark ? .dark : .light
                    result(nil)
                } else {
                    result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil))
                }

            case "setStyle":
                if let args = call.arguments as? [String: Any] {
                    if let n = args["tint"] as? NSNumber {
                        let color = ImageUtils.colorFromARGB(n.intValue)
                        self.tabBar?.tintColor = color
                        self.tintColor = color
                    }
                    if let n = args["unselectedTint"] as? NSNumber {
                        let color = ImageUtils.colorFromARGB(n.intValue)
                        self.tabBar?.unselectedItemTintColor = color
                        self.unselectedTintColor = color
                        // Rebuild items with new unselected color
                        self.rebuildItemsWithCurrentColors()
                    }
                    result(nil)
                } else {
                    result(FlutterError(code: "bad_args", message: "Missing style", details: nil))
                }

            case "setItems":
                if let args = call.arguments as? [String: Any] {
                    self.currentLabels = (args["labels"] as? [String]) ?? []
                    self.currentSymbols = (args["sfSymbols"] as? [String]) ?? []
                    self.currentActiveSymbols = (args["activeSfSymbols"] as? [String]) ?? []
                    if let badgeData = args["badgeCounts"] as? [NSNumber?] {
                        self.currentBadgeCounts = badgeData.map { $0?.intValue }
                    }

                    self.tabBar?.items = self.buildTabItems()

                    if let idx = (args["selectedIndex"] as? NSNumber)?.intValue,
                       let bar = self.tabBar,
                       let items = bar.items,
                       idx >= 0, idx < items.count, idx != self.searchItemIndex {
                        bar.selectedItem = items[idx]
                        self.selectedIndex = idx
                    }
                    result(nil)
                } else {
                    result(FlutterError(code: "bad_args", message: "Missing items", details: nil))
                }

            case "setBadgeCounts":
                if let args = call.arguments as? [String: Any],
                   let badgeData = args["badgeCounts"] as? [NSNumber?] {
                    let badgeCounts = badgeData.map { $0?.intValue }
                    self.currentBadgeCounts = badgeCounts

                    // Update existing tab bar items
                    if let bar = self.tabBar, let items = bar.items {
                        for (index, item) in items.enumerated() {
                            if index < badgeCounts.count {
                                let count = badgeCounts[index]
                                if let count = count, count > 0 {
                                    item.badgeValue = count > 99 ? "99+" : String(count)
                                } else {
                                    item.badgeValue = nil
                                }
                            }
                        }
                    }
                    result(nil)
                } else {
                    result(FlutterError(code: "bad_args", message: "Missing badge counts", details: nil))
                }

            case "refresh", "setLabels", "setSfSymbols", "setBadges", "setLayout":
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // Rebuild tab items with current colors (called when style changes)
    private func rebuildItemsWithCurrentColors() {
        guard let bar = self.tabBar else { return }

        let currentSelectedIndex = bar.items?.firstIndex { $0 == bar.selectedItem } ?? 0

        // Rebuild items with new colors
        bar.items = buildTabItems()

        // Restore selection
        if let items = bar.items, currentSelectedIndex < items.count, currentSelectedIndex != searchItemIndex {
            bar.selectedItem = items[currentSelectedIndex]
        }
    }

    func view() -> UIView {
        return container
    }

    // MARK: - UITabBarDelegate

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        // Check if search item was tapped
        if item.tag == 9999 {
            // Restore previous selection visually
            if let items = tabBar.items, selectedIndex >= 0, selectedIndex < items.count, selectedIndex != searchItemIndex {
                tabBar.selectedItem = items[selectedIndex]
            }
            // Notify Flutter to show search UI
            channel.invokeMethod("searchActiveChanged", arguments: ["isActive": true])
            return
        }

        // Regular tab item
        if let items = tabBar.items, let index = items.firstIndex(of: item) {
            selectedIndex = index
            channel.invokeMethod("valueChanged", arguments: ["index": index])
        }
    }
}
