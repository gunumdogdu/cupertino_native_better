import Flutter
import UIKit

/// Presents a native `UIAlertController` in `.actionSheet` style on request
/// from Dart over the `cn_action_sheet` channel.
///
/// There is no platform view here: an action sheet is a modal presentation, so
/// it is presented on the top view controller rather than embedded in the
/// Flutter view hierarchy. That also means it is unaffected by the iOS hybrid
/// composition bleed that forces `ModalHideMixin` to tear down inline CN
/// widgets behind Flutter-drawn modals — this sheet is real UIKit, above
/// everything.
///
/// Liquid Glass is deliberately absent from this file. On iOS 26 the system
/// applies the new appearance to alerts and action sheets with no opt-in, so
/// the correct amount of glass code is none.
///
/// Modelled on `CNNativeTabBarManager`: a singleton owning its own method
/// channel, wired up from `CupertinoNativePlugin.register`.
final class CNActionSheetManager: NSObject {

    static let shared = CNActionSheetManager()

    private var channel: FlutterMethodChannel?

    /// The result of the sheet currently on screen. Nil whenever no sheet is
    /// pending. Cleared by `send(_:)` so a tap followed by a dismissal callback
    /// cannot deliver two results down one `FlutterResult` — the engine treats
    /// a double send as a hard error.
    private var pendingResult: FlutterResult?

    /// The sheet `pendingResult` belongs to, and the identity every send is
    /// checked against. A superseded sheet is torn down rather than left on
    /// screen, but its handlers can still fire during that teardown — without
    /// an identity they would answer the next caller's call.
    private weak var presentedAlert: UIAlertController?

    func setup(messenger: FlutterBinaryMessenger) {
        let ch = FlutterMethodChannel(name: "cn_action_sheet", binaryMessenger: messenger)
        channel = ch
        ch.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "show":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "invalid_args", message: "Expected a map", details: nil))
                return
            }
            show(config: Config(args: args), result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Presentation

    private func show(config: Config, result: @escaping FlutterResult) {
        // Resolve the window once. The presenter walk and the anchor's source
        // view have to agree on it: `keyWindow()` picks an arbitrary scene when
        // more than one is foreground-active, which is the normal state for two
        // of the app's windows side by side on iPadOS.
        let window = keyWindow()

        // Resolve the presenter *before* dismissing the sheet below.
        // `dismiss(animated:)` does not clear `presentedViewController`
        // synchronously, so a walk performed afterwards can still land on the
        // alert being torn down and present the new sheet from it.
        let presenter = topPresenter(in: window, skipping: presentedAlert)

        // A sheet already on screen means the previous caller is still waiting.
        // Take that sheet down first, so its actions can no longer fire, then
        // answer the call it belonged to.
        if let stale = presentedAlert {
            stale.presentationController?.delegate = nil
            stale.dismiss(animated: false)
            presentedAlert = nil
        }
        send(nil)

        guard let presenter else {
            result(FlutterError(code: "no_presenter",
                                message: "No view controller available to present on",
                                details: nil))
            return
        }

        pendingResult = result

        let alert = UIAlertController(title: config.title,
                                      message: config.message,
                                      preferredStyle: .actionSheet)

        for (index, entry) in config.actions.enumerated() {
            let action = UIAlertAction(
                title: entry.label,
                style: entry.destructive ? .destructive : .default
            ) { [weak self, weak alert] _ in
                self?.send(index, from: alert)
            }
            action.isEnabled = entry.enabled
            alert.addAction(action)
        }

        if let cancelLabel = config.cancelLabel {
            alert.addAction(UIAlertAction(title: cancelLabel, style: .cancel) { [weak self, weak alert] _ in
                self?.send(nil, from: alert)
            })
        }

        applyAnchor(config.anchorRect, to: alert, in: window, presenter: presenter)

        // Catches a dismissal that fires no action handler — tapping outside an
        // anchored popover, or a swipe-down.
        alert.presentationController?.delegate = self

        presentedAlert = alert
        presenter.present(alert, animated: true)
    }

    /// Anchors the sheet per the iOS 26 rules.
    ///
    /// WWDC25: "ActionSheets on iPad are anchored to their source views.
    /// Starting in iOS 26, they behave the same on iPhone, appearing directly
    /// over the originating view." Assigning a source view is also what applies
    /// the new transitions, so `anchorRect` matters on every device — it is not
    /// an iPad-only escape hatch.
    ///
    /// Omitting the source is supported: the system centres the sheet, and
    /// from iOS 26 gives it a cancel button of its own. Earlier iOS adds
    /// nothing, so a centred sheet there shows exactly the actions Dart passed.
    /// The one case that needs a synthetic source is a regular-width layout
    /// before iOS 26, where UIKit raises `NSInternalInconsistencyException`
    /// without one.
    private func applyAnchor(_ anchorRect: CGRect?,
                             to alert: UIAlertController,
                             in window: UIWindow?,
                             presenter: UIViewController) {
        guard let popover = alert.popoverPresentationController else { return }

        // The rect arrives in Flutter's logical pixels, which are UIKit points,
        // measured against the Flutter view. Anchor to that view when it can be
        // found so the coordinates line up. `window` is the one the presenter
        // was resolved from, so the source view cannot land in a different one.
        let sourceView = findFlutterVC(window?.rootViewController)?.view ?? presenter.view

        if let rect = anchorRect, let sourceView {
            popover.sourceView = sourceView
            popover.sourceRect = rect
        } else if presenter.traitCollection.horizontalSizeClass == .regular, let sourceView {
            popover.sourceView = sourceView
            popover.sourceRect = CGRect(x: sourceView.bounds.midX,
                                        y: sourceView.bounds.maxY,
                                        width: 0,
                                        height: 0)
            popover.permittedArrowDirections = []
        }
        // Compact width with no anchor: left untouched on purpose. iOS 26
        // centres it with a cancel button; earlier iOS slides it up from the
        // bottom.
    }

    /// Delivers `value` to the waiting Dart call exactly once, whichever sheet
    /// it came from. Only for sends that belong to no sheet: superseding a
    /// pending call when a new `show` arrives.
    private func send(_ value: Int?) {
        guard let result = pendingResult else { return }
        pendingResult = nil
        presentedAlert = nil
        result(value)
    }

    /// Delivers `value` only while `alert` is still the sheet the pending call
    /// belongs to. A handler from a superseded sheet, or from one whose alert
    /// has already been released, is dropped rather than answering a call that
    /// is not its own.
    private func send(_ value: Int?, from alert: UIAlertController?) {
        guard let alert, alert === presentedAlert else { return }
        send(value)
    }

    // MARK: - View controller lookup

    // `keyWindow` and `findFlutterVC` are duplicated from
    // `CNNativeTabBarManager`, where both are private. Ten lines of copy beats
    // changing a shipped file to share them. `topPresenter` started as a copy
    // too and no longer is: it takes the window it should walk, and the sheet
    // it must not walk into.

    private func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = (scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene)
            ?? (scenes.first as? UIWindowScene)
        return windowScene?.windows.first(where: { $0.isKeyWindow }) ?? windowScene?.windows.first
    }

    /// Walks to the top of `window`'s presentation chain, stopping before
    /// `stale` so a sheet being replaced is never used to present its
    /// replacement.
    private func topPresenter(in window: UIWindow?,
                              skipping stale: UIAlertController?) -> UIViewController? {
        guard var vc = window?.rootViewController else { return nil }
        while let presented = vc.presentedViewController, presented !== stale {
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

    // MARK: - Payload

    /// Mirrors `debugBuildActionSheetPayload` in `lib/components/action_sheet.dart`.
    private struct Config {
        struct Action {
            let label: String
            let destructive: Bool
            let enabled: Bool
        }

        let title: String?
        let message: String?
        let cancelLabel: String?
        let actions: [Action]
        let anchorRect: CGRect?

        init(args: [String: Any]) {
            title = args["title"] as? String
            message = args["message"] as? String
            cancelLabel = args["cancelLabel"] as? String

            let raw = args["actions"] as? [[String: Any]] ?? []
            actions = raw.map { entry in
                Action(label: entry["label"] as? String ?? "",
                       destructive: entry["destructive"] as? Bool ?? false,
                       enabled: entry["enabled"] as? Bool ?? true)
            }

            if let rect = args["anchorRect"] as? [String: Any],
               let x = rect["x"] as? Double,
               let y = rect["y"] as? Double,
               let width = rect["width"] as? Double,
               let height = rect["height"] as? Double {
                anchorRect = CGRect(x: x, y: y, width: width, height: height)
            } else {
                anchorRect = nil
            }
        }
    }
}

// MARK: - Dismissal without a selection

extension CNActionSheetManager: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        send(nil, from: presentationController.presentedViewController as? UIAlertController)
    }
}
