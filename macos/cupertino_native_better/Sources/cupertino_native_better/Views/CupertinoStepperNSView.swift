import FlutterMacOS
import Cocoa

class CupertinoStepperNSView: NSView {
  private let channel: FlutterMethodChannel
  private let stepper: NSStepper

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeStepper_\(viewId)", binaryMessenger: messenger)
    self.stepper = NSStepper(frame: .zero)

    var value: Double = 0
    var minValue: Double = 0
    var maxValue: Double = 100
    var step: Double = 1
    var wraps = false
    var autorepeat = true
    var enabled = true
    var isDark = false
    var semanticLabel: String? = nil

    if let dict = args as? [String: Any] {
      if let v = dict["value"] as? NSNumber { value = v.doubleValue }
      if let v = dict["min"] as? NSNumber { minValue = v.doubleValue }
      if let v = dict["max"] as? NSNumber { maxValue = v.doubleValue }
      if let v = dict["step"] as? NSNumber { step = v.doubleValue }
      if let v = dict["wraps"] as? NSNumber { wraps = v.boolValue }
      if let v = dict["autorepeat"] as? NSNumber { autorepeat = v.boolValue }
      if let v = dict["enabled"] as? NSNumber { enabled = v.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let v = dict["semanticLabel"] as? String, !v.isEmpty { semanticLabel = v }
    }

    super.init(frame: .zero)

    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    stepper.minValue = minValue
    stepper.maxValue = maxValue
    if step > 0 { stepper.increment = step }
    stepper.valueWraps = wraps
    stepper.autorepeat = autorepeat
    stepper.doubleValue = value
    stepper.isEnabled = enabled
    // What VoiceOver reads before the value (`CNStepper.semanticLabel`).
    // NSStepper already reports its value and increment/decrement actions.
    stepper.setAccessibilityLabel(semanticLabel)
    stepper.target = self
    stepper.action = #selector(onValueChanged(_:))

    // NSStepper keeps its own size, centred in the box Flutter gives it.
    stepper.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stepper)
    NSLayoutConstraint.activate([
      stepper.centerXAnchor.constraint(equalTo: centerXAnchor),
      stepper.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "setValue":
        if let value = (args?["value"] as? NSNumber)?.doubleValue {
          self.stepper.doubleValue = value
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing value", details: nil)) }
      case "setRange":
        if let min = (args?["min"] as? NSNumber)?.doubleValue,
           let max = (args?["max"] as? NSNumber)?.doubleValue, min < max {
          self.stepper.minValue = min
          self.stepper.maxValue = max
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing min/max", details: nil)) }
      case "setStep":
        if let step = (args?["step"] as? NSNumber)?.doubleValue, step > 0 {
          self.stepper.increment = step
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing step", details: nil)) }
      case "setOptions":
        if let wraps = (args?["wraps"] as? NSNumber)?.boolValue { self.stepper.valueWraps = wraps }
        if let autorepeat = (args?["autorepeat"] as? NSNumber)?.boolValue { self.stepper.autorepeat = autorepeat }
        result(nil)
      case "setEnabled":
        if let enabled = (args?["enabled"] as? NSNumber)?.boolValue {
          self.stepper.isEnabled = enabled
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setSemanticLabel":
        let label = args?["label"] as? String
        self.stepper.setAccessibilityLabel((label?.isEmpty ?? true) ? nil : label)
        result(nil)
      case "setStyle":
        // NSStepper has no tint; `CNStepper.color` applies on iOS only.
        result(nil)
      case "setInteractive":
        result(nil)
      case "setBrightness":
        if let isDark = (args?["isDark"] as? NSNumber)?.boolValue {
          self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) {
    return nil
  }

  @objc private func onValueChanged(_ sender: NSStepper) {
    channel.invokeMethod("valueChanged", arguments: ["value": sender.doubleValue])
  }
}
