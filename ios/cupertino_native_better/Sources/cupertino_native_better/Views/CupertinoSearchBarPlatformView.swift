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
        var clearButtonColor: UIColor? = nil
        var shadow = true
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
            if let v = dict["clearButtonColor"] as? NSNumber { clearButtonColor = ImageUtils.colorFromARGB(v.intValue) }
            if let v = dict["shadow"] as? Bool { shadow = v }
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
        model.labelFont = labelFont
        model.placeholder = placeholder
        model.cancelText = cancelText
        // ...and with its text, which Flutter already has (#134).
        if !text.isEmpty { model.setText(text, notify: false) }

        // Create SwiftUI view
        let searchBarView = CNSearchBarSwiftUI(
            model: model,
            expandable: expandable,
            initiallyExpanded: initiallyExpanded,
            collapsedWidth: collapsedWidth,
            expandedHeight: expandedHeight,
            tint: tint.map { Color(uiColor: $0) } ?? .blue,
            backgroundColor: backgroundColor.map { Color(uiColor: $0) },
            textColor: textColor.map { Color(uiColor: $0) },
            placeholderColor: placeholderColor.map { Color(uiColor: $0) },
            clearButtonColor: clearButtonColor.map { Color(uiColor: $0) },
            shadow: shadow,
            showCancelButton: showCancelButton,
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

        // Don't propagate the window's safe area into the SwiftUI bar (#184).
        // While a bottom sheet slides up over the home indicator, or slides
        // down with the keyboard still up, the platform view is laid out
        // overlapping a safe-area region. UIHostingController then insets the
        // fixed-height SwiftUI content by that overlap, so the field is drawn
        // a few points off inside its own frame, by an amount that depends on
        // where the sheet was at that moment, until the sheet closes. Flutter
        // already places the bar, so the host must use its full frame. Same
        // fix as LiquidGlassContainerView, CNTabRailView and the gauge.
        if #available(iOS 16.4, *) {
            let host = UIHostingController(rootView: searchBarView)
            host.safeAreaRegions = []
            self.hostingController = host
        } else {
            self.hostingController = UIHostingController(
                rootView: searchBarView.ignoresSafeArea()
            )
        }

        super.init()

        container.backgroundColor = .clear
        if #available(iOS 13.0, *) {
            container.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
        // Flutter's direction (#173): an app that picks Arabic in Dart gets a
        // mirrored bar although the system language stays English.
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
                let rtl = CNLayoutDirection.read(args)
                CNLayoutDirection.apply(rtl, to: self.container)
                if let direction = CNSearchBarModel.direction(rtl) {
                    self.model.layoutDirection = direction
                }
                result(nil)
            case "setLabelFont":
                self.model.labelFont = CNSearchBarFont(args)
                result(nil)
            case "setLabels":
                // A language switch in Dart (#173).
                if let v = args?["placeholder"] as? String { self.model.placeholder = v }
                if let v = args?["cancelText"] as? String { self.model.cancelText = v }
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
    ///
    /// Clipped to its bounds, the glass would keep the part of its shadow
    /// that lies inside them, around the capsule's ends: a box. So the glass
    /// is also clipped to its capsule, which removes its shadow (#170).
    private func applyTransitionContainment(_ active: Bool) {
        model.glassContained = active
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
    /// Whether the view is clipped to its bounds (halo containment), so the
    /// glass is clipped to its capsule, without its shadow (#170).
    @Published var glassContained = false
    /// Flutter's text direction (#173); nil leaves the system's.
    @Published var layoutDirection: LayoutDirection? = nil
    /// The font of the text, the placeholder and Cancel (#173); nil keeps
    /// the system's body font.
    @Published var labelFont: CNSearchBarFont? = nil
    /// The placeholder and the Cancel button's title, which change with the
    /// app's language (#173).
    @Published var placeholder = "Search"
    @Published var cancelText = "Cancel"
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

    /// SwiftUI's direction for the `rtl` parameter.
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
    let expandable: Bool
    let initiallyExpanded: Bool
    let collapsedWidth: CGFloat
    let expandedHeight: CGFloat
    let tint: Color
    let backgroundColor: Color?
    let textColor: Color?
    let placeholderColor: Color?
    /// The clear button's colour: `clearButtonColor`, else
    /// `placeholderColor`, else the secondary label colour (#171).
    let clearButtonColor: Color?
    /// Whether the Liquid Glass capsule casts its shadow on iOS 26+ (#170).
    let shadow: Bool
    let showCancelButton: Bool
    let autofocus: Bool
    let searchIconName: String
    let clearIconName: String
    let clearButtonLabel: String
    let keyboard: CNSearchKeyboard
    /// The icons' sizes at the default text size; they follow Dynamic Type
    /// like the field's text (#134).
    @ScaledMetric(relativeTo: .body) private var searchIconSize: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var clearIconSize: CGFloat = 16
    /// Dynamic Type's scale of the body text, times 100: the label font's
    /// size follows it as the system's body font does (#173).
    @ScaledMetric(relativeTo: .body) private var fontScale: CGFloat = 100
    /// The direction the host lays the bar out in, used when Flutter sent
    /// none.
    @Environment(\.layoutDirection) private var inheritedDirection

    let onSubmitted: (String) -> Void
    let onCancelTapped: () -> Void

    private var isExpanded: Bool { model.isExpanded }

    /// The font of the text, the placeholder and Cancel: nil keeps the
    /// system's body font.
    private var labelFont: Font? { model.labelFont?.font(scale: fontScale / 100) }

    /// The direction the bar is laid out in: Flutter's, else the host's.
    private var layoutDirection: LayoutDirection { model.layoutDirection ?? inheritedDirection }

    private var isRightToLeft: Bool { layoutDirection == .rightToLeft }
    @FocusState private var isFocused: Bool
    @Namespace private var animation

    init(
        model: CNSearchBarModel,
        expandable: Bool,
        initiallyExpanded: Bool,
        collapsedWidth: CGFloat,
        expandedHeight: CGFloat,
        tint: Color,
        backgroundColor: Color?,
        textColor: Color?,
        placeholderColor: Color?,
        clearButtonColor: Color?,
        shadow: Bool,
        showCancelButton: Bool,
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
        self.expandable = expandable
        self.initiallyExpanded = initiallyExpanded
        self.collapsedWidth = collapsedWidth
        self.expandedHeight = expandedHeight
        self.tint = tint
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.placeholderColor = placeholderColor
        self.clearButtonColor = clearButtonColor
        self.shadow = shadow
        self.showCancelButton = showCancelButton
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
                    // Text field. The placeholder is the prompt, so
                    // `placeholderColor` reaches it; the label is what
                    // VoiceOver reads (#171).
                    TextField(text: $model.searchText, prompt: prompt) {
                        Text(model.placeholder)
                    }
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
                    // Right to left (#173): under a right-to-left
                    // environment the field's own prompt stays on the left
                    // and Latin text starts on the left. Laid out left to
                    // right and aligned trailing, the prompt, the caret of
                    // an empty field and any text sit on the right, by the
                    // magnifying glass; the text keeps its own bidi order.
                    .multilineTextAlignment(isRightToLeft ? .trailing : .leading)
                    .environment(\.layoutDirection, .leftToRight)
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))

                    // Clear button
                    if !model.searchText.isEmpty {
                        Button(action: {
                            model.setText("", notify: true)
                        }) {
                            Image(systemName: clearIconName)
                                .font(.system(size: clearIconSize))
                                .foregroundColor(clearButtonColor ?? placeholderColor ?? .secondary)
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
            .modifier(CNSearchBarGlass(
                backgroundColor: backgroundColor,
                shadow: shadow && !model.glassContained
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
                    Text(model.cancelText)
                        .font(labelFont)
                        .foregroundColor(tint)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        // Flutter's direction, so a switch reaches a bar on screen (#173).
        .environment(\.layoutDirection, layoutDirection)
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

    /// The placeholder, in `placeholderColor` when one is set, else in the
    /// system's placeholder colour.
    private var prompt: Text {
        let text = Text(model.placeholder).font(labelFont)
        if let color = placeholderColor {
            return text.foregroundColor(color)
        }
        return text
    }
}

/// The search capsule's background.
///
/// On iOS 26+ the Liquid Glass is applied to the bar itself and is not
/// clipped, so it casts its soft shadow past the capsule, as the system's
/// glass controls do (#170); the platform view is not clipped either, so the
/// shadow draws past its bounds. Without `shadow` the glass is clipped to
/// the capsule, which removes the shadow. Before iOS 26 the capsule is a
/// plain fill.
struct CNSearchBarGlass: ViewModifier {
    let backgroundColor: Color?
    let shadow: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // One clip whose shape changes, rather than a clip added and
            // removed: the field keeps its identity, so its focus and
            // text, when the shadow goes during halo containment.
            content
                .glassEffect(.regular, in: .capsule)
                .clipShape(CNSearchBarGlassClip(clipped: !shadow))
        } else {
            content
                .background(backgroundColor ?? Color(.systemGray6))
                .clipShape(Capsule())
        }
    }
}

/// The capsule when [clipped], else a rect far past it that clips nothing
/// the glass draws.
struct CNSearchBarGlassClip: Shape {
    var clipped: Bool

    func path(in rect: CGRect) -> Path {
        clipped
            ? Capsule().path(in: rect)
            : Path(rect.insetBy(dx: -400, dy: -400))
    }
}

// MARK: - Font

/// `CNSearchBar.labelFontFamily`, `labelFontSize` and `labelFontWeight`
/// (#173). A family declared in pubspec.yaml is found by `CNFontResolver`.
struct CNSearchBarFont: Equatable {
    let family: String?
    let size: CGFloat?
    let weight: UIFont.Weight?

    /// Nil when [dict] sets none of the three.
    init?(_ dict: [String: Any]?) {
        let dict = dict ?? [:]
        family = (dict["labelFontFamily"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        size = (dict["labelFontSize"] as? NSNumber).flatMap { $0.doubleValue > 0 ? CGFloat($0.doubleValue) : nil }
        weight = CNFontResolver.weight(fromFlutterValue: (dict["labelFontWeight"] as? NSNumber)?.intValue)
        if family == nil && size == nil && weight == nil { return nil }
    }

    /// The font at its size (17, the body size, by default) times
    /// Dynamic Type's [scale].
    func font(scale: CGFloat) -> Font {
        let pointSize = (size ?? 17) * scale
        if let family, let resolved = CNFontResolver.font(family: family, size: pointSize, weight: weight) {
            return Font(resolved as CTFont)
        }
        return Font(UIFont.systemFont(ofSize: pointSize, weight: weight ?? .regular) as CTFont)
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
