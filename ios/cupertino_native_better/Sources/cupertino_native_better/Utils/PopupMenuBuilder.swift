import Flutter
import UIKit

/// Builds UIKit menus from the levels `encodePopupMenuEntries` sends, for
/// `CNPopupMenuButton` and the tab bar items that open a menu.
enum PopupMenuBuilder {
  /// Builds the elements of one menu [level]. [path] is the level's own
  /// path from the top: empty for the top level, then one index per submenu.
  @available(iOS 14.0, *)
  static func elements(
    level: PopupMenuLevel,
    path: [Int] = [],
    iconScale: CGFloat,
    onSelect: @escaping ([Int]) -> Void
  ) -> [UIMenuElement] {
    var groups: [[UIMenuElement]] = []
    var current: [UIMenuElement] = []
    let count = max(level.labels.count, max(level.symbols.count, level.dividers.count))
    let flushGroup: () -> Void = {
      if !current.isEmpty { groups.append(current); current = [] }
    }
    for i in 0..<count {
        let isDiv = i < level.dividers.count ? level.dividers[i] : false
        if isDiv { flushGroup(); continue }
        let title = i < level.labels.count ? level.labels[i] : ""
        let image = Self.image(level: level, at: i, iconScale: iconScale)
        let isEnabled = i < level.enabled.count ? level.enabled[i] : true
        let isChecked = i < level.checked.count ? level.checked[i] : false
        let destructive = i < level.isDestructive.count ? level.isDestructive[i] : false
        let subtitle = i < level.subtitles.count && !level.subtitles[i].isEmpty ? level.subtitles[i] : nil
        let itemPath = path + [i]
        // A submenu becomes a nested UIMenu. UIMenu has no disabled state,
        // so a disabled submenu is shown as a disabled action instead.
        if i < level.isSubmenu.count, level.isSubmenu[i], isEnabled {
          let childLevel = (i < level.submenus.count ? level.submenus[i] : nil)
            .map { PopupMenuLevel(dict: $0) } ?? PopupMenuLevel()
          let style = i < level.submenuStyles.count ? level.submenuStyles[i] : nil
          var children = elements(level: childLevel, path: itemPath, iconScale: iconScale, onSelect: onSelect)
          // A level without dividers is one untitled group; a palette or an
          // element size lays out the submenu's own children, so it gets the
          // items themselves.
          if children.count == 1, let group = children[0] as? UIMenu, group.title.isEmpty {
            children = group.children
          }
          let menu = UIMenu(
            title: title,
            subtitle: subtitle,
            image: image,
            options: Self.options(style: style),
            children: children
          )
          if #available(iOS 16.0, *), i < level.elementSizes.count,
             let size = Self.elementSize(level.elementSizes[i]) {
            menu.preferredElementSize = size
          }
          // An inline menu inside the inline group below is flattened into
          // it, losing its palette and element size: it is a section of its
          // own instead.
          if menu.options.contains(.displayInline) {
            flushGroup()
            groups.append([menu])
            continue
          }
          current.append(menu)
          continue
        }
        // Compose menu attributes: .destructive paints the label red
        // (system destructive color); .disabled greys it out.
        var attrs: UIMenuElement.Attributes = []
        if !isEnabled { attrs.insert(.disabled) }
        if destructive { attrs.insert(.destructive) }
        if #available(iOS 16.0, *), i < level.keepsMenuPresented.count, level.keepsMenuPresented[i] {
          attrs.insert(.keepsMenuPresented)
        }
        // The subtitle goes through the initializer: `action.subtitle` is
        // UIMenuLeaf's setter, which needs iOS 16.
        let action = UIAction(title: title, subtitle: subtitle, image: image, attributes: attrs) { _ in
          onSelect(itemPath)
        }
        action.state = isChecked ? .on : .off
        current.append(action)
      }
    flushGroup()
    let children: [UIMenuElement] = groups.map { group in
      if group.count == 1, let menu = group[0] as? UIMenu, menu.options.contains(.displayInline) {
        return menu
      }
      return UIMenu(title: "", options: .displayInline, children: group)
    }
    return children
  }

  /// A submenu shown in place: a section for `inline`, a row of icons for
  /// `palette` (iOS 17; a section before).
  private static func options(style: String?) -> UIMenu.Options {
    switch style {
    case "inline":
      return .displayInline
    case "palette":
      if #available(iOS 17.0, *) { return [.displayInline, .displayAsPalette] }
      return .displayInline
    default:
      return []
    }
  }

  @available(iOS 16.0, *)
  private static func elementSize(_ name: String?) -> UIMenu.ElementSize? {
    switch name {
    case "small": return .small
    case "medium": return .medium
    case "large": return .large
    default: return nil
    }
  }

  /// The icon of entry [i] of [level].
  /// Priority: imageAsset > customIconBytes > SF Symbol
  static func image(level: PopupMenuLevel, at i: Int, iconScale: CGFloat) -> UIImage? {
    var image: UIImage? = nil
    // Priority: imageAsset > customIconBytes > SF Symbol
    
    // Handle imageAsset (highest priority)
    if i < level.imageAssetPaths.count, !level.imageAssetPaths[i].isEmpty {
      let assetPath = level.imageAssetPaths[i]
      let format = i < level.imageAssetFormats.count ? level.imageAssetFormats[i] : nil
      let iconColorARGB: Int? = {
        if i < level.colors.count, let colorNum = level.colors[i] as? NSNumber, !(level.colors[i] is NSNull) {
          return colorNum.intValue
        }
        return nil
      }()
      let iconSize: CGFloat? = {
        if i < level.sizes.count, let sizeNum = level.sizes[i] as? NSNumber {
          return CGFloat(truncating: sizeNum)
        }
        return 18.0
      }()
      
      // Use utility function to load and optionally tint image
      if let argb = iconColorARGB, #available(iOS 13.0, *) {
        image = ImageUtils.loadAndTintImage(
          from: assetPath,
          iconSize: iconSize,
          iconColor: argb,
          providedFormat: format,
          scale: iconScale
        )
      } else {
        let size = CGSize(width: iconSize ?? 18, height: iconSize ?? 18)
        // Single-colour artwork templates losslessly and picks up the
        // menu's own colouring; multi-colour artwork keeps its pixels.
        image = ImageUtils.templatedIfMonochrome(
          ImageUtils.loadFlutterAsset(assetPath, size: size, format: format, scale: iconScale)
        )
      }
    } else if i < level.imageAssetData.count, let data = level.imageAssetData[i] {
      let format = i < level.imageAssetFormats.count ? level.imageAssetFormats[i] : nil
      let iconColorARGB: Int? = {
        if i < level.colors.count, let colorNum = level.colors[i] as? NSNumber, !(level.colors[i] is NSNull) {
          return colorNum.intValue
        }
        return nil
      }()
      let iconSize: CGFloat? = {
        if i < level.sizes.count, let sizeNum = level.sizes[i] as? NSNumber {
          return CGFloat(truncating: sizeNum)
        }
        return 18.0
      }()
      
      // Use utility function to create and optionally tint image
      if let argb = iconColorARGB, #available(iOS 13.0, *) {
        image = ImageUtils.createAndTintImage(
          from: data,
          iconSize: iconSize,
          iconColor: argb,
          providedFormat: format,
          scale: iconScale
        )
      } else {
        let size: CGSize? = iconSize != nil ? CGSize(width: iconSize!, height: iconSize!) : nil
        // Single-colour artwork templates losslessly and picks up the
        // menu's own colouring; multi-colour artwork keeps its pixels.
        image = ImageUtils.templatedIfMonochrome(
          ImageUtils.createImageFromData(data, format: format, size: size, scale: iconScale)
        )
      }
    }
    
    // Handle custom icon bytes (medium priority)
    if image == nil, i < level.customIconBytes.count, let data = level.customIconBytes[i] {
      image = UIImage(data: data, scale: iconScale)?.withRenderingMode(.alwaysTemplate)
      // Apply tint color to custom icon if provided
      if i < level.customIconColors.count, 
         let colorNum = level.customIconColors[i] as? NSNumber,
         !(level.customIconColors[i] is NSNull) {
        let tintColor = ImageUtils.colorFromARGB(colorNum.intValue)
        image = image?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
      }
    }
    
    // Handle SF Symbol (lowest priority)
    if image == nil, i < level.symbols.count, !level.symbols[i].isEmpty {
      image = UIImage(systemName: level.symbols[i])
    }
    if i < level.sizes.count,
       let sizeNum = level.sizes[i] as? NSNumber {
      let s = CGFloat(truncating: sizeNum)
      if s > 0, let img = image { image = img.applyingSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: s)) }
    }
    // Rendering mode: prefer explicit per-item mode when provided; else fallback to color
    if i < level.modes.count, let mode = level.modes[i] {
      switch mode {
      case "hierarchical":
        if #available(iOS 15.0, *), i < level.colors.count,
           let colorNum = level.colors[i] as? NSNumber {
          let c = ImageUtils.colorFromARGB(colorNum.intValue)
          if let img = image {
            let cfg = UIImage.SymbolConfiguration(hierarchicalColor: c)
            image = img.applyingSymbolConfiguration(cfg)
          }
        }
      case "palette":
        if #available(iOS 15.0, *), i < level.palettes.count, !level.palettes[i].isEmpty {
          let cols = level.palettes[i].map { ImageUtils.colorFromARGB($0.intValue) }
          if let img = image {
            let cfg = UIImage.SymbolConfiguration(paletteColors: cols)
            image = img.applyingSymbolConfiguration(cfg)
          }
        }
      case "multicolor":
        if #available(iOS 15.0, *) {
          if let img = image {
            let cfg = UIImage.SymbolConfiguration.preferringMulticolor()
            image = img.applyingSymbolConfiguration(cfg)
          }
        }
      case "monochrome":
        // Explicit monochrome: use direct tint color if provided
        if i < level.colors.count,
           let colorNum = level.colors[i] as? NSNumber {
          let c = ImageUtils.colorFromARGB(colorNum.intValue)
          if let img = image, #available(iOS 13.0, *) {
            image = img.withTintColor(c, renderingMode: .alwaysOriginal)
          }
        }
      default:
        break
      }
    } else if i < level.colors.count,
              let colorNum = level.colors[i] as? NSNumber {
      let c = ImageUtils.colorFromARGB(colorNum.intValue)
      if let img = image, #available(iOS 13.0, *) {
        image = img.withTintColor(c, renderingMode: .alwaysOriginal)
      }
    }
    return image
  }
}

/// One level of the popup menu: the parallel arrays Flutter sends for a list
/// of entries (one slot per item, submenu or divider), and each submenu's own
/// level in `submenus`.
struct PopupMenuLevel {
  var labels: [String] = []
  var symbols: [String] = []
  var customIconBytes: [Data?] = []
  var customIconColors: [Any] = []
  var imageAssetPaths: [String] = []
  var imageAssetData: [Data?] = []
  var imageAssetFormats: [String] = []
  var dividers: [Bool] = []
  var enabled: [Bool] = []
  var checked: [Bool] = []
  var isDestructive: [Bool] = []
  var sizes: [Any] = []
  var colors: [Any] = []
  var modes: [String?] = []
  var palettes: [[NSNumber]] = []
  var subtitles: [String] = []
  var isSubmenu: [Bool] = []
  var submenus: [[String: Any]?] = []
  var keepsMenuPresented: [Bool] = []
  var submenuStyles: [String?] = []
  var elementSizes: [String?] = []

  init() {}

  /// Reads a level encoded by `encodePopupMenuEntries`, with the same keys
  /// and types as the top level.
  init(dict: [String: Any]) {
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
    dividers = ((dict["isDivider"] as? [NSNumber]) ?? []).map { $0.boolValue }
    enabled = ((dict["enabled"] as? [NSNumber]) ?? []).map { $0.boolValue }
    checked = ((dict["checked"] as? [NSNumber]) ?? []).map { $0.boolValue }
    isDestructive = ((dict["isDestructive"] as? [NSNumber]) ?? []).map { $0.boolValue }
    sizes = (dict["sfSymbolSizes"] as? [Any]) ?? []
    colors = (dict["sfSymbolColors"] as? [Any]) ?? []
    modes = (dict["sfSymbolRenderingModes"] as? [String?]) ?? []
    palettes = (dict["sfSymbolPaletteColors"] as? [[NSNumber]]) ?? []
    subtitles = (dict["subtitles"] as? [String]) ?? []
    isSubmenu = ((dict["isSubmenu"] as? [NSNumber]) ?? []).map { $0.boolValue }
    submenus = ((dict["submenus"] as? [Any]) ?? []).map { $0 as? [String: Any] }
    keepsMenuPresented = ((dict["keepsMenuPresented"] as? [NSNumber]) ?? []).map { $0.boolValue }
    submenuStyles = ((dict["submenuStyles"] as? [Any]) ?? []).map { $0 as? String }
    elementSizes = ((dict["elementSizes"] as? [Any]) ?? []).map { $0 as? String }
  }
}
