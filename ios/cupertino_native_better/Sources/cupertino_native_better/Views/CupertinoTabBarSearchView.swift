import Flutter
import UIKit

/// iOS 26+ native tab bar with search support.
/// Uses UITabBar with UITabBarSystemItem.search for native liquid glass morphing effect.
@available(iOS 26.0, *)
class CupertinoTabBarSearchPlatformView: NSObject, FlutterPlatformView, UITabBarDelegate {
    private let channel: FlutterMethodChannel
    private let container: UIView
    private var tabBar: CNDotTabBar?

    // State
    /// The items, read as the plain bar reads them: images, sizes, badges
    /// and names (#136).
    private var content = CNTabItemContent()
    private var selectedIndex: Int = 0
    private var tintColor: UIColor?
    private var unselectedTintColor: UIColor?
    private var searchPlaceholder: String = "Search"
    private var searchLabel: String = "Search"
    /// `CNTabBarSearchItem.icon` / `activeIcon`; the system search item's
    /// own magnifying glass when they are the default.
    private var searchSymbol: String = "magnifyingglass"
    private var searchActiveSymbol: String = "magnifyingglass"
    /// `CNTabBarSearchStyle.iconSize`, `iconColor` and `activeIconColor`.
    private var searchIconSize: CGFloat?
    private var searchIconColor: UIColor?
    private var searchActiveIconColor: UIColor?

    // Search tab is always the last item
    private var searchItemIndex: Int = -1

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(name: "CupertinoNativeTabBar_\(viewId)", binaryMessenger: messenger)
        self.container = UIView(frame: frame)

        super.init()

        // Parse creation params
        if let dict = args as? [String: Any] {
            content = CNTabItemContent(dict)
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
            searchSymbol = (dict["searchSymbol"] as? String) ?? "magnifyingglass"
            searchActiveSymbol = (dict["searchActiveSymbol"] as? String) ?? searchSymbol
            if let style = dict["searchStyle"] as? [String: Any] {
                if let n = style["iconSize"] as? NSNumber, n.doubleValue > 0 {
                    searchIconSize = CGFloat(n.doubleValue)
                }
                if let n = style["iconColor"] as? NSNumber {
                    searchIconColor = ImageUtils.colorFromARGB(n.intValue)
                }
                if let n = style["activeIconColor"] as? NSNumber {
                    searchActiveIconColor = ImageUtils.colorFromARGB(n.intValue)
                }
            }
        }

        // Flutter's text direction (#142).
        CNLayoutDirection.apply(CNLayoutDirection.read(args as? [String: Any]), to: container)
        container.backgroundColor = .clear
        container.isOpaque = false
        // This view is iOS 26+ only and uses the Liquid Glass tab bar where
        // the search button renders as a floating glass orb that extends
        // slightly above the UITabBar's bounds. Clipping the container or
        // bar (the Issue #2 containment pattern) crops the orb's top edge.
        // The shadow concerns Issue #2 addressed only apply to legacy
        // UITabBar appearance — iOS 26 Liquid Glass already has the
        // top-edge hairline disabled via `bar.shadowImage = UIImage()` and
        // `bar.layer.shadowOpacity = 0` below, so leaving clipsToBounds
        // false is safe here.
        container.clipsToBounds = false
        container.layer.shadowOpacity = 0
        container.layer.backgroundColor = UIColor.clear.cgColor

        setupUI()
        setupMethodChannel()
    }

    private func setupUI() {
        // Create native UITabBar - gets liquid glass morphing effect on iOS 26+.
        // A CNDotTabBar draws dot badges and names the tab buttons for
        // VoiceOver, as the plain bar does.
        let bar = CNDotTabBar(frame: .zero)
        tabBar = bar
        bar.delegate = self
        bar.translatesAutoresizingMaskIntoConstraints = false

        // iOS 26+ - use direct properties for liquid glass effect
        // Skip UITabBarAppearance as it interferes with iOS 26 styling
        bar.isTranslucent = true
        bar.backgroundImage = UIImage()
        bar.shadowImage = UIImage()
        bar.backgroundColor = .clear
        // Don't clip — the Liquid Glass search orb extends above the bar's
        // bounds and needs the overflow to render its top edge correctly.
        // Top-edge shadow hairline is already suppressed by shadowImage
        // above and layer.shadowOpacity below.
        bar.clipsToBounds = false
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
        var names: [Int: String] = [:]

        for i in 0..<content.count {
            let (image, selected) = content.images(at: i)
            let item = UITabBarItem(
                title: content.title(at: i),
                image: unselectedImage(image),
                // Selected: template rendering, so the bar's tint applies.
                selectedImage: selected
            )
            item.tag = i
            CupertinoTabBarPlatformView.applyBadge(content.badge(at: i), to: item)
            if let name = content.semanticLabel(at: i) {
                item.accessibilityLabel = name
                names[i] = name
            }
            items.append(item)
        }

        // The search tab is the system search item, which iOS 26 draws as a
        // separate glass button.
        let searchItem = UITabBarItem(tabBarSystemItem: .search, tag: 9999)
        if !searchLabel.isEmpty {
            searchItem.title = searchLabel
        }
        applySearchIcon(to: searchItem)
        items.append(searchItem)
        searchItemIndex = items.count - 1

        tabBar?.itemNames = names
        return items
    }

    /// iOS 26 ignores `unselectedItemTintColor`, so an unselected template
    /// image (an SF Symbol or a custom icon) carries the colour itself. Images
    /// drawn in their own colours stay as they are.
    private func unselectedImage(_ image: UIImage?) -> UIImage? {
        guard let image else { return nil }
        guard let tint = unselectedTintColor, image.renderingMode != .alwaysOriginal else { return image }
        return image.withTintColor(tint, renderingMode: .alwaysOriginal)
    }

    /// `CNTabBarSearchItem.icon` / `activeIcon` and the search style's icon
    /// size and colours, set on the system search item. With none of them
    /// set, the item keeps the system's own magnifying glass.
    private func applySearchIcon(to item: UITabBarItem) {
        let custom = searchSymbol != "magnifyingglass" || searchActiveSymbol != searchSymbol
            || searchIconSize != nil || searchIconColor != nil || searchActiveIconColor != nil
        guard custom else { return }
        let config = searchIconSize.map { UIImage.SymbolConfiguration(pointSize: $0) }
        func symbol(_ name: String, _ color: UIColor?) -> UIImage? {
            let base = config.flatMap { UIImage(systemName: name, withConfiguration: $0) } ?? UIImage(systemName: name)
            guard let color else { return base?.withRenderingMode(.alwaysTemplate) }
            return base?.withTintColor(color, renderingMode: .alwaysOriginal)
        }
        if let image = symbol(searchSymbol, searchIconColor ?? unselectedTintColor) {
            item.image = image
        }
        if let image = symbol(searchActiveSymbol, searchActiveIconColor) {
            item.selectedImage = image
        }
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
                    } else {
                        self.selectSearchTab()
                    }
                    result(nil)
                } else {
                    result(FlutterError(code: "bad_args", message: "Missing or invalid index", details: nil))
                }

            case "activateSearch":
                // Opened from code (a button, a shortcut): the search tab is
                // shown selected, as after a tap on it (#136).
                self.selectSearchTab()
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

            case "setLayoutDirection":
                CNLayoutDirection.apply(CNLayoutDirection.read(call.arguments as? [String: Any]), to: self.container)
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
                    let searchSelected = self.isSearchSelected
                    self.content = CNTabItemContent(args)
                    self.tabBar?.items = self.buildTabItems()
                    if searchSelected { self.selectSearchTab() }

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

            case "setBadges":
                // `CNTabBarItem.badge` changed alone.
                if let badges = (call.arguments as? [String: Any])?["badges"] as? [Any] {
                    self.content.badges = badges.map { ($0 as? String) ?? "" }
                    for (index, item) in (self.tabBar?.items ?? []).enumerated() where index != self.searchItemIndex {
                        CupertinoTabBarPlatformView.applyBadge(self.content.badge(at: index), to: item)
                    }
                    self.tabBar?.setNeedsLayout()
                }
                result(nil)

            // Menus open from a plain tab only, and this bar keeps the
            // system font.
            case "refresh", "setLabels", "setSfSymbols", "setLayout", "setMenus", "setFont":
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
        if let items = bar.items, currentSelectedIndex < items.count {
            bar.selectedItem = items[currentSelectedIndex]
        }
    }

    private var isSearchSelected: Bool {
        guard let bar = tabBar, let selected = bar.selectedItem else { return false }
        return selected.tag == 9999
    }

    /// Shows the search tab as selected; `deactivateSearch` puts the
    /// previous tab back.
    private func selectSearchTab() {
        guard let bar = tabBar, let items = bar.items,
              searchItemIndex >= 0, searchItemIndex < items.count else { return }
        bar.selectedItem = items[searchItemIndex]
    }

    deinit {
        channel.setMethodCallHandler(nil)
        tabBar?.delegate = nil
        tabBar?.removeFromSuperview()
    }

    func view() -> UIView {
        return container
    }

    // MARK: - UITabBarDelegate

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        // Check if search item was tapped
        if item.tag == 9999 {
            // The search tab stays selected while search is active.
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
