import Cocoa
import FlutterMacOS

/// Builds an `NSMenu` from the levels `encodePopupMenuEntries`
/// (`lib/utils/popup_menu_encoder.dart`) sends: items, dividers, subtitles,
/// nested and inline submenus, SF Symbol / rendered / image-asset icons,
/// destructive, disabled and checked items.
///
/// Shared by every macOS menu the plugin shows outside a platform view:
/// `CNContextMenu`, `CNPopupGesture`'s secondary click and the anchored
/// `CNActionSheet`. A selection reports the item's path from the top, one
/// index per level, dividers included, as `onPathSelected` does on iOS.
enum MacMenuBuilder {
  /// Builds the menu of the top [level]; [onSelect] gets the path of the
  /// chosen item. Nothing is called when the menu closes without a choice.
  static func menu(
    level: MacMenuLevel,
    appearance: NSAppearance? = nil,
    onSelect: @escaping ([Int]) -> Void
  ) -> NSMenu {
    let menu = build(level: level, path: [], onSelect: onSelect)
    if let appearance { menu.appearance = appearance }
    // Exactly the items the app gave: no system items appended when the
    // menu opens as a context menu (on macOS 27, "Ask Siri" at the top).
    menu.allowsContextMenuPlugIns = false
    #if compiler(>=6.0.3)
    if #available(macOS 15.2, *) {
      menu.automaticallyInsertsWritingToolsItems = false
    }
    #endif
    return menu
  }

  private static func build(
    level: MacMenuLevel,
    path: [Int],
    onSelect: @escaping ([Int]) -> Void
  ) -> NSMenu {
    let menu = NSMenu()
    // Each item's `isEnabled` is the payload's, not the target's answer.
    menu.autoenablesItems = false
    let delegate = MacMenuDelegate()
    menu.delegate = delegate
    // `delegate` is weak; the menu keeps its own.
    objc_setAssociatedObject(menu, &MacMenuDelegate.key, delegate, .OBJC_ASSOCIATION_RETAIN)
    for i in 0..<level.count {
      if level.isDivider(i) {
        // No leading, trailing or doubled separators: AppKit draws each one.
        if let last = menu.items.last, !last.isSeparatorItem {
          menu.addItem(.separator())
        }
        continue
      }
      let title = level.label(i)
      let itemPath = path + [i]
      let enabled = level.isEnabled(i)

      if level.isSubmenu(i) {
        let childLevel = level.submenu(i)
        if enabled, level.submenuStyle(i) != nil {
          // Inline and palette submenus show their items in place, under a
          // section header (macOS 14+). AppKit has no palette row of this
          // kind, so a palette is shown as a section as well.
          if let last = menu.items.last, !last.isSeparatorItem {
            menu.addItem(.separator())
          }
          if !title.isEmpty {
            menu.addItem(sectionHeader(title))
          }
          let section = build(level: childLevel, path: itemPath, onSelect: onSelect)
          for item in section.items {
            section.removeItem(item)
            menu.addItem(item)
          }
          continue
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        // An item with neither an action nor a submenu is disabled: a
        // disabled submenu simply gets no submenu.
        if enabled {
          let submenu = build(level: childLevel, path: itemPath, onSelect: onSelect)
          submenu.title = title
          item.submenu = submenu
        }
        item.isEnabled = enabled
        decorate(item, level: level, at: i)
        menu.addItem(item)
        continue
      }

      let action = MacMenuAction(path: itemPath, onSelect: onSelect)
      let item = NSMenuItem(
        title: title, action: #selector(MacMenuAction.menuItemChosen(_:)), keyEquivalent: "")
      item.target = action
      // `target` is weak; the item keeps its action alive.
      item.representedObject = action
      item.isEnabled = enabled
      item.state = level.isChecked(i) ? .on : .off
      decorate(item, level: level, at: i)
      if level.isDestructive(i) {
        // AppKit has no destructive menu item style; the label and a
        // symbol icon are drawn in the system red, as the destructive
        // attribute does on iOS. The highlighted item goes back to the
        // plain title and icon (see MacMenuDelegate), which AppKit draws in
        // the highlight's text colour: red on the accent colour is hard to
        // read.
        action.isDestructive = true
        action.plainTitle = title
        action.plainImage = item.image
        let red = NSAttributedString(
          string: title,
          attributes: [
            .foregroundColor: enabled ? NSColor.systemRed : NSColor.systemRed.withAlphaComponent(0.4),
            .font: NSFont.menuFont(ofSize: 0),
          ])
        action.redTitle = red
        item.attributedTitle = red
        if let image = item.image, image.isTemplate, level.color(i) == nil {
          let redImage = image.withSymbolConfiguration(.init(paletteColors: [.systemRed])) ?? image
          action.redImage = redImage
          item.image = redImage
        } else {
          action.redImage = item.image
        }
      }
      menu.addItem(item)
    }
    if let last = menu.items.last, last.isSeparatorItem {
      menu.removeItem(last)
    }
    return menu
  }

  /// Subtitle and icon of entry [i].
  private static func decorate(_ item: NSMenuItem, level: MacMenuLevel, at i: Int) {
    if #available(macOS 14.4, *), let subtitle = level.subtitle(i) {
      item.subtitle = subtitle
    }
    if let image = image(level: level, at: i) {
      item.image = image
      showImage(of: item)
    }
  }

  /// From macOS 27 AppKit hides most menu item images unless asked to show
  /// them. An icon the app set is part of the item, so it is kept.
  static func showImage(of item: NSMenuItem) {
    #if compiler(>=6.4)
    if #available(macOS 27.0, *) {
      item.preferredImageVisibility = .visible
    }
    #endif
  }

  static func sectionHeader(_ title: String) -> NSMenuItem {
    if #available(macOS 14.0, *) {
      return .sectionHeader(title: title)
    }
    let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    header.isEnabled = false
    return header
  }

  // MARK: - Icons

  /// The icon of entry [i]: image asset, then rendered custom icon, then SF
  /// Symbol, as on iOS.
  static func image(level: MacMenuLevel, at i: Int) -> NSImage? {
    let size = level.size(i)
    let color = level.color(i)
    if let path = level.imageAssetPath(i), let img = loadAsset(path) {
      return sized(tinted(img, color), size ?? 16)
    }
    if let data = level.imageAssetData(i), let img = NSImage(data: data) {
      return sized(tinted(img, color), size ?? 16)
    }
    if let data = level.customIconBytes(i), let img = NSImage(data: data) {
      // Rendered by Flutter at the screen scale, in the requested colour.
      let scale = NSScreen.main?.backingScaleFactor ?? 2
      img.size = NSSize(width: img.size.width / scale, height: img.size.height / scale)
      return img
    }
    guard let name = level.symbol(i),
          var img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    else { return nil }
    if let s = size, s > 0 {
      img = img.withSymbolConfiguration(.init(pointSize: s, weight: .regular)) ?? img
    }
    switch level.mode(i) {
    case "hierarchical":
      if let c = color {
        img = img.withSymbolConfiguration(.init(hierarchicalColor: c)) ?? img
      }
    case "palette":
      let colors = level.palette(i)
      if !colors.isEmpty {
        img = img.withSymbolConfiguration(.init(paletteColors: colors)) ?? img
      }
    case "multicolor":
      img = img.withSymbolConfiguration(.preferringMulticolor()) ?? img
    default:
      // Monochrome or no mode: a colour paints the whole symbol; without one
      // it stays a template and follows the menu's own text colour.
      if let c = color {
        img = img.withSymbolConfiguration(.init(paletteColors: [c])) ?? img
      }
    }
    return img
  }

  /// A Flutter asset by its (resolved) asset path.
  private static func loadAsset(_ path: String) -> NSImage? {
    let key = FlutterDartProject.lookupKey(forAsset: path)
    let candidates = [
      Bundle.main.bundleURL.appendingPathComponent(key),
      Bundle.main.bundleURL
        .appendingPathComponent("Contents/Frameworks/App.framework/Resources/flutter_assets")
        .appendingPathComponent(path),
    ]
    for url in candidates where FileManager.default.fileExists(atPath: url.path) {
      if let img = NSImage(contentsOf: url) { return img }
    }
    return nil
  }

  private static func sized(_ image: NSImage, _ side: CGFloat) -> NSImage {
    let w = image.size.width, h = image.size.height
    guard w > 0, h > 0 else { return image }
    let scale = side / max(w, h)
    image.size = NSSize(width: w * scale, height: h * scale)
    return image
  }

  private static func tinted(_ image: NSImage, _ color: NSColor?) -> NSImage {
    guard let color else {
      // Single-colour artwork follows the menu's colouring like a symbol.
      return image
    }
    let out = NSImage(size: image.size, flipped: false) { rect in
      image.draw(in: rect)
      color.set()
      rect.fill(using: .sourceAtop)
      return true
    }
    return out
  }

  static func color(argb: Int) -> NSColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
  }
}

/// The target of one menu item: reports its path when chosen.
final class MacMenuAction: NSObject {
  let path: [Int]
  private let onSelect: ([Int]) -> Void

  /// A destructive item's red title and icon, and its plain icon for the
  /// highlighted state.
  var isDestructive = false
  var plainTitle = ""
  var redTitle: NSAttributedString?
  var redImage: NSImage?
  var plainImage: NSImage?

  init(path: [Int], onSelect: @escaping ([Int]) -> Void) {
    self.path = path
    self.onSelect = onSelect
  }

  @objc func menuItemChosen(_ sender: NSMenuItem) {
    onSelect(path)
  }
}

/// Shows a highlighted destructive item with its plain title and icon, so
/// AppKit draws them in the highlight's text colour, and puts the red ones
/// back when the highlight moves on.
final class MacMenuDelegate: NSObject, NSMenuDelegate {
  static var key: UInt8 = 0
  private weak var highlighted: NSMenuItem?

  func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
    if let previous = highlighted, previous !== item { restore(previous) }
    if let item, let action = item.representedObject as? MacMenuAction, action.isDestructive {
      // The same title without a colour, which AppKit draws in the
      // highlight's text colour.
      item.attributedTitle = NSAttributedString(
        string: action.plainTitle, attributes: [.font: NSFont.menuFont(ofSize: 0)])
      item.image = action.plainImage
    }
    highlighted = item
  }

  func menuDidClose(_ menu: NSMenu) {
    if let previous = highlighted { restore(previous) }
    highlighted = nil
  }

  private func restore(_ item: NSMenuItem) {
    guard let action = item.representedObject as? MacMenuAction, action.isDestructive else { return }
    item.attributedTitle = action.redTitle
    item.image = action.redImage
  }
}

/// One level of a popup menu: the parallel arrays `encodePopupMenuEntries`
/// sends for a list of entries (one slot per item, submenu or divider), and
/// each submenu's own level in `submenus`. Reads every array leniently: a
/// slot that is missing, null or of another type reads as "not set".
struct MacMenuLevel {
  private let dict: [String: Any]

  init(dict: [String: Any]) {
    self.dict = dict
  }

  var count: Int {
    max(array("labels").count, array("sfSymbols").count, array("isDivider").count)
  }

  private func array(_ key: String) -> [Any] {
    (dict[key] as? [Any]) ?? []
  }

  private func slot(_ key: String, _ i: Int) -> Any? {
    let a = array(key)
    guard i < a.count, !(a[i] is NSNull) else { return nil }
    return a[i]
  }

  private func bool(_ key: String, _ i: Int, _ fallback: Bool) -> Bool {
    (slot(key, i) as? NSNumber)?.boolValue ?? fallback
  }

  private func string(_ key: String, _ i: Int) -> String? {
    guard let s = slot(key, i) as? String, !s.isEmpty else { return nil }
    return s
  }

  private func data(_ key: String, _ i: Int) -> Data? {
    if let typed = slot(key, i) as? FlutterStandardTypedData { return typed.data }
    return slot(key, i) as? Data
  }

  func label(_ i: Int) -> String { string("labels", i) ?? "" }
  func isDivider(_ i: Int) -> Bool { bool("isDivider", i, false) }
  func isEnabled(_ i: Int) -> Bool { bool("enabled", i, true) }
  func isChecked(_ i: Int) -> Bool { bool("checked", i, false) }
  func isDestructive(_ i: Int) -> Bool { bool("isDestructive", i, false) }
  func isSubmenu(_ i: Int) -> Bool { bool("isSubmenu", i, false) }
  func subtitle(_ i: Int) -> String? { string("subtitles", i) }
  func symbol(_ i: Int) -> String? { string("sfSymbols", i) }
  func mode(_ i: Int) -> String? { string("sfSymbolRenderingModes", i) }
  func submenuStyle(_ i: Int) -> String? { string("submenuStyles", i) }
  func imageAssetPath(_ i: Int) -> String? { string("imageAssetPaths", i) }
  func imageAssetData(_ i: Int) -> Data? { data("imageAssetData", i) }
  func customIconBytes(_ i: Int) -> Data? { data("customIconBytes", i) }

  func size(_ i: Int) -> CGFloat? {
    (slot("sfSymbolSizes", i) as? NSNumber).map { CGFloat(truncating: $0) }
  }

  func color(_ i: Int) -> NSColor? {
    (slot("sfSymbolColors", i) as? NSNumber).map { MacMenuBuilder.color(argb: $0.intValue) }
  }

  func palette(_ i: Int) -> [NSColor] {
    ((slot("sfSymbolPaletteColors", i) as? [Any]) ?? [])
      .compactMap { $0 as? NSNumber }
      .map { MacMenuBuilder.color(argb: $0.intValue) }
  }

  func submenu(_ i: Int) -> MacMenuLevel {
    MacMenuLevel(dict: (slot("submenus", i) as? [String: Any]) ?? [:])
  }
}
