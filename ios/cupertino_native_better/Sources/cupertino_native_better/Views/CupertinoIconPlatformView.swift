import Flutter
import UIKit
import SVGKit

class CupertinoIconPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let container: UIView
  private let imageView: UIImageView

  private var name: String = ""
  private var customIconBytes: Data?
  private var assetPath: String?
  private var imageData: Data?
  private var imageFormat: String?
  private var iconScale: CGFloat = UIScreen.main.scale
  private var isDark: Bool = false
  private var size: CGFloat?
  private var color: UIColor?
  private var palette: [UIColor] = []
  private var renderingMode: String?
  private var gradientEnabled: Bool = false
  /// The running symbol effect (`CNIcon.effect`), as `CNSymbolEffect.toMap()`.
  private var symbolEffect: [String: Any]?
  /// How a change of SF Symbol animates (`CNIcon.replaceTransition`); nil
  /// swaps it at once.
  private var replaceTransition: String?
  /// The SF Symbol shown now, so a replace transition plays only when the
  /// symbol itself changes, not on a colour or size change.
  private var shownSymbolName: String?

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeIcon_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)
    self.imageView = UIImageView(frame: .zero)

    if let dict = args as? [String: Any] {
      if let s = dict["name"] as? String { self.name = s }
      if let data = dict["customIconBytes"] as? FlutterStandardTypedData {
        self.customIconBytes = data.data
      }
      if let path = dict["assetPath"] as? String { self.assetPath = path }
      if let data = dict["imageData"] as? FlutterStandardTypedData {
        self.imageData = data.data
      }
      if let format = dict["imageFormat"] as? String { self.imageFormat = format }
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
    }

    super.init()

    container.backgroundColor = .clear
    if #available(iOS 13.0, *) {
      container.overrideUserInterfaceStyle = isDark ? .dark : .light
    }

    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.contentMode = .scaleAspectFit
    container.addSubview(imageView)
    NSLayoutConstraint.activate([
      imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      imageView.topAnchor.constraint(equalTo: container.topAnchor),
      imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
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
        if let args = call.arguments as? [String: Any] {
          // Handle imageAsset properties first (priority over SF Symbol)
          if let assetPath = args["assetPath"] as? String, !assetPath.isEmpty {
            self.assetPath = assetPath
            self.imageData = nil
            self.imageFormat = nil
          } else if let imageData = args["imageData"] as? FlutterStandardTypedData {
            self.imageData = imageData.data
            self.imageFormat = args["imageFormat"] as? String
            self.assetPath = nil
          } else if let name = args["name"] as? String {
            // Fallback to SF Symbol
            self.name = name
            self.assetPath = nil
            self.imageData = nil
            self.imageFormat = nil
          }
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
          // Handle imageAsset properties
          if let assetPath = args["assetPath"] as? String, !assetPath.isEmpty {
            self.assetPath = assetPath
            self.imageData = nil
            self.imageFormat = nil
          } else if let imageData = args["imageData"] as? FlutterStandardTypedData {
            self.imageData = imageData.data
            self.imageFormat = args["imageFormat"] as? String
            self.assetPath = nil
          } else if let n = args["name"] as? String {
            // Handle SF Symbol name in style update
            self.name = n
            self.assetPath = nil
            self.imageData = nil
            self.imageFormat = nil
          }
          self.rebuild()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          if #available(iOS 13.0, *) {
            self.container.overrideUserInterfaceStyle = isDark ? .dark : .light
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setSymbolEffect":
        let effect = (call.arguments as? [String: Any])?["effect"] as? [String: Any]
        let old = self.symbolEffect
        self.symbolEffect = effect
        if #available(iOS 17.0, *), self.imageView.image?.isSymbolImage == true {
          SymbolEffectPlayer.transition(from: old, to: effect, on: self.imageView)
        }
        result(nil)
      case "playSymbolEffect":
        if let effect = (call.arguments as? [String: Any])?["effect"] as? [String: Any],
           #available(iOS 17.0, *), self.imageView.image?.isSymbolImage == true {
          SymbolEffectPlayer.play(effect, on: self.imageView)
        }
        result(nil)
      case "setReplaceTransition":
        self.replaceTransition = (call.arguments as? [String: Any])?["transition"] as? String
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  private func rebuild() {
    var img: UIImage? = nil
    
    // Priority: imageData > assetPath > customIconBytes > SF Symbol
    if let data = imageData {
      // Raw image data (PNG, SVG, etc.)
      img = Self.createImageFromData(data, format: imageFormat, scale: iconScale)
    } else if let path = assetPath {
      // Flutter asset path
      img = Self.loadFlutterAsset(path)
    } else if let data = customIconBytes {
      // Legacy custom icon bytes (PNG from IconData)
      img = UIImage(data: data, scale: self.iconScale)?.withRenderingMode(.alwaysTemplate)
    } else if !name.isEmpty {
      // SF Symbol
      img = UIImage(systemName: name)
    }
    
    guard var image = img else {
      imageView.image = nil
      shownSymbolName = nil
      return
    }

    // Apply size configuration
    if let s = size {
      let cfg = UIImage.SymbolConfiguration(pointSize: s)
      if let newImg = image.applyingSymbolConfiguration(cfg) { image = newImg }
    }

    if let mode = renderingMode {
      switch mode {
      case "monochrome":
        if #available(iOS 13.0, *) {
          if let c = color {
            image = image.withTintColor(c, renderingMode: .alwaysOriginal)
          } else {
            image = image.withTintColor(.black, renderingMode: .alwaysOriginal)
          }
        }
      case "hierarchical":
        if #available(iOS 15.0, *), let c = color {
          let cfg = UIImage.SymbolConfiguration(hierarchicalColor: c)
          if let newImg = image.applyingSymbolConfiguration(cfg) { image = newImg }
        }
      case "palette":
        if #available(iOS 15.0, *), !palette.isEmpty {
          let cfg = UIImage.SymbolConfiguration(paletteColors: palette)
          if let newImg = image.applyingSymbolConfiguration(cfg) { image = newImg }
        }
      case "multicolor":
        if #available(iOS 15.0, *) {
          let cfg = UIImage.SymbolConfiguration.preferringMulticolor()
          if let newImg = image.applyingSymbolConfiguration(cfg) { image = newImg }
        }
      default:
        break
      }
    } else if let c = color {
      if #available(iOS 13.0, *) {
        image = image.withTintColor(c, renderingMode: .alwaysOriginal)
      }
    } else {
      // Default to black instead of system tint blue when no color/mode provided
      if #available(iOS 13.0, *) {
        image = image.withTintColor(.black, renderingMode: .alwaysOriginal)
      }
    }

    if gradientEnabled {
      // Future: prefer built-in gradient when available on newer OS versions.
      // if #available(iOS 18.0, *), let cfg = UIImage.SymbolConfiguration.preferringGradient() { image = image.applyingSymbolConfiguration(cfg) ?? image }
    }

    // Only an SF Symbol replacing another one animates; anything else, and
    // every first image, is set directly.
    let symbolName: String? = (imageData == nil && assetPath == nil && customIconBytes == nil && !name.isEmpty) ? name : nil
    if #available(iOS 17.0, *), let transition = replaceTransition,
       let newName = symbolName, let oldName = shownSymbolName, newName != oldName,
       imageView.image?.isSymbolImage == true, image.isSymbolImage {
      // The running effect carries over to the new symbol.
      SymbolEffectPlayer.replace(with: image, on: imageView, transition: transition)
    } else {
      imageView.image = image
      restartSymbolEffect()
    }
    shownSymbolName = symbolName
  }

  /// A new image stops the running symbol effect, and adding it again is
  /// ignored while it is still registered, so remove it and start it again.
  /// `drawOff` restarts without animation, so the symbol stays hidden; a
  /// finished `drawOn` needs nothing, as the new image is already visible.
  private func restartSymbolEffect() {
    guard let effect = symbolEffect, effect["type"] as? String != "drawOn",
          #available(iOS 17.0, *), imageView.image?.isSymbolImage == true else { return }
    imageView.removeAllSymbolEffects(animated: false)
    SymbolEffectPlayer.start(effect, on: imageView, animated: effect["type"] as? String != "drawOff")
  }

  // Use shared utility functions
  private static func colorFromARGB(_ argb: Int) -> UIColor {
    return ImageUtils.colorFromARGB(argb)
  }

  private static func loadFlutterAsset(_ assetPath: String) -> UIImage? {
    return ImageUtils.loadFlutterAsset(assetPath)
  }

  private static func createImageFromData(_ data: Data, format: String?, scale: CGFloat) -> UIImage? {
    return ImageUtils.createImageFromData(data, format: format, scale: scale)
  }
}
