import Cocoa
import FlutterMacOS
import SwiftUI

/// What the gauge shows; SwiftUI redraws on each change.
final class GaugeModel: ObservableObject {
  @Published var style = "capacity"
  @Published var value: Double = 0
  @Published var min: Double = 0
  @Published var max: Double = 1
  @Published var warningValue: Double?
  @Published var criticalValue: Double?
  @Published var tint: NSColor?
  @Published var warningColor: NSColor?
  @Published var criticalColor: NSColor?
  @Published var label: String?
  @Published var currentValueLabel: String?
  @Published var minimumValueLabel: String?
  @Published var maximumValueLabel: String?
  @Published var tickMarkCount = 0
  @Published var majorTickMarkCount = 0
  @Published var tickMarksAbove = false
  @Published var editable = false
  @Published var semanticLabel: String?
  @Published var semanticValue: String?

  /// Called with the rating the user set.
  var onEdit: (Double) -> Void = { _ in }

  /// A valid range for SwiftUI's `Gauge` and `NSLevelIndicator`.
  var range: ClosedRange<Double> { min...Swift.max(max, min + 1e-9) }

  var hasLabels: Bool {
    label != nil || currentValueLabel != nil || minimumValueLabel != nil || maximumValueLabel != nil
  }

  /// Whether the style is drawn by `NSLevelIndicator` (on macOS 12 every
  /// style is).
  var usesLevelIndicator: Bool {
    if ["capacity", "discreteCapacity", "relevancy", "rating"].contains(style) { return true }
    if #available(macOS 13.0, *) { return false }
    return true
  }

  // MARK: Zones

  /// The colour of the normal zone: the tint, else green when there are
  /// zones (as `NSLevelIndicator`), else nil for the style's own colour.
  var normalColor: Color? {
    if let tint = tint { return Color(nsColor: tint) }
    return (warningValue != nil || criticalValue != nil) ? Color(nsColor: .systemGreen) : nil
  }

  var warning: Color { Color(nsColor: warningColor ?? .systemYellow) }
  var critical: Color { Color(nsColor: criticalColor ?? .systemRed) }

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
    let normal = normalColor ?? Color(nsColor: .systemGreen)
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

/// `NSLevelIndicator` in SwiftUI, for the capacity, discrete, relevancy and
/// rating styles (and every style on macOS 12).
struct LevelIndicatorRepresentable: NSViewRepresentable {
  @ObservedObject var model: GaugeModel

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }

  func makeNSView(context: Context) -> NSLevelIndicator {
    let indicator = NSLevelIndicator()
    indicator.target = context.coordinator
    indicator.action = #selector(Coordinator.changed(_:))
    indicator.setContentHuggingPriority(.defaultLow, for: .horizontal)
    indicator.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return indicator
  }

  func updateNSView(_ indicator: NSLevelIndicator, context: Context) {
    context.coordinator.model = model
    switch model.style {
    case "discreteCapacity": indicator.levelIndicatorStyle = .discreteCapacity
    case "relevancy": indicator.levelIndicatorStyle = .relevancy
    case "rating": indicator.levelIndicatorStyle = .rating
    default: indicator.levelIndicatorStyle = .continuousCapacity
    }
    let range = model.range
    indicator.minValue = range.lowerBound
    indicator.maxValue = range.upperBound
    // One threshold means "from here on"; the other is put out of reach,
    // as NSLevelIndicator reads both.
    switch (model.warningValue, model.criticalValue) {
    case let (w?, c?):
      indicator.warningValue = w
      indicator.criticalValue = c
    case let (w?, nil):
      indicator.warningValue = w
      indicator.criticalValue = range.upperBound + 1
    case let (nil, c?):
      indicator.warningValue = c
      indicator.criticalValue = c
    default:
      indicator.warningValue = range.upperBound + 1
      indicator.criticalValue = range.upperBound + 1
    }
    indicator.doubleValue = model.value
    // The colours are null-resettable: nil is the style's own (green
    // capacity, grey stars).
    indicator.fillColor = model.tint
    indicator.warningFillColor = model.warningColor
    indicator.criticalFillColor = model.criticalColor
    indicator.numberOfTickMarks = model.tickMarkCount
    indicator.numberOfMajorTickMarks = Swift.min(model.majorTickMarkCount, model.tickMarkCount)
    indicator.tickMarkPosition = model.tickMarksAbove ? .above : .below
    indicator.isEditable = model.editable
    indicator.isEnabled = true
    indicator.setAccessibilityLabel(model.semanticLabel)
    indicator.setAccessibilityValueDescription(model.semanticValue)
  }

  final class Coordinator: NSObject {
    var model: GaugeModel

    init(model: GaugeModel) { self.model = model }

    @objc func changed(_ sender: NSLevelIndicator) {
      // A rating is a whole number of stars.
      let value = sender.doubleValue.rounded()
      model.value = value
      model.onEdit(value)
    }
  }
}

/// The SwiftUI gauge styles of macOS 13 and later.
@available(macOS 13.0, *)
private struct GaugeStyleModifier: ViewModifier {
  let style: String

  func body(content: Content) -> some View {
    switch style {
    case "circular": content.gaugeStyle(.accessoryCircular)
    case "linear": content.gaugeStyle(.accessoryLinear)
    default: content.gaugeStyle(.accessoryCircularCapacity)
    }
  }
}

/// `CNGauge` on macOS: `NSLevelIndicator` for the level indicator styles,
/// with the labels around it laid out as the macOS `Gauge` lays out a
/// linear one, and SwiftUI's `Gauge` for the ring and line styles.
struct MacGaugeView: View {
  @ObservedObject var model: GaugeModel

  // The hosting view centres the content in the frame Flutter gives it.
  var body: some View { content }

  @ViewBuilder
  private var content: some View {
    if model.usesLevelIndicator {
      labelled(LevelIndicatorRepresentable(model: model).fixedSize(
        horizontal: model.style == "rating", vertical: true))
        .accessibilityElement(children: .contain)
    } else if #available(macOS 13.0, *) {
      swiftUIGauge
    }
  }

  @available(macOS 13.0, *)
  private var swiftUIGauge: some View {
    let gauge = Gauge(value: model.value, in: model.range) {
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
      if model.style != "circularCapacity", let gradient = model.zoneGradient {
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
  static let boundsFont: Font = .body

  @ViewBuilder
  private func boundsText(_ s: String?) -> some View {
    if let s = s {
      if model.style == "linear" { Text(s).font(Self.boundsFont) } else { Text(s) }
    }
  }

  /// The label above, the bounds at the ends, the current value below.
  @ViewBuilder
  private func labelled<V: View>(_ indicator: V) -> some View {
    if model.hasLabels {
      VStack(spacing: 3) {
        if let label = model.label { Text(label) }
        HStack(spacing: 6) {
          if let min = model.minimumValueLabel { Text(min) }
          indicator
          if let max = model.maximumValueLabel { Text(max) }
        }
        if let current = model.currentValueLabel {
          Text(current).foregroundColor(.secondary)
        }
      }
    } else {
      indicator
    }
  }
}

/// `CNGauge` on macOS: a SwiftUI hosting view (see `MacGaugeView`) that
/// reports its fitting size to Flutter and takes clicks only for an editable
/// rating.
final class CupertinoGaugeNSView: NSView {
  private let channel: FlutterMethodChannel
  private let model = GaugeModel()
  private let host: NSHostingController<MacGaugeView>
  private var lastReportedSize: CGSize = .zero

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "CupertinoNativeGauge_\(viewId)", binaryMessenger: messenger)
    host = NSHostingController(rootView: MacGaugeView(model: model))
    super.init(frame: .zero)

    let dict = args as? [String: Any] ?? [:]
    applyConfig(dict)
    let isDark = (dict["isDark"] as? NSNumber)?.boolValue ?? false
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    model.onEdit = { [weak self] value in
      self?.channel.invokeMethod("valueChanged", arguments: ["value": value])
    }

    let hosted = host.view
    hosted.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hosted)
    NSLayoutConstraint.activate([
      hosted.leadingAnchor.constraint(equalTo: leadingAnchor),
      hosted.trailingAnchor.constraint(equalTo: trailingAnchor),
      hosted.topAnchor.constraint(equalTo: topAnchor),
      hosted.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "getIntrinsicSize":
        let size = self.fittingSize(width: self.bounds.width)
        self.lastReportedSize = size
        result(["width": Double(size.width), "height": Double(size.height)])
      case "setValue":
        if let v = (args?["value"] as? NSNumber)?.doubleValue { self.model.value = v }
        result(nil)
      case "setConfig":
        self.applyConfig(args ?? [:])
        self.reportSizeIfChanged()
        result(nil)
      case "setBrightness":
        guard let isDark = (args?["isDark"] as? NSNumber)?.boolValue else {
          result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)); return
        }
        self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        result(nil)
      case "setInteractive", "setTransitioning":
        // Nothing to block or clip: a gauge draws no halo, and a hidden
        // one is replaced by a placeholder.
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) { return nil }

  /// Only an editable rating takes clicks; any other gauge lets clicks and
  /// scrolls through to the Flutter view under it.
  override func hitTest(_ point: NSPoint) -> NSView? {
    guard model.editable else { return nil }
    return super.hitTest(point)
  }

  override func layout() {
    super.layout()
    reportSizeIfChanged()
  }

  private func applyConfig(_ dict: [String: Any]) {
    func number(_ key: String) -> Double? { (dict[key] as? NSNumber)?.doubleValue }
    func string(_ key: String) -> String? {
      guard let s = dict[key] as? String, !s.isEmpty else { return nil }
      return s
    }
    func color(_ key: String) -> NSColor? {
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
    if let v = dict["tickMarkCount"] as? NSNumber { model.tickMarkCount = v.intValue }
    if let v = dict["majorTickMarkCount"] as? NSNumber { model.majorTickMarkCount = v.intValue }
    if let v = dict["tickMarkPosition"] as? String { model.tickMarksAbove = v == "above" }
    if let v = dict["editable"] as? NSNumber { model.editable = v.boolValue }
    if dict.keys.contains("semanticLabel") { model.semanticLabel = string("semanticLabel") }
    if dict.keys.contains("semanticValue") { model.semanticValue = string("semanticValue") }
    if let v = number("value") { model.value = v }
  }

  // MARK: - Size

  /// The size the gauge needs at [width] (its own width for the rating and
  /// ring styles).
  private func fittingSize(width: CGFloat) -> CGSize {
    let fills = ["capacity", "discreteCapacity", "relevancy", "linear"].contains(model.style)
      || (model.usesLevelIndicator && model.style != "rating")
    let proposal = CGSize(
      width: fills && width > 0 ? width : CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude)
    let size = host.sizeThatFits(in: proposal)
    return CGSize(width: ceil(size.width), height: ceil(size.height))
  }

  private func reportSizeIfChanged() {
    let size = fittingSize(width: bounds.width)
    guard size.width > 0, size.height > 0, size != lastReportedSize else { return }
    lastReportedSize = size
    channel.invokeMethod(
      "sizeChanged", arguments: ["width": Double(size.width), "height": Double(size.height)])
  }
}
