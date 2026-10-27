import Flutter
import UIKit

/// Streams foldable-device state for the Flutter view to Dart over the
/// `cn_foldable` channel: the hinge (iPhone Duo), the edge the system puts its
/// vertical bar on, and the screen's reserved regions (the fold and the
/// camera).
///
/// Everything it observes is new in the iOS 27.1 SDK — `UIHingeInteraction`,
/// `UITraitCollection.verticalBarEdge` and `UIView.reservedRegions(kind:)` —
/// so the observer is compiled only when the UIKit module is the 27.1 one or
/// newer (module version 9127.0.85). Built with an older Xcode the plugin still
/// compiles, and the channel answers `supported: false`.
///
/// There is no platform view. A hidden, non-interactive tracking view is added
/// to the `FlutterViewController`'s view, so every rect it reports is already in
/// Flutter's logical coordinates. Because it is a subview of that view, it
/// moves with it when `CNTabBarNative` re-parents the Flutter view into a tab.
final class CNFoldableManager: NSObject {

    static let shared = CNFoldableManager()

    private var channel: FlutterMethodChannel?

    /// Dart `start` calls not yet balanced by `stop`. The tracker stays
    /// attached while this is above zero.
    private var clients = 0

    /// The attached tracking view; `CNFoldableTrackingView` on the 27.1 SDK.
    private weak var tracker: UIView?

    private var sendScheduled = false
    private var lastSent: NSDictionary?
    private var attachAttempts = 0

    func setup(messenger: FlutterBinaryMessenger) {
        let ch = FlutterMethodChannel(name: "cn_foldable", binaryMessenger: messenger)
        channel = ch
        ch.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            clients += 1
            attachAttempts = 0
            attachIfNeeded()
            result(snapshot())
        case "stop":
            clients = max(0, clients - 1)
            if clients == 0 { detach() }
            result(nil)
        case "getState":
            result(snapshot())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Tracker lifecycle

    private func attachIfNeeded() {
        guard clients > 0, tracker == nil else { return }
#if canImport(UIKit, _version: 9127.0.85)
        guard #available(iOS 27.1, *) else { return }
        guard let host = flutterViewController()?.view else {
            // Too early (no window yet): retry briefly, then give up quietly.
            attachAttempts += 1
            if attachAttempts <= 20 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.attachIfNeeded()
                }
            }
            return
        }
        let view = CNFoldableTrackingView(frame: host.bounds)
        view.onChange = { [weak self] in self?.scheduleSend() }
        // Behind everything, so it can never cover a platform view.
        host.insertSubview(view, at: 0)
        tracker = view
        view.setNeedsUpdateConstraints()
        scheduleSend()
#endif
    }

    private func detach() {
        tracker?.removeFromSuperview()
        tracker = nil
        lastSent = nil
    }

    // MARK: - Sending

    /// Coalesces bursts (a fold animation updates the angle, the size and the
    /// regions together) into one message per run-loop turn, and drops
    /// messages identical to the last one sent.
    private func scheduleSend() {
        guard !sendScheduled else { return }
        sendScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.sendScheduled = false
            let state = self.snapshot()
            let dict = state as NSDictionary
            if let last = self.lastSent, last.isEqual(dict) { return }
            self.lastSent = dict
            self.channel?.invokeMethod("onStateChanged", arguments: state)
        }
    }

    private func snapshot() -> [String: Any] {
#if canImport(UIKit, _version: 9127.0.85)
        if #available(iOS 27.1, *) {
            if let view = tracker as? CNFoldableTrackingView {
                return view.snapshot()
            }
            return ["supported": true, "attached": false]
        }
#endif
        return ["supported": false]
    }

    // MARK: - Finding the Flutter view

    private func flutterViewController() -> FlutterViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let ordered = scenes.sorted { lhs, _ in lhs.activationState == .foregroundActive }
        for scene in ordered {
            let windows = scene.windows.sorted { lhs, _ in lhs.isKeyWindow }
            for window in windows {
                if let found = find(in: window.rootViewController) { return found }
            }
        }
        return nil
    }

    private func find(in vc: UIViewController?) -> FlutterViewController? {
        guard let vc else { return nil }
        if let flutter = vc as? FlutterViewController { return flutter }
        for child in vc.children {
            if let found = find(in: child) { return found }
        }
        return find(in: vc.presentedViewController)
    }
}

#if canImport(UIKit, _version: 9127.0.85)
/// Reads the hinge, the vertical-bar edge and the reserved regions for the
/// Flutter view and reports each change through `onChange`.
@available(iOS 27.1, *)
private final class CNFoldableTrackingView: UIView {

    var onChange: (() -> Void)?

    private var hinge: UIHinge?
    private var regions: [UIView.ReservedRegion] = []
    private var lastSize: CGSize = .zero

    /// Reserved regions are read in `updateConstraints()`: UIKit records the
    /// regions read there and runs it again when they change. That needs the
    /// constraint pass to run for this view.
    override class var requiresConstraintBasedLayout: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = .clear
        autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // The handler runs with the initial state and on every change; a nil
        // hinge means this hierarchy does not provide hinge updates (no hinge).
        addInteraction(UIHingeInteraction { [weak self] _, update in
            self?.hinge = update.hinge
            self?.onChange?()
        })

        registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) {
            (view: CNFoldableTrackingView, _: UITraitCollection) in
            view.onChange?()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func updateConstraints() {
        regions = reservedRegions(kind: .division, options: .includeInactive)
            + reservedRegions(kind: .occlusion, options: .includeInactive)
        super.updateConstraints()
        onChange?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Region frames are in this view's coordinates, so a resize (fold,
        // unfold, rotation) has to re-read them.
        if bounds.size != lastSize {
            lastSize = bounds.size
            setNeedsUpdateConstraints()
            onChange?()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsUpdateConstraints()
        onChange?()
    }

    func snapshot() -> [String: Any] {
        var state: [String: Any] = [
            "supported": true,
            "attached": window != nil,
            "width": Double(bounds.width),
            "height": Double(bounds.height),
            "verticalBarSide": verticalBarSide(),
            "regions": regions.map(encode),
        ]
        if let hinge {
            state["hinge"] = [
                "status": status(hinge.status),
                "angle": Double(hinge.angle),
            ]
        }
        return state
    }

    /// The physical side of the vertical bar. The trait is expressed as
    /// leading/trailing, but the bar is aligned with the hardware, so resolve it
    /// against the layout direction once here and hand Dart a physical side.
    private func verticalBarSide() -> String {
        let rtl = effectiveUserInterfaceLayoutDirection == .rightToLeft
        switch traitCollection.verticalBarEdge {
        case .leading: return rtl ? "right" : "left"
        case .trailing: return rtl ? "left" : "right"
        default: return "none"
        }
    }

    private func status(_ status: UIHinge.Status) -> String {
        switch status {
        case .closed: return "closed"
        case .partiallyOpen: return "partiallyOpen"
        case .fullyOpen: return "fullyOpen"
        default: return "unknown"
        }
    }

    private func encode(_ region: UIView.ReservedRegion) -> [String: Any] {
        [
            "kind": region.kind == .division ? "division" : "occlusion",
            "x": Double(region.frame.origin.x),
            "y": Double(region.frame.origin.y),
            "width": Double(region.frame.width),
            "height": Double(region.frame.height),
            "marginTop": Double(region.margins.top),
            "marginLeft": Double(region.margins.left),
            "marginBottom": Double(region.margins.bottom),
            "marginRight": Double(region.margins.right),
            "active": region.isActive,
        ]
    }
}
#endif
