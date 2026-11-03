import Flutter
import UIKit

class CupertinoColorWellPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let container: UIView
  private let colorWell: UIColorWell
  /// True while Dart sets the colour, so that change is not reported back.
  private var settingFromDart = false

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeColorWell_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)
    self.colorWell = UIColorWell(frame: .zero)

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
