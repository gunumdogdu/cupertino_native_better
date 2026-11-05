import Flutter
import SwiftUI
import UIKit

/// Presents a native popover anchored to a rect of the Flutter view on
/// request from Dart over the `cn_popover` channel: the iOS side of
/// `CNPopover`.
///
/// The popover is a `UIHostingController` presented with the `.popover`
/// style, its source the Flutter view and the anchor's rect. The delegate
/// keeps it a popover on iPhone too (no adaptation into a sheet). Its
/// content is SwiftUI built from the data Dart sends (`CNPopoverConfig`):
/// a title and message, rows, switches and buttons. Flutter widgets cannot
/// be placed inside it: the app's one Flutter view stays behind it.
///
/// `show` takes the payload of `debugBuildPopoverPayload` and answers, once
/// the popover has closed, the id of the row or button that closed it, or
/// nil (a tap outside, Escape or the escape gesture, a cancel button,
/// `dismiss`, a newer `show`, a hot restart). `update`, `setAnchor` and
/// `dismiss` act only on the popover of the session they name.
final class CNPopoverManager: NSObject, UIPopoverPresentationControllerDelegate {

    static let shared = CNPopoverManager()

    private var channel: FlutterMethodChannel?

    /// The open popover's call, answered exactly once by `finish`.
    private var pendingResult: FlutterResult?
    private var session: Int?
    private var host: UIViewController?
    private var store: CNPopoverStore?
    private var edge = "bottom"
    private weak var sourceView: UIView?

    /// The engine's root isolate when the popover opened. A hot restart
    /// starts a new one; the popover, whose caller is gone, then closes.
    private var isolateObservation: NSKeyValueObservation?

    func setup(messenger: FlutterBinaryMessenger) {
        let ch = FlutterMethodChannel(name: "cn_popover", binaryMessenger: messenger)
        channel = ch
        ch.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let callSession = args?["session"] as? Int
        switch call.method {
        case "show":
            guard let args, let config = CNPopoverConfig(args: args) else {
                result(FlutterError(code: "invalid_args", message: "Expected {session, anchor, edge, content}", details: nil))
                return
            }
            show(config, result: result)

        case "update":
            if callSession == session, let content = args?["content"] as? [String: Any] {
                store?.content = CNPopoverConfig.Content(dict: content)
            }
            result(nil)

        case "setAnchor":
            if callSession == session, let rect = CNPopoverConfig.rect(args?["anchor"]) {
                move(to: rect)
            }
            result(nil)

        case "dismiss":
            if callSession == nil || callSession == session {
                finish(nil, dismiss: true)
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Presentation

    private func show(_ config: CNPopoverConfig, result: @escaping FlutterResult) {
        // A popover already open belongs to an earlier call: it answers nil
        // and goes away at once; the new one is presented once it is gone,
        // as presenting from a controller that is being dismissed fails.
        if let previous = host {
            finish(nil, dismiss: false)
            if previous.presentingViewController != nil {
                previous.dismiss(animated: false) { [weak self] in
                    self?.present(config, result: result)
                }
                return
            }
        }
        present(config, result: result)
    }

    private func present(_ config: CNPopoverConfig, result: @escaping FlutterResult) {
        let window = keyWindow()
        guard let flutterController = findFlutterVC(window?.rootViewController) as? FlutterViewController,
              let view = flutterController.view else {
            result(FlutterError(code: "no_view", message: "No Flutter view to anchor the popover to", details: nil))
            return
        }
        guard let presenter = topPresenter(in: window) else {
            result(FlutterError(code: "no_presenter", message: "No view controller to present the popover on", details: nil))
            return
        }
        // A controller still on its way out (a popover closed by a row a
        // moment ago) cannot present yet: wait for its transition.
        if let leaving = presenter.presentedViewController, leaving.isBeingDismissed {
            if let coordinator = leaving.transitionCoordinator {
                coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                    self?.present(config, result: result)
                }
            } else {
                DispatchQueue.main.async { [weak self] in self?.present(config, result: result) }
            }
            return
        }

        let store = CNPopoverStore(content: config.content, tint: config.tint.map { Color($0) })
        let host = CNPopoverHostController(rootView: CNPopoverRootView(store: store))
        let style: UIUserInterfaceStyle = config.isDark.map { $0 ? .dark : .light } ?? .unspecified
        host.overrideUserInterfaceStyle = style
        host.modalPresentationStyle = .popover

        let category = view.traitCollection.preferredContentSizeCategory
        let maxWidth = max(160, min(360, view.bounds.width - 40))
        let width = config.width.map { min($0, view.bounds.width - 20) }
            ?? Self.idealWidth(of: config.content, category: category, in: 200...maxWidth)
        store.width = width
        let height = Self.height(of: config.content, width: width, category: category)
        host.preferredContentSize = CGSize(width: width, height: height)

        guard let popover = host.popoverPresentationController else {
            result(FlutterError(code: "no_popover", message: "The popover could not be created", details: nil))
            return
        }
        // The glass of the popover belongs to the presentation, so it needs
        // the appearance too.
        if style != .unspecified, #available(iOS 17.0, *) {
            popover.traitOverrides.userInterfaceStyle = style
        }
        popover.delegate = self
        popover.sourceView = view
        popover.sourceRect = config.anchor
        popover.permittedArrowDirections = Self.arrowDirection(
            edge: config.edge, anchor: config.anchor, in: view, size: host.preferredContentSize)
        popover.canOverlapSourceViewRect = false

        store.onRow = { [weak self, weak host] id in
            guard let self, let host, host === self.host else { return }
            self.finish(id, dismiss: true)
        }
        store.onAction = { [weak self, weak host] action in
            guard let self, let host, host === self.host else { return }
            self.finish(action.style == "cancel" ? nil : action.id, dismiss: true)
        }
        store.onToggle = { [weak self, weak host] id, value in
            guard let self, let host, host === self.host else { return }
            self.sendToggle(id: id, value: value)
        }
        store.onHeight = { [weak host, weak store] height in
            guard let host, let store, height > 0,
                  abs(host.preferredContentSize.height - height) > 0.5 else { return }
            host.preferredContentSize = CGSize(width: store.width, height: height)
        }
        let escape: () -> Void = { [weak self, weak host] in
            guard let self, let host, host === self.host else { return }
            self.finish(nil, dismiss: true)
        }
        store.onEscape = escape
        host.onEscape = escape

        pendingResult = result
        session = config.session
        edge = config.edge
        sourceView = view
        self.host = host
        self.store = store
        observeIsolate(of: flutterController.engine)

        presenter.present(host, animated: true) {
            // VoiceOver moves into the popover, which is modal for it.
            UIAccessibility.post(notification: .screenChanged, argument: host.view)
        }
        // UIKit refuses some presentations with only a log line (a presenter
        // already presenting something else); the call must not wait for a
        // popover that never appeared.
        if host.presentingViewController == nil, self.host === host {
            finish(nil, dismiss: false)
        }
    }

    /// Moves the open popover to a new anchor rect (the anchor scrolled, or
    /// the window was resized).
    private func move(to rect: CGRect) {
        guard let popover = host?.popoverPresentationController,
              popover.sourceRect != rect else { return }
        popover.sourceRect = rect
        popover.containerView?.setNeedsLayout()
        popover.containerView?.layoutIfNeeded()
    }

    /// Answers the open popover's call with [value] once, and closes the
    /// popover when [dismiss] is set (it is already gone otherwise).
    private func finish(_ value: String?, dismiss: Bool) {
        let result = pendingResult
        let host = self.host
        pendingResult = nil
        session = nil
        self.host = nil
        store = nil
        isolateObservation = nil
        if dismiss, let host, host.presentingViewController != nil, !host.isBeingDismissed {
            host.dismiss(animated: true)
        }
        result?(value)
    }

    private func sendToggle(id: String, value: Bool) {
        guard let session else { return }
        channel?.invokeMethod("onToggleChanged", arguments: [
            "session": session, "id": id, "value": value,
        ]) { [weak self] reply in
            // No Dart handler: the app restarted and nobody is waiting for
            // this popover any more.
            if (reply as? NSObject) === FlutterMethodNotImplemented, self?.session == session {
                self?.finish(nil, dismiss: true)
            }
        }
    }

    private func observeIsolate(of engine: FlutterEngine?) {
        guard let engine else { return }
        let isolate = engine.isolateId
        isolateObservation = engine.observe(\.isolateId, options: [.new]) { [weak self] engine, _ in
            DispatchQueue.main.async {
                guard let self, self.isolateObservation != nil, engine.isolateId != isolate else { return }
                self.finish(nil, dismiss: true)
            }
        }
    }

    // MARK: - UIPopoverPresentationControllerDelegate

    // A popover on iPhone too: no adaptation into a sheet in a compact
    // width.
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        .none
    }

    func adaptivePresentationStyle(
        for controller: UIPresentationController, traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        .none
    }

    /// A tap outside closed the popover.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard presentationController.presentedViewController === host else { return }
        finish(nil, dismiss: false)
    }

    // MARK: - Geometry

    /// The arrow direction for [edge], or for the opposite edge when the
    /// popover does not fit on that side and fits better on the other one,
    /// as AppKit's popovers do. A popover meant for the left or right side
    /// that fits on neither (a narrow iPhone screen) goes below or above the
    /// anchor instead. UIKit is given a single direction so that it never
    /// picks another side on its own.
    static func arrowDirection(edge: String, anchor: CGRect, in view: UIView,
                               size: CGSize) -> UIPopoverArrowDirection {
        let area = view.bounds.inset(by: view.safeAreaInsets)
        // The arrow and the margin UIKit keeps from the screen's edges.
        let extra: CGFloat = 13 + 10
        let above = anchor.minY - area.minY
        let below = area.maxY - anchor.maxY
        let left = anchor.minX - area.minX
        let right = area.maxX - anchor.maxX
        func pick(_ room: CGFloat, _ opposite: CGFloat, _ needed: CGFloat,
                  _ preferred: UIPopoverArrowDirection,
                  _ other: UIPopoverArrowDirection) -> UIPopoverArrowDirection {
            room >= needed + extra || room >= opposite ? preferred : other
        }
        let vertical = pick(below, above, size.height, .up, .down)
        switch edge {
        case "top":
            return pick(above, below, size.height, .down, .up)
        case "left", "right":
            if max(left, right) < size.width + extra { return vertical }
            return edge == "left"
                ? pick(left, right, size.width, .right, .left)
                : pick(right, left, size.width, .left, .right)
        default:
            return vertical
        }
    }

    /// The width the content takes on one line, within [range].
    static func idealWidth(of content: CNPopoverConfig.Content,
                           category: UIContentSizeCategory,
                           in range: ClosedRange<CGFloat>) -> CGFloat {
        let host = UIHostingController(rootView: CNPopoverMeasure(content: content, category: category))
        let ideal = host.view.intrinsicContentSize.width
        guard ideal.isFinite, ideal > 0 else { return range.upperBound }
        return min(range.upperBound, max(range.lowerBound, ceil(ideal)))
    }

    /// The content's height at [width].
    static func height(of content: CNPopoverConfig.Content, width: CGFloat,
                       category: UIContentSizeCategory) -> CGFloat {
        let host = UIHostingController(rootView: CNPopoverMeasure(content: content, category: category))
        let size = host.sizeThatFits(in: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        return ceil(size.height)
    }

    // MARK: - View controller lookup

    // Duplicated from the action sheet manager, where they are private.

    private func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = (scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene)
            ?? (scenes.first as? UIWindowScene)
        return windowScene?.windows.first(where: { $0.isKeyWindow }) ?? windowScene?.windows.first
    }

    private func topPresenter(in window: UIWindow?) -> UIViewController? {
        guard var vc = window?.rootViewController else { return nil }
        while let presented = vc.presentedViewController, !presented.isBeingDismissed {
            vc = presented
        }
        return vc
    }

    private func findFlutterVC(_ vc: UIViewController?) -> UIViewController? {
        guard let vc else { return nil }
        if vc is FlutterViewController { return vc }
        for child in vc.children {
            if let found = findFlutterVC(child) { return found }
        }
        return nil
    }
}

// MARK: - Config (plain data parsed from the channel)

/// Mirrors `debugBuildPopoverPayload` in `lib/components/popover.dart`.
struct CNPopoverConfig {
    struct Row {
        let id: String
        /// The `CNListItem` part, parsed as `CNNativeSheet` parses its rows.
        let item: CNSheetConfig.Item
        let checked: Bool
        let enabled: Bool
    }
    struct Toggle {
        let id: String
        let label: String
        let subtitle: String?
        let symbol: String?
        var value: Bool
        let enabled: Bool
    }
    struct Action {
        let id: String?
        let label: String
        /// `plain`, `default`, `destructive` or `cancel`.
        let style: String
    }
    struct Content {
        let title: String?
        let message: String?
        let rows: [Row]
        var toggles: [Toggle]
        let actions: [Action]

        init(dict: [String: Any]) {
            title = (dict["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            message = (dict["message"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let rawRows = dict["rows"] as? [[String: Any]] ?? []
            let items = CNSheetConfig.parseItems(rawRows)
            rows = zip(rawRows, items).map { raw, item in
                Row(id: raw["id"] as? String ?? "",
                    item: item,
                    checked: raw["checked"] as? Bool ?? false,
                    enabled: raw["enabled"] as? Bool ?? true)
            }
            toggles = (dict["toggles"] as? [[String: Any]] ?? []).map { t in
                Toggle(id: t["id"] as? String ?? "",
                       label: t["label"] as? String ?? "",
                       subtitle: t["subtitle"] as? String,
                       symbol: t["sfSymbol"] as? String,
                       value: t["value"] as? Bool ?? false,
                       enabled: t["enabled"] as? Bool ?? true)
            }
            actions = (dict["actions"] as? [[String: Any]] ?? []).map { a in
                Action(id: a["id"] as? String,
                       label: a["label"] as? String ?? "",
                       style: a["style"] as? String ?? "plain")
            }
        }
    }

    let session: Int
    let anchor: CGRect
    /// `top`, `bottom`, `left` or `right`.
    let edge: String
    let content: Content
    let width: CGFloat?
    let tint: UIColor?
    let isDark: Bool?

    init?(args: [String: Any]) {
        guard let session = args["session"] as? Int,
              let anchor = Self.rect(args["anchor"]),
              let content = args["content"] as? [String: Any] else { return nil }
        self.session = session
        self.anchor = anchor
        edge = args["edge"] as? String ?? "bottom"
        self.content = Content(dict: content)
        width = (args["width"] as? NSNumber).map { CGFloat($0.doubleValue) }
        tint = (args["tint"] as? Int).map { ImageUtils.colorFromARGB($0) }
        isDark = args["isDark"] as? Bool
    }

    static func rect(_ value: Any?) -> CGRect? {
        guard let r = value as? [String: Any],
              let x = (r["x"] as? NSNumber)?.doubleValue,
              let y = (r["y"] as? NSNumber)?.doubleValue,
              let w = (r["width"] as? NSNumber)?.doubleValue,
              let h = (r["height"] as? NSNumber)?.doubleValue else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

// MARK: - Store and host

final class CNPopoverStore: ObservableObject {
    @Published var content: CNPopoverConfig.Content
    @Published var width: CGFloat = 280
    let tint: Color?

    var onRow: (String) -> Void = { _ in }
    var onAction: (CNPopoverConfig.Action) -> Void = { _ in }
    var onToggle: (String, Bool) -> Void = { _, _ in }
    var onHeight: (CGFloat) -> Void = { _ in }
    var onEscape: () -> Void = {}

    init(content: CNPopoverConfig.Content, tint: Color?) {
        self.content = content
        self.tint = tint
    }

    /// The switch at [index], reporting the user's changes. Values set by
    /// `update` change the content without reporting.
    func toggle(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { [weak self] in
                guard let self, self.content.toggles.indices.contains(index) else { return false }
                return self.content.toggles[index].value
            },
            set: { [weak self] value in
                guard let self, self.content.toggles.indices.contains(index) else { return }
                self.content.toggles[index].value = value
                self.onToggle(self.content.toggles[index].id, value)
            })
    }
}

/// The popover's controller. Its view is modal for VoiceOver, and Escape on
/// a hardware keyboard or the VoiceOver escape gesture closes it.
final class CNPopoverHostController: UIHostingController<CNPopoverRootView> {
    var onEscape: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        // The popover draws its own background (Liquid Glass on iOS 26).
        view.backgroundColor = .clear
        view.accessibilityViewIsModal = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(escapePressed))]
    }

    @objc private func escapePressed() { onEscape?() }

    override func accessibilityPerformEscape() -> Bool {
        onEscape?()
        return true
    }
}

// MARK: - SwiftUI content

private struct CNPopoverHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// The content in a scroll view (it scrolls when the popover is shorter than
/// the content), at the popover's width, reporting its height so the
/// popover follows changes of the content and of the text size.
struct CNPopoverRootView: View {
    @ObservedObject var store: CNPopoverStore

    var body: some View {
        ScrollView(.vertical) {
            CNPopoverBody(
                content: store.content,
                tint: store.tint,
                toggle: { [store] in store.toggle($0) },
                onRow: { [store] in store.onRow($0) },
                onAction: { [store] in store.onAction($0) })
                // The popover's own width: UIKit narrows a popover that has
                // no room for its preferred width.
                .frame(maxWidth: .infinity)
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: CNPopoverHeightKey.self, value: proxy.size.height)
                })
        }
        .modifier(CNPopoverScrollBounce())
        .onPreferenceChange(CNPopoverHeightKey.self) { [store] height in
            store.onHeight(height)
        }
        .accessibilityAction(.escape) { [store] in store.onEscape() }
    }
}

/// The content measured off screen, before the popover is presented, at the
/// text size of the Flutter view.
struct CNPopoverMeasure: View {
    let content: CNPopoverConfig.Content
    let category: UIContentSizeCategory

    var body: some View {
        CNPopoverBody(content: content, tint: nil,
                      toggle: { [content] in .constant(content.toggles[$0].value) },
                      onRow: { _ in }, onAction: { _ in })
            .modifier(CNPopoverTextSize(category: category))
    }
}

private struct CNPopoverTextSize: ViewModifier {
    let category: UIContentSizeCategory

    func body(content: Content) -> some View {
        if let size = DynamicTypeSize(category) {
            content.dynamicTypeSize(size)
        } else {
            content
        }
    }
}

/// No bounce when everything fits (iOS 16.4).
private struct CNPopoverScrollBounce: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.scrollBounceBehavior(.basedOnSize)
        } else {
            content
        }
    }
}

/// The popover's content, top to bottom: the title and message, the rows,
/// the switches and the buttons, separated by dividers.
struct CNPopoverBody: View {
    let content: CNPopoverConfig.Content
    let tint: Color?
    let toggle: (Int) -> Binding<Bool>
    let onRow: (String) -> Void
    let onAction: (CNPopoverConfig.Action) -> Void

    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 28

    private var hasHeader: Bool { content.title != nil || content.message != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasHeader {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, content.rows.isEmpty && content.toggles.isEmpty
                             && content.actions.isEmpty ? 14 : 10)
            }
            if !content.rows.isEmpty {
                if hasHeader { Divider() }
                rows
            }
            if !content.toggles.isEmpty {
                if hasHeader || !content.rows.isEmpty { Divider() }
                toggles
            }
            if !content.actions.isEmpty {
                actions
                    .padding(.horizontal, 16)
                    .padding(.top, hasHeader && content.rows.isEmpty && content.toggles.isEmpty ? 4 : 12)
                    .padding(.bottom, 14)
            }
        }
        .tint(tint)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = content.title {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            if let message = content.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(content.rows.indices, id: \.self) { i in
                let row = content.rows[i]
                if i > 0 {
                    Divider().padding(.leading, textInset)
                }
                Button {
                    onRow(row.id)
                } label: {
                    rowLabel(row)
                }
                .buttonStyle(CNPopoverRowStyle())
                .disabled(!row.enabled)
                .accessibilityAddTraits(row.checked ? .isSelected : [])
            }
        }
    }

    /// Where a row's text starts: after the leading icon, when any row has
    /// one, so the separators line up with the text.
    private var textInset: CGFloat {
        let anyLeading = content.rows.contains { $0.item.image != nil || $0.item.symbol != nil }
        return anyLeading ? 16 + iconSide + 12 : 16
    }

    private func rowLabel(_ row: CNPopoverConfig.Row) -> some View {
        let anyLeading = content.rows.contains { $0.item.image != nil || $0.item.symbol != nil }
        // A disabled row is drawn in the tertiary colour rather than with a
        // lower opacity, which the glass of an iOS 26 popover does not show.
        let primary: HierarchicalShapeStyle = row.enabled ? .primary : .tertiary
        let secondary: HierarchicalShapeStyle = row.enabled ? .secondary : .tertiary
        return HStack(spacing: 12) {
            if anyLeading {
                leading(row.item)
                    .foregroundStyle(primary)
                    .opacity(row.item.image != nil && !row.enabled ? 0.4 : 1)
                    .frame(width: iconSide, height: iconSide)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(row.item.title)
                    .font(.body)
                    .foregroundStyle(primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = row.item.subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let trailing = row.item.trailing {
                Text(trailing)
                    .font(.subheadline)
                    .foregroundStyle(secondary)
            }
            if row.checked {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tint ?? .accentColor)
                    .accessibilityHidden(true)
            }
            if row.item.chevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: rowHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func leading(_ item: CNSheetConfig.Item) -> some View {
        if let image = item.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .accessibilityHidden(true)
        } else if let symbol = item.symbol {
            Image(systemName: symbol)
                .font(.body)
                .accessibilityHidden(true)
        }
    }

    private var toggles: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(content.toggles.indices, id: \.self) { i in
                let item = content.toggles[i]
                if i > 0 {
                    Divider().padding(.leading, 16)
                }
                SwiftUI.Toggle(isOn: toggle(i)) {
                    HStack(spacing: 12) {
                        if let symbol = item.symbol {
                            Image(systemName: symbol)
                                .font(.body)
                                .frame(width: iconSide)
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                            if let subtitle = item.subtitle {
                                Text(subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .disabled(!item.enabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .frame(minHeight: rowHeight)
            }
        }
    }

    /// Two buttons side by side, more stacked, each as wide as the popover.
    @ViewBuilder
    private var actions: some View {
        if content.actions.count <= 2 {
            HStack(spacing: 10) {
                ForEach(content.actions.indices, id: \.self) { i in
                    actionButton(content.actions[i])
                }
            }
        } else {
            VStack(spacing: 8) {
                ForEach(content.actions.indices, id: \.self) { i in
                    actionButton(content.actions[i])
                }
            }
        }
    }

    @ViewBuilder
    private func actionButton(_ action: CNPopoverConfig.Action) -> some View {
        let role: ButtonRole? = action.style == "destructive" ? .destructive
            : action.style == "cancel" ? .cancel : nil
        let button = Button(role: role) {
            onAction(action)
        } label: {
            Text(action.label)
                .fontWeight(action.style == "default" ? .semibold : .regular)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        switch action.style {
        case "default":
            button
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        case "cancel":
            button
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
        default:
            button.buttonStyle(.bordered)
        }
    }
}

/// A list row: the system fill behind it while it is pressed.
private struct CNPopoverRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CNPopoverRowBody(configuration: configuration)
    }
}

private struct CNPopoverRowBody: View {
    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .background(configuration.isPressed ? Color(UIColor.systemFill) : Color.clear)
    }
}
