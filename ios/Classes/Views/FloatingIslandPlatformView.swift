import Flutter
import UIKit
import SwiftUI
import Combine

class FloatingIslandPlatformView: NSObject, FlutterPlatformView {
    private let channel: FlutterMethodChannel
    private let hostingController: UIViewController
    private let container: UIView
    private var viewModel: FloatingIslandViewModel

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(
            name: "CNFloatingIsland_\(viewId)",
            binaryMessenger: messenger
        )
        self.container = UIView(frame: frame)
        self.viewModel = FloatingIslandViewModel()

        // Parse arguments
        var isExpanded = false
        var position = "top"
        var collapsedHeight: CGFloat = 44
        var collapsedWidth: CGFloat? = nil
        var expandedHeight: CGFloat? = nil
        var expandedWidth: CGFloat? = nil
        var cornerRadius: CGFloat = 22
        var tint: UIColor? = nil
        var springDamping: CGFloat = 0.8
        var springResponse: CGFloat = 0.4
        var isDark = false

        if let dict = args as? [String: Any] {
            if let v = dict["isExpanded"] as? Bool { isExpanded = v }
            if let v = dict["position"] as? String { position = v }
            if let v = dict["collapsedHeight"] as? NSNumber { collapsedHeight = CGFloat(truncating: v) }
            if let v = dict["collapsedWidth"] as? NSNumber { collapsedWidth = CGFloat(truncating: v) }
            if let v = dict["expandedHeight"] as? NSNumber { expandedHeight = CGFloat(truncating: v) }
            if let v = dict["expandedWidth"] as? NSNumber { expandedWidth = CGFloat(truncating: v) }
            if let v = dict["cornerRadius"] as? NSNumber { cornerRadius = CGFloat(truncating: v) }
            if let v = dict["tint"] as? NSNumber { tint = ImageUtils.colorFromARGB(v.intValue) }
            if let v = dict["springDamping"] as? NSNumber { springDamping = CGFloat(truncating: v) }
            if let v = dict["springResponse"] as? NSNumber { springResponse = CGFloat(truncating: v) }
            if let v = dict["isDark"] as? Bool { isDark = v }
        }

        viewModel.isExpanded = isExpanded
        viewModel.collapsedHeight = collapsedHeight
        viewModel.collapsedWidth = collapsedWidth ?? 160
        viewModel.expandedHeight = expandedHeight ?? 200
        viewModel.expandedWidth = expandedWidth
        viewModel.cornerRadius = cornerRadius
        viewModel.tint = tint.map { Color(uiColor: $0) }
        viewModel.springDamping = springDamping
        viewModel.springResponse = springResponse
        viewModel.isTop = position == "top"

        // Create SwiftUI view
        let floatingIslandView = FloatingIslandSwiftUI(viewModel: viewModel)
        self.hostingController = UIHostingController(rootView: floatingIslandView)

        super.init()

        container.backgroundColor = .clear
        container.isOpaque = false
        // Issue #29: clip + clear shadow sources so iOS 26 Liquid Glass effects
        // do not render a halo outside the platform-view bounds during route
        // transitions (same containment pattern as Issue #2).
        container.clipsToBounds = true
        container.layer.backgroundColor = UIColor.clear.cgColor
        container.layer.shadowOpacity = 0
        if #available(iOS 13.0, *) {
            container.overrideUserInterfaceStyle = isDark ? .dark : .light
        }

        // Transparent hosting view (Issue #29: prevent white placeholder during route transitions)
        hostingController.view.backgroundColor = .clear
        hostingController.view.isOpaque = false
        hostingController.view.layer.backgroundColor = UIColor.clear.cgColor
        hostingController.view.layer.shadowOpacity = 0
        hostingController.view.clipsToBounds = true
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        setupMethodChannel()
        setupCallbacks()
    }

    private func setupMethodChannel() {
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { result(nil); return }

            switch call.method {
            case "expand":
                let animated = (call.arguments as? [String: Any])?["animated"] as? Bool ?? true
                if animated {
                    withAnimation(.spring(response: self.viewModel.springResponse, dampingFraction: self.viewModel.springDamping)) {
                        self.viewModel.isExpanded = true
                    }
                } else {
                    self.viewModel.isExpanded = true
                }
                result(nil)

            case "collapse":
                let animated = (call.arguments as? [String: Any])?["animated"] as? Bool ?? true
                if animated {
                    withAnimation(.spring(response: self.viewModel.springResponse, dampingFraction: self.viewModel.springDamping)) {
                        self.viewModel.isExpanded = false
                    }
                } else {
                    self.viewModel.isExpanded = false
                }
                result(nil)

            case "setBrightness":
                if let args = call.arguments as? [String: Any],
                   let isDark = (args["isDark"] as? NSNumber)?.boolValue {
                    if #available(iOS 13.0, *) {
                        self.container.overrideUserInterfaceStyle = isDark ? .dark : .light
                    }
                    result(nil)
                } else {
                    result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil))
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func setupCallbacks() {
        viewModel.onExpandedChanged = { [weak self] expanded in
            self?.channel.invokeMethod(expanded ? "expanded" : "collapsed", arguments: nil)
        }
        viewModel.onTapped = { [weak self] in
            self?.channel.invokeMethod("tapped", arguments: nil)
        }
    }

    func view() -> UIView {
        return container
    }
}

// MARK: - View Model

class FloatingIslandViewModel: ObservableObject {
    @Published var isExpanded: Bool = false {
        didSet {
            if oldValue != isExpanded {
                onExpandedChanged?(isExpanded)
            }
        }
    }
    @Published var collapsedHeight: CGFloat = 44
    @Published var collapsedWidth: CGFloat = 160
    @Published var expandedHeight: CGFloat = 200
    @Published var expandedWidth: CGFloat? = nil
    @Published var cornerRadius: CGFloat = 22
    @Published var tint: Color? = nil
    @Published var springDamping: CGFloat = 0.8
    @Published var springResponse: CGFloat = 0.4
    @Published var isTop: Bool = true

    var onExpandedChanged: ((Bool) -> Void)?
    var onTapped: (() -> Void)?
}

// MARK: - SwiftUI View

struct FloatingIslandSwiftUI: View {
    @ObservedObject var viewModel: FloatingIslandViewModel
    @Namespace private var animation

    /// Observe transition state to disable glass effect during navigation
    @ObservedObject private var transitionObserver: CNTransitionObserverWrapper = CNTransitionObserverWrapper()

    var body: some View {
        GeometryReader { geometry in
            let maxWidth = geometry.size.width
            let expandedWidth = viewModel.expandedWidth ?? (maxWidth - 32)
            let currentWidth = viewModel.isExpanded ? expandedWidth : viewModel.collapsedWidth
            let currentHeight = viewModel.isExpanded ? viewModel.expandedHeight : viewModel.collapsedHeight
            let currentRadius = viewModel.isExpanded ? 24 : viewModel.cornerRadius

            VStack {
                if !viewModel.isTop {
                    Spacer()
                }

                islandContent(width: currentWidth, height: currentHeight, cornerRadius: currentRadius)
                    .frame(width: currentWidth, height: currentHeight)
                    .matchedGeometryEffect(id: "island", in: animation)

                if viewModel.isTop {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func islandContent(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            // Native glass effect on iOS 26+
            // Conditionally apply glass effect based on transition state
            if transitionObserver.isTransitioning {
                // During transitions, use a simple background instead of glass
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(UIColor.systemBackground).opacity(0.8))
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .onTapGesture {
                        withAnimation(.spring(response: viewModel.springResponse, dampingFraction: viewModel.springDamping)) {
                            viewModel.onTapped?()
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .onTapGesture {
                        withAnimation(.spring(response: viewModel.springResponse, dampingFraction: viewModel.springDamping)) {
                            viewModel.onTapped?()
                        }
                    }
            }
        } else {
            // Fallback for older iOS
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(fallbackBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                .onTapGesture {
                    withAnimation(.spring(response: viewModel.springResponse, dampingFraction: viewModel.springDamping)) {
                        viewModel.onTapped?()
                    }
                }
        }
    }

    private var fallbackBackground: some ShapeStyle {
        if let tint = viewModel.tint {
            return AnyShapeStyle(tint.opacity(0.3))
        }
        return AnyShapeStyle(Color(.systemGray5).opacity(0.9))
    }
}

// Helper for type erasure
struct AnyShapeStyle: ShapeStyle {
    private let _makeBody: (inout CGRect, inout Bool) -> AnyView

    init<S: ShapeStyle>(_ style: S) {
        _makeBody = { _, _ in AnyView(Rectangle().fill(style)) }
    }

    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        return self
    }
}

// MARK: - Transition Observer Wrapper

/// Wrapper for CNTransitionObserver to handle iOS version availability
class CNTransitionObserverWrapper: ObservableObject {
    @Published var isTransitioning: Bool = false
    private var cancellable: Any?

    init() {
        if #available(iOS 13.0, *) {
            // Subscribe to the shared CNTransitionObserver
            cancellable = CNTransitionObserver.shared.$isTransitioning
                .receive(on: RunLoop.main)
                .sink { [weak self] value in
                    self?.isTransitioning = value
                }
        }
    }

    deinit {
        if #available(iOS 13.0, *) {
            if let cancellable = cancellable as? AnyCancellable {
                cancellable.cancel()
            }
        }
    }
}
