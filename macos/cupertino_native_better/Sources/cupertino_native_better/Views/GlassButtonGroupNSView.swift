import FlutterMacOS
import AppKit
import SwiftUI

// Liquid Glass (GlassEffectContainer, glassEffect) needs the macOS 26 SDK.
#if compiler(>=6.2)

/// One button of a `CNGlassButtonGroup`, decoded from Flutter's map.
@available(macOS 26.0, *)
struct MacGlassGroupButtonData {
  let title: String?
  let iconName: String?
  let iconImage: NSImage?
  let iconSize: CGFloat
  let iconColor: Color?
  let tint: Color?
  let style: String
  let isEnabled: Bool
  let isInteractive: Bool
  let glassEffectUnionId: String?
  let glassEffectId: String?
  let glassEffectInteractive: Bool
  let config: GlassButtonConfig
  let badgeCount: Int?
  let menuLabels: [String]?
  let menuSfSymbols: [String]?

  var isPopup: Bool { !(menuLabels ?? []).isEmpty }

  init(dict: [String: Any]) {
    title = dict["label"] as? String
    iconName = dict["iconName"] as? String
    iconSize = (dict["iconSize"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 20
    iconColor = (dict["iconColor"] as? NSNumber).map { Color(nsColor: macGroupColor($0.intValue)) }
    tint = (dict["tint"] as? NSNumber).map { Color(nsColor: macGroupColor($0.intValue)) }
    style = dict["style"] as? String ?? "glass"
    isEnabled = (dict["enabled"] as? NSNumber)?.boolValue ?? true
    isInteractive = (dict["interaction"] as? NSNumber)?.boolValue ?? true
    glassEffectUnionId = dict["glassEffectUnionId"] as? String
    glassEffectId = dict["glassEffectId"] as? String
    glassEffectInteractive = (dict["glassEffectInteractive"] as? NSNumber)?.boolValue ?? false
    badgeCount = (dict["badgeCount"] as? NSNumber)?.intValue
    menuLabels = dict["menuLabels"] as? [String]
    menuSfSymbols = dict["menuSfSymbols"] as? [String]
    iconImage = Self.image(from: dict, size: iconSize)

    func number(_ key: String) -> CGFloat? {
      (dict[key] as? NSNumber).map { CGFloat(truncating: $0) }
    }
    config = GlassButtonConfig(
      borderRadius: number("borderRadius"),
      top: number("paddingTop"),
      bottom: number("paddingBottom"),
      left: number("paddingLeft"),
      right: number("paddingRight"),
      horizontal: number("paddingHorizontal"),
      vertical: number("paddingVertical"),
      minHeight: number("minHeight") ?? 44,
      spacing: number("imagePadding") ?? 8
    )
  }

  /// A custom icon Flutter rendered (`iconBytes`) or raster image data
  /// (`imageBytes`). Asset paths and SVG data need the macOS image utility
  /// and draw no image yet.
  private static func image(from dict: [String: Any], size: CGFloat) -> NSImage? {
    let format = (dict["imageFormat"] as? String)?.lowercased()
    var data: Data? = nil
    if format != "svg", let bytes = dict["imageBytes"] as? FlutterStandardTypedData {
      data = bytes.data
    } else if let bytes = dict["iconBytes"] as? FlutterStandardTypedData {
      data = bytes.data
    }
    guard let data = data, let image = NSImage(data: data) else { return nil }
    image.size = NSSize(width: size, height: size)
    return image
  }
}

@available(macOS 26.0, *)
final class MacGlassButtonGroupModel: ObservableObject {
  @Published var buttons: [MacGlassGroupButtonData] = []
  @Published var axis: Axis = .horizontal
  @Published var spacing: CGFloat = 8
  @Published var spacingForGlass: CGFloat = 40
  @Published var interactive = true
  /// Called with the button's index when it is clicked.
  var onPressed: (Int) -> Void = { _ in }
  /// Called with each button's frame (top-left origin, in the hosting view)
  /// after layout, for the badges and the menus.
  var onFrames: ([Int: CGRect]) -> Void = { _ in }
}

private struct MacGroupButtonFramesKey: PreferenceKey {
  static var defaultValue: [Int: CGRect] = [:]
  static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { $1 })
  }
}

/// The buttons in one `GlassEffectContainer`, so their glass blends and
/// buttons with the same `glassEffectUnionId` merge into one shape.
@available(macOS 26.0, *)
struct MacGlassButtonGroupSwiftUI: View {
  @ObservedObject var model: MacGlassButtonGroupModel
  @Namespace private var namespace

  /// As on iOS: a horizontal bar of several buttons starts blending earlier,
  /// so the glass does not pinch between them.
  private var effectiveSpacingForGlass: CGFloat {
    if model.axis == .horizontal, model.buttons.count >= 2 {
      return max(model.spacingForGlass, 80)
    }
    return model.spacingForGlass
  }

  var body: some View {
    GlassEffectContainer(spacing: effectiveSpacingForGlass) {
      if model.axis == .horizontal {
        HStack(alignment: .center, spacing: model.spacing) { buttons }
      } else {
        VStack(alignment: .center, spacing: model.spacing) { buttons }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    .coordinateSpace(.named("cnGlassGroup"))
    .onPreferenceChange(MacGroupButtonFramesKey.self) { model.onFrames($0) }
    .allowsHitTesting(model.interactive)
  }

  @ViewBuilder
  private var buttons: some View {
    ForEach(Array(model.buttons.enumerated()), id: \.offset) { index, button in
      MacGlassGroupButton(data: button, namespace: namespace) { model.onPressed(index) }
        .fixedSize(horizontal: true, vertical: false)
        .background(
          GeometryReader { geo in
            Color.clear.preference(
              key: MacGroupButtonFramesKey.self,
              value: [index: geo.frame(in: .named("cnGlassGroup"))])
          })
    }
  }
}

/// A glass button of the group; the port of the iOS `GlassButtonSwiftUI`
/// with the group's shared namespace.
@available(macOS 26.0, *)
struct MacGlassGroupButton: View {
  let data: MacGlassGroupButtonData
  let namespace: Namespace.ID
  let onPressed: () -> Void

  /// `prominentClearGlass` tints the glass itself, so its content is white.
  private var isProminentClear: Bool { data.style == "prominentClearGlass" }

  private var iconColor: Color? {
    isProminentClear ? (data.iconColor ?? .white) : (data.iconColor ?? data.tint)
  }

  /// A custom button style draws no disabled look of its own.
  private var contentOpacity: Double { data.isEnabled ? 1 : 0.4 }

  private var shape: SwiftUI.AnyShape {
    if let radius = data.config.borderRadius {
      return SwiftUI.AnyShape(RoundedRectangle(cornerRadius: radius))
    }
    return SwiftUI.AnyShape(Capsule())
  }

  private var glass: Glass {
    var glass: Glass
    switch data.style {
    case "clearGlass": glass = .clear
    case "prominentClearGlass": glass = Glass.clear.tint(data.tint)
    default: glass = .regular
    }
    return data.glassEffectInteractive ? glass.interactive() : glass
  }

  var body: some View {
    Button(action: onPressed) {
      HStack(spacing: data.config.spacing) {
        if let image = data.iconImage {
          Image(nsImage: image)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: data.iconSize, height: data.iconSize)
            .foregroundStyle(iconColor ?? .primary)
        } else if let name = data.iconName {
          Image(systemName: name)
            .font(.system(size: data.iconSize))
            .foregroundStyle(iconColor ?? .primary)
        }
        if let title = data.title {
          Text(title)
            .foregroundStyle(isProminentClear ? .white : (data.tint ?? .primary))
        }
      }
      .opacity(contentOpacity)
      .padding(data.config.padding)
      .frame(minHeight: data.config.minHeight)
      .contentShape(shape)
    }
    .buttonStyle(MacGroupPlainButtonStyle())
    // The glass goes on the button, not inside its label: on macOS a label
    // with its own glass in a GlassEffectContainer only takes clicks when
    // the hosting view sits at the window's origin, which a platform view
    // never does (only the last button of a union reacted).
    .glassEffect(glass, in: shape)
    .modifier(MacGlassUnion(unionId: data.glassEffectUnionId, id: data.glassEffectId, namespace: namespace))
    .disabled(!data.isEnabled)
    .allowsHitTesting(data.isEnabled && data.isInteractive)
  }
}

/// Joins a button's glass to its union and gives it its id.
@available(macOS 26.0, *)
private struct MacGlassUnion: ViewModifier {
  let unionId: String?
  let id: String?
  let namespace: Namespace.ID

  func body(content: Content) -> some View {
    switch (unionId, id) {
    case let (union?, id?):
      content.glassEffectUnion(id: union, namespace: namespace).glassEffectID(id, in: namespace)
    case let (union?, nil):
      content.glassEffectUnion(id: union, namespace: namespace)
    case let (nil, id?):
      content.glassEffectID(id, in: namespace)
    default:
      content
    }
  }
}

/// No highlight of its own: the glass shows the press.
@available(macOS 26.0, *)
private struct MacGroupPlainButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View { configuration.label }
}

#endif

/// The red count drawn over a button's corner, in AppKit above the glass so
/// the glass does not sample it.
private final class MacGroupBadgeView: NSView {
  private let label = NSTextField(labelWithString: "")

  init(count: Int) {
    super.init(frame: .zero)
    wantsLayer = true
    layer?.backgroundColor = NSColor.systemRed.cgColor
    layer?.shadowColor = NSColor.black.cgColor
    layer?.shadowOpacity = 0.2
    layer?.shadowOffset = CGSize(width: 0, height: -1)
    layer?.shadowRadius = 2
    label.font = .systemFont(ofSize: 12, weight: .semibold)
    label.textColor = .white
    label.alignment = .center
    label.stringValue = count > 99 ? "99+" : "\(count)"
    addSubview(label)
    let width = count <= 9 ? 18 : max(label.intrinsicContentSize.width + 8, 18)
    frame.size = NSSize(width: width, height: 18)
    layer?.cornerRadius = 9
    setAccessibilityElement(false)
  }

  required init?(coder: NSCoder) { return nil }

  override var isFlipped: Bool { true }

  override func layout() {
    super.layout()
    let height = label.intrinsicContentSize.height
    label.frame = NSRect(x: 0, y: (bounds.height - height) / 2, width: bounds.width, height: height)
  }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

#if compiler(>=6.2)

/// `CNGlassButtonGroup` on macOS 26+: the buttons in a SwiftUI
/// `GlassEffectContainer`, laid out like the iOS view (3 points above for
/// the badges, 6 points to the right) so Flutter sizes both the same way.
@available(macOS 26.0, *)
class GlassButtonGroupNSView: NSView {
  private let channel: FlutterMethodChannel
  private let model = MacGlassButtonGroupModel()
  private let hostingView: NSHostingView<MacGlassButtonGroupSwiftUI>
  private var buttonFrames: [Int: CGRect] = [:]
  private var badgeViews: [MacGroupBadgeView] = []

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: "CupertinoNativeGlassButtonGroup_\(viewId)", binaryMessenger: messenger)
    self.hostingView = NSHostingView(rootView: MacGlassButtonGroupSwiftUI(model: model))
    super.init(frame: .zero)

    let dict = args as? [String: Any] ?? [:]
    model.buttons = ((dict["buttons"] as? [[String: Any]]) ?? []).map(MacGlassGroupButtonData.init)
    model.axis = (dict["axis"] as? String) == "vertical" ? .vertical : .horizontal
    if let v = dict["spacing"] as? NSNumber { model.spacing = CGFloat(truncating: v) }
    if let v = dict["spacingForGlass"] as? NSNumber { model.spacingForGlass = CGFloat(truncating: v) }
    let isDark = (dict["isDark"] as? NSNumber)?.boolValue ?? false
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    model.onPressed = { [weak self] index in self?.buttonPressed(index) }
    model.onFrames = { [weak self] frames in
      self?.buttonFrames = frames
      self?.updateBadges()
    }

    hostingView.sizingOptions = []
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hostingView)
    let constraints = [
      hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
      hostingView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
      hostingView.topAnchor.constraint(equalTo: topAnchor, constant: 3),
      hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ]
    // Not required: Flutter can size the view to zero for a frame.
    constraints.forEach { $0.priority = .defaultHigh }
    NSLayoutConstraint.activate(constraints)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "updateButton":
        if let index = (args?["index"] as? NSNumber)?.intValue,
           let button = args?["button"] as? [String: Any],
           index >= 0, index < self.model.buttons.count {
          self.model.buttons[index] = MacGlassGroupButtonData(dict: button)
          self.updateBadgesAfterLayout()
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing index or button", details: nil))
        }
      case "updateButtons":
        if let buttons = args?["buttons"] as? [[String: Any]] {
          self.model.buttons = buttons.map(MacGlassGroupButtonData.init)
          self.updateBadgesAfterLayout()
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing buttons", details: nil))
        }
      case "setBrightness":
        if let isDark = (args?["isDark"] as? NSNumber)?.boolValue {
          self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil))
        }
      case "setInteractive":
        self.model.interactive = (args?["interactive"] as? NSNumber)?.boolValue ?? true
        result(nil)
      case "setTransitioning", "buttonPressed":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) { return nil }

  override var isFlipped: Bool { true }

  override func layout() {
    super.layout()
    updateBadges()
  }

  private func buttonPressed(_ index: Int) {
    guard index >= 0, index < model.buttons.count else { return }
    let button = model.buttons[index]
    if button.isPopup {
      showMenu(for: index, button: button)
    } else {
      channel.invokeMethod("buttonPressed", arguments: ["index": index])
    }
  }

  // MARK: Menus

  /// Opens the button's items as a menu under it, like a pull-down button.
  private func showMenu(for index: Int, button: MacGlassGroupButtonData) {
    let menu = NSMenu()
    menu.autoenablesItems = false
    for (i, label) in (button.menuLabels ?? []).enumerated() {
      let item = NSMenuItem(title: label, action: #selector(menuItemSelected(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = [index, i]
      if let symbols = button.menuSfSymbols, i < symbols.count, !symbols[i].isEmpty {
        item.image = NSImage(systemSymbolName: symbols[i], accessibilityDescription: nil)
      }
      menu.addItem(item)
    }
    let frame = buttonFrames[index] ?? .zero
    let below = NSPoint(x: frame.minX, y: frame.maxY + 4)
    let point = hostingView.isFlipped ? below : NSPoint(x: below.x, y: hostingView.bounds.height - below.y)
    menu.popUp(positioning: nil, at: point, in: hostingView)
  }

  @objc private func menuItemSelected(_ item: NSMenuItem) {
    guard let pair = item.representedObject as? [Int], pair.count == 2 else { return }
    channel.invokeMethod("buttonPressed", arguments: ["index": pair[0], "selectedIndex": pair[1]])
  }

  // MARK: Badges

  /// A new count can come without a new frame, which is what usually
  /// redraws the badges; SwiftUI lays the new buttons out first.
  private func updateBadgesAfterLayout() {
    DispatchQueue.main.async { [weak self] in self?.updateBadges() }
  }

  /// Puts a badge over the top-right corner of each button with a count.
  private func updateBadges() {
    badgeViews.forEach { $0.removeFromSuperview() }
    badgeViews.removeAll()
    let origin = hostingView.frame.origin
    for (index, button) in model.buttons.enumerated() {
      guard let count = button.badgeCount, count > 0, let frame = buttonFrames[index] else { continue }
      let badge = MacGroupBadgeView(count: count)
      badge.frame.origin = NSPoint(x: origin.x + frame.maxX - 12, y: origin.y + frame.minY - 3)
      addSubview(badge)
      badgeViews.append(badge)
    }
  }
}

#endif

/// `CNGlassButtonGroup` below macOS 26. Flutter draws its own fallback
/// there, so this view only answers the calls a widget may still send.
class FallbackGlassButtonGroupNSView: NSView {
  private let channel: FlutterMethodChannel

  init(viewId: Int64, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: "CupertinoNativeGlassButtonGroup_\(viewId)", binaryMessenger: messenger)
    super.init(frame: .zero)
    channel.setMethodCallHandler { _, result in result(nil) }
  }

  required init?(coder: NSCoder) { return nil }
}

private func macGroupColor(_ argb: Int) -> NSColor {
  let a = CGFloat((argb >> 24) & 0xFF) / 255.0
  let r = CGFloat((argb >> 16) & 0xFF) / 255.0
  let g = CGFloat((argb >> 8) & 0xFF) / 255.0
  let b = CGFloat(argb & 0xFF) / 255.0
  return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
