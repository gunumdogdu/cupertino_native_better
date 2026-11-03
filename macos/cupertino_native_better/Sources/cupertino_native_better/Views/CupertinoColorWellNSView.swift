import FlutterMacOS
import Cocoa

class CupertinoColorWellNSView: NSView {
  private let channel: FlutterMethodChannel
  private let colorWell: NSColorWell

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeColorWell_\(viewId)", binaryMessenger: messenger)
    // The minimal style is a compact swatch that opens the system colour
    // popover, the closest to UIColorWell. Before macOS 13 there is only the
    // bordered well that opens the shared colour panel.
    if #available(macOS 13.0, *) {
      self.colorWell = NSColorWell(style: .minimal)
    } else {
      self.colorWell = NSColorWell(frame: .zero)
    }

    var color: NSColor = .systemBlue
    var supportsAlpha = true
    var enabled = true
    var isDark = false
    var semanticLabel: String? = nil

    if let dict = args as? [String: Any] {
      if let v = dict["color"] as? NSNumber { color = Self.colorFromARGB(v.intValue) }
      if let v = dict["supportsAlpha"] as? NSNumber { supportsAlpha = v.boolValue }
      if let v = dict["enabled"] as? NSNumber { enabled = v.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let v = dict["semanticLabel"] as? String, !v.isEmpty { semanticLabel = v }
    }

    super.init(frame: .zero)

    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    colorWell.color = color
    applySupportsAlpha(supportsAlpha)
    if #available(macOS 26.0, *) {
      // Colours reach Dart as 8-bit sRGB, which has no room for HDR
      // brightness; keep the picker to standard dynamic range.
      colorWell.maximumLinearExposure = 1
    }
    colorWell.isEnabled = enabled
    // What VoiceOver reads for the well (`CNColorWell.semanticLabel`).
    colorWell.setAccessibilityLabel(semanticLabel)
    // Setting `color` in code does not send the action, so Dart's own
    // changes are not reported back.
    colorWell.target = self
    colorWell.action = #selector(onColorChanged(_:))

    colorWell.translatesAutoresizingMaskIntoConstraints = false
    addSubview(colorWell)
    NSLayoutConstraint.activate([
      colorWell.leadingAnchor.constraint(equalTo: leadingAnchor),
      colorWell.trailingAnchor.constraint(equalTo: trailingAnchor),
      colorWell.topAnchor.constraint(equalTo: topAnchor),
      colorWell.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "setColor":
        if let argb = (args?["color"] as? NSNumber)?.intValue {
          self.colorWell.color = Self.colorFromARGB(argb)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing color", details: nil)) }
      case "setOptions":
        // `title` and `supportsEyedropper` have no NSColorWell counterpart.
        if let supportsAlpha = (args?["supportsAlpha"] as? NSNumber)?.boolValue {
          self.applySupportsAlpha(supportsAlpha)
        }
        result(nil)
      case "setEnabled":
        if let enabled = (args?["enabled"] as? NSNumber)?.boolValue {
          self.colorWell.isEnabled = enabled
          if !enabled { self.colorWell.deactivate() }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setSemanticLabel":
        let label = args?["label"] as? String
        self.colorWell.setAccessibilityLabel((label?.isEmpty ?? true) ? nil : label)
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

  override func removeFromSuperview() {
    // The colour panel is shared by the app; stop it sending this removed
    // well's colour changes.
    colorWell.deactivate()
    super.removeFromSuperview()
  }

  private func applySupportsAlpha(_ supportsAlpha: Bool) {
    if #available(macOS 14.0, *) {
      colorWell.supportsAlpha = supportsAlpha
    }
  }

  @objc private func onColorChanged(_ sender: NSColorWell) {
    channel.invokeMethod("colorChanged", arguments: ["color": Self.srgbARGB(sender.color)])
  }

  private static func colorFromARGB(_ argb: Int) -> NSColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
  }

  /// Converts a picked colour to 8-bit sRGB ARGB. The colour panel can
  /// return colours in Display P3, generic or catalogue colour spaces; they
  /// are converted to sRGB, which maps them into its gamut, and clamped.
  private static func srgbARGB(_ color: NSColor) -> Int {
    let srgb = color.usingColorSpace(.sRGB) ?? color.usingColorSpace(.extendedSRGB)
    let r = srgb?.redComponent ?? 0
    let g = srgb?.greenComponent ?? 0
    let b = srgb?.blueComponent ?? 0
    let a = srgb?.alphaComponent ?? 1
    func channel(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
    return (channel(a) << 24) | (channel(r) << 16) | (channel(g) << 8) | channel(b)
  }
}
