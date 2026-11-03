import FlutterMacOS
import Cocoa

class CupertinoIconNSView: NSView {
  private let channel: FlutterMethodChannel
  private let imageView: NSImageView

  private var name: String = ""
  private var isDark: Bool = false
  private var size: CGFloat?
  private var color: NSColor?
  private var palette: [NSColor] = []
  private var renderingMode: String?
  private var gradientEnabled: Bool = false
  /// The running symbol effect (`CNIcon.effect`), as `CNSymbolEffect.toMap()`.
  private var symbolEffect: [String: Any]?
  /// How a change of SF Symbol animates (`CNIcon.replaceTransition`); nil
  /// swaps it at once.
  private var replaceTransition: String?
  /// The SF Symbol shown now, so a replace transition plays only when the
  /// symbol itself changes.
  private var shownSymbolName: String?
  /// Set once the icon uses any symbol effect or replace transition. Symbol
  /// effects only play on symbol images, so from then on colour goes through
  /// `contentTintColor` instead of being painted into a bitmap copy.
  private var usesSymbolAnimation = false

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeIcon_\(viewId)", binaryMessenger: messenger)
    self.imageView = NSImageView(frame: .zero)

    if let dict = args as? [String: Any] {
      if let s = dict["name"] as? String { self.name = s }
      if let b = dict["isDark"] as? NSNumber { self.isDark = b.boolValue }
      if let style = dict["style"] as? [String: Any] {
        if let v = style["iconSize"] as? NSNumber { self.size = CGFloat(truncating: v) }
        if let v = style["iconColor"] as? NSNumber { self.color = Self.colorFromARGB(v.intValue) }
        if let arr = style["iconPaletteColors"] as? [NSNumber] { self.palette = arr.map { Self.colorFromARGB($0.intValue) } }
        if let mode = style["iconRenderingMode"] as? String { self.renderingMode = mode }
        if let g = style["iconGradientEnabled"] as? NSNumber { self.gradientEnabled = g.boolValue }
      }
      if let effect = dict["symbolEffect"] as? [String: Any] { self.symbolEffect = effect }
      if let t = dict["replaceTransition"] as? String { self.replaceTransition = t }
      self.usesSymbolAnimation = self.symbolEffect != nil || self.replaceTransition != nil
    }

    super.init(frame: .zero)

    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.imageScaling = .scaleProportionallyUpOrDown
    addSubview(imageView)
    NSLayoutConstraint.activate([
      imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
      imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
      imageView.topAnchor.constraint(equalTo: topAnchor),
      imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])

    // Also starts `symbolEffect`, if any.
    rebuild()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "getIntrinsicSize":
        if let img = self.imageView.image {
          result(["width": Double(img.size.width), "height": Double(img.size.height)])
        } else {
          result(["width": 0.0, "height": 0.0])
        }
      case "setSymbol":
        if let args = call.arguments as? [String: Any], let n = args["name"] as? String {
          self.name = n
          self.rebuild()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing name", details: nil)) }
      case "setStyle":
        if let args = call.arguments as? [String: Any] {
          if let v = args["iconSize"] as? NSNumber { self.size = CGFloat(truncating: v) }
          if let v = args["iconColor"] as? NSNumber { self.color = Self.colorFromARGB(v.intValue) }
          if let arr = args["iconPaletteColors"] as? [NSNumber] { self.palette = arr.map { Self.colorFromARGB($0.intValue) } }
          if let mode = args["iconRenderingMode"] as? String { self.renderingMode = mode }
          if let g = args["iconGradientEnabled"] as? NSNumber { self.gradientEnabled = g.boolValue }
          // Handle SF Symbol name in style update to prevent disappearing icons
          if let n = args["name"] as? String { self.name = n }
          self.rebuild()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setSymbolEffect":
        let effect = (call.arguments as? [String: Any])?["effect"] as? [String: Any]
        let old = self.symbolEffect
        self.symbolEffect = effect
        self.switchToSymbolAnimation()
        if #available(macOS 14.0, *) {
          SymbolEffectPlayer.transition(from: old, to: effect, on: self.imageView)
        }
        result(nil)
      case "playSymbolEffect":
        self.switchToSymbolAnimation()
        if let effect = (call.arguments as? [String: Any])?["effect"] as? [String: Any],
           #available(macOS 14.0, *) {
          SymbolEffectPlayer.play(effect, on: self.imageView)
        }
        result(nil)
      case "setReplaceTransition":
        self.replaceTransition = (call.arguments as? [String: Any])?["transition"] as? String
        self.switchToSymbolAnimation()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) { return nil }

  /// Redraws the symbol as a symbol image the first time an effect or a
  /// replace transition is used.
  private func switchToSymbolAnimation() {
    if usesSymbolAnimation { return }
    usesSymbolAnimation = true
    rebuild()
  }

  private func rebuild() {
    guard var image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
      imageView.image = nil
      shownSymbolName = nil
      return
    }

    if usesSymbolAnimation {
      showAnimatableSymbol(image)
      return
    }

    if let s = size {
      if #available(macOS 12.0, *) {
        let cfg = NSImage.SymbolConfiguration(pointSize: s, weight: .regular)
        image = image.withSymbolConfiguration(cfg) ?? image
      }
    }

    if let mode = renderingMode {
      switch mode {
      case "monochrome":
        if let c = color {
          image = image.tinted(with: c)
        } else {
          image = image.tinted(with: .black)
        }
      case "hierarchical":
        if #available(macOS 12.0, *), let c = color {
          let cfg = NSImage.SymbolConfiguration(hierarchicalColor: c)
          image = image.withSymbolConfiguration(cfg) ?? image
        }
      case "multicolor":
        if #available(macOS 12.0, *) {
          let cfg = NSImage.SymbolConfiguration.preferringMulticolor()
          image = image.withSymbolConfiguration(cfg) ?? image
        }
      case "palette":
        // Palette rendering is not fully supported per-icon in AppKit; best-effort with no-op here.
        break
      default:
        break
      }
    } else if let c = color {
      image = image.tinted(with: c)
    } else {
      // Default to black instead of system tint when no color/mode provided
      image = image.tinted(with: .black)
    }

    // Gradient toggle is no-op until supported natively on macOS

    imageView.image = image
    shownSymbolName = name
  }

  /// Shows `image` as a symbol image, coloured with `contentTintColor`, so
  /// symbol effects and replace transitions can play on it.
  private func showAnimatableSymbol(_ base: NSImage) {
    var image = base
    var tint: NSColor? = color ?? .black
    if let s = size, #available(macOS 12.0, *) {
      image = image.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: s, weight: .regular)) ?? image
    }
    switch renderingMode {
    case "hierarchical":
      if #available(macOS 12.0, *), let c = color {
        image = image.withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: c)) ?? image
        tint = nil
      }
    case "palette":
      if #available(macOS 12.0, *), !palette.isEmpty {
        image = image.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: palette)) ?? image
        tint = nil
      }
    case "multicolor":
      if #available(macOS 12.0, *) {
        image = image.withSymbolConfiguration(NSImage.SymbolConfiguration.preferringMulticolor()) ?? image
        tint = nil
      }
    default:
      break
    }
    imageView.contentTintColor = tint
    if #available(macOS 14.0, *), let transition = replaceTransition,
       let old = shownSymbolName, old != name, imageView.image != nil {
      SymbolEffectPlayer.replace(with: image, on: imageView, transition: transition)
    } else {
      imageView.image = image
    }
    shownSymbolName = name
    restartSymbolEffect()
  }

  /// A new image stops the running symbol effect, and adding it again is
  /// ignored while it is still registered, so remove it and start it again.
  /// `drawOff` restarts without animation, so the symbol stays hidden; a
  /// finished `drawOn` needs nothing, as the new image is already visible.
  private func restartSymbolEffect() {
    guard let effect = symbolEffect, effect["type"] as? String != "drawOn",
          #available(macOS 14.0, *) else { return }
    imageView.removeAllSymbolEffects(animated: false)
    SymbolEffectPlayer.start(effect, on: imageView, animated: effect["type"] as? String != "drawOff")
  }

}

private extension NSImage {
  func tinted(with color: NSColor) -> NSImage {
    let img = NSImage(size: size)
    img.lockFocus()
    let rect = NSRect(origin: .zero, size: size)
    color.set()
    rect.fill()
    draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)
    img.unlockFocus()
    return img
  }
}

private extension CupertinoIconNSView {
  static func colorFromARGB(_ argb: Int) -> NSColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
  }
}
