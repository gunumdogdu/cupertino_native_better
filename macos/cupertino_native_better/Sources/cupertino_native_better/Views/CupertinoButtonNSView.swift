import FlutterMacOS
import Cocoa
import SwiftUI

/// `CNButton` on macOS: an `NSButton` in the bezel of its `CNButtonStyle`
/// (see `NativeButtonHost`), or, for a glass button that joins a glass
/// union or morphs (`glassEffectUnionId` / `glassEffectId`, macOS 26), a
/// SwiftUI glass button.
class CupertinoButtonNSView: NSView {
  private let channel: FlutterMethodChannel
  private var host: NativeButtonHost?
  private var hostingController: NSHostingController<AnyView>?
  private var swiftUIBase: AnyView?
  private var badgeView: NSView?
  private var isEnabled: Bool = true
  private var isInteractive: Bool = true
  private var usesSwiftUI: Bool = false
  private var semanticLabel: String?

  // The icon as Flutter last described it, so a size or colour change can
  // rebuild it.
  private var icon = IconSource()

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeButton_\(viewId)", binaryMessenger: messenger)
    super.init(frame: .zero)

    let dict = (args as? [String: Any]) ?? [:]
    let title = dict["buttonTitle"] as? String
    let buttonStyle = (dict["buttonStyle"] as? String) ?? "automatic"
    let isDark = (dict["isDark"] as? NSNumber)?.boolValue ?? false
    let tint = ((dict["style"] as? [String: Any])?["tint"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
    let enabled = (dict["enabled"] as? NSNumber)?.boolValue ?? true
    let glassEffectUnionId = dict["glassEffectUnionId"] as? String
    let glassEffectId = dict["glassEffectId"] as? String
    let glassEffectInteractive = (dict["glassEffectInteractive"] as? NSNumber)?.boolValue ?? false
    let borderRadius = Self.cgFloat(dict["borderRadius"])
    let paddingTop = Self.cgFloat(dict["paddingTop"])
    let paddingBottom = Self.cgFloat(dict["paddingBottom"])
    let paddingLeft = Self.cgFloat(dict["paddingLeft"])
    let paddingRight = Self.cgFloat(dict["paddingRight"])
    let paddingHorizontal = Self.cgFloat(dict["paddingHorizontal"])
    let paddingVertical = Self.cgFloat(dict["paddingVertical"])
    let minHeight = Self.cgFloat(dict["minHeight"])
    let imagePadding = Self.cgFloat(dict["imagePadding"])
    let badgeCount = (dict["badgeCount"] as? NSNumber)?.intValue
    icon.read(dict)
    isEnabled = enabled
    isInteractive = (dict["interaction"] as? NSNumber)?.boolValue ?? true
    if let label = dict["semanticLabel"] as? String, !label.isEmpty { semanticLabel = label }

    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    let image = icon.makeImage()

    if NativeButtonHost.hasGlass, glassEffectUnionId != nil || glassEffectId != nil {
      usesSwiftUI = true
      #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        setupSwiftUIButton(
          title: title,
          iconName: icon.symbolName,
          iconImage: image,
          iconSize: icon.size ?? 20,
          iconColor: icon.color.map { Color(nsColor: $0) },
          tint: tint.map { Color(nsColor: $0) },
          isRound: true,
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
      }
      #endif
    } else {
      let host = NativeButtonHost(target: self, action: #selector(onPressed(_:)))
      self.host = host
      host.frame = bounds
      host.autoresizingMask = [.width, .height]
      addSubview(host)
      host.update {
        $0.title = title
        $0.image = image
        $0.imagePlacement = (dict["imagePlacement"] as? String) ?? "leading"
        $0.imagePadding = imagePadding
        $0.style = buttonStyle
        $0.tint = tint
        $0.borderRadius = borderRadius
        $0.expectedHeight = minHeight ?? 44
        $0.paddingLeft = paddingLeft ?? paddingHorizontal
        $0.paddingRight = paddingRight ?? paddingHorizontal
        $0.labelColor = (dict["labelColor"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
        $0.labelFontSize = Self.cgFloat(dict["labelFontSize"]).flatMap { $0 > 0 ? $0 : nil }
        $0.labelFontFamily = (dict["labelFontFamily"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        $0.labelFontWeight = (dict["labelFontWeight"] as? NSNumber)?.intValue
        $0.isEnabled = enabled
        $0.isInteractive = isInteractive
        $0.accessibilityText = semanticLabel
      }
    }

    if let count = badgeCount, count > 0 {
      addBadge(count: count)
    }

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      self.handle(call, result: result)
    }
  }

  required init?(coder: NSCoder) { return nil }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard isInteractive else { return nil }
    return super.hitTest(point)
  }

  // MARK: - Method calls

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "getIntrinsicSize":
      if let host = host {
        let size = host.preferredSize()
        result(["width": Double(size.width), "height": Double(size.height)])
      } else {
        let size = hostingController?.view.fittingSize ?? .zero
        result(["width": Double(size.width > 0 ? size.width : 80), "height": Double(size.height > 0 ? size.height : 32)])
      }
    case "setStyle":
      guard let args = args else {
        result(FlutterError(code: "bad_args", message: "Missing style", details: nil)); return
      }
      // A SwiftUI button keeps the style it was created with.
      if let host = host {
        host.update {
          if let n = args["tint"] as? NSNumber {
            $0.tint = ImageUtils.colorFromARGB(n.intValue)
          } else if (args["clearTint"] as? NSNumber)?.boolValue == true {
            $0.tint = nil
          }
          if let bs = args["buttonStyle"] as? String { $0.style = bs }
        }
      }
      result(nil)
    case "setButtonTitle":
      guard let t = args?["title"] as? String else {
        result(FlutterError(code: "bad_args", message: "Missing title", details: nil)); return
      }
      host?.title = t
      result(nil)
    case "setImagePlacement":
      guard let placement = args?["placement"] as? String else {
        result(FlutterError(code: "bad_args", message: "Missing placement", details: nil)); return
      }
      host?.imagePlacement = placement
      result(nil)
    case "setImagePadding":
      host?.imagePadding = Self.cgFloat(args?["padding"])
      result(nil)
    case "setHorizontalPadding":
      host?.paddingLeft = Self.cgFloat(args?["padding"])
      host?.paddingRight = Self.cgFloat(args?["padding"])
      result(nil)
    case "setTextStyle", "setLabelStyle":
      // `setLabelStyle` is CNButtonConfig's label style (#40); `setTextStyle`
      // its older form with color / fontSize / fontWeight / fontFamily keys.
      host?.update { h in
        let a = args ?? [:]
        if (a["clearFontFamily"] as? NSNumber)?.boolValue == true { h.labelFontFamily = nil }
        if (a["clearFontSize"] as? NSNumber)?.boolValue == true { h.labelFontSize = nil }
        if (a["clearLabelColor"] as? NSNumber)?.boolValue == true { h.labelColor = nil }
        if (a["clearFontWeight"] as? NSNumber)?.boolValue == true { h.labelFontWeight = nil }
        if call.method == "setTextStyle", args == nil {
          h.labelFontFamily = nil; h.labelFontSize = nil; h.labelColor = nil; h.labelFontWeight = nil
        }
        if let f = (a["labelFontFamily"] ?? a["fontFamily"]) as? String, !f.isEmpty { h.labelFontFamily = f }
        if let s = Self.cgFloat(a["labelFontSize"] ?? a["fontSize"]), s > 0 { h.labelFontSize = s }
        if let c = (a["labelColor"] ?? a["color"]) as? NSNumber { h.labelColor = ImageUtils.colorFromARGB(c.intValue) }
        if let w = (a["labelFontWeight"] ?? a["fontWeight"]) as? NSNumber { h.labelFontWeight = w.intValue }
      }
      result(nil)
    case "setEnabled":
      guard let e = args?["enabled"] as? NSNumber else {
        result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)); return
      }
      isEnabled = e.boolValue
      host?.isEnabled = isEnabled
      result(nil)
    case "setInteraction":
      guard let i = args?["interaction"] as? NSNumber else {
        result(FlutterError(code: "bad_args", message: "Missing interaction", details: nil)); return
      }
      isInteractive = i.boolValue
      host?.isInteractive = isInteractive
      result(nil)
    case "setInteractive":
      // A modal route above the button (ModalHideMixin).
      if let i = args?["interactive"] as? NSNumber {
        isInteractive = i.boolValue
        host?.isInteractive = isInteractive
      }
      result(nil)
    case "setSemanticLabel":
      let label = args?["label"] as? String
      semanticLabel = (label?.isEmpty ?? true) ? nil : label
      applySemanticLabel()
      result(nil)
    case "setButtonIcon":
      guard let args = args else {
        result(FlutterError(code: "bad_args", message: "Missing icon args", details: nil)); return
      }
      icon.update(args)
      host?.image = icon.makeImage()
      result(nil)
    case "setBrightness":
      guard let isDark = (args?["isDark"] as? NSNumber)?.boolValue else {
        result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)); return
      }
      appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
      result(nil)
    case "setPressed":
      // NSButton draws its own pressed state; only the SwiftUI button needs
      // the feedback.
      if usesSwiftUI, let p = args?["pressed"] as? NSNumber {
        alphaValue = p.boolValue ? 0.7 : 1.0
      }
      result(nil)
    case "setTransitioning":
      // Keep the bezel inside the view while the route animates.
      layer?.masksToBounds = (args?["active"] as? NSNumber)?.boolValue ?? false
      result(nil)
    case "setBadgeCount":
      if let count = (args?["badgeCount"] as? NSNumber)?.intValue, count > 0 {
        addBadge(count: count)
      } else {
        removeBadge()
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @objc private func onPressed(_ sender: Any?) {
    guard isEnabled, isInteractive else { return }
    channel.invokeMethod("pressed", arguments: nil)
  }

  private func applySemanticLabel() {
    if let host = host {
      host.accessibilityText = semanticLabel
    } else if let hosting = hostingController, let base = swiftUIBase {
      hosting.rootView = semanticLabel.map { AnyView(base.accessibilityLabel(Text($0))) } ?? base
    }
  }

  private static func cgFloat(_ value: Any?) -> CGFloat? {
    (value as? NSNumber).map { CGFloat(truncating: $0) }
  }

  // MARK: - SwiftUI glass (glass unions and morphing, macOS 26)

  #if compiler(>=6.2)
  @available(macOS 26.0, *)
  private func setupSwiftUIButton(
    title: String?,
    iconName: String?,
    iconImage: NSImage?,
    iconSize: CGFloat,
    iconColor: Color?,
    tint: Color?,
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
    // A symbol keeps its name so SwiftUI draws it as a symbol; any other
    // image is passed as an image.
    let swiftUIButton = GlassButtonSwiftUI(
      title: title,
      iconName: icon.isSymbol ? iconName : nil,
      iconImage: icon.isSymbol ? nil : iconImage,
      iconSize: iconSize,
      iconColor: iconColor,
      tint: tint,
      isRound: isRound,
      style: style,
      isEnabled: enabled,
      onPressed: { [weak self] in self?.onPressed(nil) },
      glassEffectUnionId: glassEffectUnionId,
      glassEffectId: glassEffectId,
      glassEffectInteractive: glassEffectInteractive,
      config: config,
      badgeCount: nil
    )
    let base = AnyView(swiftUIButton)
    swiftUIBase = base
    let hostingController = NSHostingController(
      rootView: semanticLabel.map { AnyView(base.accessibilityLabel(Text($0))) } ?? base
    )
    hostingController.view.wantsLayer = true
    hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
    self.hostingController = hostingController
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hostingController.view)
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }
  #endif

  // MARK: - Badge

  private func addBadge(count: Int) {
    removeBadge()
    let badge = NSView()
    badge.wantsLayer = true
    badge.layer?.backgroundColor = NSColor.systemRed.cgColor
    badge.layer?.cornerRadius = 10
    badge.translatesAutoresizingMaskIntoConstraints = false
    let label = NSTextField(labelWithString: count > 99 ? "99+" : "\(count)")
    label.textColor = .white
    label.font = .systemFont(ofSize: 12, weight: .semibold)
    label.alignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    badge.addSubview(label)
    addSubview(badge)
    badgeView = badge
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 5),
      label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -5),
      label.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
      badge.topAnchor.constraint(equalTo: topAnchor),
      badge.trailingAnchor.constraint(equalTo: trailingAnchor),
      badge.heightAnchor.constraint(equalToConstant: 20),
      badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
    ])
  }

  private func removeBadge() {
    badgeView?.removeFromSuperview()
    badgeView = nil
  }
}

/// A button's image as Flutter describes it: an image asset, raw bytes, a
/// custom icon rendered by Flutter or an SF Symbol, with size, colour and
/// rendering mode. Shared by `CNButton` and `CNPopupMenuButton`.
struct IconSource {
  var symbolName: String?
  var assetPath: String?
  var imageData: Data?
  var imageFormat: String?
  var customIconBytes: Data?
  var size: CGFloat?
  var color: NSColor?
  var mode: String?
  var palette: [NSColor] = []

  /// Whether the image is the SF Symbol (no other source wins over it).
  var isSymbol: Bool {
    symbolName != nil && assetPath == nil && imageData == nil && customIconBytes == nil
  }

  /// Reads the `button*` keys of creation parameters.
  mutating func read(_ dict: [String: Any]) {
    symbolName = (dict["buttonIconName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    assetPath = (dict["buttonAssetPath"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    imageData = (dict["buttonImageData"] as? FlutterStandardTypedData)?.data
    imageFormat = dict["buttonImageFormat"] as? String
    customIconBytes = (dict["buttonCustomIconBytes"] as? FlutterStandardTypedData)?.data
    size = (dict["buttonIconSize"] as? NSNumber).map { CGFloat(truncating: $0) }
    color = (dict["buttonIconColor"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
    mode = dict["buttonIconRenderingMode"] as? String
    palette = ((dict["buttonIconPaletteColors"] as? [NSNumber]) ?? []).map { ImageUtils.colorFromARGB($0.intValue) }
  }

  /// Applies a `setButtonIcon` update: a new source replaces the old one;
  /// size, colour and mode change only when sent.
  mutating func update(_ args: [String: Any]) {
    let hasAsset = (args["buttonAssetPath"] as? String).map { !$0.isEmpty } ?? false
    let hasData = args["buttonImageData"] is FlutterStandardTypedData
    let hasCustom = args["buttonCustomIconBytes"] is FlutterStandardTypedData
    let hasSymbol = (args["buttonIconName"] as? String).map { !$0.isEmpty } ?? false
    if hasAsset || hasData || hasCustom || hasSymbol {
      symbolName = nil; assetPath = nil; imageData = nil; imageFormat = nil; customIconBytes = nil
      if hasAsset { assetPath = args["buttonAssetPath"] as? String }
      if hasData { imageData = (args["buttonImageData"] as? FlutterStandardTypedData)?.data }
      if hasAsset || hasData { imageFormat = args["buttonImageFormat"] as? String }
      if hasCustom { customIconBytes = (args["buttonCustomIconBytes"] as? FlutterStandardTypedData)?.data }
      if hasSymbol { symbolName = args["buttonIconName"] as? String }
    }
    if let s = args["buttonIconSize"] as? NSNumber { size = CGFloat(truncating: s) }
    if let c = args["buttonIconColor"] as? NSNumber { color = ImageUtils.colorFromARGB(c.intValue) }
    if let m = args["buttonIconRenderingMode"] as? String { mode = m }
    if let p = args["buttonIconPaletteColors"] as? [NSNumber] { palette = p.map { ImageUtils.colorFromARGB($0.intValue) } }
  }

  /// The image to show, by the iOS priority: image asset or bytes, then a
  /// custom icon, then the SF Symbol.
  func makeImage() -> NSImage? {
    if assetPath != nil || imageData != nil || customIconBytes != nil {
      let image = ImageUtils.image(
        assetPath: assetPath,
        imageData: imageData,
        format: imageFormat,
        customIconBytes: assetPath == nil && imageData == nil ? customIconBytes : nil,
        size: size,
        color: color
      )
      if image != nil { return image }
    }
    guard let name = symbolName else { return nil }
    return ImageUtils.symbolImage(name: name, size: size, color: color, mode: mode, palette: palette)
  }
}
