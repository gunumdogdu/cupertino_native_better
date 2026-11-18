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
        var clearIconColor: UIColor? = nil
        var glassShadow = true
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
        var rtl: Bool? = nil
        var labelFont: CNSearchBarFont? = nil

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
            if let v = dict["clearIconColor"] as? NSNumber { clearIconColor = ImageUtils.colorFromARGB(v.intValue) }
            if let v = dict["glassShadow"] as? Bool { glassShadow = v }
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
            rtl = CNLayoutDirection.read(dict)
            labelFont = CNSearchBarFont(dict)
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
        model.layoutDirection = CNSearchBarModel.direction(rtl)
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
            clearIconColor: clearIconColor.map { Color(uiColor: $0) },
            glassShadow: glassShadow,
            showCancelButton: showCancelButton,
            cancelText: cancelText,
            autofocus: autofocus,
            searchIconName: searchIconName,
            clearIconName: clearIconName,
            searchIconSize: searchIconSize,
            clearIconSize: clearIconSize,
            clearButtonLabel: clearButtonLabel,
            labelFont: labelFont,
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
        // Flutter's direction (#173): an app that picks Arabic in Dart gets
        // a mirrored bar although the system language stays English.
        CNLayoutDirection.apply(rtl, to: container)

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
            case "setLayoutDirection":
                let rtl = CNLayoutDirection.read(call.arguments as? [String: Any])
                CNLayoutDirection.apply(rtl, to: self.container)
                if let direction = CNSearchBarModel.direction(rtl) { self.model.layoutDirection = direction }
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
                CNHaloMask.apply(self.container, arguments: call.arguments)
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
    /// Flutter's text direction (#173); nil leaves the system's.
    @Published var layoutDirection: LayoutDirection? = nil
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

    /// The SwiftUI direction for the `rtl` parameter.
    static func direction(_ rtl: Bool?) -> LayoutDirection? {
        guard let rtl else { return nil }
        return rtl ? .rightToLeft : .leftToRight
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
    /// The clear button's colour (`CNSearchBar.clearIcon.color`); defaults
    /// to [placeholderColor], then the system's secondary colour (#171).
    let clearIconColor: Color?
    /// Whether the iOS 26 glass keeps the shadow it draws outside the
    /// capsule (#170).
    let glassShadow: Bool
    let showCancelButton: Bool
    let cancelText: String
    let autofocus: Bool
    let searchIconName: String
    let clearIconName: String
    let clearButtonLabel: String
    /// `labelFontFamily` / `labelFontSize` / `labelFontWeight` (#173).
    let customFont: CNSearchBarFont?
    let keyboard: CNSearchKeyboard
    /// The icons' sizes at the default text size; they follow Dynamic Type
    /// like the field's text (#134).
    @ScaledMetric(relativeTo: .body) private var searchIconSize: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var clearIconSize: CGFloat = 16
    /// The text's size at the default text size; it follows Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var labelFontSize: CGFloat = 17

    let onSubmitted: (String) -> Void
    let onCancelTapped: () -> Void

    private var isExpanded: Bool { model.isExpanded }

    /// The text, placeholder and Cancel font: nil keeps the system's body
    /// font.
    private var labelFont: Font? {
        customFont?.font(size: labelFontSize)
    }
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
        clearIconColor: Color?,
        glassShadow: Bool,
        showCancelButton: Bool,
        cancelText: String,
        autofocus: Bool,
        searchIconName: String,
        clearIconName: String,
        searchIconSize: CGFloat?,
        clearIconSize: CGFloat?,
        clearButtonLabel: String,
        labelFont: CNSearchBarFont?,
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
        self.clearIconColor = clearIconColor
        self.glassShadow = glassShadow
        self.showCancelButton = showCancelButton
        self.cancelText = cancelText
        self.autofocus = autofocus
        self.searchIconName = searchIconName
        self.clearIconName = clearIconName
        self._searchIconSize = ScaledMetric(wrappedValue: searchIconSize ?? 16, relativeTo: .body)
        self._clearIconSize = ScaledMetric(wrappedValue: clearIconSize ?? 16, relativeTo: .body)
        self.clearButtonLabel = clearButtonLabel
        self.customFont = labelFont
        self._labelFontSize = ScaledMetric(wrappedValue: labelFont?.size ?? 17, relativeTo: .body)
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
                    // Text field. The placeholder is drawn by SwiftUI behind
                    // it: the field's own placeholder is always the system
                    // grey (#171) and follows the system's direction, not
                    // Flutter's (#173). VoiceOver reads it as the label.
                    ZStack(alignment: .leading) {
                        if model.searchText.isEmpty {
                            Text(placeholder)
                                .font(labelFont)
                                .foregroundColor(placeholderColor ?? Color(uiColor: .placeholderText))
                                .lineLimit(1)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                        TextField("", text: $model.searchText)
                        .accessibilityLabel(Text(placeholder))
                        .font(labelFont)
                        .foregroundColor(textColor ?? .primary)
                        .focused($isFocused)
                        .submitLabel(.search)
                        .textInputAutocapitalization(keyboard.capitalization)
                        .autocorrectionDisabled(!keyboard.autocorrect)
                        .keyboardType(keyboard.type)
                        .onSubmit {
                            onSubmitted(model.searchText)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))

                    // Clear button
                    if !model.searchText.isEmpty {
                        Button(action: {
                            model.setText("", notify: true)
                        }) {
                            Image(systemName: clearIconName)
                                .font(.system(size: clearIconSize))
                                .foregroundColor(clearIconColor ?? placeholderColor ?? .secondary)
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
            .modifier(CNSearchBarBackground(
                backgroundColor: backgroundColor,
                glassShadow: glassShadow
            ))
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
                        .font(labelFont)
                        .foregroundColor(tint)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .modifier(CNSearchBarDirection(direction: model.layoutDirection))
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
}

// MARK: - Font

/// `CNSearchBar.labelFontFamily`, `labelFontSize` and `labelFontWeight`
/// (#173). A family declared in pubspec.yaml is found by `CNFontResolver`.
struct CNSearchBarFont {
    let family: String?
    let size: CGFloat?
    let weight: UIFont.Weight?

    init?(_ dict: [String: Any]) {
        family = (dict["labelFontFamily"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        size = (dict["labelFontSize"] as? NSNumber).flatMap { $0.doubleValue > 0 ? CGFloat($0.doubleValue) : nil }
        weight = CNFontResolver.weight(fromFlutterValue: (dict["labelFontWeight"] as? NSNumber)?.intValue)
        if family == nil && size == nil && weight == nil { return nil }
    }

    /// The font at [size], already scaled for Dynamic Type.
    func font(size: CGFloat) -> Font {
        if let family, let font = CNFontResolver.font(family: family, size: size, weight: weight) {
            return Font(font)
        }
        return Font(UIFont.systemFont(ofSize: size, weight: weight ?? .regular))
    }
}

// MARK: - Direction

/// Lays the bar out in Flutter's direction when it sent one (#173): the
/// magnifying glass, text, clear button and Cancel mirror for right to left.
private struct CNSearchBarDirection: ViewModifier {
    let direction: LayoutDirection?

    func body(content: Content) -> some View {
        if let direction {
            content.environment(\.layoutDirection, direction)
        } else {
            content
        }
    }
}

// MARK: - Background

/// The bar's capsule: Liquid Glass on iOS 26+, a fill before.
///
/// iOS 26 glass draws a soft shadow outside its shape, which is what lets
/// a light capsule stand out on a light page. Clipping the bar to the
/// capsule cut it off (#170), so the glass is applied to the bar itself and
/// only clipped when [glassShadow] is false.
private struct CNSearchBarBackground: ViewModifier {
    let backgroundColor: Color?
    let glassShadow: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if glassShadow {
                content.glassEffect(.regular, in: .capsule)
            } else {
                content
                    .background(Color.clear.glassEffect(.regular, in: .capsule))
                    .clipShape(Capsule())
            }
        } else {
            content
                .background(backgroundColor ?? Color(.systemGray6))
                .clipShape(Capsule())
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
