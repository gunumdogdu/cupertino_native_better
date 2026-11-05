import Flutter
import SwiftUI
import UIKit

/// What the gauge shows; SwiftUI redraws on each change.
final class GaugeModel: ObservableObject {
  @Published var style = "capacity"
  @Published var value: Double = 0
  @Published var min: Double = 0
  @Published var max: Double = 1
  @Published var warningValue: Double?
  @Published var criticalValue: Double?
  @Published var tint: UIColor?
  @Published var warningColor: UIColor?
  @Published var criticalColor: UIColor?
  @Published var label: String?
  @Published var currentValueLabel: String?
  @Published var minimumValueLabel: String?
  @Published var maximumValueLabel: String?
  @Published var editable = false
  @Published var semanticLabel: String?
  @Published var semanticValue: String?

  /// Called with the rating the user set.
  var onEdit: (Double) -> Void = { _ in }

  /// A valid range for SwiftUI's `Gauge`.
  var range: ClosedRange<Double> { min...Swift.max(max, min + 1e-9) }

  var hasLabels: Bool {
    label != nil || currentValueLabel != nil || minimumValueLabel != nil || maximumValueLabel != nil
  }

  /// The value the gauge draws: a discrete gauge fills whole units only, as
  /// the segments of the macOS one do.
  var shownValue: Double {
    let v = Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
    guard style == "discreteCapacity" else { return v }
    return range.lowerBound + (v - range.lowerBound).rounded(.down)
  }

  // MARK: Zones

  /// The colour of the normal zone: the tint, else green when there are
  /// zones (as on macOS), else nil for the style's own colour.
  var normalColor: Color? {
    if let tint = tint { return Color(tint) }
    return (warningValue != nil || criticalValue != nil) ? Color(UIColor.systemGreen) : nil
  }

  var warning: Color { Color(warningColor ?? .systemYellow) }
  var critical: Color { Color(criticalColor ?? .systemRed) }

  /// A scale where low is bad: the critical value is below the warning one.
  var descending: Bool {
    if let w = warningValue, let c = criticalValue { return c < w }
    return false
  }

  /// The colour for the current value, as `NSLevelIndicator` picks it.
  var currentColor: Color? {
    if descending, let w = warningValue, let c = criticalValue {
      if value <= c { return critical }
      if value <= w { return warning }
      return normalColor
    }
    if let c = criticalValue, value >= c { return critical }
    if let w = warningValue, value >= w { return warning }
    return normalColor
  }

  private func fraction(_ v: Double) -> Double {
    let r = range
    return Swift.min(Swift.max((v - r.lowerBound) / (r.upperBound - r.lowerBound), 0), 1)
  }

  /// The zones along the range as a gradient with hard stops, for the
  /// marker styles; nil without zones.
  var zoneGradient: Gradient? {
    guard warningValue != nil || criticalValue != nil else { return nil }
    let normal = normalColor ?? Color(UIColor.systemGreen)
    var zones: [(Color, Double)] = []
    if descending, let w = warningValue, let c = criticalValue {
      zones = [(critical, 0), (warning, fraction(c)), (normal, fraction(w))]
    } else {
      zones = [(normal, 0)]
      if let w = warningValue { zones.append((warning, fraction(w))) }
      if let c = criticalValue { zones.append((critical, fraction(c))) }
    }
    var stops: [Gradient.Stop] = []
    for (i, zone) in zones.enumerated() {
      let end = i + 1 < zones.count ? zones[i + 1].1 : 1
      stops.append(.init(color: zone.0, location: zone.1))
      stops.append(.init(color: zone.0, location: end))
    }
    return Gradient(stops: stops)
  }
}

@available(iOS 16.0, *)
private struct GaugeStyleModifier: ViewModifier {
  let style: String

  func body(content: Content) -> some View {
    switch style {
    case "relevancy": content.gaugeStyle(.accessoryLinearCapacity)
    case "circularCapacity": content.gaugeStyle(.accessoryCircularCapacity)
    case "circular": content.gaugeStyle(.accessoryCircular)
    case "linear": content.gaugeStyle(.accessoryLinear)
    default: content.gaugeStyle(.linearCapacity)
    }
  }
}

/// The rating: one SF Symbol star per whole unit up to `max`, filled up to
/// the value (a half star for a half), sized with Dynamic Type. Editable
/// with a tap or a drag across the stars, and with VoiceOver's adjustable
/// swipes. iOS has no rating control; Apple's apps draw ratings with these
/// symbols.
struct RatingStarsView: View {
  @ObservedObject var model: GaugeModel
  @State private var dragValue: Double?
  @Environment(\.layoutDirection) private var layoutDirection

  private var count: Int { Swift.max(1, Swift.min(100, Int(model.max.rounded(.down)))) }

  var body: some View {
    let shown = dragValue ?? model.value
    let stars = HStack(spacing: 2) {
      ForEach(0..<count, id: \.self) { i in
        Image(systemName: symbol(i, shown))
          .foregroundColor(shown >= Double(i) + 0.5 ? filledColor : Color(UIColor.tertiaryLabel))
      }
    }
    .font(.body)
    .overlay(
      GeometryReader { geo in
        Color.clear
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { dragValue = rating(at: $0.location.x, width: geo.size.width) }
              .onEnded {
                let value = rating(at: $0.location.x, width: geo.size.width)
                dragValue = nil
                set(value)
              })
      }
      .allowsHitTesting(model.editable)
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(model.semanticLabel ?? ""))
    .accessibilityValue(Text(model.semanticValue ?? ""))
    if model.editable {
      stars.accessibilityAdjustableAction { direction in
        switch direction {
        case .increment: set(Swift.min(model.max, model.value.rounded(.down) + 1))
        case .decrement: set(Swift.max(0, model.value.rounded(.up) - 1))
        @unknown default: break
        }
      }
    } else {
      stars
    }
  }

  private var filledColor: Color { model.tint.map { Color($0) } ?? Color(UIColor.secondaryLabel) }

  private func symbol(_ i: Int, _ value: Double) -> String {
    if value >= Double(i) + 1 { return "star.fill" }
    if value >= Double(i) + 0.5 { return "star.leadinghalf.filled" }
    return "star"
  }

  /// The star under [x]: 0 before the first one.
  private func rating(at x: CGFloat, width: CGFloat) -> Double {
    guard width > 0 else { return model.value }
    let fromStart = layoutDirection == .rightToLeft ? width - x : x
    let star = width / CGFloat(count)
    return Double(Swift.min(Swift.max((fromStart / star).rounded(.up), 0), CGFloat(count)))
  }

  private func set(_ value: Double) {
    guard model.editable, value != model.value else { return }
    model.value = value
    model.onEdit(value)
  }
}

/// `CNGauge` on iOS: SwiftUI's `Gauge` in the style's form, or the rating
/// stars with the labels laid out as the macOS gauge lays out a linear one.
struct IOSGaugeView: View {
  @ObservedObject var model: GaugeModel

  var body: some View {
    if model.style == "rating" {
      labelled(RatingStarsView(model: model))
    } else if #available(iOS 16.0, *) {
      gauge
    }
  }

  @available(iOS 16.0, *)
  private var gauge: some View {
    let gauge = Gauge(value: model.shownValue, in: model.range) {
      optionalText(model.label)
    } currentValueLabel: {
      optionalText(model.currentValueLabel)
    } minimumValueLabel: {
      boundsText(model.minimumValueLabel)
    } maximumValueLabel: {
      boundsText(model.maximumValueLabel)
    }
    .modifier(GaugeStyleModifier(style: model.style))
    .accessibilityLabel(Text(model.semanticLabel ?? ""))
    .accessibilityValue(Text(model.semanticValue ?? ""))
    return ZStack {
      // `.accessoryLinear` lays out as its 8-point line and draws the bounds
      // labels centred on it, outside that height: reserve their height.
      if model.style == "linear",
         model.minimumValueLabel != nil || model.maximumValueLabel != nil {
        Text(" ").font(Self.boundsFont).hidden()
      }
      if ["circular", "linear"].contains(model.style), let gradient = model.zoneGradient {
        gauge.tint(gradient)
      } else {
        gauge.tint(model.currentColor)
      }
    }
  }

  @ViewBuilder
  private func optionalText(_ s: String?) -> some View {
    if let s = s { Text(s) }
  }

  /// The font of the bounds labels of the line style, stated so that its
  /// height can be reserved (the accessory style's own is a widget font).
  static let boundsFont: Font = .subheadline

  @ViewBuilder
  private func boundsText(_ s: String?) -> some View {
    if let s = s {
      if model.style == "linear" { Text(s).font(Self.boundsFont) } else { Text(s) }
    }
  }

  @ViewBuilder
  private func labelled<V: View>(_ content: V) -> some View {
    if model.hasLabels {
      VStack(spacing: 3) {
        if let label = model.label { Text(label) }
        HStack(spacing: 6) {
          if let min = model.minimumValueLabel { Text(min).foregroundColor(.secondary) }
          content
          if let max = model.maximumValueLabel { Text(max).foregroundColor(.secondary) }
        }
        if let current = model.currentValueLabel {
          Text(current).foregroundColor(.secondary)
        }
      }
      .font(.subheadline)
    } else {
      content
    }
  }
}

/// Lays out the hosting view and tells the platform view after each layout,
/// so it can report a new height for a new width.
private final class GaugeContainerView: UIView {
  var onLayout: () -> Void = {}

  override func layoutSubviews() {
    super.layoutSubviews()
    onLayout()
  }
}

/// `CNGauge` on iOS: `IOSGaugeView` in a hosting controller. It reports its
/// fitting size to Flutter (it follows Dynamic Type) and takes touches only
/// for an editable rating.
final class CupertinoGaugePlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let model = GaugeModel()
  private let container = GaugeContainerView()
  private let host: UIHostingController<IOSGaugeView>
  private var lastReportedSize: CGSize = .zero

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "CupertinoNativeGauge_\(viewId)", binaryMessenger: messenger)
    host = UIHostingController(rootView: IOSGaugeView(model: model))
    super.init()

    let dict = args as? [String: Any] ?? [:]
    container.frame = frame
    container.backgroundColor = .clear
    let isDark = (dict["isDark"] as? NSNumber)?.boolValue ?? false
    container.overrideUserInterfaceStyle = isDark ? .dark : .light

    host.view.backgroundColor = .clear
    if #available(iOS 16.4, *) {
      host.safeAreaRegions = []
    }
    host.view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(host.view)
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      host.view.topAnchor.constraint(equalTo: container.topAnchor),
      host.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])

    applyConfig(dict)
    model.onEdit = { [weak self] value in
      self?.channel.invokeMethod("valueChanged", arguments: ["value": value])
    }
    container.onLayout = { [weak self] in self?.reportSizeIfChanged() }
    NotificationCenter.default.addObserver(
      self, selector: #selector(contentSizeCategoryChanged),
      name: UIContentSizeCategory.didChangeNotification, object: nil)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "getIntrinsicSize":
        let size = self.fittingSize()
        self.lastReportedSize = size
        result(["width": Double(size.width), "height": Double(size.height)])
      case "setValue":
        if let v = (args?["value"] as? NSNumber)?.doubleValue {
          withAnimation(.easeInOut(duration: 0.25)) { self.model.value = v }
        }
        result(nil)
      case "setConfig":
        self.applyConfig(args ?? [:])
        self.reportSizeIfChanged()
        result(nil)
      case "setBrightness":
        guard let isDark = (args?["isDark"] as? NSNumber)?.boolValue else {
          result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)); return
        }
        self.container.overrideUserInterfaceStyle = isDark ? .dark : .light
        result(nil)
      case "setInteractive":
        self.container.isUserInteractionEnabled =
          ((args?["interactive"] as? NSNumber)?.boolValue ?? true) && self.model.editable
        result(nil)
      case "setTransitioning":
        // A gauge draws no halo to clip.
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  func view() -> UIView { container }

  private func applyConfig(_ dict: [String: Any]) {
    func number(_ key: String) -> Double? { (dict[key] as? NSNumber)?.doubleValue }
    func string(_ key: String) -> String? {
      guard let s = dict[key] as? String, !s.isEmpty else { return nil }
      return s
    }
    func color(_ key: String) -> UIColor? {
      (dict[key] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
    }
    if let s = dict["style"] as? String { model.style = s }
    if let v = number("min") { model.min = v }
    if let v = number("max") { model.max = v }
    if dict.keys.contains("warningValue") { model.warningValue = number("warningValue") }
    if dict.keys.contains("criticalValue") { model.criticalValue = number("criticalValue") }
    if dict.keys.contains("tint") { model.tint = color("tint") }
    if dict.keys.contains("warningColor") { model.warningColor = color("warningColor") }
    if dict.keys.contains("criticalColor") { model.criticalColor = color("criticalColor") }
    if dict.keys.contains("label") { model.label = string("label") }
    if dict.keys.contains("currentValueLabel") { model.currentValueLabel = string("currentValueLabel") }
    if dict.keys.contains("minimumValueLabel") { model.minimumValueLabel = string("minimumValueLabel") }
    if dict.keys.contains("maximumValueLabel") { model.maximumValueLabel = string("maximumValueLabel") }
    if let v = dict["editable"] as? NSNumber { model.editable = v.boolValue }
    if dict.keys.contains("semanticLabel") { model.semanticLabel = string("semanticLabel") }
    if dict.keys.contains("semanticValue") { model.semanticValue = string("semanticValue") }
    if let v = number("value") { model.value = v }
    // Only an editable rating takes touches; any other gauge lets them
    // through to Flutter.
    container.isUserInteractionEnabled = model.editable
  }

  // MARK: - Size

  /// The size the gauge needs at its current width (its own width for the
  /// rating and ring styles), at the current text size.
  private func fittingSize() -> CGSize {
    let fills = ["capacity", "discreteCapacity", "relevancy", "linear"].contains(model.style)
    let width = container.bounds.width
    let proposal = CGSize(
      width: fills && width > 0 ? width : CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude)
    let size = host.sizeThatFits(in: proposal)
    return CGSize(width: ceil(size.width), height: ceil(size.height))
  }

  private func reportSizeIfChanged() {
    let size = fittingSize()
    guard size.width > 0, size.height > 0, size.height < 10_000, size != lastReportedSize else { return }
    lastReportedSize = size
    channel.invokeMethod(
      "sizeChanged", arguments: ["width": Double(size.width), "height": Double(size.height)])
  }

  @objc private func contentSizeCategoryChanged() {
    DispatchQueue.main.async { [weak self] in self?.reportSizeIfChanged() }
  }
}
