import Flutter
import UIKit

class CupertinoPopupMenuButtonPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let container: UIView
  private let button: CNPopupMenuUIButton
  private var currentButtonStyle: String = "automatic"
  private var isRoundButton: Bool = false
  private var isTransitioning: Bool = false
  private var labels: [String] = []
  private var symbols: [String] = []
  private var customIconBytes: [Data?] = []
  private var customIconColors: [Any] = []
  private var imageAssetPaths: [String] = []
  private var imageAssetData: [Data?] = []
  private var imageAssetFormats: [String] = []
  private var dividers: [Bool] = []
  private var enabled: [Bool] = []
  private var checked: [Bool] = []
  // Issue #55: per-item destructive flag. When true, the menu action is
  // built with `UIMenuElement.Attributes.destructive` so iOS renders the
  // label (not just the icon) in the system red destructive color.
  private var isDestructive: [Bool] = []
  private var itemSizes: [Any] = []
  private var itemColors: [Any] = []
  private var itemModes: [String?] = []
  private var itemPalettes: [[NSNumber]] = []
  private var itemGradients: [NSNumber?] = []
  // Subtitles and submenus. Flutter only sends them when the menu uses
  // them; each submenu arrives as its own level, encoded like the top one.
  private var subtitles: [String] = []
  private var isSubmenu: [Bool] = []
  private var submenus: [[String: Any]?] = []
  // Items that keep the menu open, and submenus shown in place. Also only
  // sent when used.
  private var keepsMenuPresented: [Bool] = []
  private var submenuStyles: [String?] = []
  private var elementSizes: [String?] = []
  private var iconScale: CGFloat = UIScreen.main.scale
  private var preserveTopToBottomOrder: Bool = false
  // Track current button icon configuration to keep image across state updates
  private var btnIconName: String? = nil
  private var btnCustomIconBytes: Data? = nil
  private var btnAssetPath: String? = nil
  private var btnImageData: Data? = nil
  private var btnImageFormat: String? = nil
  private var btnIconSize: CGFloat? = nil
  private var btnIconColor: UIColor? = nil
  private var btnIconMode: String? = nil
  private var btnIconPalette: [UIColor] = []
  /// The title, kept so an icon change doesn't drop it (#141).
  private var currentTitle: String? = nil
  /// `CNPopupMenuButton.imagePlacement` / `imagePadding` for a button with
  /// both a title and an image (#141).
  private var imagePlacement: NSDirectionalRectEdge = .leading
  private var imagePadding: CGFloat? = nil
  /// `labelFontFamily` / `labelFontSize` / `labelFontWeight` / `labelColor`.
  private var labelFontFamily: String? = nil
  private var labelFontSize: CGFloat? = nil
  private var labelFontWeight: Int? = nil
  private var labelColor: UIColor? = nil

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativePopupMenuButton_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)
    self.button = CNPopupMenuUIButton(type: .system)

    var title: String? = nil
    var semanticLabel: String? = nil
    var iconName: String? = nil
    var iconSize: CGFloat? = nil
    var iconColor: UIColor? = nil
    var makeRound: Bool = false
    var isDark: Bool = false
    var tint: UIColor? = nil
    var buttonStyle: String = "automatic"
    var labels: [String] = []
    var symbols: [String] = []
    var customIconBytes: [Data?] = []
    var customIconColors: [Any] = []
    var dividers: [NSNumber] = []
    var enabled: [NSNumber] = []
    var sizes: [Any] = []
    var colors: [Any] = []
    var iconScale: CGFloat = UIScreen.main.scale
    var buttonIconMode: String? = nil
    var buttonIconPalette: [NSNumber] = []
    var buttonCustomIconBytes: Data? = nil

    if let dict = args as? [String: Any] {
      if let t = dict["buttonTitle"] as? String { title = t }
      switch dict["imagePlacement"] as? String {
      case "trailing": self.imagePlacement = .trailing
      case "top": self.imagePlacement = .top
      case "bottom": self.imagePlacement = .bottom
      default: self.imagePlacement = .leading
      }
      if let v = dict["imagePadding"] as? NSNumber { self.imagePadding = CGFloat(v.doubleValue) }
      if let f = dict["labelFontFamily"] as? String, !f.isEmpty { self.labelFontFamily = f }
      if let v = dict["labelFontSize"] as? NSNumber, v.doubleValue > 0 { self.labelFontSize = CGFloat(v.doubleValue) }
      if let v = dict["labelFontWeight"] as? NSNumber { self.labelFontWeight = v.intValue }
      if let v = dict["labelColor"] as? NSNumber { self.labelColor = Self.colorFromARGB(v.intValue) }
      if let v = dict["keepsSourceVisible"] as? NSNumber { self.button.keepsSourceVisible = v.boolValue }
      if let label = dict["semanticLabel"] as? String, !label.isEmpty {
        semanticLabel = label
      }
      if let data = dict["buttonCustomIconBytes"] as? FlutterStandardTypedData {
        buttonCustomIconBytes = data.data
      }
      if let ap = dict["buttonAssetPath"] as? String { btnAssetPath = ap }
      if let data = dict["buttonImageData"] as? FlutterStandardTypedData {
        btnImageData = data.data
      }
      if let f = dict["buttonImageFormat"] as? String { btnImageFormat = f }
      if let s = dict["buttonIconName"] as? String { iconName = s }
      if let s = dict["buttonIconSize"] as? NSNumber { iconSize = CGFloat(truncating: s) }
      if let c = dict["buttonIconColor"] as? NSNumber { iconColor = Self.colorFromARGB(c.intValue) }
      if let r = dict["round"] as? NSNumber { makeRound = r.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let style = dict["style"] as? [String: Any], let n = style["tint"] as? NSNumber { tint = Self.colorFromARGB(n.intValue) }
      if let bs = dict["buttonStyle"] as? String { buttonStyle = bs }
      labels = (dict["labels"] as? [String]) ?? []
      symbols = (dict["sfSymbols"] as? [String]) ?? []
      if let bytesArray = dict["customIconBytes"] as? [FlutterStandardTypedData?] {
        customIconBytes = bytesArray.map { $0?.data }
      }
      customIconColors = (dict["customIconColors"] as? [Any]) ?? []
      imageAssetPaths = (dict["imageAssetPaths"] as? [String]) ?? []
      if let bytesArray = dict["imageAssetData"] as? [FlutterStandardTypedData?] {
        imageAssetData = bytesArray.map { $0?.data }
      }
      imageAssetFormats = (dict["imageAssetFormats"] as? [String]) ?? []
      dividers = (dict["isDivider"] as? [NSNumber]) ?? []
      enabled = (dict["enabled"] as? [NSNumber]) ?? []
      if let c = dict["checked"] as? [NSNumber] { self.checked = c.map { $0.boolValue } }
      if let d = dict["isDestructive"] as? [NSNumber] { self.isDestructive = d.map { $0.boolValue } }
      sizes = (dict["sfSymbolSizes"] as? [Any]) ?? []
      colors = (dict["sfSymbolColors"] as? [Any]) ?? []
      if let modes = dict["sfSymbolRenderingModes"] as? [String?] { self.itemModes = modes }
      if let palettes = dict["sfSymbolPaletteColors"] as? [[NSNumber]] { self.itemPalettes = palettes }
      if let gradients = dict["sfSymbolGradientEnabled"] as? [NSNumber?] { self.itemGradients = gradients }
      if let m = dict["buttonIconRenderingMode"] as? String { buttonIconMode = m }
      if let pal = dict["buttonIconPaletteColors"] as? [NSNumber] { buttonIconPalette = pal }
      self.subtitles = (dict["subtitles"] as? [String]) ?? []
      self.isSubmenu = ((dict["isSubmenu"] as? [NSNumber]) ?? []).map { $0.boolValue }
      self.submenus = Self.parseSubmenus(dict["submenus"])
      let layout = PopupMenuLevel(dict: dict)
      self.keepsMenuPresented = layout.keepsMenuPresented
      self.submenuStyles = layout.submenuStyles
      self.elementSizes = layout.elementSizes
      if let preserve = dict["preserveTopToBottomOrder"] as? NSNumber {
        self.preserveTopToBottomOrder = preserve.boolValue
      }
    }

    super.init()

    // `onOpened` / `onClosed` (#141).
    button.onMenuWillShow = { [weak self] in self?.channel.invokeMethod("menuOpened", arguments: nil) }
    button.onMenuDidHide = { [weak self] in self?.channel.invokeMethod("menuClosed", arguments: nil) }

    container.backgroundColor = .clear
    if #available(iOS 13.0, *) { container.overrideUserInterfaceStyle = isDark ? .dark : .light }

    button.translatesAutoresizingMaskIntoConstraints = false
    // Choose a visible default tint if none provided
    if let t = tint { button.tintColor = t }
    else if #available(iOS 13.0, *) { button.tintColor = .label }

    // Add button and pin to container
    container.addSubview(button)
    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      button.topAnchor.constraint(equalTo: container.topAnchor),
      button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])

    // Store
    self.labels = labels
    self.symbols = symbols
    self.customIconBytes = customIconBytes
    self.customIconColors = customIconColors
    self.dividers = dividers.map { $0.boolValue }
    self.enabled = enabled.map { $0.boolValue }
    self.iconScale = iconScale

    self.isRoundButton = makeRound
    applyButtonStyle(buttonStyle: buttonStyle, round: makeRound)
    currentButtonStyle = buttonStyle
    // Now set content (title/image) using configuration when available
    // Cache current icon props for state updates
    self.btnIconName = iconName
    self.btnCustomIconBytes = buttonCustomIconBytes
    self.btnIconSize = iconSize
    self.btnIconColor = iconColor
    self.btnIconMode = buttonIconMode
    if !buttonIconPalette.isEmpty { self.btnIconPalette = buttonIconPalette.map { Self.colorFromARGB($0.intValue) } }
    // Apply content initially
    currentTitle = title
    setButtonContent(title: title, image: makeButtonIconImage(), iconOnly: (title == nil))
    if #available(iOS 15.0, *), var cfg = button.configuration {
      // Prefer explicit icon mode/color if provided
      if let symCfg = makeButtonSymbolConfiguration() {
        cfg.preferredSymbolConfigurationForImage = symCfg
      } else if let t = tint, btnIconColor == nil, btnIconMode == nil {
        // Fallback: color the symbol using current button tint if no explicit color/mode
        cfg.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(hierarchicalColor: t)
      }
      button.configuration = cfg
    }

    // Ensure the image persists across configuration state changes (highlight/menu)
    if #available(iOS 15.0, *) {
      button.configurationUpdateHandler = { [weak self] btn in
        guard let self = self else { return }
        var cfg = btn.configuration ?? .plain()
        // Preserve existing title; just re-apply image
        cfg.image = self.makeButtonIconImage()
        cfg.preferredSymbolConfigurationForImage = self.makeButtonSymbolConfiguration()
        self.applyContentOptions(to: &cfg)
        btn.configuration = cfg
      }
    }

    self.itemSizes = sizes
    self.itemColors = colors
    rebuildMenu()
    if #available(iOS 14.0, *) {
      button.showsMenuAsPrimaryAction = true
    } else {
      button.addTarget(self, action: #selector(onButtonPressedLegacy(_:)), for: .touchUpInside)
    }

    // Observe transition state changes to swap glass style during navigation
    if #available(iOS 13.0, *) {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleTransitionStateChange(_:)),
        name: CNTransitionObserver.transitionStateChangedNotification,
        object: nil
      )
    }

    // What VoiceOver reads (`CNPopupMenuButton.semanticLabel`); nil keeps the
    // title, or the SF Symbol's own name for an icon-only button.
    button.accessibilityLabel = semanticLabel

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "setSemanticLabel":
        let label = (call.arguments as? [String: Any])?["label"] as? String
        self.button.accessibilityLabel = (label?.isEmpty ?? true) ? nil : label
        result(nil)
      case "setTransitioning":
        // Issue #29 follow-up: apply halo-containment clipping only while
        // the enclosing route is animating OR while a modal/sheet/popup
        // is presented on top. At rest the container is unclipped so the
        // glass capsule renders its full soft-edge glow.
        let active = ((call.arguments as? [String: Any])?["active"] as? NSNumber)?.boolValue ?? false
        self.applyTransitionContainment(active)
        result(nil)
      case "getIntrinsicSize":
        let size = self.button.intrinsicContentSize
        result(["width": Double(size.width), "height": Double(size.height)])
      case "setItems":
        if let args = call.arguments as? [String: Any] {
          self.labels = (args["labels"] as? [String]) ?? []
          self.symbols = (args["sfSymbols"] as? [String]) ?? []
          self.dividers = ((args["isDivider"] as? [NSNumber]) ?? []).map { $0.boolValue }
          self.enabled = ((args["enabled"] as? [NSNumber]) ?? []).map { $0.boolValue }
          self.checked = ((args["checked"] as? [NSNumber]) ?? []).map { $0.boolValue }
          self.isDestructive = ((args["isDestructive"] as? [NSNumber]) ?? []).map { $0.boolValue }
          let sizes = (args["sfSymbolSizes"] as? [NSNumber]) ?? []
          let colors = (args["sfSymbolColors"] as? [NSNumber]) ?? []
          self.itemSizes = sizes
          self.itemColors = colors
          self.itemModes = (args["sfSymbolRenderingModes"] as? [String?]) ?? []
          self.itemPalettes = (args["sfSymbolPaletteColors"] as? [[NSNumber]]) ?? []
          self.itemGradients = (args["sfSymbolGradientEnabled"] as? [NSNumber?]) ?? []
          // Handle imageAsset properties
          self.imageAssetPaths = (args["imageAssetPaths"] as? [String]) ?? []
          if let bytesArray = args["imageAssetData"] as? [FlutterStandardTypedData?] {
            self.imageAssetData = bytesArray.map { $0?.data }
          }
          self.imageAssetFormats = (args["imageAssetFormats"] as? [String]) ?? []
          self.subtitles = (args["subtitles"] as? [String]) ?? []
          self.isSubmenu = ((args["isSubmenu"] as? [NSNumber]) ?? []).map { $0.boolValue }
          self.submenus = Self.parseSubmenus(args["submenus"])
          self.readLayout(args)
          self.rebuildMenu()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing items", details: nil)) }
      case "setStyle":
        if let args = call.arguments as? [String: Any] {
          if let n = args["tint"] as? NSNumber {
            self.button.tintColor = Self.colorFromARGB(n.intValue)
            self.applyButtonStyle(buttonStyle: self.currentButtonStyle, round: self.isRoundButton)
            // If no explicit icon color/mode is set, color the symbol with tint
            if #available(iOS 15.0, *), self.btnIconColor == nil, self.btnIconMode == nil, let tint = self.button.tintColor, var cfg = self.button.configuration {
              cfg.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(hierarchicalColor: tint)
              self.button.configuration = cfg
            }
          }
          if let bs = args["buttonStyle"] as? String {
            self.currentButtonStyle = bs
            self.applyButtonStyle(buttonStyle: bs, round: self.isRoundButton)
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setButtonIcon":
        if let args = call.arguments as? [String: Any] {
          // Update cached props
          if let name = args["buttonIconName"] as? String { self.btnIconName = name }
          if let s = args["buttonIconSize"] as? NSNumber { self.btnIconSize = CGFloat(truncating: s) }
          if let c = args["buttonIconColor"] as? NSNumber { self.btnIconColor = Self.colorFromARGB(c.intValue) }
          if let m = args["buttonIconRenderingMode"] as? String { self.btnIconMode = m }
          if let pal = args["buttonIconPaletteColors"] as? [NSNumber] { self.btnIconPalette = pal.map { Self.colorFromARGB($0.intValue) } }
          self.setButtonContent(title: self.currentTitle, image: self.makeButtonIconImage(),
                                iconOnly: self.currentTitle == nil)
          if #available(iOS 15.0, *), var cfg = self.button.configuration {
            if let symCfg = self.makeButtonSymbolConfiguration() {
              cfg.preferredSymbolConfigurationForImage = symCfg
            } else if self.btnIconColor == nil, self.btnIconMode == nil, let tint = self.button.tintColor {
              cfg.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(hierarchicalColor: tint)
            }
            self.button.configuration = cfg
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing icon args", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          if #available(iOS 13.0, *) { self.container.overrideUserInterfaceStyle = isDark ? .dark : .light }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setButtonTitle":
        if let args = call.arguments as? [String: Any], let t = args["title"] as? String {
          self.currentTitle = t
          self.setButtonContent(title: t, image: self.makeButtonIconImage(), iconOnly: false)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing title", details: nil)) }
      case "setPressed":
        if let args = call.arguments as? [String: Any], let p = args["pressed"] as? NSNumber {
          self.button.isHighlighted = p.boolValue
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing pressed", details: nil)) }
      case "setInteractive":
        if let args = call.arguments as? [String: Any],
           let interactive = (args["interactive"] as? NSNumber)?.boolValue {
          NSLog("[CN CNPopup] setInteractive=\(interactive)")
          self._cnSetInteractiveRecursive(self.container, interactive)
          self._cnSetInteractiveRecursive(self.button, interactive)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  private func _cnSetInteractiveRecursive(_ view: UIView?, _ interactive: Bool) {
    guard let view = view else { return }
    view.isUserInteractionEnabled = interactive
    for sub in view.subviews { _cnSetInteractiveRecursive(sub, interactive) }
  }

  /// Toggle Issue #29 halo containment based on whether the enclosing
  /// route is animating or a modal is presented on top.
  private func applyTransitionContainment(_ active: Bool) {
    if active {
      container.isOpaque = false
      container.clipsToBounds = true
      container.layer.backgroundColor = UIColor.clear.cgColor
      container.layer.shadowOpacity = 0
      button.clipsToBounds = true
      button.layer.shadowOpacity = 0
      button.layer.backgroundColor = UIColor.clear.cgColor
      button.backgroundColor = .clear
    } else {
      container.clipsToBounds = false
      button.clipsToBounds = false
    }
  }

  /// The top level of the menu, from the arrays Flutter sent at creation or
  /// in the last `setItems`.
  private var rootLevel: PopupMenuLevel {
    var level = PopupMenuLevel()
    level.labels = labels
    level.symbols = symbols
    level.customIconBytes = customIconBytes
    level.customIconColors = customIconColors
    level.imageAssetPaths = imageAssetPaths
    level.imageAssetData = imageAssetData
    level.imageAssetFormats = imageAssetFormats
    level.dividers = dividers
    level.enabled = enabled
    level.checked = checked
    level.isDestructive = isDestructive
    level.sizes = itemSizes
    level.colors = itemColors
    level.modes = itemModes
    level.palettes = itemPalettes
    level.subtitles = subtitles
    level.isSubmenu = isSubmenu
    level.submenus = submenus
    level.keepsMenuPresented = keepsMenuPresented
    level.submenuStyles = submenuStyles
    level.elementSizes = elementSizes
    return level
  }

  private func readLayout(_ dict: [String: Any]) {
    let level = PopupMenuLevel(dict: dict)
    keepsMenuPresented = level.keepsMenuPresented
    submenuStyles = level.submenuStyles
    elementSizes = level.elementSizes
  }

  private static func parseSubmenus(_ value: Any?) -> [[String: Any]?] {
    return ((value as? [Any]) ?? []).map { $0 as? [String: Any] }
  }

  private func rebuildMenu() {
    // iOS 14+ native menu
    if #available(iOS 14.0, *) {
      // If preserveTopToBottomOrder is enabled, use deferred menu to check position at display time
      if preserveTopToBottomOrder {
        // iOS 16+ keeps the given order itself, whichever way the menu
        // opens, submenus included. The reversal below only reaches the
        // top level, so a submenu opened upward showed its items reversed.
        if #available(iOS 16.0, *) {
          button.preferredMenuElementOrder = .fixed
          button.menu = UIMenu(title: "", children: buildMenuItems(level: rootLevel))
          return
        }
        let deferredElement = UIDeferredMenuElement.uncached { [weak self] completion in
          guard let self = self else { completion([]); return }
          let items = self.buildMenuItems(level: self.rootLevel)

          // Check button position at display time
          let buttonFrame = self.button.convert(self.button.bounds, to: nil)
          let screenHeight = UIScreen.main.bounds.height
          let opensUpward = buttonFrame.midY > screenHeight * 0.4

          if opensUpward {
            // Reverse groups AND items within each group
            let reversed: [UIMenuElement] = items.reversed().map { element in
              if let menu = element as? UIMenu {
                return UIMenu(title: menu.title, options: menu.options, children: menu.children.reversed())
              }
              return element
            }
            completion(reversed)
          } else {
            completion(items)
          }
        }
        button.menu = UIMenu(title: "", children: [deferredElement])
        return
      }

      // Standard menu building (native behavior)
      let items = buildMenuItems(level: rootLevel)
      button.menu = UIMenu(title: "", children: items)
    }
  }

  private func buildMenuItems(level: PopupMenuLevel) -> [UIMenuElement] {
    PopupMenuBuilder.elements(level: level, iconScale: iconScale) { [weak self] path in
      // `index` is the top-level entry, as before; `path` the full path.
      self?.channel.invokeMethod("itemSelected", arguments: ["index": path[0], "path": path])
    }
  }

  @objc private func onButtonPressedLegacy(_ sender: UIButton) {
    // iOS 13 fallback: use action sheet
    let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    let count = max(labels.count, max(symbols.count, dividers.count))
    for i in 0..<count {
      if i < dividers.count, dividers[i] {
        // Simulate separator with disabled action
        let fake = UIAlertAction(title: "—", style: .default, handler: nil)
        fake.isEnabled = false
        ac.addAction(fake)
        continue
      }
      let title = i < labels.count ? labels[i] : ""
      let destructive = i < self.isDestructive.count ? self.isDestructive[i] : false
      let action = UIAlertAction(title: title, style: destructive ? .destructive : .default) { [weak self] _ in
        self?.channel.invokeMethod("itemSelected", arguments: ["index": i])
      }
      if i < enabled.count { action.isEnabled = enabled[i] }
      // Optional: set image where supported (iOS 13 has `image` on UIAlertAction)
      var img: UIImage? = nil
      if i < customIconBytes.count, let data = customIconBytes[i] {
        img = UIImage(data: data, scale: self.iconScale)?.withRenderingMode(.alwaysTemplate)
        // Apply tint color to custom icon if provided
        if i < self.customIconColors.count,
           let colorNum = self.customIconColors[i] as? NSNumber,
           !(self.customIconColors[i] is NSNull) {
          let tintColor = Self.colorFromARGB(colorNum.intValue)
          img = img?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
        }
      } else if i < symbols.count, !symbols[i].isEmpty {
        img = UIImage(systemName: symbols[i])
      }
      if let img = img {
        if #available(iOS 13.0, *) { action.setValue(img, forKey: "image") }
      }
      ac.addAction(action)
    }
    ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

    if let pop = ac.popoverPresentationController {
      pop.sourceView = sender
      pop.sourceRect = sender.bounds
    }
    parentViewController(for: container)?.present(ac, animated: true, completion: nil)
  }

  private func parentViewController(for view: UIView) -> UIViewController? {
    var responder: UIResponder? = view
    while let r = responder {
      if let vc = r as? UIViewController { return vc }
      responder = r.next
    }
    return nil
  }

  // Use shared utility functions
  private static func colorFromARGB(_ argb: Int) -> UIColor {
    return ImageUtils.colorFromARGB(argb)
  }

  @available(iOS 13.0, *)
  private func makeButtonIconImage() -> UIImage? {
    // Priority: imageAsset > customIconBytes > SF Symbol
    
    // Handle imageAsset (highest priority)
    if let path = btnAssetPath, !path.isEmpty {
      let iconColorARGB = btnIconColor != nil ? ImageUtils.colorToARGB(btnIconColor!) : nil
      let size = CGSize(width: btnIconSize ?? 20, height: btnIconSize ?? 20)
      
      // Use utility function to load and optionally tint image
      if let argb = iconColorARGB, #available(iOS 13.0, *) {
        return ImageUtils.loadAndTintImage(
          from: path,
          iconSize: btnIconSize,
          iconColor: argb,
          providedFormat: btnImageFormat,
          scale: iconScale
        )
      } else {
        return ImageUtils.loadFlutterAsset(path, size: size, format: btnImageFormat, scale: iconScale)
      }
    } else if let data = btnImageData {
      let iconColorARGB = btnIconColor != nil ? ImageUtils.colorToARGB(btnIconColor!) : nil
      
      // Use utility function to create and optionally tint image
      if let argb = iconColorARGB, #available(iOS 13.0, *) {
        return ImageUtils.createAndTintImage(
          from: data,
          iconSize: btnIconSize,
          iconColor: argb,
          providedFormat: btnImageFormat,
          scale: iconScale
        )
      } else {
        let size: CGSize? = btnIconSize != nil ? CGSize(width: btnIconSize!, height: btnIconSize!) : nil
        return ImageUtils.createImageFromData(data, format: btnImageFormat, size: size, scale: iconScale)
      }
    }
    
    // Handle custom icon bytes (medium priority)
    if let data = btnCustomIconBytes {
      var image = UIImage(data: data, scale: self.iconScale)?.withRenderingMode(.alwaysTemplate)
      // Apply custom icon color if provided, preserving the tint with .alwaysOriginal
      if let image = image, let color = btnIconColor {
        return image.withTintColor(color, renderingMode: .alwaysOriginal)
      }
      return image
    }
    
    // Handle SF Symbol (lowest priority)
    guard let name = btnIconName, var image = UIImage(systemName: name) else { return nil }
    if let sz = btnIconSize {
      image = image.applyingSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: sz)) ?? image
    }
    if let mode = btnIconMode {
      switch mode {
      case "hierarchical":
        if #available(iOS 15.0, *), let c = btnIconColor {
          let cfg = UIImage.SymbolConfiguration(hierarchicalColor: c)
          image = image.applyingSymbolConfiguration(cfg) ?? image
        }
      case "palette":
        if #available(iOS 15.0, *), !btnIconPalette.isEmpty {
          let cfg = UIImage.SymbolConfiguration(paletteColors: btnIconPalette)
          image = image.applyingSymbolConfiguration(cfg) ?? image
        }
      case "multicolor":
        if #available(iOS 15.0, *) {
          let cfg = UIImage.SymbolConfiguration.preferringMulticolor()
          image = image.applyingSymbolConfiguration(cfg) ?? image
        }
      default:
        break
      }
    } else if let col = btnIconColor {
      if #available(iOS 15.0, *) {
        let cfg = UIImage.SymbolConfiguration(hierarchicalColor: col)
        image = image.applyingSymbolConfiguration(cfg) ?? image
      } else {
        image = image.withTintColor(col, renderingMode: .alwaysOriginal)
      }
    }
    return image
  }

  @available(iOS 15.0, *)
  private func makeButtonSymbolConfiguration() -> UIImage.SymbolConfiguration? {
    if let mode = btnIconMode {
      switch mode {
      case "hierarchical":
        if let c = btnIconColor { return UIImage.SymbolConfiguration(hierarchicalColor: c) }
      case "palette":
        if !btnIconPalette.isEmpty { return UIImage.SymbolConfiguration(paletteColors: btnIconPalette) }
      case "multicolor":
        return UIImage.SymbolConfiguration.preferringMulticolor()
      default:
        break
      }
    } else if let c = btnIconColor {
      return UIImage.SymbolConfiguration(hierarchicalColor: c)
    }
    return nil
  }

  private func applyButtonStyle(buttonStyle: String, round: Bool) {
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
        // Use tinted fallback during transitions to prevent glass sampling artifacts
        if #available(iOS 26.0, *), !isTransitioning { config = .glass() } else { config = .tinted() }
      case "prominentGlass":
        // Use tinted fallback during transitions to prevent glass sampling artifacts
        if #available(iOS 26.0, *), !isTransitioning { config = .prominentGlass() } else { config = .tinted() }
      case "clearGlass":
        if #available(iOS 26.0, *), !isTransitioning { config = .clearGlass() } else { config = .tinted() }
      case "prominentClearGlass":
        if #available(iOS 26.0, *), !isTransitioning { config = .prominentClearGlass() } else { config = .tinted() }
      default:
        config = .plain()
      }
      config.cornerStyle = round ? .capsule : .dynamic
      if let tint = button.tintColor {
        switch buttonStyle {
        case "filled", "borderedProminent", "prominentGlass", "prominentClearGlass":
          config.baseBackgroundColor = tint
        case "tinted", "bordered", "gray", "plain", "glass", "clearGlass":
          config.baseForegroundColor = tint
        default:
          break
        }
      }
      // Restore content after style swap
      config.title = currentTitle
      config.image = currentImage
      config.preferredSymbolConfigurationForImage = currentSymbolCfg
      applyContentOptions(to: &config)
      button.configuration = config
    } else {
      button.layer.cornerRadius = round ? 999 : 8
      button.clipsToBounds = true
      if buttonStyle == "glass" {
        button.backgroundColor = UIColor(white: 1.0, alpha: 0.22)
        button.layer.borderColor = UIColor.separator.withAlphaComponent(0.45).cgColor
        button.layer.borderWidth = 1.0 / UIScreen.main.scale
      } else {
        button.backgroundColor = .clear
        button.layer.borderWidth = 0
      }
    }
  }

  /// The image placement and padding, and the label's font and colour
  /// (#141), which every configuration the button gets carries.
  @available(iOS 15.0, *)
  private func applyContentOptions(to cfg: inout UIButton.Configuration) {
    cfg.imagePlacement = imagePlacement
    if let padding = imagePadding { cfg.imagePadding = padding }
    guard labelFontFamily != nil || labelFontSize != nil || labelFontWeight != nil || labelColor != nil else { return }
    let family = labelFontFamily, size = labelFontSize, color = labelColor
    let weight = CNFontResolver.weight(fromFlutterValue: labelFontWeight)
    cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
      var outgoing = incoming
      let base = incoming.font ?? UIFont.preferredFont(forTextStyle: .body)
      let pointSize = size ?? base.pointSize
      if let family, let font = CNFontResolver.font(family: family, size: pointSize, weight: weight) {
        outgoing.font = font
      } else if let weight {
        outgoing.font = UIFont.systemFont(ofSize: pointSize, weight: weight)
      } else {
        outgoing.font = base.withSize(pointSize)
      }
      if let color { outgoing.foregroundColor = color }
      return outgoing
    }
  }

  private func setButtonContent(title: String?, image: UIImage?, iconOnly: Bool) {
    if #available(iOS 15.0, *) {
      var cfg = button.configuration ?? .plain()
      cfg.title = title
      cfg.image = image
      applyContentOptions(to: &cfg)
      button.configuration = cfg
    } else {
      button.setTitle(title, for: .normal)
      button.setImage(image, for: .normal)
      if iconOnly {
        button.contentEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
      }
    }
  }

  private static func loadFlutterAsset(_ assetPath: String) -> UIImage? {
    return ImageUtils.loadFlutterAsset(assetPath)
  }

  private static func createImageFromData(_ data: Data, format: String?, scale: CGFloat) -> UIImage? {
    return ImageUtils.createImageFromData(data, format: format, scale: scale)
  }

  deinit {
    if #available(iOS 13.0, *) {
      NotificationCenter.default.removeObserver(self)
    }
  }

  @objc private func handleTransitionStateChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let transitioning = userInfo["isTransitioning"] as? Bool else { return }

    self.isTransitioning = transitioning

    // Only swap styles if using glass style on iOS 26+
    if #available(iOS 26.0, *) {
      if ["glass", "prominentGlass", "clearGlass", "prominentClearGlass"].contains(currentButtonStyle) {
        DispatchQueue.main.async {
          self.applyButtonStyle(buttonStyle: self.currentButtonStyle, round: self.isRoundButton)
        }
      }
    }
  }
}

/// The button `CNPopupMenuButton` shows its menu from. It tells when the
/// menu opens and closes (`onOpened`, `onClosed`), and with
/// `keepsSourceVisible` UIKit grows the menu out of a clear stand-in at the
/// button's place instead of out of the button, so the button itself is not
/// morphed into the menu and back (#141).
final class CNPopupMenuUIButton: UIButton {
  var onMenuWillShow: (() -> Void)?
  var onMenuDidHide: (() -> Void)?
  var keepsSourceVisible = false
  private var standIn: UIView?

  private func standInPreview() -> UITargetedPreview? {
    guard keepsSourceVisible, let superview, window != nil else { return nil }
    let stand = standIn ?? {
      let view = UIView()
      view.backgroundColor = .clear
      view.isUserInteractionEnabled = false
      view.isAccessibilityElement = false
      superview.insertSubview(view, belowSubview: self)
      standIn = view
      return view
    }()
    stand.frame = frame
    let parameters = UIPreviewParameters()
    parameters.backgroundColor = .clear
    parameters.visiblePath = UIBezierPath(roundedRect: stand.bounds, cornerRadius: min(bounds.width, bounds.height) / 2)
    return UITargetedPreview(view: stand, parameters: parameters)
  }

  override func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
  ) -> UITargetedPreview? {
    standInPreview() ?? super.contextMenuInteraction(interaction, previewForHighlightingMenuWithConfiguration: configuration)
  }

  override func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
  ) -> UITargetedPreview? {
    standInPreview() ?? super.contextMenuInteraction(interaction, previewForDismissingMenuWithConfiguration: configuration)
  }

  override func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    willDisplayMenuFor configuration: UIContextMenuConfiguration,
    animator: UIContextMenuInteractionAnimating?
  ) {
    super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
    onMenuWillShow?()
  }

  override func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    willEndFor configuration: UIContextMenuConfiguration,
    animator: UIContextMenuInteractionAnimating?
  ) {
    super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
    let done = { [weak self] in
      self?.standIn?.removeFromSuperview()
      self?.standIn = nil
      self?.onMenuDidHide?()
    }
    if let animator { animator.addCompletion(done) } else { done() }
  }
}
