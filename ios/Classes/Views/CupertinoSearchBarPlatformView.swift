import Flutter
import UIKit
import SwiftUI

class CupertinoSearchBarPlatformView: NSObject, FlutterPlatformView {
    private let channel: FlutterMethodChannel
    private let hostingController: UIViewController
    private let container: UIView

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(
            name: "CNSearchBar_\(viewId)",
            binaryMessenger: messenger
        )
        self.container = UIView(frame: frame)

        // Capture channel for use in closures before super.init()
        let channelRef = self.channel

        // Parse arguments
        var placeholder = "Search"
        var expandable = true
        var initiallyExpanded = false
        var collapsedWidth: CGFloat = 44
        var expandedHeight: CGFloat = 36
        var tint: UIColor? = nil
        var backgroundColor: UIColor? = nil
        var textColor: UIColor? = nil
        var placeholderColor: UIColor? = nil
        var showCancelButton = true
        var cancelText = "Cancel"
        var autofocus = false
        var searchIconName = "magnifyingglass"
        var clearIconName = "xmark.circle.fill"
        var isDark = false

        if let dict = args as? [String: Any] {
            if let v = dict["placeholder"] as? String { placeholder = v }
            if let v = dict["expandable"] as? Bool { expandable = v }
            if let v = dict["initiallyExpanded"] as? Bool { initiallyExpanded = v }
            if let v = dict["collapsedWidth"] as? NSNumber { collapsedWidth = CGFloat(truncating: v) }
            if let v = dict["expandedHeight"] as? NSNumber { expandedHeight = CGFloat(truncating: v) }
            if let v = dict["tint"] as? NSNumber { tint = ImageUtils.colorFromARGB(v.intValue) }
            if let v = dict["backgroundColor"] as? NSNumber { backgroundColor = ImageUtils.colorFromARGB(v.intValue) }
            if let v = dict["textColor"] as? NSNumber { textColor = ImageUtils.colorFromARGB(v.intValue) }
            if let v = dict["placeholderColor"] as? NSNumber { placeholderColor = ImageUtils.colorFromARGB(v.intValue) }
            if let v = dict["showCancelButton"] as? Bool { showCancelButton = v }
            if let v = dict["cancelText"] as? String { cancelText = v }
            if let v = dict["autofocus"] as? Bool { autofocus = v }
            if let v = dict["searchIconName"] as? String { searchIconName = v }
            if let v = dict["clearIconName"] as? String { clearIconName = v }
            if let v = dict["isDark"] as? Bool { isDark = v }
        }

        // Create SwiftUI view
        let searchBarView = CNSearchBarSwiftUI(
            placeholder: placeholder,
            expandable: expandable,
            initiallyExpanded: initiallyExpanded,
            collapsedWidth: collapsedWidth,
            expandedHeight: expandedHeight,
            tint: tint.map { Color(uiColor: $0) } ?? .blue,
            backgroundColor: backgroundColor.map { Color(uiColor: $0) },
            textColor: textColor.map { Color(uiColor: $0) },
            placeholderColor: placeholderColor.map { Color(uiColor: $0) },
            showCancelButton: showCancelButton,
            cancelText: cancelText,
            autofocus: autofocus,
            searchIconName: searchIconName,
            clearIconName: clearIconName,
            onTextChanged: { text in
                channelRef.invokeMethod("textChanged", arguments: ["text": text])
            },
            onSubmitted: { text in
                channelRef.invokeMethod("submitted", arguments: ["text": text])
            },
            onExpandStateChanged: { expanded in
                channelRef.invokeMethod(expanded ? "expanded" : "collapsed", arguments: nil)
            },
            onCancelTapped: {
                channelRef.invokeMethod("cancelTapped", arguments: nil)
            }
        )

        self.hostingController = UIHostingController(rootView: searchBarView)

        super.init()

        container.backgroundColor = .clear
        if #available(iOS 13.0, *) {
            container.overrideUserInterfaceStyle = isDark ? .dark : .light
        }

        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        setupMethodChannel()
    }

    private func setupMethodChannel() {
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { result(nil); return }

            switch call.method {
            case "expand":
                // Handled by SwiftUI state
                result(nil)
            case "collapse":
                // Handled by SwiftUI state
                result(nil)
            case "clear":
                // Handled by SwiftUI state
                result(nil)
            case "setText":
                // Handled by SwiftUI state
                result(nil)
            case "focus":
                result(nil)
            case "unfocus":
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
            case "setTransitioning":
                let active = ((call.arguments as? [String: Any])?["active"] as? NSNumber)?.boolValue ?? false
                self.applyTransitionContainment(active)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func view() -> UIView {
        return container
    }

    /// Toggle Issue #29 halo containment (container + hosting view).
    private func applyTransitionContainment(_ active: Bool) {
        if active {
            container.isOpaque = false
            container.clipsToBounds = true
            container.layer.backgroundColor = UIColor.clear.cgColor
            container.layer.shadowOpacity = 0
            hostingController.view.clipsToBounds = true
            hostingController.view.isOpaque = false
            hostingController.view.layer.backgroundColor = UIColor.clear.cgColor
            hostingController.view.layer.shadowOpacity = 0
        } else {
            container.clipsToBounds = false
            hostingController.view.clipsToBounds = false
        }
    }
}

// MARK: - SwiftUI Search Bar View

struct CNSearchBarSwiftUI: View {
    let placeholder: String
    let expandable: Bool
    let initiallyExpanded: Bool
    let collapsedWidth: CGFloat
    let expandedHeight: CGFloat
    let tint: Color
    let backgroundColor: Color?
    let textColor: Color?
    let placeholderColor: Color?
    let showCancelButton: Bool
    let cancelText: String
    let autofocus: Bool
    let searchIconName: String
    let clearIconName: String

    let onTextChanged: (String) -> Void
    let onSubmitted: (String) -> Void
    let onExpandStateChanged: (Bool) -> Void
    let onCancelTapped: () -> Void

    @State private var isExpanded: Bool
    @State private var searchText: String = ""
    @FocusState private var isFocused: Bool
    @Namespace private var animation

    init(
        placeholder: String,
        expandable: Bool,
        initiallyExpanded: Bool,
        collapsedWidth: CGFloat,
        expandedHeight: CGFloat,
        tint: Color,
        backgroundColor: Color?,
        textColor: Color?,
        placeholderColor: Color?,
        showCancelButton: Bool,
        cancelText: String,
        autofocus: Bool,
        searchIconName: String,
        clearIconName: String,
        onTextChanged: @escaping (String) -> Void,
        onSubmitted: @escaping (String) -> Void,
        onExpandStateChanged: @escaping (Bool) -> Void,
        onCancelTapped: @escaping () -> Void
    ) {
        self.placeholder = placeholder
        self.expandable = expandable
        self.initiallyExpanded = initiallyExpanded
        self.collapsedWidth = collapsedWidth
        self.expandedHeight = expandedHeight
        self.tint = tint
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.placeholderColor = placeholderColor
        self.showCancelButton = showCancelButton
        self.cancelText = cancelText
        self.autofocus = autofocus
        self.searchIconName = searchIconName
        self.clearIconName = clearIconName
        self.onTextChanged = onTextChanged
        self.onSubmitted = onSubmitted
        self.onExpandStateChanged = onExpandStateChanged
        self.onCancelTapped = onCancelTapped
        self._isExpanded = State(initialValue: initiallyExpanded || !expandable)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Search bar container
            HStack(spacing: 8) {
                // Search icon
                Image(systemName: searchIconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(tint)
                    .matchedGeometryEffect(id: "searchIcon", in: animation)

                if isExpanded {
                    // Text field
                    TextField(placeholder, text: $searchText)
                        .foregroundColor(textColor ?? .primary)
                        .focused($isFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            onSubmitted(searchText)
                        }
                        .onChange(of: searchText) { newValue in
                            onTextChanged(newValue)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))

                    // Clear button
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            onTextChanged("")
                        }) {
                            Image(systemName: clearIconName)
                                .font(.system(size: 16))
                                .foregroundColor(placeholderColor ?? .secondary)
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: expandedHeight)
            .frame(maxWidth: isExpanded ? .infinity : collapsedWidth)
            .background(glassBackground)
            .clipShape(Capsule())
            .contentShape(Capsule())
            .onTapGesture {
                if !isExpanded && expandable {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded = true
                        onExpandStateChanged(true)
                    }
                    if autofocus {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isFocused = true
                        }
                    }
                }
            }

            // Cancel button
            if showCancelButton && isExpanded {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded = false
                        searchText = ""
                        isFocused = false
                        onExpandStateChanged(false)
                        onCancelTapped()
                    }
                }) {
                    Text(cancelText)
                        .foregroundColor(tint)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
        .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
    }

    @ViewBuilder
    private var glassBackground: some View {
        if #available(iOS 26.0, *) {
            // Use native glass effect on iOS 26+
            Color.clear
                .glassEffect(.regular, in: .capsule)
        } else {
            // Fallback to blur effect
            if let bg = backgroundColor {
                bg
            } else {
                Color(.systemGray6)
            }
        }
    }
}
