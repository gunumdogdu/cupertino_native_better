import Flutter
import UIKit

/// Presents a native `UIAlertController` in `.alert` style on request from Dart
/// over the `cn_alert` channel.
///
/// There is no platform view here: an alert is a modal presentation, so it is
/// presented on the top view controller rather than embedded in the Flutter
/// view hierarchy. That also means it is unaffected by the iOS hybrid
/// composition bleed that forces `ModalHideMixin` to tear down inline CN
/// widgets behind Flutter-drawn modals — this alert is real UIKit, above
/// everything.
///
/// Liquid Glass is deliberately absent from this file. On iOS 26 the system
/// applies the new appearance to alerts with no opt-in, so the correct amount
/// of glass code is none.
///
/// No anchoring either. WWDC25 session 284 changed *action sheet* presentation
/// on iOS 26 — a sheet now anchors to its source view on iPhone as well as
/// iPad. An alert is always centred, so there is no `sourceView` to set and
/// `popoverPresentationController` is never touched.
///
/// Modelled on `CNNativeTabBarManager`: a singleton owning its own method
/// channel, wired up from `CupertinoNativePlugin.register`.
final class CNAlertManager: NSObject {

    static let shared = CNAlertManager()

    private var channel: FlutterMethodChannel?

    /// The result of the alert currently on screen. Nil whenever no alert is
    /// pending. Cleared by `send(_:)` so a button tap followed by a dismissal
    /// callback cannot deliver two results down one `FlutterResult` — the
    /// engine treats a double send as a hard error.
    private var pendingResult: FlutterResult?
    /// Counts `show` calls, so a call waiting for a leaving controller
    /// knows when a newer one replaced it.
    private var generation = 0

    /// The alert `pendingResult` belongs to, and the identity every send is
    /// checked against. A superseded alert is torn down rather than left on
    /// screen, but its handlers can still fire during that teardown — without
    /// an identity they would answer the next caller's call.
    private weak var presentedAlert: UIAlertController?

    func setup(messenger: FlutterBinaryMessenger) {
        let ch = FlutterMethodChannel(name: "cn_alert", binaryMessenger: messenger)
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
        generation &+= 1
        // Resolve the presenter *before* dismissing the alert below.
        // `dismiss(animated:)` does not clear `presentedViewController`
        // synchronously, so a walk performed afterwards can still land on the
        // alert being torn down and present the new one from it.
        let presenter = topPresenter(in: keyWindow(), skipping: presentedAlert)

        // An alert already on screen means the previous caller is still
        // waiting. Take it down first, so its actions can no longer fire, then
        // answer the call it belonged to.
        //
        // The replacement is presented from the dismissal completion, not here:
        // `dismiss(animated:)` does not clear `presenter.presentedViewController`
        // in this call stack, so presenting now would be refused by UIKit
        // ("already presenting") and dropped silently, leaving this call
        // unanswered forever.
        if let stale = presentedAlert {
            presentedAlert = nil
            send(nil)
            stale.dismiss(animated: false) { [weak self] in
                self?.present(config: config, on: presenter, result: result)
            }
            return
        }

        // No alert on screen, but `presentedAlert` is weak: a released
        // controller can leave `pendingResult` behind. Flush it.
        send(nil)
        present(config: config, on: presenter, result: result)
    }

    private func present(config: Config,
                         on presenter: UIViewController?,
                         result: @escaping FlutterResult,
                         waits: Int = 3) {
        guard let presenter else {
            result(FlutterError(code: "no_presenter",
                                message: "No view controller available to present on",
                                details: nil))
            return
        }

        // A controller still on its way out (a popover or a sheet closed a
        // moment ago) cannot be presented over yet: wait for it to go.
        if let leaving = presenter.presentedViewController, leaving.isBeingDismissed, waits > 0 {
            // Pending while it waits, so a newer `show` answers it.
            pendingResult = result
            let generation = self.generation
            Self.afterDismissal(of: leaving) { [weak self] in
                // A newer `show` took over (and answered this call).
                guard let self, self.generation == generation else { return }
                self.pendingResult = nil
                self.present(config: config, on: presenter, result: result, waits: waits - 1)
            }
            return
        }

        // UIKit drops a presentation onto a controller that is already showing
        // a modal, without telling anyone. Report it instead of hanging: the
        // Dart side collapses a `PlatformException` to a null result, so the
        // caller still gets an answer. Its own code, because "no presenter" and
        // "presenter busy" send a developer looking in different places.
        guard presenter.presentedViewController == nil else {
            result(FlutterError(code: "presenter_busy",
                                message: "The presenting view controller is already showing a modal",
                                details: nil))
            return
        }

        // Mirrors the guard in `CNAlert.show`. Every way out of a `.alert` runs
        // an action handler, so an alert with no action that accepts a tap can
        // never be answered and would block the app. Reachable here only when
        // the payload decodes to an empty or all-disabled action list.
        guard config.actions.contains(where: { $0.enabled }) else {
            result(FlutterError(code: "no_enabled_action",
                                message: "An alert needs at least one enabled action to be answerable",
                                details: nil))
            return
        }

        pendingResult = result

        let alert = CNStyledAlertController(title: config.title,
                                            message: config.message,
                                            preferredStyle: .alert)
        // The app's font and text direction (#144).
        alert.textStyle = config.textStyle
        alert.destructiveTitles = Set(config.actions.filter { $0.style == .destructive }.map { $0.label })
        alert.rtl = config.rtl
        CNLayoutDirection.apply(config.rtl, to: alert)
        // Follow the app's theme rather than the window's.
        if let isDark = config.isDark {
            alert.overrideUserInterfaceStyle = isDark ? .dark : .light
        }

        // UIKit requires every text field to be added before the controller is
        // presented, and before the actions read them back.
        for entry in config.textFields {
            alert.addTextField { field in
                field.placeholder = entry.placeholder
                field.text = entry.initialText
                field.isSecureTextEntry = entry.obscure
            }
        }

        // `UIAlertController` raises `NSInternalInconsistencyException` on a
        // second `.cancel` action, which is an Objective-C exception from inside
        // UIKit: neither Dart nor Swift can catch it, so the process dies. The
        // Dart side asserts against it, but asserts are stripped from release
        // builds and this payload is untrusted. Demote rather than drop, so a
        // removed button cannot leave the alert without a way out.
        var cancelUsed = false
        for (index, entry) in config.actions.enumerated() {
            var style = entry.style
            if style == .cancel {
                if cancelUsed { style = .default } else { cancelUsed = true }
            }
            let action = UIAlertAction(
                title: entry.label,
                style: style
            ) { [weak self, weak alert] _ in
                // Read the text while the controller is still alive —
                // `alert.textFields` is nil once it deallocates.
                let texts = alert?.textFields?.map { $0.text ?? "" } ?? []
                self?.send(["index": index, "textFields": texts], from: alert)
            }
            action.isEnabled = entry.enabled
            alert.addAction(action)
        }

        // `preferredAction` must reference an action already in
        // `alert.actions`, so this runs after the loop above.
        if let preferredIndex = config.actions.firstIndex(where: { $0.preferred }),
           preferredIndex < alert.actions.count {
            alert.preferredAction = alert.actions[preferredIndex]
        }

        // No `presentationController.delegate` here, deliberately. UIKit
        // asserts inside `-[_UIAlertControllerPresentationController
        // setDelegate:]` and aborts the process — a `UIAlertController`'s
        // presentation controller does not accept a delegate. Nothing is lost:
        // a `.alert` cannot be dismissed by tapping outside, so every way out
        // of it runs one of the action handlers above, and those are what
        // answer the pending call.
        presentedAlert = alert
        presenter.present(alert, animated: true)
        // UIKit refuses some presentations with only a log line; the call
        // must not wait for an alert that never appeared.
        if alert.presentingViewController == nil, presentedAlert === alert {
            // An error rather than null, so `throwOnFailure` can tell it
            // from a dismissal (#135).
            fail(FlutterError(code: "refused", message: "UIKit did not present the alert", details: nil))
        }
    }

    /// Runs [body] once [leaving], a controller on its way out, has gone.
    /// Presenting from or over it before then is refused by UIKit with only a
    /// log line (#127). Gives up after about two seconds, so a stuck
    /// transition still ends in an answer.
    static func afterDismissal(of leaving: UIViewController, tries: Int = 40,
                               _ body: @escaping () -> Void) {
        if let coordinator = leaving.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in
                DispatchQueue.main.async(execute: body)
            }
        } else if tries > 0, leaving.isBeingDismissed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if leaving.isBeingDismissed {
                    afterDismissal(of: leaving, tries: tries - 1, body)
                } else {
                    body()
                }
            }
        } else {
            DispatchQueue.main.async(execute: body)
        }
    }

    /// Delivers `value` to the waiting Dart call exactly once, whichever alert
    /// it came from. Only for sends that belong to no alert: superseding a
    /// pending call when a new `show` arrives.
    private func send(_ value: [String: Any]?) {
        guard let result = pendingResult else { return }
        pendingResult = nil
        presentedAlert = nil
        result(value)
    }

    /// Answers the waiting Dart call with [error]: the alert never appeared.
    private func fail(_ error: FlutterError) {
        guard let result = pendingResult else { return }
        pendingResult = nil
        presentedAlert = nil
        result(error)
    }

    /// Delivers `value` only while `alert` is still the alert the pending call
    /// belongs to. A handler from a superseded alert, or from one whose
    /// controller has already been released, is dropped rather than answering a
    /// call that is not its own.
    private func send(_ value: [String: Any]?, from alert: UIAlertController?) {
        guard let alert, alert === presentedAlert else { return }
        send(value)
    }

    // MARK: - View controller lookup

    // `keyWindow` is duplicated from `CNNativeTabBarManager`, where it is
    // private. Ten lines of copy beats changing a shipped file to share them.
    // `topPresenter` takes the window it should walk and the alert it must not
    // walk into.

    private func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = (scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene)
            ?? (scenes.first as? UIWindowScene)
        return windowScene?.windows.first(where: { $0.isKeyWindow }) ?? windowScene?.windows.first
    }

    /// Walks to the top of `window`'s presentation chain, stopping before
    /// `stale` so an alert being replaced is never used to present its
    /// replacement.
    private func topPresenter(in window: UIWindow?,
                              skipping stale: UIAlertController?) -> UIViewController? {
        guard var vc = window?.rootViewController else { return nil }
        // A controller being dismissed cannot present; stop below it.
        while let presented = vc.presentedViewController, presented !== stale,
              !presented.isBeingDismissed {
            vc = presented
        }
        return vc
    }

    // MARK: - Payload

    /// Mirrors `debugBuildAlertPayload` in `lib/components/alert.dart`.
    private struct Config {
        struct Action {
            let label: String
            let style: UIAlertAction.Style
            let enabled: Bool
            let preferred: Bool
        }

        struct TextField {
            let placeholder: String?
            let initialText: String?
            let obscure: Bool
        }

        let title: String?
        let message: String?
        let actions: [Action]
        let textFields: [TextField]
        let isDark: Bool?
        let textStyle: CNDialogTextStyle?
        let rtl: Bool?

        init(args: [String: Any]) {
            title = args["title"] as? String
            message = args["message"] as? String
            isDark = args["isDark"] as? Bool
            textStyle = CNDialogTextStyle(args["textStyle"])
            rtl = CNLayoutDirection.read(args)

            let rawActions = args["actions"] as? [[String: Any]] ?? []
            actions = rawActions.map { entry in
                Action(label: entry["label"] as? String ?? "",
                       style: Config.style(named: entry["style"] as? String),
                       enabled: entry["enabled"] as? Bool ?? true,
                       preferred: entry["preferred"] as? Bool ?? false)
            }

            let rawFields = args["textFields"] as? [[String: Any]] ?? []
            textFields = rawFields.map { entry in
                TextField(placeholder: entry["placeholder"] as? String,
                          initialText: entry["initialText"] as? String,
                          obscure: entry["obscure"] as? Bool ?? false)
            }
        }

        /// Maps the payload's style string onto `UIAlertAction.Style`. An
        /// unknown or missing value falls back to `.default` rather than
        /// dropping the action.
        private static func style(named name: String?) -> UIAlertAction.Style {
            switch name {
            case "cancel": return .cancel
            case "destructive": return .destructive
            default: return .default
            }
        }
    }
}
