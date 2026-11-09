import FlutterMacOS
import Cocoa
import SwiftUI

/// `CNSlider` on macOS: an `NSSlider`, on every supported macOS.
///
/// - `step` is drawn and snapped as tick marks when it divides the range
///   into at most 25 steps, as a SwiftUI slider with a step does on the Mac;
///   a finer step only snaps the value.
/// - `numberOfTicks`, and `tickValues` that are evenly spaced from `min` to
///   `max`, are NSSlider tick marks (`allowsTickMarkValuesOnly` snaps).
///   Unevenly spaced `tickValues` are drawn by the SwiftUI slider of
///   macOS 26+, which takes ticks at any value; below 26 they are not drawn,
///   but the value still snaps to them.
/// - `neutralValue` is `NSSlider.neutralValue` (macOS 26+).
/// - The track colour is `trackFillColor`. NSSlider has no thumb colour, no
///   colour for the unfilled track and no thumbless style, so `thumbColor`,
///   `trackBackgroundColor` and `CNSliderStyle.thumbless` are ignored.
/// - `semanticLabel` is the accessibility label.
class CupertinoSliderNSView: NSView {
  private let channel: FlutterMethodChannel
  private let slider: NSSlider
  /// The SwiftUI slider, only while it draws uneven tick values (macOS 26+).
  private var hostingController: NSHostingController<CupertinoSliderView>?
  private let model: SliderModel

  private var step: Double?
  private var semanticLabel: String?
  private var tint: NSColor?
  /// The value Flutter last set or was last told about; a repeat of it is
  /// not reported again (#137).
  private var lastReported: Double = 0
  /// Between the mouse-down and mouse-up of a drag, so `changeStart` and
  /// `changeEnd` go out once per gesture.
  private var inGesture = false

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeSlider_\(viewId)", binaryMessenger: messenger)
    self.slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)

    var value: Double = 0
    var minValue: Double = 0
    var maxValue: Double = 1
    var enabled = true
    var isDark = false
    var trackArgs: [String: Any] = [:]
    if let dict = args as? [String: Any] {
      trackArgs = dict
      if let v = dict["value"] as? NSNumber { value = v.doubleValue }
      if let v = dict["min"] as? NSNumber { minValue = v.doubleValue }
      if let v = dict["max"] as? NSNumber { maxValue = v.doubleValue }
      if let v = dict["enabled"] as? NSNumber { enabled = v.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
    }
    self.model = SliderModel(value: value, min: minValue, max: maxValue, enabled: enabled) { _ in }

    super.init(frame: .zero)

    if let dict = args as? [String: Any] {
      if let v = dict["step"] as? NSNumber, v.doubleValue > 0 { step = v.doubleValue }
      if let v = dict["semanticLabel"] as? String, !v.isEmpty { semanticLabel = v }
      if let style = dict["style"] as? [String: Any] { readTint(style) }
    }
    model.readTrackConfiguration(trackArgs)
    lastReported = value
    model.onChange = { [weak self] newValue in self?.userChanged(to: newValue) }
    model.onEditing = { [weak self] editing in
      if editing { self?.beginGesture() } else { self?.endGesture() }
    }

    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    slider.isContinuous = true
    slider.target = self
    slider.action = #selector(onSliderChanged(_:))
    slider.translatesAutoresizingMaskIntoConstraints = false
    addSubview(slider)
    NSLayoutConstraint.activate([
      slider.leadingAnchor.constraint(equalTo: leadingAnchor),
      slider.trailingAnchor.constraint(equalTo: trailingAnchor),
      slider.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
    applyAll()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "setValue":
        if let value = (args?["value"] as? NSNumber)?.doubleValue {
          self.model.value = value
          self.slider.doubleValue = value
          self.lastReported = value
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing value", details: nil)) }
      case "setRange":
        if let min = (args?["min"] as? NSNumber)?.doubleValue,
           let max = (args?["max"] as? NSNumber)?.doubleValue {
          self.model.min = min
          self.model.max = max
          self.model.value = Swift.min(Swift.max(self.model.value, min), max)
          self.applyAll()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing min/max", details: nil)) }
      case "setEnabled":
        if let enabled = (args?["enabled"] as? NSNumber)?.boolValue {
          self.model.enabled = enabled
          self.slider.isEnabled = enabled
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setStyle":
        self.readTint(args ?? [:])
        self.applyTint()
        result(nil)
      case "setStep":
        if let step = (args?["step"] as? NSNumber)?.doubleValue {
          self.step = step > 0 ? step : nil
          self.applyAll()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing step", details: nil)) }
      case "setTrackConfiguration":
        self.model.readTrackConfiguration(args ?? [:])
        self.applyAll()
        result(nil)
      case "setSliderStyle":
        // NSSlider has no thumbless style; the slider keeps its thumb.
        result(nil)
      case "setSemanticLabel":
        let label = args?["label"] as? String
        self.semanticLabel = (label?.isEmpty ?? true) ? nil : label
        self.applyLabel()
        result(nil)
      case "setBrightness":
        if let isDark = (args?["isDark"] as? NSNumber)?.boolValue {
          self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setInteractive":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) {
    return nil
  }

  // MARK: - Configuration

  /// The track colour: `trackTint` (the track colour Dart resolves from
  /// `trackColor`, `color` or the theme), else a general `tint`.
  private func readTint(_ style: [String: Any]) {
    if let n = (style["trackTint"] as? NSNumber) ?? (style["tint"] as? NSNumber) {
      tint = Self.colorFromARGB(n.intValue)
    }
  }

  /// Whether the SwiftUI slider draws the track: only for tick values that
  /// NSSlider's evenly spaced tick marks cannot show, on macOS 26+.
  private var usesSwiftUISlider: Bool {
    #if compiler(>=6.2)
    guard #available(macOS 26.0, *) else { return false }
    return model.tickValues != nil && evenTickCount == nil && !model.resolvedTickValues.isEmpty
    #else
    return false
    #endif
  }

  /// The number of NSSlider tick marks for the tick options, or nil when
  /// they are not evenly spaced from `min` to `max`.
  private var evenTickCount: Int? {
    if let n = model.numberOfTicks { return n > 1 ? n : nil }
    if model.tickValues == nil { return nil }
    guard let values = model.tickValues, values.count > 1 else { return nil }
    let sorted = values.sorted()
    let span = model.max - model.min
    guard span > 0 else { return nil }
    let gap = span / Double(sorted.count - 1)
    for (i, v) in sorted.enumerated() where abs(v - (model.min + gap * Double(i))) > 1e-9 * abs(span) {
      return nil
    }
    return sorted.count
  }

  private func applyAll() {
    slider.minValue = model.min
    slider.maxValue = model.max
    slider.doubleValue = model.value
    slider.isEnabled = model.enabled
    if let n = evenTickCount {
      slider.numberOfTickMarks = n
      slider.allowsTickMarkValuesOnly = model.allowsTickValuesOnly
    } else if let n = stepTickCount {
      slider.numberOfTickMarks = n
      slider.allowsTickMarkValuesOnly = true
    } else {
      slider.numberOfTickMarks = 0
      slider.allowsTickMarkValuesOnly = false
    }
    #if compiler(>=6.2)
    if #available(macOS 26.0, *) {
      // Fills from the neutral value; without one, from `min` as before.
      slider.neutralValue = model.clampedNeutralValue ?? model.min
    }
    #endif
    model.step = step
    applyTint()
    applyLabel()
    applyHosting()
  }

  /// Tick marks for `step` when there are no tick options: one per step,
  /// when the step divides the range into at most 25 steps.
  private var stepTickCount: Int? {
    guard model.tickValues == nil, model.numberOfTicks == nil, let s = step, s > 0 else { return nil }
    let steps = (model.max - model.min) / s
    let rounded = steps.rounded()
    guard rounded >= 1, rounded <= 25, abs(steps - rounded) < 1e-9 * Swift.max(1, steps) else { return nil }
    return Int(rounded) + 1
  }

  private func applyTint() {
    slider.trackFillColor = tint
    if let t = tint { model.tintColor = Color(t) }
  }

  private func applyLabel() {
    slider.setAccessibilityLabel(semanticLabel)
    model.label = semanticLabel ?? ""
  }

  /// Shows the SwiftUI slider instead of the NSSlider while it is needed.
  private func applyHosting() {
    if usesSwiftUISlider {
      if hostingController == nil {
        let host = NSHostingController(rootView: CupertinoSliderView(model: model))
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = NSColor.clear.cgColor
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host.view)
        NSLayoutConstraint.activate([
          host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
          host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
          host.view.topAnchor.constraint(equalTo: topAnchor),
          host.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        hostingController = host
      }
      slider.isHidden = true
    } else {
      hostingController?.view.removeFromSuperview()
      hostingController = nil
      slider.isHidden = false
    }
  }

  // MARK: - User changes

  @objc private func onSliderChanged(_ sender: NSSlider) {
    let snapped = snap(sender.doubleValue)
    if snapped != sender.doubleValue { sender.doubleValue = snapped }
    // NSSlider tracks the mouse itself; the event that sent the action
    // tells where in the drag it is.
    switch NSApp.currentEvent?.type {
    case .leftMouseDown?, .leftMouseDragged?:
      beginGesture()
      userChanged(to: snapped)
    case .leftMouseUp?:
      // A click on the knob that did not move sends only the mouse-up.
      beginGesture()
      userChanged(to: snapped)
      endGesture()
    default:
      userChanged(to: snapped)
    }
  }

  /// A value the user picked, from either slider. Reported once per change.
  private func userChanged(to value: Double) {
    let snapped = snap(value)
    model.value = snapped
    guard snapped != lastReported else { return }
    lastReported = snapped
    channel.invokeMethod("valueChanged", arguments: ["value": snapped])
  }

  private func beginGesture() {
    guard !inGesture else { return }
    inGesture = true
    channel.invokeMethod("changeStart", arguments: ["value": model.value])
  }

  private func endGesture() {
    guard inGesture else { return }
    inGesture = false
    channel.invokeMethod("changeEnd", arguments: ["value": model.value])
  }

  /// Snaps to `step`, or to the nearest tick value NSSlider cannot snap to
  /// by itself (uneven ticks below macOS 26).
  private func snap(_ value: Double) -> Double {
    if model.allowsTickValuesOnly, evenTickCount == nil {
      let ticks = model.resolvedTickValues
      if !ticks.isEmpty {
        return ticks.min { abs($0 - value) < abs($1 - value) } ?? value
      }
    }
    if let s = step, s > 0, evenTickCount == nil, stepTickCount == nil {
      let steps = ((value - model.min) / s).rounded()
      return Swift.min(Swift.max(model.min + steps * s, model.min), model.max)
    }
    return value
  }

  private static func colorFromARGB(_ argb: Int) -> NSColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
  }
}
