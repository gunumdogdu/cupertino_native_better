import Flutter
import SwiftUI
import UIKit

/// A native sheet (`UISheetPresentationController`) over the Flutter app,
/// driven by data sent from Dart over `cn_native_sheet`.
///
/// The content is SwiftUI built from that data: pages with a title, toolbar
/// buttons and a native list, and a tab bar inside the sheet when there is
/// more than one page. Flutter widgets cannot live inside the sheet: an iOS
/// app has one Flutter view, and it stays behind the sheet, where it keeps
/// receiving touches above the undimmed detents.
final class CNNativeSheetManager: NSObject, UISheetPresentationControllerDelegate,
    UIAdaptivePresentationControllerDelegate {

    static let shared = CNNativeSheetManager()

    private var channel: FlutterMethodChannel?
    private weak var hostController: UIViewController?
    private var store: CNSheetStore?
    private var detents: [CNSheetConfig.Detent] = []

    func setup(messenger: FlutterBinaryMessenger) {
        let ch = FlutterMethodChannel(name: "cn_native_sheet", binaryMessenger: messenger)
        channel = ch
        ch.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        switch call.method {
        case "show":
            guard #available(iOS 17.0, *) else {
                result(false)
                return
            }
            guard let args else {
                result(FlutterError(code: "invalid_args", message: "Expected a map", details: nil))
                return
            }
            result(present(config: CNSheetConfig(args: args)))

        case "dismiss":
            hostController?.dismiss(animated: true)
            hostController = nil
            store = nil
            result(nil)

        case "setDetent":
            if let index = args?["index"] as? Int { select(detent: index) }
            result(nil)

        case "setSelectedPage":
            if let index = args?["index"] as? Int,
               let tabs = (hostController as? CNSheetTabContainer)?.tabs,
               tabs.viewControllers?.indices.contains(index) == true {
                tabs.selectedIndex = index
            }
            result(nil)

        case "setItems":
            if let page = args?["page"] as? Int,
               let items = args?["items"] as? [[String: Any]] {
                store?.setItems(page: page, items: CNSheetConfig.parseItems(items))
            }
            result(nil)

        case "setBadgeCounts":
            if let badges = args?["badgeCounts"] as? [Any?] {
                (hostController as? CNSheetTabContainer)?.tabs.setBadges(badges.map { $0 as? Int })
            }
            result(nil)

        case "setBrightness":
            if let isDark = args?["isDark"] as? Bool {
                let style: UIUserInterfaceStyle = isDark ? .dark : .light
                hostController?.overrideUserInterfaceStyle = style
                if #available(iOS 17.0, *) {
                    hostController?.sheetPresentationController?.traitOverrides.userInterfaceStyle = style
                }
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 17.0, *)
    private func present(config: CNSheetConfig) -> Bool {
        // A sheet still up (show() again, or a hot restart) is replaced once
        // it is gone: presenting from a controller that is being dismissed
        // fails silently.
        if let previous = hostController {
            hostController = nil
            store = nil
            previous.dismiss(animated: false) { [weak self] in
                _ = self?.present(config: config)
            }
            return true
        }
        guard let presenter = topPresenter() else {
            NSLog("CNNativeSheetManager: no presenter found")
            return false
        }
        let store = CNSheetStore(config: config)
        let onEvent: (String, [String: Any]?) -> Void = { [weak self] name, payload in
            self?.channel?.invokeMethod(name, arguments: payload)
        }
        let host: UIViewController
        if config.pages.count > 1 {
            let container = CNSheetTabContainer(tabs: CNSheetTabBarController(store: store, onEvent: onEvent))
            if config.detents.contains(where: { $0.kind == "collapsed" }) {
                container.collapsedHeight = Self.collapsedHeight
            }
            host = container
        } else {
            host = CNSheetPageView.controller(store: store, index: 0, onEvent: onEvent)
        }
        // Without an appearance from Dart the sheet follows the system.
        let style: UIUserInterfaceStyle = config.isDark.map { $0 ? .dark : .light } ?? .unspecified
        host.overrideUserInterfaceStyle = style
        host.modalPresentationStyle = .pageSheet
        host.isModalInPresentation = !config.dismissible

        detents = config.detents
        if let sheet = host.sheetPresentationController {
            // The sheet's glass belongs to the presentation, not to the
            // content, so it needs the appearance too.
            if style != .unspecified { sheet.traitOverrides.userInterfaceStyle = style }
            sheet.delegate = self  // also reports a sheet dragged closed
            sheet.detents = config.detents.enumerated().map { makeDetent($0.element, index: $0.offset) }
            sheet.prefersGrabberVisible = config.showGrabber
            if config.detents.indices.contains(config.initialDetent) {
                sheet.selectedDetentIdentifier = identifier(of: config.initialDetent)
            }
            if let undimmed = config.undimmedDetent, config.detents.indices.contains(undimmed) {
                sheet.largestUndimmedDetentIdentifier = identifier(of: undimmed)
            }
        }
        self.store = store
        self.hostController = host
        presenter.present(host, animated: true)
        return true
    }

    private func identifier(of index: Int) -> UISheetPresentationController.Detent.Identifier {
        switch detents[index].kind {
        case "medium": return .medium
        case "large": return .large
        default: return .init("cn_detent_\(index)")
        }
    }

    /// The height of a sheet collapsed to its tab bar: 13 points for the
    /// grabber over the 75-point bar, measured against Find My on iOS 27. At
    /// this height iOS 26 and later draw the sheet as a capsule, inset from
    /// the screen's edges.
    static let collapsedHeight: CGFloat = 88

    private func makeDetent(_ detent: CNSheetConfig.Detent, index: Int) -> UISheetPresentationController.Detent {
        switch detent.kind {
        case "medium": return .medium()
        case "large": return .large()
        default:
            let value = detent.kind == "collapsed" ? Self.collapsedHeight : detent.value
            let isFraction = detent.kind == "fraction"
            if #available(iOS 16.0, *) {
                return .custom(identifier: identifier(of: index)) { context in
                    isFraction ? context.maximumDetentValue * value : value
                }
            }
            return .medium()
        }
    }

    private func select(detent index: Int) {
        guard detents.indices.contains(index),
              let sheet = hostController?.sheetPresentationController else { return }
        sheet.animateChanges {
            sheet.selectedDetentIdentifier = identifier(of: index)
        }
    }

    // MARK: Delegates

    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
        _ sheetPresentationController: UISheetPresentationController
    ) {
        guard let id = sheetPresentationController.selectedDetentIdentifier,
              let index = detents.indices.first(where: { identifier(of: $0) == id }) else { return }
        channel?.invokeMethod("onDetentChanged", arguments: ["index": index])
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        hostController = nil
        store = nil
        channel?.invokeMethod("onDismissed", arguments: nil)
    }

    private func topPresenter() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = (scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene)
            ?? (scenes.first as? UIWindowScene)
        let window = windowScene?.windows.first(where: { $0.isKeyWindow }) ?? windowScene?.windows.first
        guard var vc = window?.rootViewController else { return nil }
        while let presented = vc.presentedViewController { vc = presented }
        return vc
    }
}

// MARK: - Config (plain data parsed from the channel)

struct CNSheetConfig {
    struct Detent {
        let kind: String
        let value: CGFloat
    }
    struct Button {
        let id: String
        let symbol: String?
        let label: String?
    }
    struct Item {
        let title: String
        let subtitle: String?
        let trailing: String?
        let symbol: String?
        let image: UIImage?
        let chevron: Bool
    }
    struct Page {
        let title: String
        let symbol: String?
        let activeSymbol: String?
        var badge: Int?
        let buttons: [Button]
        var items: [Item]
    }

    let pages: [Page]
    let detents: [Detent]
    let initialDetent: Int
    let undimmedDetent: Int?
    let dismissible: Bool
    let showGrabber: Bool
    let tint: UIColor?
    let isDark: Bool?
    let selectedPage: Int

    init(args: [String: Any]) {
        pages = (args["pages"] as? [[String: Any]] ?? []).map { p in
            Page(
                title: p["title"] as? String ?? "",
                symbol: p["sfSymbol"] as? String,
                activeSymbol: p["activeSfSymbol"] as? String,
                badge: p["badgeCount"] as? Int,
                buttons: (p["buttons"] as? [[String: Any]] ?? []).map { b in
                    Button(id: b["id"] as? String ?? "",
                           symbol: b["sfSymbol"] as? String,
                           label: b["label"] as? String)
                },
                items: CNSheetConfig.parseItems(p["items"] as? [[String: Any]] ?? [])
            )
        }
        detents = (args["detents"] as? [[String: Any]] ?? []).map { d in
            Detent(kind: d["kind"] as? String ?? "medium",
                   value: CGFloat((d["value"] as? NSNumber)?.doubleValue ?? 0))
        }
        initialDetent = args["initialDetent"] as? Int ?? 0
        undimmedDetent = args["undimmedDetent"] as? Int
        dismissible = args["dismissible"] as? Bool ?? true
        showGrabber = args["showGrabber"] as? Bool ?? true
        if let argb = args["tint"] as? Int { tint = ImageUtils.colorFromARGB(argb) } else { tint = nil }
        isDark = args["isDark"] as? Bool
        selectedPage = args["selectedPage"] as? Int ?? 0
    }

    static func parseItems(_ data: [[String: Any]]) -> [Item] {
        data.map { i in
            Item(
                title: i["title"] as? String ?? "",
                subtitle: i["subtitle"] as? String,
                trailing: i["trailingText"] as? String,
                symbol: i["leadingSfSymbol"] as? String,
                image: loadImage(i["leadingImage"] as? [String: Any]),
                chevron: i["showChevron"] as? Bool ?? false
            )
        }
    }

    private static func loadImage(_ data: [String: Any]?) -> UIImage? {
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

// MARK: - Observable store

final class CNSheetStore: ObservableObject {
    @Published var pages: [CNSheetConfig.Page]
    let selectedPage: Int
    let tint: UIColor?

    init(config: CNSheetConfig) {
        pages = config.pages
        selectedPage = config.pages.indices.contains(config.selectedPage) ? config.selectedPage : 0
        tint = config.tint
    }

    func setItems(page: Int, items: [CNSheetConfig.Item]) {
        guard pages.indices.contains(page) else { return }
        pages[page].items = items
    }
}

// MARK: - Tab bar inside the sheet

/// The pages' tab bar. A UIKit tab bar controller rather than a SwiftUI
/// `TabView`, which draws the opaque system background behind its pages:
/// inside a sheet on iOS 26 that layer is blended into the sheet's Liquid
/// Glass and turns it pale, where system apps show the glass itself.
final class CNSheetTabBarController: UITabBarController, UITabBarControllerDelegate {
    private let onEvent: (String, [String: Any]?) -> Void

    @available(iOS 17.0, *)
    init(store: CNSheetStore, onEvent: @escaping (String, [String: Any]?) -> Void) {
        self.onEvent = onEvent
        super.init(nibName: nil, bundle: nil)
        viewControllers = store.pages.indices.map { index in
            let page = store.pages[index]
            let controller = CNSheetPageView.controller(store: store, index: index, onEvent: onEvent)
            let symbol = page.symbol ?? "circle"
            controller.tabBarItem = UITabBarItem(
                title: page.title,
                image: UIImage(systemName: symbol),
                selectedImage: UIImage(systemName: page.activeSymbol ?? symbol))
            if let badge = page.badge, badge > 0 { controller.tabBarItem.badgeValue = "\(badge)" }
            return controller
        }
        selectedIndex = store.selectedPage
        if let tint = store.tint { tabBar.tintColor = tint }
        delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The pages' opacity; 0 hides them while the sheet is collapsed to its
    /// tab bar. A page selected meanwhile takes it on its first layout.
    var pageAlpha: CGFloat = 1 {
        didSet { applyPageAlpha() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyPageAlpha()
    }

    private func applyPageAlpha() {
        for page in viewControllers ?? [] {
            page.viewIfLoaded?.alpha = pageAlpha
        }
    }

    func setBadges(_ badges: [Int?]) {
        for (i, controller) in (viewControllers ?? []).enumerated() where i < badges.count {
            let badge = badges[i] ?? 0
            controller.tabBarItem.badgeValue = badge > 0 ? "\(badge)" : nil
        }
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        onEvent("onPageSelected", ["index": selectedIndex])
    }
}

/// Hosts the tab bar controller in a view that reaches the screen's bottom
/// edge. A sheet resting at a partial detent floats above that edge, and a
/// tab bar laid out inside it sits higher and narrower than in system apps
/// such as Find My on iOS 27, whose tab bar keeps the position it has at the
/// bottom of the screen. The sheet still clips everything to its own shape.
/// iOS 26 places a screen-level tab bar lower, past the sheet's rounded
/// corners, so there the bar is laid out inside the sheet.
///
/// With a collapsed detent the sheet shrinks to its tab bar, as Find My's
/// does: over the last 100 points above that height the tab bar's own glass
/// platter fades into the sheet's glass and the bar moves from the
/// screen-level position to the middle of the sheet. The page fades out a
/// little earlier, before the bar reaches its title.
final class CNSheetTabContainer: UIViewController {
    let tabs: CNSheetTabBarController

    /// The collapsed detent's height, when the sheet has one.
    var collapsedHeight: CGFloat?

    private static let collapseRange: CGFloat = 100
    private static let pageFadeStart: CGFloat = 40
    private static let pageFadeRange: CGFloat = 80
    private weak var platterGlass: CALayer?
    private weak var observedSuperview: UIView?
    private var sheetObservations: [NSKeyValueObservation] = []

    init(tabs: CNSheetTabBarController) {
        self.tabs = tabs
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        addChild(tabs)
        view.addSubview(tabs.view)
        tabs.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        observeSheetPosition()
        // 0 when collapsed, 1 from collapseRange above the collapsed height.
        var expansion: CGFloat = 1
        var pageAlpha: CGFloat = 1
        if let collapsed = collapsedHeight {
            let above = view.bounds.height - collapsed
            expansion = min(1, max(0, above / Self.collapseRange))
            pageAlpha = min(1, max(0, (above - Self.pageFadeStart) / Self.pageFadeRange))
        }
        var gap: CGFloat = 0
        if #available(iOS 27.0, *), let window = view.window {
            gap = max(0, window.bounds.maxY - view.convert(view.bounds, to: window).maxY)
        }
        // The home indicator's inset sets the bar's height and margins. UIKit
        // passes it to some partial-height sheets and not to others (not to
        // one that can collapse); a collapsed bar has none.
        let bottomInset = (view.window?.safeAreaInsets.bottom ?? 0) * expansion
        let additional = max(0, bottomInset - view.safeAreaInsets.bottom)
        if tabs.additionalSafeAreaInsets.bottom != additional {
            tabs.additionalSafeAreaInsets.bottom = additional
        }
        tabs.view.frame = CGRect(
            x: 0, y: 0, width: view.bounds.width, height: view.bounds.height + gap * expansion)
        guard collapsedHeight != nil else { return }
        tabs.pageAlpha = pageAlpha
        platterLayer()?.opacity = Float(expansion)
    }

    /// The sheet scales and moves the views around this one after laying it
    /// out (a floating sheet is drawn smaller the lower it rests), so the
    /// tab bar's offset is worked out again whenever they change, inside the
    /// sheet's own animation.
    private func observeSheetPosition() {
        guard view.window != nil, observedSuperview !== view.superview else { return }
        observedSuperview = view.superview
        sheetObservations = []
        // Layers, not views: the sheet scales a layer that wraps its views'.
        let windowLayer = view.window?.layer
        var ancestor = view.layer.superlayer
        while let current = ancestor, current !== windowLayer {
            sheetObservations.append(current.observe(\.transform) { [weak self] _, _ in
                self?.sheetMoved()
            })
            sheetObservations.append(current.observe(\.position) { [weak self] _, _ in
                self?.sheetMoved()
            })
            ancestor = current.superlayer
        }
    }

    private func sheetMoved() {
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    /// The glass behind the tab bar's items. UIKit has no public switch for
    /// it; when a later iOS draws it differently it is not found and the
    /// platter simply stays.
    private func platterLayer() -> CALayer? {
        if let platterGlass { return platterGlass }
        func find(_ layer: CALayer) -> CALayer? {
            if let owner = layer.delegate, String(describing: type(of: owner)).hasSuffix("GlassGroupView") {
                return layer
            }
            for sublayer in layer.sublayers ?? [] {
                if let found = find(sublayer) { return found }
            }
            return nil
        }
        // The view holding the tab bar, beside the one holding the pages.
        guard let bar = tabs.viewIfLoaded?.subviews.first(where: { tabs.tabBar.isDescendant(of: $0) })
        else { return nil }
        platterGlass = find(bar.layer)
        return platterGlass
    }
}

// MARK: - A page: title, toolbar buttons and a list

@available(iOS 17.0, *)
struct CNSheetPageView: View {
    @ObservedObject var store: CNSheetStore
    let index: Int
    let onEvent: (String, [String: Any]?) -> Void

    /// The page in a hosting controller with a clear background, so the
    /// sheet draws its own (Liquid Glass at the partial detents on iOS 26).
    static func controller(store: CNSheetStore, index: Int,
                           onEvent: @escaping (String, [String: Any]?) -> Void) -> UIViewController {
        let host = UIHostingController(rootView: CNSheetPageView(store: store, index: index, onEvent: onEvent))
        host.view.backgroundColor = .clear
        return host
    }

    private var list: some View {
        let page = store.pages[index]
        return List {
            ForEach(page.items.indices, id: \.self) { i in
                Button {
                    onEvent("onItemTap", ["page": index, "index": i])
                } label: {
                    row(page.items[i])
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(i == 0 ? .hidden : .automatic, edges: .top)
                .listRowSeparator(i == page.items.count - 1 ? .hidden : .automatic, edges: .bottom)
                .modifier(CNSheetRowInsets(twoLines: page.items[i].subtitle != nil))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    var body: some View {
        let page = store.pages[index]
        NavigationStack {
            list
            .modifier(CNClearNavigationBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // System sheets such as Find My's draw the title at the
                // leading edge in Title Bold (28 pt at the default text
                // size), beside the bar buttons; a large navigation title is
                // 34 pt. Measured against Find My on iOS 27.
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) { title(page.title) }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { title(page.title) }
                }
                ForEach(page.buttons.indices, id: \.self) { b in
                    let button = page.buttons[b]
                    ToolbarItem(placement: .topBarTrailing) {
                        SwiftUI.Button {
                            onEvent("onButtonTap", ["page": index, "id": button.id])
                        } label: {
                            if let symbol = button.symbol {
                                Image(systemName: symbol)
                            } else {
                                Text(button.label ?? "")
                            }
                        }
                        .accessibilityLabel(button.label ?? button.symbol ?? "")
                    }
                }
            }
        }
        .tint(store.tint.map { Color($0) })
    }

    // Find My's two-line rows at the default text size, in the sheet's own
    // points (a sheet resting at a partial height is drawn at 96% scale).
    @ScaledMetric(relativeTo: .headline) private var rowHeight: CGFloat = 74
    @ScaledMetric(relativeTo: .headline) private var textTop: CGFloat = 17.9

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.title.bold())
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }

    private func row(_ item: CNSheetConfig.Item) -> some View {
        // Two-line rows follow Find My's people list, measured on iOS 27: 72
        // pt tall, the photo centred, the text starting 10 pt after it and
        // set a little low, its first line's cap height 21.7 pt from the top.
        let twoLines = item.subtitle != nil
        return HStack(alignment: twoLines ? .top : .center, spacing: 10) {
            leading(item)
                .padding(.top, twoLines ? (rowHeight - 44) / 2 : 0)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title).font(.headline)
                    Spacer(minLength: 8)
                    if let trailing = item.trailing {
                        Text(trailing).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if let subtitle = item.subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.top, twoLines ? textTop : 0)
            if item.chevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(maxHeight: twoLines ? rowHeight : nil)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: twoLines ? rowHeight : nil, alignment: .top)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func leading(_ item: CNSheetConfig.Item) -> some View {
        if let image = item.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .accessibilityHidden(true)
        } else if let symbol = item.symbol {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
    }
}

/// Two-line rows set their own height, so their vertical insets are zero
/// (iOS 26; earlier versions keep the default insets around the 72 pt row).
@available(iOS 17.0, *)
private struct CNSheetRowInsets: ViewModifier {
    let twoLines: Bool

    func body(content: Content) -> some View {
        if twoLines, #available(iOS 26.0, *) {
            content.listRowInsets(.vertical, 0)
        } else {
            content
        }
    }
}

/// Clears the opaque system background `NavigationStack` puts behind its
/// content, which would pale the sheet's glass the same way.
@available(iOS 17.0, *)
private struct CNClearNavigationBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.containerBackground(.clear, for: .navigation)
        } else {
            content
        }
    }
}
