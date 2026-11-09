import Flutter
import UIKit

class CupertinoSliderPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let container: UIView
  private let slider: UISlider
  private var minValue: Float
  private var maxValue: Float
  private var step: Double = 0 // 0 = no stepping
  /// `CNSlider.numberOfTicks` / `tickValues` / `allowsTickValuesOnly` /
  /// `neutralValue`, applied as a `UISlider.TrackConfiguration` on iOS 26+.
  private var numberOfTicks: Int?
  private var tickValues: [Float]?
  private var allowsTickValuesOnly = true
  private var neutralValue: Float?
  /// Whether a track configuration was set, so one can be cleared without
  /// touching sliders that never used it.
  private var hasTrackConfiguration = false
  /// The value Flutter last set or was last told about. UIKit sends
  /// `.valueChanged` again when a touch ends without moving the slider;
  /// that value is not reported a second time (#137).
  private var lastReported: Double
  /// `CNSlider.seekOnTap`: a tap on the track moves the value there.
  private var seekOnTap = false
  private lazy var seekTap = UITapGestureRecognizer(target: self, action: #selector(onSeekTap(_:)))
  /// Between `.touchDown` and the end of the touch, so `changeStart` and
  /// `changeEnd` go out once per gesture.
  private var inGesture = false

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeSlider_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)
    self.slider = UISlider(frame: .zero)
    self.minValue = 0
    self.maxValue = 1
    self.lastReported = 0

    var initialValue: Double = 0
    var enabled: Bool = true
    var isDark: Bool = false
    var tint: UIColor? = nil
    var thumbTint: UIColor? = nil
    var trackTint: UIColor? = nil
    var trackBgTint: UIColor? = nil
    var step: Double = 0
    var semanticLabel: String? = nil
    var sliderStyle: String? = nil
    var trackArgs: [String: Any] = [:]

    if let dict = args as? [String: Any] {
      if let v = dict["value"] as? NSNumber { initialValue = v.doubleValue }
      if let v = dict["min"] as? NSNumber { self.minValue = v.floatValue }
      if let v = dict["max"] as? NSNumber { self.maxValue = v.floatValue }
      if let v = dict["enabled"] as? NSNumber { enabled = v.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let v = dict["step"] as? NSNumber { step = v.doubleValue }
      if let v = dict["semanticLabel"] as? String, !v.isEmpty { semanticLabel = v }
      if let v = dict["sliderStyle"] as? String { sliderStyle = v }
      if let v = dict["seekOnTap"] as? NSNumber { seekOnTap = v.boolValue }
      trackArgs = dict
      if let style = dict["style"] as? [String: Any] {
        if let n = style["tint"] as? NSNumber { tint = Self.colorFromARGB(n.intValue) }
        if let n = style["thumbTint"] as? NSNumber { thumbTint = Self.colorFromARGB(n.intValue) }
        if let n = style["trackTint"] as? NSNumber { trackTint = Self.colorFromARGB(n.intValue) }
        if let n = style["trackBackgroundTint"] as? NSNumber { trackBgTint = Self.colorFromARGB(n.intValue) }
      }
    }

    self.lastReported = initialValue
    super.init()
    // What VoiceOver reads (`CNSlider.semanticLabel`).
    slider.accessibilityLabel = semanticLabel

    self.step = step

    container.backgroundColor = .clear
    if #available(iOS 13.0, *) {
      container.overrideUserInterfaceStyle = isDark ? .dark : .light
    }

    slider.minimumValue = self.minValue
    slider.maximumValue = self.maxValue
    slider.value = Float(initialValue)
    slider.isEnabled = enabled
    if let c = trackTint ?? tint { slider.minimumTrackTintColor = c }
    if let c = trackBgTint { slider.maximumTrackTintColor = c }
    if let c = thumbTint ?? tint { slider.thumbTintColor = c }

    if let style = sliderStyle { applySliderStyle(style) }
    readTrackConfiguration(trackArgs)
    applyTrackConfiguration()

    slider.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(slider)
    NSLayoutConstraint.activate([
      slider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      slider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      slider.topAnchor.constraint(equalTo: container.topAnchor),
      slider.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])

    slider.addTarget(self, action: #selector(onSliderChanged(_:)), for: .valueChanged)
    slider.addTarget(self, action: #selector(onTouchDown(_:)), for: .touchDown)
    slider.addTarget(self, action: #selector(onTouchEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    // The slider keeps its own touches; the tap only adds a seek.
    seekTap.cancelsTouchesInView = false
    applySeekOnTap()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "setSemanticLabel":
        // What VoiceOver reads (`CNSlider.semanticLabel`).
        let label = (call.arguments as? [String: Any])?["label"] as? String
        self.slider.accessibilityLabel = (label?.isEmpty ?? true) ? nil : label
        result(nil)
      case "setValue":
        if let args = call.arguments as? [String: Any], let value = (args["value"] as? NSNumber)?.doubleValue {
          let animated = (args["animated"] as? NSNumber)?.boolValue ?? false
          self.slider.setValue(Float(value), animated: animated)
          self.lastReported = Double(self.slider.value)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing value", details: nil)) }
      case "setRange":
        if let args = call.arguments as? [String: Any],
           let min = (args["min"] as? NSNumber)?.doubleValue,
           let max = (args["max"] as? NSNumber)?.doubleValue {
          self.minValue = Float(min)
          self.maxValue = Float(max)
          self.slider.minimumValue = self.minValue
          self.slider.maximumValue = self.maxValue
          if self.slider.value < self.minValue { self.slider.value = self.minValue }
          if self.slider.value > self.maxValue { self.slider.value = self.maxValue }
          // Ticks and the enabled range follow the new range.
          self.applyTrackConfiguration()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing min/max", details: nil)) }
      case "setEnabled":
        if let args = call.arguments as? [String: Any], let enabled = (args["enabled"] as? NSNumber)?.boolValue {
          self.slider.isEnabled = enabled
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setStyle":
        if let args = call.arguments as? [String: Any] {
          if let n = args["trackTint"] as? NSNumber { self.slider.minimumTrackTintColor = Self.colorFromARGB(n.intValue) }
          if let n = args["trackBackgroundTint"] as? NSNumber { self.slider.maximumTrackTintColor = Self.colorFromARGB(n.intValue) }
          if let n = args["thumbTint"] as? NSNumber { self.slider.thumbTintColor = Self.colorFromARGB(n.intValue) }
          if let n = args["tint"] as? NSNumber {
            let c = Self.colorFromARGB(n.intValue)
            if self.slider.minimumTrackTintColor == nil { self.slider.minimumTrackTintColor = c }
            if self.slider.thumbTintColor == nil { self.slider.thumbTintColor = c }
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          if #available(iOS 13.0, *) {
            self.container.overrideUserInterfaceStyle = isDark ? .dark : .light
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setStep":
        if let args = call.arguments as? [String: Any], let step = (args["step"] as? NSNumber)?.doubleValue {
          self.step = step
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing step", details: nil)) }
      case "setSeekOnTap":
        self.seekOnTap = ((call.arguments as? [String: Any])?["seekOnTap"] as? NSNumber)?.boolValue ?? false
        self.applySeekOnTap()
        result(nil)
      case "setSliderStyle":
        if let style = (call.arguments as? [String: Any])?["sliderStyle"] as? String {
          self.applySliderStyle(style)
        }
        result(nil)
      case "setTrackConfiguration":
        self.readTrackConfiguration(call.arguments as? [String: Any] ?? [:])
        self.applyTrackConfiguration()
        result(nil)
      case "setInteractive":
        if let args = call.arguments as? [String: Any],
           let interactive = (args["interactive"] as? NSNumber)?.boolValue {
          NSLog("[CN Slider] setInteractive=\(interactive)")
          self._cnSetInteractiveRecursive(self.container, interactive)
          self._cnSetInteractiveRecursive(self.slider, interactive)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  /// Reads the track options from creation params or `setTrackConfiguration`,
  /// which always sends all of them; a missing key clears that option.
  private func readTrackConfiguration(_ dict: [String: Any]) {
    numberOfTicks = (dict["numberOfTicks"] as? NSNumber)?.intValue
    tickValues = (dict["tickValues"] as? [NSNumber])?.map { $0.floatValue }
    allowsTickValuesOnly = (dict["allowsTickValuesOnly"] as? NSNumber)?.boolValue ?? true
    neutralValue = (dict["neutralValue"] as? NSNumber)?.floatValue
  }

  /// `CNSlider.style`: `thumbless` drops the thumb on iOS 26+.
  private func applySliderStyle(_ style: String) {
    if #available(iOS 26.0, *) {
      slider.sliderStyle = style == "thumbless" ? .thumbless : .default
    }
  }

  /// Applies the ticks and neutral value as a `UISlider.TrackConfiguration`
  /// (iOS 26+). The configuration places ticks and the neutral value as
  /// fractions of the track (0 at the minimum, 1 at the maximum), so the
  /// values Flutter sends in the slider's own range are converted.
  private func applyTrackConfiguration() {
    guard #available(iOS 26.0, *) else { return }
    let ticks = tickValues
    let count = numberOfTicks
    guard ticks != nil || count != nil || neutralValue != nil else {
      if hasTrackConfiguration {
        slider.trackConfiguration = nil
        hasTrackConfiguration = false
      }
      return
    }
    let span = maxValue - minValue
    func fraction(_ value: Float) -> Float {
      guard span != 0 else { return 0 }
      return Swift.max(0, Swift.min((value - minValue) / span, 1))
    }
    let neutral = fraction(neutralValue ?? minValue)
    let config: UISlider.TrackConfiguration
    if let ticks = ticks {
      config = UISlider.TrackConfiguration(
        allowsTickValuesOnly: allowsTickValuesOnly,
        neutralValue: neutral,
        ticks: ticks.map { UISlider.TrackConfiguration.Tick(position: fraction($0)) }
      )
    } else if let count = count {
      config = UISlider.TrackConfiguration(
        allowsTickValuesOnly: allowsTickValuesOnly,
        neutralValue: neutral,
        numberOfTicks: count
      )
    } else {
      // Only a neutral value: a track without ticks.
      config = UISlider.TrackConfiguration(
        allowsTickValuesOnly: false,
        neutralValue: neutral,
        ticks: []
      )
    }
    slider.trackConfiguration = config
    hasTrackConfiguration = true
  }

  @objc private func onSliderChanged(_ sender: UISlider) {
    let value = stepped(Double(sender.value))
    if Float(value) != sender.value { sender.value = Float(value) }
    report(value)
  }

  /// Sends a value the user picked, unless Flutter already has it (#137).
  private func report(_ value: Double) {
    guard value != lastReported else { return }
    lastReported = value
    channel.invokeMethod("valueChanged", arguments: ["value": value])
  }

  /// Snaps to `step` within the range.
  private func stepped(_ raw: Double) -> Double {
    let lo = Double(minValue)
    let hi = Double(maxValue)
    var value = Swift.max(lo, Swift.min(raw, hi))
    if step > 0 {
      value = lo + round((value - lo) / step) * step
      value = Swift.max(lo, Swift.min(value, hi))
    }
    return value
  }

  // MARK: - Gesture start / end (`onChangeStart`, `onChangeEnd`)

  @objc private func onTouchDown(_ sender: UISlider) {
    beginGesture()
  }

  @objc private func onTouchEnded(_ sender: UISlider) {
    endGesture()
  }

  private func beginGesture() {
    guard !inGesture else { return }
    inGesture = true
    channel.invokeMethod("changeStart", arguments: ["value": Double(slider.value)])
  }

  private func endGesture() {
    guard inGesture else { return }
    inGesture = false
    channel.invokeMethod("changeEnd", arguments: ["value": Double(slider.value)])
  }

  // MARK: - Tap to seek (`CNSlider.seekOnTap`)

  private func applySeekOnTap() {
    if seekOnTap {
      if seekTap.view == nil { slider.addGestureRecognizer(seekTap) }
    } else if seekTap.view != nil {
      slider.removeGestureRecognizer(seekTap)
    }
  }

  /// Moves the value to the tapped point. The tap is recognized before the
  /// slider's own touch ends, so a gesture the slider started (`.touchDown`)
  /// ends after the seek, with the new value; a tap the slider did not track
  /// gets its own start and end.
  @objc private func onSeekTap(_ recognizer: UITapGestureRecognizer) {
    guard recognizer.state == .ended, slider.isEnabled, maxValue > minValue else { return }
    let value = stepped(valueAt(recognizer.location(in: slider).x))
    let tracked = inGesture
    if !tracked { beginGesture() }
    slider.setValue(Float(value), animated: true)
    report(value)
    if !tracked { endGesture() }
  }

  /// The value under `x`: the thumb's centre travels between its positions
  /// at the minimum and the maximum; a thumbless slider uses its track.
  private func valueAt(_ x: CGFloat) -> Double {
    let bounds = slider.bounds
    let track = slider.trackRect(forBounds: bounds)
    var lo = track.minX
    var hi = track.maxX
    let thumbAtMin = slider.thumbRect(forBounds: bounds, trackRect: track, value: minValue)
    let thumbAtMax = slider.thumbRect(forBounds: bounds, trackRect: track, value: maxValue)
    if thumbAtMin.width > 1, thumbAtMax.midX - thumbAtMin.midX > 1 {
      lo = thumbAtMin.midX
      hi = thumbAtMax.midX
    }
    guard hi > lo else { return Double(slider.value) }
    var fraction = Double((x - lo) / (hi - lo))
    if slider.effectiveUserInterfaceLayoutDirection == .rightToLeft { fraction = 1 - fraction }
    fraction = Swift.max(0, Swift.min(fraction, 1))
    return Double(minValue) + fraction * Double(maxValue - minValue)
  }

  // Use shared utility functions
  private static func colorFromARGB(_ argb: Int) -> UIColor {
    return ImageUtils.colorFromARGB(argb)
  }

  private func _cnSetInteractiveRecursive(_ view: UIView?, _ interactive: Bool) {
    guard let view = view else { return }
    view.isUserInteractionEnabled = interactive
    for sub in view.subviews { _cnSetInteractiveRecursive(sub, interactive) }
  }
}
