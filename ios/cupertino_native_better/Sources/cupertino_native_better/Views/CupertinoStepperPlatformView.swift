import Flutter
import UIKit
import SwiftUI

class CupertinoStepperPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let model: StepperModel
  private let hostingController: UIHostingController<CupertinoStepperView>

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "CupertinoNativeStepper_\(viewId)", binaryMessenger: messenger)
    self.channel = channel

    let model = StepperModel { newValue in
      channel.invokeMethod("valueChanged", arguments: ["value": newValue])
    }
    var isDark = false
    if let dict = args as? [String: Any] {
      if let v = dict["min"] as? NSNumber { model.min = v.doubleValue }
      if let v = dict["max"] as? NSNumber { model.max = v.doubleValue }
      if let v = dict["step"] as? NSNumber, v.doubleValue > 0 { model.step = v.doubleValue }
      if let v = dict["value"] as? NSNumber { model.value = v.doubleValue }
      if let v = dict["wraps"] as? NSNumber { model.wraps = v.boolValue }
      if let v = dict["autorepeat"] as? NSNumber { model.autorepeat = v.boolValue }
      if let v = dict["enabled"] as? NSNumber { model.enabled = v.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let v = dict["semanticLabel"] as? String { model.label = v }
      if let style = dict["style"] as? [String: Any], let n = style["tint"] as? NSNumber {
        model.tint = Color(ImageUtils.colorFromARGB(n.intValue))
      }
    }
    self.model = model

    self.hostingController = UIHostingController(rootView: CupertinoStepperView(model: model))
    self.hostingController.view.backgroundColor = .clear
    self.hostingController.view.isOpaque = false
    self.hostingController.overrideUserInterfaceStyle = isDark ? .dark : .light
    // Keep the keyboard from pushing the stepper upward (Issue #4, see
    // CupertinoSwitchPlatformView). This view is only created on iOS 26+.
    if #available(iOS 16.4, *) {
      self.hostingController.safeAreaRegions.remove(.keyboard)
    }

    super.init()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "setValue":
        if let value = (args?["value"] as? NSNumber)?.doubleValue {
          // Setting the model does not call onChange, so this does not echo
          // back to Dart.
          self.model.value = value
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing value", details: nil)) }
      case "setRange":
        if let min = (args?["min"] as? NSNumber)?.doubleValue,
           let max = (args?["max"] as? NSNumber)?.doubleValue {
          self.model.min = min
          self.model.max = max
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing min/max", details: nil)) }
      case "setStep":
        if let step = (args?["step"] as? NSNumber)?.doubleValue, step > 0 {
          self.model.step = step
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing step", details: nil)) }
      case "setOptions":
        if let wraps = (args?["wraps"] as? NSNumber)?.boolValue { self.model.wraps = wraps }
        if let autorepeat = (args?["autorepeat"] as? NSNumber)?.boolValue { self.model.autorepeat = autorepeat }
        result(nil)
      case "setEnabled":
        if let enabled = (args?["enabled"] as? NSNumber)?.boolValue {
          self.model.enabled = enabled
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setSemanticLabel":
        self.model.label = args?["label"] as? String ?? ""
        result(nil)
      case "setStyle":
        // A missing or null tint restores the system colour.
        self.model.tint = (args?["tint"] as? NSNumber).map { Color(ImageUtils.colorFromARGB($0.intValue)) }
        result(nil)
      case "setBrightness":
        if let isDark = (args?["isDark"] as? NSNumber)?.boolValue {
          self.hostingController.overrideUserInterfaceStyle = isDark ? .dark : .light
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setInteractive":
        // Issue #53 follow-up: only isUserInteractionEnabled blocks native
        // touches while a Flutter modal is up.
        if let interactive = (args?["interactive"] as? NSNumber)?.boolValue {
          self.hostingController.view.isUserInteractionEnabled = interactive
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { hostingController.view }
}

/// The native stepper: a SwiftUI `Stepper` rather than a `UIStepper`.
///
/// On iOS 26+ both draw the same system stepper, but `UIStepper` ignores
/// `tintColor` and custom increment/decrement images there, and neither
/// draws a disabled state for the whole control; only a button that cannot
/// step further is dimmed. The SwiftUI stepper takes a colour, and the
/// dimming is driven here by giving no action to a button that must not
/// step: at a limit, and both buttons while disabled. Wrapping and turning
/// autorepeat off, which SwiftUI's stepper has no options for, are done in
/// [StepperModel].
struct CupertinoStepperView: View {
  @ObservedObject var model: StepperModel

  @ViewBuilder
  var body: some View {
    // The label is hidden on screen but is what VoiceOver reads before the
    // value (`CNStepper.semanticLabel`). VoiceOver's swipe up/down runs the
    // same actions as a tap.
    let stepper = Stepper(
      model.label,
      onIncrement: model.canStep(1) ? { model.step(1) } : nil,
      onDecrement: model.canStep(-1) ? { model.step(-1) } : nil,
      onEditingChanged: { model.pressChanged($0) }
    )
    .labelsHidden()
    .disabled(!model.enabled)
    // The stepper does not read out the number it changes.
    .accessibilityValue(Text(model.formattedValue))
    .ignoresSafeArea(.keyboard)

    // The system stepper takes its colour from the foreground style (the
    // symbols, and a light wash of it on the capsule); `.tint` has no
    // effect on it.
    if let tint = model.tint {
      stepper.foregroundStyle(tint)
    } else {
      stepper
    }
  }
}

final class StepperModel: ObservableObject {
  @Published var value: Double = 0
  @Published var min: Double = 0
  @Published var max: Double = 100
  @Published var step: Double = 1
  @Published var wraps = false
  @Published var autorepeat = true
  @Published var enabled = true
  @Published var tint: Color? = nil
  @Published var label = ""
  let onChange: (Double) -> Void

  /// Whether a finger is on the stepper, and how many steps it has made.
  private var pressing = false
  private var stepsThisPress = 0

  init(onChange: @escaping (Double) -> Void) {
    self.onChange = onChange
  }

  /// Whether the button for [direction] (1 or -1) can step.
  func canStep(_ direction: Double) -> Bool {
    guard enabled else { return false }
    if wraps { return true }
    return direction > 0 ? value < max : value > min
  }

  /// One step in [direction], wrapping or stopping at the ends like
  /// `UIStepper`.
  func step(_ direction: Double) {
    guard canStep(direction) else { return }
    // SwiftUI's stepper always repeats while held; without autorepeat only
    // the first step of a press counts.
    if pressing && !autorepeat && stepsThisPress > 0 { return }
    stepsThisPress += 1
    var next = value + direction * step
    if next > max { next = wraps ? min : max }
    if next < min { next = wraps ? max : min }
    // Drop floating-point noise, so 0.1 + 0.2 stays 0.3.
    next = (next * 1e9).rounded() / 1e9
    guard next != value else { return }
    value = next
    onChange(next)
  }

  func pressChanged(_ pressing: Bool) {
    self.pressing = pressing
    stepsThisPress = 0
  }

  /// The value in the user's locale with as many decimals as [step] has
  /// (none for whole steps), so 1.5 reads "1.5" and 3 reads "3".
  var formattedValue: String {
    var decimals = 0
    var scaled = step
    while decimals < 6 && abs(scaled - scaled.rounded()) > 1e-9 {
      scaled *= 10
      decimals += 1
    }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = decimals
    formatter.maximumFractionDigits = decimals
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
  }
}
