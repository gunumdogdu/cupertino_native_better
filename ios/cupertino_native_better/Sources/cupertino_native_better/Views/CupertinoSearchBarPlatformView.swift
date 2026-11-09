import Flutter
import UIKit
import SwiftUI

class CupertinoSearchBarPlatformView: NSObject, FlutterPlatformView {
    private let channel: FlutterMethodChannel
    private let hostingController: UIViewController
    private let container: UIView
    /// State shared with the SwiftUI view, so the controller's methods
    /// (`setText`, `clear`, `focus`, `unfocus`, `expand`, `collapse`) reach
    /// it (#126).
    private let model: CNSearchBarModel

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
        var expanded: Bool? = nil
        var text = ""
        var keyboard = CNSearchKeyboard()
        var searchIconSize: CGFloat? = nil
        var clearIconSize: CGFloat? = nil
        var clearButtonLabel = "Clear"

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
            if let v = dict["expanded"] as? Bool { expanded = v }
            if let v = dict["text"] as? String { text = v }
            keyboard = CNSearchKeyboard(dict)
            if let v = dict["searchIconSize"] as? NSNumber, v.doubleValue > 0 { searchIconSize = CGFloat(v.doubleValue) }
            if let v = dict["clearIconSize"] as? NSNumber, v.doubleValue > 0 { clearIconSize = CGFloat(v.doubleValue) }
            if let v = dict["clearButtonLabel"] as? String, !v.isEmpty { clearButtonLabel = v }
        }

        let model = CNSearchBarModel(
            // A view created again (after a modal) opens as the bar was.
            expanded: (expanded ?? initiallyExpanded) || !expandable,
            expandable: expandable,
            autofocus: autofocus,
            onTextChanged: { text in
                channelRef.invokeMethod("textChanged", arguments: ["text": text])
            },
            onExpandStateChanged: { expanded in
                channelRef.invokeMethod(expanded ? "expanded" : "collapsed", arguments: nil)
            }
        )
        self.model = model
        // ...and with its text, which Flutter already has (#134).
        if !text.isEmpty { model.setText(text, notify: false) }

        // Create SwiftUI view
        let searchBarView = CNSearchBarSwiftUI(
            model: model,
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
            searchIconSize: searchIconSize,
            clearIconSize: clearIconSize,
            clearButtonLabel: clearButtonLabel,
            keyboard: keyboard,
            onSubmitted: { text in
                channelRef.invokeMethod("submitted", arguments: ["text": text])
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

            let args = call.arguments as? [String: Any]
            let animated = (args?["animated"] as? NSNumber)?.boolValue ?? true
            switch call.method {
            case "expand":
                self.model.setExpanded(true, animated: animated)
                if self.model.autofocus { self.model.requestFocus(true) }
                result(nil)
            case "collapse":
                self.model.setExpanded(false, animated: animated)
                result(nil)
            case "clear":
                self.model.setText("", notify: true)
                result(nil)
            case "setText":
                self.model.setText((args?["text"] as? String) ?? "", notify: true)
                result(nil)
            case "textChanged":
                // Flutter's own copy of the text changed (it clears it when it
                // collapses the bar): take it over without reporting it back.
                self.model.setText((args?["text"] as? String) ?? "", notify: false)
                result(nil)
            case "focus":
                if !self.model.isExpanded { self.model.setExpanded(true, animated: true) }
                self.model.requestFocus(true)
                result(nil)
            case "unfocus":
                self.model.requestFocus(false)
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
            case "setInteractive":
                if let args = call.arguments as? [String: Any],
                   let interactive = (args["interactive"] as? NSNumber)?.boolValue {
                    NSLog("[CN SearchBar] setInteractive=\(interactive)")
                    self._cnSetInteractiveRecursive(self.container, interactive)
                    self._cnSetInteractiveRecursive(self.hostingController.view, interactive)
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func view() -> UIView {
        return container
    }

    private func _cnSetInteractiveRecursive(_ view: UIView?, _ interactive: Bool) {
        guard let view = view else { return }
        view.isUserInteractionEnabled = interactive
        for sub in view.subviews { _cnSetInteractiveRecursive(sub, interactive) }
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

// MARK: - Shared state

/// The search bar's state, owned by the platform view so the controller's
/// method calls can change it, and observed by [CNSearchBarSwiftUI].
final class CNSearchBarModel: ObservableObject {
    @Published var isExpanded: Bool
    @Published var searchText: String = ""
    /// Bumped on each `focus`/`unfocus` call; [wantsFocus] says which.
    @Published var focusToken: Int = 0
    private(set) var wantsFocus = false

    let expandable: Bool
    let autofocus: Bool
    private let onTextChanged: (String) -> Void
    private let onExpandStateChanged: (Bool) -> Void
    /// The text Flutter already knows, so a change is reported once and a
    /// change that came from Flutter is not echoed back.
    private var reportedText = ""

    init(
        expanded: Bool,
        expandable: Bool,
        autofocus: Bool,
        onTextChanged: @escaping (String) -> Void,
        onExpandStateChanged: @escaping (Bool) -> Void
    ) {
        self.isExpanded = expanded
        self.expandable = expandable
        self.autofocus = autofocus
        self.onTextChanged = onTextChanged
        self.onExpandStateChanged = onExpandStateChanged
    }

    /// Reports [text] to Flutter unless Flutter already has it.
    func report(_ text: String) {
        guard text != reportedText else { return }
        reportedText = text
        onTextChanged(text)
    }

    func setText(_ text: String, notify: Bool) {
        if !notify { reportedText = text }
        searchText = text
        if notify { report(text) }
    }

    func requestFocus(_ focused: Bool) {
        wantsFocus = focused
        focusToken &+= 1
    }

    /// Opens or closes the bar. Closing also clears the text and ends
    /// editing, as the Cancel button does. A bar that is not [expandable]
    /// stays open.
    func setExpanded(_ expanded: Bool, animated: Bool) {
        guard expanded != isExpanded else { return }
        if !expanded && !expandable { return }
        let apply = {
            self.isExpanded = expanded
            if !expanded {
                self.wantsFocus = false
                self.focusToken &+= 1
                self.setText("", notify: true)
            }
        }
        if animated {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8), apply)
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, apply)
        }
        onExpandStateChanged(expanded)
    }
}

// MARK: - SwiftUI Search Bar View

struct CNSearchBarSwiftUI: View {
    @ObservedObject var model: CNSearchBarModel
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
    let clearButtonLabel: String
    let keyboard: CNSearchKeyboard
    /// The icons' sizes at the default text size; they follow Dynamic Type
    /// like the field's text (#134).
    @ScaledMetric(relativeTo: .body) private var searchIconSize: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var clearIconSize: CGFloat = 16

    let onSubmitted: (String) -> Void
    let onCancelTapped: () -> Void

    private var isExpanded: Bool { model.isExpanded }
    @FocusState private var isFocused: Bool
    @Namespace private var animation

    init(
        model: CNSearchBarModel,
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
        searchIconSize: CGFloat?,
        clearIconSize: CGFloat?,
        clearButtonLabel: String,
        keyboard: CNSearchKeyboard,
        onSubmitted: @escaping (String) -> Void,
        onCancelTapped: @escaping () -> Void
    ) {
        self.model = model
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
        self._searchIconSize = ScaledMetric(wrappedValue: searchIconSize ?? 16, relativeTo: .body)
        self._clearIconSize = ScaledMetric(wrappedValue: clearIconSize ?? 16, relativeTo: .body)
        self.clearButtonLabel = clearButtonLabel
        self.keyboard = keyboard
        self.onSubmitted = onSubmitted
        self.onCancelTapped = onCancelTapped
    }

    var body: some View {
        HStack(spacing: 8) {
            // Search bar container
            HStack(spacing: 8) {
                // Search icon
                Image(systemName: searchIconName)
                    .font(.system(size: searchIconSize, weight: .medium))
                    .foregroundColor(tint)
                    .matchedGeometryEffect(id: "searchIcon", in: animation)

                if isExpanded {
                    // Text field
                    TextField(placeholder, text: $model.searchText)
                        .foregroundColor(textColor ?? .primary)
                        .focused($isFocused)
                        .submitLabel(.search)
                        .textInputAutocapitalization(keyboard.capitalization)
                        .autocorrectionDisabled(!keyboard.autocorrect)
                        .keyboardType(keyboard.type)
                        .onSubmit {
                            onSubmitted(model.searchText)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))

                    // Clear button
                    if !model.searchText.isEmpty {
                        Button(action: {
                            model.setText("", notify: true)
                        }) {
                            Image(systemName: clearIconName)
                                .font(.system(size: clearIconSize))
                                .foregroundColor(placeholderColor ?? .secondary)
                        }
                        // Without a label VoiceOver reads the symbol's name,
                        // "Close" (#134).
                        .accessibilityLabel(Text(clearButtonLabel))
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
                    model.setExpanded(true, animated: true)
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
                    isFocused = false
                    if expandable {
                        model.setExpanded(false, animated: true)
                    } else {
                        // A bar that stays open still ends the search, as a
                        // search controller's Cancel does (#134).
                        model.setText("", notify: true)
                    }
                    onCancelTapped()
                }) {
                    Text(cancelText)
                        .foregroundColor(tint)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
        .animation(.easeInOut(duration: 0.2), value: model.searchText.isEmpty)
        // Typing and every other change of the text reach Flutter once.
        .onChange(of: model.searchText) { newValue in
            model.report(newValue)
        }
        .onChange(of: model.focusToken) { _ in
            if model.wantsFocus {
                // The field may only just have been inserted by an expand.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if model.wantsFocus && model.isExpanded { isFocused = true }
                }
            } else {
                isFocused = false
            }
        }
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

// MARK: - Keyboard

/// `CNSearchBar.textCapitalization`, `autocorrect` and `keyboardType`, mapped
/// as Flutter's own text fields map them to UIKit.
struct CNSearchKeyboard {
    var capitalization: TextInputAutocapitalization = .never
    var autocorrect = true
    var type: UIKeyboardType = .default

    init() {}

    init(_ dict: [String: Any]) {
        switch dict["textCapitalization"] as? String {
        case "words": capitalization = .words
        case "sentences": capitalization = .sentences
        case "characters": capitalization = .characters
        default: capitalization = .never
        }
        autocorrect = (dict["autocorrect"] as? Bool) ?? true
        let decimal = (dict["keyboardDecimal"] as? Bool) ?? false
        let signed = (dict["keyboardSigned"] as? Bool) ?? false
        switch dict["keyboardType"] as? String {
        case "TextInputType.number":
            type = signed ? .numbersAndPunctuation : (decimal ? .decimalPad : .numberPad)
        case "TextInputType.phone": type = .phonePad
        case "TextInputType.datetime": type = .numbersAndPunctuation
        case "TextInputType.emailAddress": type = .emailAddress
        case "TextInputType.url": type = .URL
        case "TextInputType.visiblePassword": type = .asciiCapable
        case "TextInputType.name": type = .namePhonePad
        case "TextInputType.twitter": type = .twitter
        case "TextInputType.webSearch": type = .webSearch
        default: type = .default
        }
    }
}
