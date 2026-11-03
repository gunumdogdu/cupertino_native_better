import Flutter
import UIKit

/// The platform view's root view. It reports each touch that reaches it
/// without taking part in handling it: a tap recognizer on the well kept
/// iOS 26.2 from opening the picker.
private final class TouchReportingView: UIView {
  var onTouch: (() -> Void)?

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hit = super.hitTest(point, with: event)
    if hit != nil, event?.type == .touches { onTouch?() }
    return hit
  }
}

/// UIColorWell ignores an assigned accessibilityLabel and always reads
/// "Color"; this one reads `CNColorWell.semanticLabel` when there is one.
private final class LabeledColorWell: UIColorWell {
  private var semanticLabel: String?

  override var accessibilityLabel: String? {
    get { semanticLabel ?? super.accessibilityLabel }
    set { semanticLabel = newValue }
  }
}

class CupertinoColorWellPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let container: TouchReportingView
  private let colorWell: LabeledColorWell
  /// True while Dart sets the colour, so that change is not reported back.
  private var settingFromDart = false
  /// True while looking for the picker a touch opens.
  private var matchingPicker = false

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeColorWell_\(viewId)", binaryMessenger: messenger)
    self.container = TouchReportingView(frame: frame)
    self.colorWell = LabeledColorWell(frame: .zero)

    var color: UIColor = .systemBlue
    var supportsAlpha = true
    var supportsEyedropper = true
    var title: String? = nil
    var enabled = true
    var isDark = false
    var semanticLabel: String? = nil

    if let dict = args as? [String: Any] {
      if let v = dict["color"] as? NSNumber { color = ImageUtils.colorFromARGB(v.intValue) }
      if let v = dict["supportsAlpha"] as? NSNumber { supportsAlpha = v.boolValue }
      if let v = dict["supportsEyedropper"] as? NSNumber { supportsEyedropper = v.boolValue }
      if let v = dict["title"] as? String { title = v }
      if let v = dict["enabled"] as? NSNumber { enabled = v.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let v = dict["semanticLabel"] as? String, !v.isEmpty { semanticLabel = v }
    }

    super.init()

    container.backgroundColor = .clear
    container.overrideUserInterfaceStyle = isDark ? .dark : .light

    applyOptions(supportsAlpha: supportsAlpha, supportsEyedropper: supportsEyedropper, title: title)
    if #available(iOS 26.0, *) {
      // Colours reach Dart as 8-bit sRGB, which has no room for HDR
      // brightness; keep the picker to standard dynamic range.
      colorWell.maximumLinearExposure = 1
    }
    setColor(color)
    setEnabled(enabled)
    // What VoiceOver reads for the well (`CNColorWell.semanticLabel`).
    colorWell.accessibilityLabel = semanticLabel

    // The well fills the box Flutter gives it; it draws its ring to fit.
    colorWell.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(colorWell)
    NSLayoutConstraint.activate([
      colorWell.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      colorWell.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      colorWell.topAnchor.constraint(equalTo: container.topAnchor),
      colorWell.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])

    // UIColorWell presents UIColorPickerViewController itself, from the view
    // controller it finds up the responder chain: the FlutterViewController
    // that hosts this platform view. It sends .valueChanged for every
    // colour the user picks, continuously while dragging.
    colorWell.addTarget(self, action: #selector(onColorChanged(_:)), for: .valueChanged)
    // The picker is presented by the FlutterViewController, so it takes the
    // system appearance; it gets the app's, which this view carries. The
    // well opens it from its own gesture and sends no control event, so the
    // root view tells when a touch reaches it.
    container.onTouch = { [weak self] in self?.startMatchingPicker() }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "setColor":
        if let argb = (args?["color"] as? NSNumber)?.intValue {
          self.setColor(ImageUtils.colorFromARGB(argb))
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing color", details: nil)) }
      case "setOptions":
        self.applyOptions(
          supportsAlpha: (args?["supportsAlpha"] as? NSNumber)?.boolValue ?? self.colorWell.supportsAlpha,
          supportsEyedropper: (args?["supportsEyedropper"] as? NSNumber)?.boolValue ?? true,
          title: args?["title"] as? String
        )
        result(nil)
      case "setEnabled":
        if let enabled = (args?["enabled"] as? NSNumber)?.boolValue {
          self.setEnabled(enabled)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setSemanticLabel":
        let label = args?["label"] as? String
        self.colorWell.accessibilityLabel = (label?.isEmpty ?? true) ? nil : label
        result(nil)
      case "setBrightness":
        if let isDark = (args?["isDark"] as? NSNumber)?.boolValue {
          self.container.overrideUserInterfaceStyle = isDark ? .dark : .light
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setInteractive":
        // Issue #53 follow-up: only isUserInteractionEnabled blocks native
        // touches while a Flutter modal is up.
        if let interactive = (args?["interactive"] as? NSNumber)?.boolValue {
          self.container.isUserInteractionEnabled = interactive
          self.colorWell.isUserInteractionEnabled = interactive
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  private func setColor(_ color: UIColor) {
    settingFromDart = true
    colorWell.selectedColor = color
    settingFromDart = false
  }

  /// UIColorWell draws no disabled state on iOS 26+ (a disabled well looks
  /// the same and only ignores taps), so it is dimmed here, like the
  /// Flutter fallback.
  private func setEnabled(_ enabled: Bool) {
    colorWell.isEnabled = enabled
    colorWell.alpha = enabled ? 1 : 0.4
  }

  private func applyOptions(supportsAlpha: Bool, supportsEyedropper: Bool, title: String?) {
    colorWell.supportsAlpha = supportsAlpha
    colorWell.title = title
    if #available(iOS 26.0, *) {
      colorWell.supportsEyedropper = supportsEyedropper
    }
  }

  /// Hit-testing can report one touch more than once.
  private func startMatchingPicker() {
    guard !matchingPicker else { return }
    matchingPicker = true
    matchPickerAppearance(tries: 30)
  }

  /// Gives the colour picker presented above this view the well's
  /// appearance.
  private func matchPickerAppearance(tries: Int) {
    var controller = container.window?.rootViewController
    while let presented = controller?.presentedViewController {
      if NSStringFromClass(type(of: presented)).contains("ColorPicker") {
        presented.overrideUserInterfaceStyle = container.overrideUserInterfaceStyle
        matchingPicker = false
        return
      }
      controller = presented
    }
    // The well presents the picker a moment after the tap ends.
    guard tries > 1 else { matchingPicker = false; return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      self?.matchPickerAppearance(tries: tries - 1)
    }
  }

  @objc private func onColorChanged(_ sender: UIColorWell) {
    guard !settingFromDart, let color = sender.selectedColor else { return }
    channel.invokeMethod("colorChanged", arguments: ["color": Self.srgbARGB(color)])
  }

  /// Converts a picked colour to 8-bit sRGB ARGB. The picker can return
  /// Display P3 or extended-range sRGB colours, whose components fall
  /// outside 0...1 in sRGB; they are converted to sRGB with relative
  /// colorimetric intent, which maps them into its gamut, and clamped.
  static func srgbARGB(_ color: UIColor) -> Int {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
    if let srgb = CGColorSpace(name: CGColorSpace.sRGB),
       let converted = color.cgColor.converted(to: srgb, intent: .relativeColorimetric, options: nil),
       let c = converted.components, c.count >= 4 {
      (r, g, b, a) = (c[0], c[1], c[2], c[3])
    } else {
      // Extended sRGB components, clamped below.
      color.getRed(&r, green: &g, blue: &b, alpha: &a)
    }
    func channel(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
    return (channel(a) << 24) | (channel(r) << 16) | (channel(g) << 8) | channel(b)
  }
}
