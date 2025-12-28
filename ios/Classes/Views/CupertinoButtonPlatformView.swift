import Flutter
import UIKit
import SwiftUI

class CupertinoButtonPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let container: UIView
  private var button: UIButton?
  private var hostingController: UIHostingController<AnyView>?
  private var badgeView: UIView?
  private var badgeLabel: UILabel?
  private var isEnabled: Bool = true
  private var currentButtonStyle: String = "automatic"
  private var usesSwiftUI: Bool = false
  private var makeRound: Bool = false

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeButton_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)
    self.button = UIButton(type: .system)

    var title: String? = nil
    var iconName: String? = nil
    var customIconBytes: Data? = nil
    var assetPath: String? = nil
    var imageData: Data? = nil
    var imageFormat: String? = nil
    var iconSize: CGFloat? = nil
    var iconColor: UIColor? = nil
    var makeRound: Bool = false
    var isDark: Bool = false
    var tint: UIColor? = nil
    var buttonStyle: String = "automatic"
    var enabled: Bool = true
    var iconMode: String? = nil
    var iconPalette: [NSNumber] = []
    var iconScale: CGFloat = UIScreen.main.scale
    var imagePlacement: String = "leading"
    var imagePadding: CGFloat? = nil
    var paddingTop: CGFloat? = nil
    var paddingBottom: CGFloat? = nil
    var paddingLeft: CGFloat? = nil
    var paddingRight: CGFloat? = nil
    var paddingHorizontal: CGFloat? = nil
    var paddingVertical: CGFloat? = nil
    var borderRadius: CGFloat? = nil
    var minHeight: CGFloat? = nil
    var glassEffectUnionId: String? = nil
    var glassEffectId: String? = nil
    var glassEffectInteractive: Bool = false
    var badgeCount: Int? = nil

    if let dict = args as? [String: Any] {
      if let t = dict["buttonTitle"] as? String { title = t }
      if let data = dict["buttonCustomIconBytes"] as? FlutterStandardTypedData {
        customIconBytes = data.data
      }
      if let ap = dict["buttonAssetPath"] as? String { assetPath = ap }
      if let data = dict["buttonImageData"] as? FlutterStandardTypedData {
        imageData = data.data
      }
      if let f = dict["buttonImageFormat"] as? String { imageFormat = f }
      if let s = dict["buttonIconName"] as? String { iconName = s }
      if let s = dict["buttonIconSize"] as? NSNumber { iconSize = CGFloat(truncating: s) }
      if let c = dict["buttonIconColor"] as? NSNumber { iconColor = Self.colorFromARGB(c.intValue) }
      if let r = dict["round"] as? NSNumber {
        makeRound = r.boolValue
        self.makeRound = makeRound
      }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let style = dict["style"] as? [String: Any], let n = style["tint"] as? NSNumber { tint = Self.colorFromARGB(n.intValue) }
      if let bs = dict["buttonStyle"] as? String { buttonStyle = bs }
      if let e = dict["enabled"] as? NSNumber { enabled = e.boolValue }
      if let m = dict["buttonIconRenderingMode"] as? String { iconMode = m }
      if let pal = dict["buttonIconPaletteColors"] as? [NSNumber] { iconPalette = pal }
      if let ip = dict["imagePlacement"] as? String { imagePlacement = ip }
      if let ip = dict["imagePadding"] as? NSNumber { imagePadding = CGFloat(truncating: ip) }
      if let pt = dict["paddingTop"] as? NSNumber { paddingTop = CGFloat(truncating: pt) }
      if let pb = dict["paddingBottom"] as? NSNumber { paddingBottom = CGFloat(truncating: pb) }
      if let pl = dict["paddingLeft"] as? NSNumber { paddingLeft = CGFloat(truncating: pl) }
      if let pr = dict["paddingRight"] as? NSNumber { paddingRight = CGFloat(truncating: pr) }
      if let ph = dict["paddingHorizontal"] as? NSNumber { paddingHorizontal = CGFloat(truncating: ph) }
      if let pv = dict["paddingVertical"] as? NSNumber { paddingVertical = CGFloat(truncating: pv) }
      if let br = dict["borderRadius"] as? NSNumber { borderRadius = CGFloat(truncating: br) }
      if let mh = dict["minHeight"] as? NSNumber { minHeight = CGFloat(truncating: mh) }
      if let gueId = dict["glassEffectUnionId"] as? String { glassEffectUnionId = gueId }
      if let geId = dict["glassEffectId"] as? String { glassEffectId = geId }
      if let geInteractive = dict["glassEffectInteractive"] as? NSNumber { glassEffectInteractive = geInteractive.boolValue }
      if let bc = dict["badgeCount"] as? NSNumber { badgeCount = bc.intValue }
    }

    super.init()

    container.backgroundColor = .clear
    if #available(iOS 13.0, *) { container.overrideUserInterfaceStyle = isDark ? .dark : .light }

    // Create final image first (needed for both SwiftUI and UIKit paths)
    var finalImage: UIImage? = nil
    // Priority: imageAsset > customIconBytes > SF Symbol
    
    // Handle imageAsset (highest priority)
    if let path = assetPath, !path.isEmpty {
      let detectedFormat = ImageUtils.detectImageFormat(assetPath: path, providedFormat: imageFormat)
      let iconColorARGB: Int? = iconColor != nil ? ImageUtils.colorToARGB(iconColor!) : nil
      
      // Use utility function to load and optionally tint image
      if let argb = iconColorARGB, #available(iOS 13.0, *) {
        finalImage = ImageUtils.loadAndTintImage(
          from: path,
          iconSize: iconSize,
          iconColor: argb,
          providedFormat: imageFormat,
          scale: iconScale
        )
      } else {
        let size: CGSize? = iconSize != nil ? CGSize(width: iconSize!, height: iconSize!) : nil
        finalImage = ImageUtils.loadFlutterAsset(path, size: size, format: detectedFormat, scale: iconScale)
      }
      
      // If no color but size is specified, scale the image
      if finalImage != nil, iconColor == nil, let iconSize = iconSize {
        let targetSize = CGSize(width: iconSize, height: iconSize)
        if finalImage!.size != targetSize {
          finalImage = ImageUtils.scaleImage(finalImage!, to: targetSize, scale: iconScale)
        }
      }
    } else if let data = imageData {
      let format = imageFormat
      let iconColorARGB: Int? = iconColor != nil ? ImageUtils.colorToARGB(iconColor!) : nil
      
      // Use utility function to create and optionally tint image
      if let argb = iconColorARGB, #available(iOS 13.0, *) {
        finalImage = ImageUtils.createAndTintImage(
          from: data,
          iconSize: iconSize,
          iconColor: argb,
          providedFormat: format,
          scale: iconScale
        )
      } else {
        let size: CGSize? = iconSize != nil ? CGSize(width: iconSize!, height: iconSize!) : nil
        finalImage = ImageUtils.createImageFromData(data, format: format, size: size, scale: iconScale)
      }
    }
    
    // Handle custom icon bytes (medium priority)
    if finalImage == nil, let data = customIconBytes, var image = UIImage(data: data, scale: iconScale) {
      // Apply template rendering mode for tinting
      image = image.withRenderingMode(.alwaysTemplate)
      finalImage = image
    }
    
    // Handle SF Symbol (lowest priority)
    if finalImage == nil, let name = iconName, var image = UIImage(systemName: name) {
      if let sz = iconSize { image = image.applyingSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: sz)) ?? image }
      if let mode = iconMode {
        switch mode {
        case "hierarchical":
          if #available(iOS 15.0, *), let col = iconColor {
            let cfg = UIImage.SymbolConfiguration(hierarchicalColor: col)
            image = image.applyingSymbolConfiguration(cfg) ?? image
          }
        case "palette":
          if #available(iOS 15.0, *), !iconPalette.isEmpty {
            let cols = iconPalette.map { Self.colorFromARGB($0.intValue) }
            let cfg = UIImage.SymbolConfiguration(paletteColors: cols)
            image = image.applyingSymbolConfiguration(cfg) ?? image
          }
        case "multicolor":
          if #available(iOS 15.0, *) {
            let cfg = UIImage.SymbolConfiguration.preferringMulticolor()
            image = image.applyingSymbolConfiguration(cfg) ?? image
          }
        case "monochrome":
          if let col = iconColor, #available(iOS 13.0, *) {
            image = image.withTintColor(col, renderingMode: .alwaysOriginal)
          }
        default:
          break
        }
      } else if let col = iconColor, #available(iOS 13.0, *) {
        image = image.withTintColor(col, renderingMode: .alwaysOriginal)
      }
      finalImage = image
    }
    
    // Check if we should use SwiftUI for full glass effect support
    if #available(iOS 26.0, *), (glassEffectUnionId != nil || glassEffectId != nil) {
      usesSwiftUI = true
      setupSwiftUIButton(
        title: title,
        iconName: iconName,
        iconImage: finalImage,
        iconSize: iconSize ?? 20,
        iconColor: iconColor,
        tint: tint,
        isRound: makeRound,
        style: buttonStyle,
        enabled: enabled,
        glassEffectUnionId: glassEffectUnionId,
        glassEffectId: glassEffectId,
        glassEffectInteractive: glassEffectInteractive,
        borderRadius: borderRadius,
        paddingTop: paddingTop,
        paddingBottom: paddingBottom,
        paddingLeft: paddingLeft,
        paddingRight: paddingRight,
        paddingHorizontal: paddingHorizontal,
        paddingVertical: paddingVertical,
        minHeight: minHeight,
        spacing: imagePadding
      )
    } else {
      // Use UIKit button for standard implementation
      let uiButton = UIButton(type: .system)
      self.button = uiButton
      
      uiButton.translatesAutoresizingMaskIntoConstraints = false
      if let t = tint { uiButton.tintColor = t }
      else if #available(iOS 13.0, *) { uiButton.tintColor = .label }

      container.addSubview(uiButton)
      NSLayoutConstraint.activate([
        uiButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        uiButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        uiButton.topAnchor.constraint(equalTo: container.topAnchor),
        uiButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      ])
      
      applyButtonStyle(buttonStyle: buttonStyle, round: makeRound)
      currentButtonStyle = buttonStyle
      uiButton.isEnabled = enabled
      isEnabled = enabled
      
    // Calculate horizontal padding from individual padding values
    let calculatedHorizontalPadding: CGFloat? = {
      if let ph = paddingHorizontal {
        return ph
      } else if let pl = paddingLeft, let pr = paddingRight, pl == pr {
        return pl
      } else if let pl = paddingLeft {
        return pl
      } else if let pr = paddingRight {
        return pr
      }
      return nil
    }()
    
    setButtonContent(
      title: title,
      image: finalImage,
      iconOnly: (title == nil),
      imagePlacement: imagePlacement,
      imagePadding: imagePadding,
      horizontalPadding: calculatedHorizontalPadding
    )

    // Default system highlight/pressed behavior
      uiButton.addTarget(self, action: #selector(onPressed(_:)), for: .touchUpInside)
      uiButton.adjustsImageWhenHighlighted = true
      
      // Force layout update for proper first-time rendering
      // Similar to TabBar fix - ensures button is properly laid out before display
      DispatchQueue.main.async { [weak self, weak uiButton] in
        guard let self = self, let uiButton = uiButton else { return }
        self.container.setNeedsLayout()
        self.container.layoutIfNeeded()
        uiButton.setNeedsLayout()
        uiButton.layoutIfNeeded()
        // Force another update cycle for proper rendering
        DispatchQueue.main.async { [weak uiButton] in
          guard let uiButton = uiButton else { return }
          uiButton.setNeedsDisplay()
          uiButton.setNeedsLayout()
          uiButton.layoutIfNeeded()
        }
      }
    }

    // Add badge if badgeCount is provided
    if let count = badgeCount, count > 0 {
      addBadge(count: count)
    }

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "getIntrinsicSize":
        if usesSwiftUI {
          // For SwiftUI buttons, return estimated size
          // In a real implementation, you might want to measure the actual SwiftUI view
          result(["width": 80.0, "height": 32.0])
        } else if let button = self.button {
          let size = button.intrinsicContentSize
        result(["width": Double(size.width), "height": Double(size.height)])
        } else {
          result(["width": 80.0, "height": 32.0])
        }
      case "setStyle":
        if let args = call.arguments as? [String: Any] {
          if usesSwiftUI {
            // For SwiftUI buttons, style changes would require recreating the view
            // This is a limitation - in a production app, you might want to handle this differently
            result(nil)
          } else if let button = self.button {
          if let n = args["tint"] as? NSNumber {
              button.tintColor = Self.colorFromARGB(n.intValue)
            // Re-apply style so configuration picks up new base colors
              self.applyButtonStyle(buttonStyle: self.currentButtonStyle, round: self.makeRound)
          }
          if let bs = args["buttonStyle"] as? String {
            self.currentButtonStyle = bs
              self.applyButtonStyle(buttonStyle: bs, round: self.makeRound)
            }
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setEnabled":
        if let args = call.arguments as? [String: Any], let e = args["enabled"] as? NSNumber {
          self.isEnabled = e.boolValue
          if !usesSwiftUI, let button = self.button {
            button.isEnabled = self.isEnabled
          }
          // For SwiftUI buttons, disabled state is handled by the view itself
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setPressed":
        if let args = call.arguments as? [String: Any], let p = args["pressed"] as? NSNumber {
          if !usesSwiftUI, let button = self.button {
            button.isHighlighted = p.boolValue
          }
          // For SwiftUI buttons, pressed state is handled by the view itself
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing pressed", details: nil)) }
      case "setButtonTitle":
        if let args = call.arguments as? [String: Any], let t = args["title"] as? String {
          self.setButtonContent(title: t, image: nil, iconOnly: false, imagePlacement: nil, imagePadding: nil, horizontalPadding: nil)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing title", details: nil)) }
      case "setButtonIcon":
        if let args = call.arguments as? [String: Any] {
          var image: UIImage? = nil
          let size = CGSize(width: args["buttonIconSize"] as? CGFloat ?? 20, height: args["buttonIconSize"] as? CGFloat ?? 20)
          
          // Priority: imageAsset > customIconBytes > SF Symbol
          // Handle imageAsset properties first
          if let assetPath = args["buttonAssetPath"] as? String, !assetPath.isEmpty {
            let format = args["buttonImageFormat"] as? String
            let iconColorARGB = (args["buttonIconColor"] as? NSNumber)?.intValue
            
            // Use utility function to load and optionally tint image
            if let argb = iconColorARGB, #available(iOS 13.0, *) {
              image = ImageUtils.loadAndTintImage(
                from: assetPath,
                iconSize: size.width,
                iconColor: argb,
                providedFormat: format,
                scale: UIScreen.main.scale
              )
            } else {
              image = ImageUtils.loadFlutterAsset(assetPath, size: size, format: format, scale: UIScreen.main.scale)
            }
            
            // If no color but size is specified, scale the image
            if image != nil, iconColorARGB == nil, image!.size != size {
              image = ImageUtils.scaleImage(image!, to: size, scale: UIScreen.main.scale)
            }
          } else if let imageData = args["buttonImageData"] as? FlutterStandardTypedData {
            let format = args["buttonImageFormat"] as? String
            let iconColorARGB = (args["buttonIconColor"] as? NSNumber)?.intValue
            
            // Use utility function to create and optionally tint image
            if let argb = iconColorARGB, #available(iOS 13.0, *) {
              image = ImageUtils.createAndTintImage(
                from: imageData.data,
                iconSize: size.width,
                iconColor: argb,
                providedFormat: format,
                scale: UIScreen.main.scale
              )
            } else {
              image = ImageUtils.createImageFromData(imageData.data, format: format, size: size, scale: UIScreen.main.scale)
            }
          } else if let customIconBytes = args["buttonCustomIconBytes"] as? FlutterStandardTypedData {
            image = UIImage(data: customIconBytes.data, scale: UIScreen.main.scale)?.withRenderingMode(.alwaysTemplate)
          } else if let name = args["buttonIconName"] as? String {
            image = UIImage(systemName: name)
          }
          
          // Apply size and styling if image was found
          if let img = image {
            if let s = args["buttonIconSize"] as? NSNumber {
              image = img.applyingSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: CGFloat(truncating: s))) ?? img
            }
            if let mode = args["buttonIconRenderingMode"] as? String, let img0 = image {
              var img = img0
              switch mode {
              case "hierarchical":
                if #available(iOS 15.0, *), let c = args["buttonIconColor"] as? NSNumber {
                  let cfg = UIImage.SymbolConfiguration(hierarchicalColor: Self.colorFromARGB(c.intValue))
                  image = img.applyingSymbolConfiguration(cfg) ?? img
                }
              case "palette":
                if #available(iOS 15.0, *), let pal = args["buttonIconPaletteColors"] as? [NSNumber] {
                  let cols = pal.map { Self.colorFromARGB($0.intValue) }
                  let cfg = UIImage.SymbolConfiguration(paletteColors: cols)
                  image = img.applyingSymbolConfiguration(cfg) ?? img
                }
              case "multicolor":
                if #available(iOS 15.0, *) {
                  let cfg = UIImage.SymbolConfiguration.preferringMulticolor()
                  image = img.applyingSymbolConfiguration(cfg) ?? img
                }
              case "monochrome":
                if let c = args["buttonIconColor"] as? NSNumber, #available(iOS 13.0, *) {
                  image = img.withTintColor(Self.colorFromARGB(c.intValue), renderingMode: .alwaysOriginal)
                }
              default:
                break
              }
            } else if let c = args["buttonIconColor"] as? NSNumber, let img = image, #available(iOS 13.0, *) {
              image = img.withTintColor(Self.colorFromARGB(c.intValue), renderingMode: .alwaysOriginal)
            }
          }
          
          self.setButtonContent(title: nil, image: image, iconOnly: true, imagePlacement: nil, imagePadding: nil, horizontalPadding: nil)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing icon args", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          if #available(iOS 13.0, *) { self.container.overrideUserInterfaceStyle = isDark ? .dark : .light }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setImagePlacement":
        if let args = call.arguments as? [String: Any], let placement = args["placement"] as? String {
          if !usesSwiftUI, let button = self.button, #available(iOS 15.0, *) {
            var cfg = button.configuration ?? .plain()
            switch placement {
            case "leading": cfg.imagePlacement = .leading
            case "trailing": cfg.imagePlacement = .trailing
            case "top": cfg.imagePlacement = .top
            case "bottom": cfg.imagePlacement = .bottom
            default: cfg.imagePlacement = .leading
            }
            button.configuration = cfg
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing placement", details: nil)) }
      case "setImagePadding":
        if let args = call.arguments as? [String: Any], let padding = (args["padding"] as? NSNumber).map({ CGFloat(truncating: $0) }) {
          if !usesSwiftUI, let button = self.button, #available(iOS 15.0, *) {
            var cfg = button.configuration ?? .plain()
            cfg.imagePadding = padding
            button.configuration = cfg
          }
          result(nil)
        } else {
          // Clear padding if args is nil
          if !usesSwiftUI, let button = self.button, #available(iOS 15.0, *) {
            var cfg = button.configuration ?? .plain()
            cfg.imagePadding = 0
            button.configuration = cfg
          }
          result(nil)
        }
      case "setHorizontalPadding":
        if let args = call.arguments as? [String: Any], let padding = (args["padding"] as? NSNumber).map({ CGFloat(truncating: $0) }) {
          if !usesSwiftUI, let button = self.button {
          if #available(iOS 15.0, *) {
              var cfg = button.configuration ?? .plain()
            var insets = cfg.contentInsets
            insets.leading = padding
            insets.trailing = padding
            cfg.contentInsets = insets
              button.configuration = cfg
          } else {
              button.contentEdgeInsets = UIEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
            }
          }
          result(nil)
        } else {
          // Clear padding if args is nil
          if !usesSwiftUI, let button = self.button {
          if #available(iOS 15.0, *) {
              var cfg = button.configuration ?? .plain()
            var insets = cfg.contentInsets
            insets.leading = 0
            insets.trailing = 0
            cfg.contentInsets = insets
              button.configuration = cfg
          } else {
              button.contentEdgeInsets = .zero
            }
          }
          result(nil)
        }
      case "setBadgeCount":
        if let args = call.arguments as? [String: Any] {
          if let count = args["badgeCount"] as? NSNumber {
            let intCount = count.intValue
            if intCount > 0 {
              self.addBadge(count: intCount)
            } else {
              self.removeBadge()
            }
          } else {
            self.removeBadge()
          }
          result(nil)
        } else {
          self.removeBadge()
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  @available(iOS 26.0, *)
  private func setupSwiftUIButton(
    title: String?,
    iconName: String?,
    iconImage: UIImage?,
    iconSize: CGFloat,
    iconColor: UIColor?,
    tint: UIColor?,
    isRound: Bool,
    style: String,
    enabled: Bool,
    glassEffectUnionId: String?,
    glassEffectId: String?,
    glassEffectInteractive: Bool,
    borderRadius: CGFloat?,
    paddingTop: CGFloat?,
    paddingBottom: CGFloat?,
    paddingLeft: CGFloat?,
    paddingRight: CGFloat?,
    paddingHorizontal: CGFloat?,
    paddingVertical: CGFloat?,
    minHeight: CGFloat?,
    spacing: CGFloat?
  ) {
    // Create GlassButtonConfig with provided values or defaults
    let config = GlassButtonConfig(
      borderRadius: borderRadius,
      top: paddingTop,
      bottom: paddingBottom,
      left: paddingLeft,
      right: paddingRight,
      horizontal: paddingHorizontal,
      vertical: paddingVertical,
      minHeight: minHeight ?? 44.0,
      spacing: spacing ?? 8.0
    )
    
    // Create a wrapper view that provides a namespace for the button
    struct ButtonWrapperView: View {
      @Namespace private var namespace
      
      let title: String?
      let iconName: String?
      let iconImage: UIImage?
      let iconSize: CGFloat
      let iconColor: Color?
      let tint: Color?
      let isRound: Bool
      let style: String
      let isEnabled: Bool
      let onPressed: () -> Void
      let glassEffectUnionId: String?
      let glassEffectId: String?
      let glassEffectInteractive: Bool
      let config: GlassButtonConfig
      
      var body: some View {
        GlassButtonSwiftUI(
          title: title,
          iconName: iconName,
          iconImage: iconImage,
          iconSize: iconSize,
          iconColor: iconColor,
          tint: tint,
          isRound: isRound,
          style: style,
          isEnabled: isEnabled,
          onPressed: onPressed,
          glassEffectUnionId: glassEffectUnionId,
          glassEffectId: glassEffectId,
          glassEffectInteractive: glassEffectInteractive,
          namespace: namespace,
          config: config
        )
      }
    }
    
    let swiftUIButton = ButtonWrapperView(
      title: title,
      iconName: iconName,
      iconImage: iconImage,
      iconSize: iconSize,
      iconColor: iconColor != nil ? Color(iconColor!) : nil,
      tint: tint != nil ? Color(tint!) : nil,
      isRound: isRound,
      style: style,
      isEnabled: enabled,
      onPressed: { [weak self] in
        self?.onPressed(nil)
      },
      glassEffectUnionId: glassEffectUnionId,
      glassEffectId: glassEffectId,
      glassEffectInteractive: glassEffectInteractive,
      config: config
    )
    
    let hostingController = UIHostingController(rootView: AnyView(swiftUIButton))
    hostingController.view.backgroundColor = UIColor.clear
    self.hostingController = hostingController
    
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(hostingController.view)
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    
    // Force layout update for proper first-time rendering
    // Similar to TabBar fix - ensures SwiftUI view is properly laid out before display
    DispatchQueue.main.async { [weak self, weak hostingController] in
      guard let self = self, let hostingController = hostingController else { return }
      self.container.setNeedsLayout()
      self.container.layoutIfNeeded()
      hostingController.view.setNeedsLayout()
      hostingController.view.layoutIfNeeded()
      // Force another update cycle for proper rendering
      DispatchQueue.main.async { [weak hostingController] in
        guard let hostingController = hostingController else { return }
        hostingController.view.setNeedsDisplay()
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
      }
    }
  }
  
  @objc private func onPressed(_ sender: UIButton?) {
    guard isEnabled else { return }
    channel.invokeMethod("pressed", arguments: nil)
  }

  // Use shared utility functions
  private static func colorFromARGB(_ argb: Int) -> UIColor {
    return ImageUtils.colorFromARGB(argb)
  }

  private func applyButtonStyle(buttonStyle: String, round: Bool) {
    guard let button = self.button, !usesSwiftUI else { return }
    
    if #available(iOS 15.0, *) {
      // Preserve current content while swapping configurations
      let currentTitle = button.configuration?.title
      let currentImage = button.configuration?.image
      let currentSymbolCfg = button.configuration?.preferredSymbolConfigurationForImage
      var config: UIButton.Configuration
      switch buttonStyle {
      case "plain": config = .plain()
      case "gray": config = .gray()
      case "tinted": config = .tinted()
      case "bordered": config = .bordered()
      case "borderedProminent": config = .borderedProminent()
      case "filled": config = .filled()
      case "glass":
        if #available(iOS 26.0, *) {
          config = .glass()
        } else {
          config = .tinted()
        }
      case "prominentGlass":
        if #available(iOS 26.0, *) {
          config = .prominentGlass()
        } else {
          config = .tinted()
        }
      default:
        config = .plain()
      }
      config.cornerStyle = round ? .capsule : .dynamic
      // Apply theme tint to configuration in a platform-standard way
      if let tint = button.tintColor {
        switch buttonStyle {
        case "filled", "borderedProminent", "prominentGlass":
          // Treat prominentGlass like filled: color the background and let system pick readable foreground
          config.baseBackgroundColor = tint
        case "tinted", "bordered", "gray", "plain", "glass":
          // Foreground-only tint
          config.baseForegroundColor = tint
        default:
          break
        }
      }
      // Restore content after style swap
      config.title = currentTitle
      config.image = currentImage
      config.preferredSymbolConfigurationForImage = currentSymbolCfg
      button.configuration = config
    } else {
      button.layer.cornerRadius = round ? 999 : 8
      button.clipsToBounds = true
      // Default background to preserve pressed/highlight behavior; custom glass handled above for iOS15+
      button.backgroundColor = .clear
      button.layer.borderWidth = 0
    }
  }

  private func setButtonContent(
    title: String?,
    image: UIImage?,
    iconOnly: Bool,
    imagePlacement: String? = nil,
    imagePadding: CGFloat? = nil,
    horizontalPadding: CGFloat? = nil
  ) {
    guard let button = self.button, !usesSwiftUI else { return }
    
    if #available(iOS 15.0, *) {
      var cfg = button.configuration ?? .plain()
      if let title = title {
        cfg.title = title
      }

      // Configure single-line text with ellipsis truncation
      cfg.titleLineBreakMode = .byTruncatingTail

      if let image = image {
        cfg.image = image
      }
      
      // Apply imagePlacement
      if let placement = imagePlacement {
        switch placement {
        case "leading":
          cfg.imagePlacement = .leading
        case "trailing":
          cfg.imagePlacement = .trailing
        case "top":
          cfg.imagePlacement = .top
        case "bottom":
          cfg.imagePlacement = .bottom
        default:
          cfg.imagePlacement = .leading
        }
      }
      
      // Apply imagePadding
      if let padding = imagePadding {
        cfg.imagePadding = padding
      }
      
      // Apply horizontalPadding
      if let padding = horizontalPadding {
        var insets = cfg.contentInsets
        insets.leading = padding
        insets.trailing = padding
        cfg.contentInsets = insets
      }
      
      button.configuration = cfg
    } else {
      button.setTitle(title, for: .normal)

      // Configure titleLabel to prevent text wrapping (default: single line)
      button.titleLabel?.lineBreakMode = .byTruncatingTail
      button.titleLabel?.numberOfLines = 1

      button.setImage(image, for: .normal)
      if iconOnly {
        button.contentEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
      } else if let padding = horizontalPadding {
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
      }
    }
  }

  private static func createImageFromData(_ data: Data, format: String?, scale: CGFloat) -> UIImage? {
    return ImageUtils.createImageFromData(data, format: format, scale: scale)
  }

  // MARK: - Badge Management

  private func addBadge(count: Int) {
    // Remove existing badge first
    removeBadge()

    // Format badge text (show "99+" for counts > 99)
    let badgeText = count > 99 ? "99+" : "\(count)"

    // Create badge container
    let badge = UIView()
    badge.backgroundColor = .systemRed
    badge.layer.cornerRadius = 10
    badge.clipsToBounds = true
    badge.translatesAutoresizingMaskIntoConstraints = false

    // Create badge label
    let label = UILabel()
    label.text = badgeText
    label.textColor = .white
    label.font = .systemFont(ofSize: 12, weight: .semibold)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false

    badge.addSubview(label)
    container.addSubview(badge)

    // Store references
    badgeView = badge
    badgeLabel = label

    // Layout constraints for label inside badge
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 5),
      label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -5),
      label.topAnchor.constraint(equalTo: badge.topAnchor, constant: 2),
      label.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -2),
    ])

    // Badge positioning constraints (top-right corner)
    NSLayoutConstraint.activate([
      badge.topAnchor.constraint(equalTo: container.topAnchor, constant: 0),
      badge.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: 0),
      badge.heightAnchor.constraint(equalToConstant: 20),
      badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
    ])

    // Bring badge to front
    container.bringSubviewToFront(badge)
  }

  private func removeBadge() {
    badgeView?.removeFromSuperview()
    badgeView = nil
    badgeLabel = nil
  }
}
