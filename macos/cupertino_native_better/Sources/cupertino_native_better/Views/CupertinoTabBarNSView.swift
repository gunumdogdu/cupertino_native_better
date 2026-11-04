import FlutterMacOS
import Cocoa

/// `CNTabBar` on macOS: an `NSSegmentedControl` used as a row of tabs, the
/// way Mac apps switch between views (with `role = .tabs` on macOS 27).
///
/// - Each tab shows its image and its label side by side, by the iOS
///   priority: an image asset (Flutter asset or bytes, PNG/JPG/GIF/SVG),
///   then a custom icon, then the SF Symbol; the selected tab shows its
///   active image (`activeImageAsset`, `activeCustomIcon`, `activeIcon`).
///   Single-colour art becomes a template, as symbols are, so it reads on
///   the selection; multi-colour art keeps its colours.
/// - The control keeps its natural width and is centred in the bar, with
///   room around it, so it is not clipped by the window's rounded corners.
/// - `tint` colours the selected segment where AppKit lets it
///   (`selectedSegmentBezelColor`); the `.tabs` role of macOS 27 draws its
///   own neutral selection and ignores it. Symbols stay template images, so
///   AppKit picks a colour that reads on the selection.
/// - `badge` is drawn as a small red capsule (or dot for `dotBadge`) at the
///   top-trailing corner of the tab's content: AppKit has no segment badge.
/// - `split` has no AppKit counterpart and is ignored: the tabs stay in one
///   control. A `searchItem` becomes a trailing tab with its symbol and
///   label which, like the iOS 26 search tab, reports `searchActiveChanged`
///   instead of `valueChanged`; the app shows its own search field.
/// - Item menus (`menuItems`) stay plain tabs.
class CupertinoTabBarNSView: NSView {
  /// Room around the control: it must not touch the window's rounded corners
  /// at the bottom of a window, and the badges reach above it.
  private static let horizontalPadding: CGFloat = 16
  private static let verticalPadding: CGFloat = 8
  /// Point size of a symbol at `CNSymbol`'s default size (24): the size of
  /// the control's label font, so icon and label match.
  private static let defaultSymbolPointSize: CGFloat = 13
  private static let defaultRequestedIconSize: CGFloat = 24

  private let channel: FlutterMethodChannel
  private let control: NSSegmentedControl

  private var labels: [String] = []
  private var symbols: [String] = []
  private var activeSymbols: [String] = []
  private var badges: [String] = []
  private var customIconBytes: [Data?] = []
  private var activeCustomIconBytes: [Data?] = []
  /// `CNTabBarItem.imageAsset` / `activeImageAsset`: a Flutter asset path,
  /// its bytes and their format ("" where an item has none).
  private var imageAssetPaths: [String] = []
  private var activeImageAssetPaths: [String] = []
  private var imageAssetData: [Data?] = []
  private var activeImageAssetData: [Data?] = []
  private var imageAssetFormats: [String] = []
  private var activeImageAssetFormats: [String] = []
  private var sizes: [CGFloat?] = []
  private var tint: NSColor?
  private var labelFontFamily: String?
  private var labelFontSize: CGFloat?

  private var hasSearch = false
  private var searchLabel = "Search"
  private var searchSymbol = "magnifyingglass"
  private var searchActiveSymbol = "magnifyingglass"
  private var searchActive = false
  /// The selected tab (not the search tab).
  private var selectedIndex = 0

  private var badgeViews: [Int: CNMacTabBadgeView] = [:]

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeTabBar_\(viewId)", binaryMessenger: messenger)
    self.control = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)

    super.init(frame: .zero)

    var isDark = false
    var background: NSColor?
    if let dict = args as? [String: Any] {
      readItems(dict)
      if let v = dict["selectedIndex"] as? NSNumber { selectedIndex = v.intValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let style = dict["style"] as? [String: Any] {
        if let n = style["tint"] as? NSNumber { tint = Self.colorFromARGB(n.intValue) }
        if let n = style["backgroundColor"] as? NSNumber { background = Self.colorFromARGB(n.intValue) }
      }
      readFont(dict)
      if (dict["hasSearch"] as? NSNumber)?.boolValue == true {
        hasSearch = true
        if let v = dict["searchLabel"] as? String, !v.isEmpty { searchLabel = v }
        if let v = dict["searchSymbol"] as? String, !v.isEmpty { searchSymbol = v }
        if let v = dict["searchActiveSymbol"] as? String, !v.isEmpty { searchActiveSymbol = v }
      }
    }

    wantsLayer = true
    layer?.backgroundColor = (background ?? .clear).cgColor
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    // Tabs share the width equally, as UITabBar items do.
    control.segmentDistribution = .fillEqually
    #if canImport(AppKit, _version: 2775)
    if #available(macOS 27.0, *) {
      // The macOS 27 look for a segmented control that switches views.
      control.role = .tabs
    }
    #endif
    control.target = self
    control.action = #selector(onChanged(_:))
    applyFont()
    rebuildSegments()
    applyTint()

    control.translatesAutoresizingMaskIntoConstraints = false
    addSubview(control)
    // Natural width, centred; it only shrinks when the bar is narrower.
    let pad = Self.horizontalPadding
    NSLayoutConstraint.activate([
      control.centerXAnchor.constraint(equalTo: centerXAnchor),
      control.centerYAnchor.constraint(equalTo: centerYAnchor),
      control.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: pad),
      control.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -pad),
    ])

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      self.handle(call, result: result)
    }
  }

  required init?(coder: NSCoder) { return nil }

  // MARK: - Method channel

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "getIntrinsicSize":
      let size = control.intrinsicContentSize
      result([
        "width": Double(size.width + 2 * Self.horizontalPadding),
        "height": Double(size.height + 2 * Self.verticalPadding),
      ])
    case "setSelectedIndex":
      if let idx = (args?["index"] as? NSNumber)?.intValue {
        selectedIndex = idx
        if !searchActive { control.selectedSegment = idx }
        refreshImages()
        result(nil)
      } else { result(FlutterError(code: "bad_args", message: "Missing index", details: nil)) }
    case "setItems":
      if let args = args {
        readItems(args)
        if let v = args["selectedIndex"] as? NSNumber { selectedIndex = v.intValue }
        rebuildSegments()
        result(nil)
      } else { result(FlutterError(code: "bad_args", message: "Missing items", details: nil)) }
    case "setBadges":
      if let badges = args?["badges"] as? [String] {
        self.badges = badges
        applyBadges()
        result(nil)
      } else { result(FlutterError(code: "bad_args", message: "Missing badges", details: nil)) }
    case "setStyle":
      if let args = args {
        if let n = args["tint"] as? NSNumber { tint = Self.colorFromARGB(n.intValue) }
        if let n = args["backgroundColor"] as? NSNumber {
          layer?.backgroundColor = Self.colorFromARGB(n.intValue).cgColor
        }
        applyTint()
        result(nil)
      } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
    case "setFont":
      readFont(args ?? [:])
      applyFont()
      needsLayout = true
      result(nil)
    case "setLayout":
      // `split`, `rightCount` and `splitSpacing` have no AppKit counterpart:
      // the tabs stay in one segmented control.
      if let v = (args?["selectedIndex"] as? NSNumber)?.intValue {
        selectedIndex = v
        if !searchActive { control.selectedSegment = v }
        refreshImages()
      }
      result(nil)
    case "setBrightness":
      if let isDark = (args?["isDark"] as? NSNumber)?.boolValue {
        appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        result(nil)
      } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
    case "activateSearch":
      if hasSearch { setSearchActive(true) }
      result(nil)
    case "deactivateSearch":
      if hasSearch { setSearchActive(false) }
      result(nil)
    case "setSearchText", "setMenus", "refresh", "setInteractive":
      // The search text lives in the app's own field; item menus stay plain
      // tabs; `refresh` works around a UITabBar layout bug.
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Reading arguments

  private func readItems(_ dict: [String: Any]) {
    labels = (dict["labels"] as? [String]) ?? []
    symbols = (dict["sfSymbols"] as? [String]) ?? []
    activeSymbols = (dict["activeSfSymbols"] as? [String]) ?? []
    badges = (dict["badges"] as? [String]) ?? []
    customIconBytes = ((dict["customIconBytes"] as? [Any]) ?? []).map { ($0 as? FlutterStandardTypedData)?.data }
    activeCustomIconBytes = ((dict["activeCustomIconBytes"] as? [Any]) ?? []).map { ($0 as? FlutterStandardTypedData)?.data }
    imageAssetPaths = (dict["imageAssetPaths"] as? [Any] ?? []).map { ($0 as? String) ?? "" }
    activeImageAssetPaths = (dict["activeImageAssetPaths"] as? [Any] ?? []).map { ($0 as? String) ?? "" }
    imageAssetData = ((dict["imageAssetData"] as? [Any]) ?? []).map { ($0 as? FlutterStandardTypedData)?.data }
    activeImageAssetData = ((dict["activeImageAssetData"] as? [Any]) ?? []).map { ($0 as? FlutterStandardTypedData)?.data }
    imageAssetFormats = (dict["imageAssetFormats"] as? [Any] ?? []).map { ($0 as? String) ?? "" }
    activeImageAssetFormats = (dict["activeImageAssetFormats"] as? [Any] ?? []).map { ($0 as? String) ?? "" }
    sizes = ((dict["sfSymbolSizes"] as? [Any]) ?? []).map { ($0 as? NSNumber).map { CGFloat(truncating: $0) } }
  }

  private func readFont(_ dict: [String: Any]) {
    labelFontFamily = (dict["labelFontFamily"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    labelFontSize = (dict["labelFontSize"] as? NSNumber).map { CGFloat(truncating: $0) }
  }

  // MARK: - Segments

  private var itemCount: Int {
    max(labels.count, symbols.count, customIconBytes.count, imageAssetPaths.count, imageAssetData.count)
  }

  private var searchSegment: Int? { hasSearch ? itemCount : nil }

  private func rebuildSegments() {
    let count = itemCount + (hasSearch ? 1 : 0)
    control.segmentCount = count
    for i in 0..<itemCount {
      control.setLabel(i < labels.count ? labels[i] : "", forSegment: i)
    }
    if let s = searchSegment {
      control.setLabel(searchLabel, forSegment: s)
    }
    if searchActive, let s = searchSegment {
      control.selectedSegment = s
    } else if selectedIndex >= 0 && selectedIndex < itemCount {
      control.selectedSegment = selectedIndex
    } else {
      control.selectedSegment = -1
    }
    refreshImages()
    applyBadges()
    invalidateIntrinsicContentSize()
  }

  /// Sets each segment's image: the active symbol or icon on the selected
  /// segment, the plain one elsewhere.
  private func refreshImages() {
    let selected = control.selectedSegment
    for i in 0..<itemCount {
      control.setImage(image(for: i, active: i == selected), forSegment: i)
      control.setImageScaling(.scaleProportionallyDown, forSegment: i)
    }
    if let s = searchSegment {
      let name = s == selected ? searchActiveSymbol : searchSymbol
      control.setImage(symbolImage(name, requestedSize: nil, description: searchLabel), forSegment: s)
    }
  }

  private func image(for i: Int, active: Bool) -> NSImage? {
    let label = i < labels.count ? labels[i] : ""
    let requested = i < sizes.count ? sizes[i] : nil
    // An image asset wins; the active one on the selected tab, else the
    // plain one for both states.
    if active, let image = assetImage(at: i, paths: activeImageAssetPaths, data: activeImageAssetData,
                                      formats: activeImageAssetFormats, requested: requested, label: label) {
      return image
    }
    let hasActiveCustomIcon = active && i < activeCustomIconBytes.count && activeCustomIconBytes[i] != nil
    if !hasActiveCustomIcon, let image = assetImage(at: i, paths: imageAssetPaths, data: imageAssetData,
                                                    formats: imageAssetFormats, requested: requested, label: label) {
      return image
    }
    let bytes = active
      ? ((i < activeCustomIconBytes.count ? activeCustomIconBytes[i] : nil) ?? (i < customIconBytes.count ? customIconBytes[i] : nil))
      : (i < customIconBytes.count ? customIconBytes[i] : nil)
    if let data = bytes, let image = NSImage(data: data) {
      // Rendered by Flutter at the requested size times the pixel ratio;
      // shown at the size a symbol of that size gets here.
      let side = Self.symbolPointSize(requested) * 1.25
      image.size = NSSize(width: side, height: side)
      image.isTemplate = true
      image.accessibilityDescription = label.isEmpty ? nil : label
      return image
    }
    let name = active
      ? ((i < activeSymbols.count && !activeSymbols[i].isEmpty) ? activeSymbols[i] : (i < symbols.count ? symbols[i] : ""))
      : (i < symbols.count ? symbols[i] : "")
    guard !name.isEmpty else { return nil }
    return symbolImage(name, requestedSize: requested, description: label.isEmpty ? name : label)
  }

  /// Item `i`'s image asset from `data` (its bytes) or `paths` (a Flutter
  /// asset), at the size a custom icon gets. Without a colour it becomes a
  /// template when single-coloured, so AppKit colours it like a symbol.
  private func assetImage(
    at i: Int, paths: [String], data: [Data?], formats: [String], requested: CGFloat?, label: String
  ) -> NSImage? {
    let bytes = i < data.count ? data[i] : nil
    let path = i < paths.count && !paths[i].isEmpty ? paths[i] : nil
    guard bytes != nil || path != nil else { return nil }
    let format = i < formats.count && !formats[i].isEmpty ? formats[i] : nil
    guard let loaded = ImageUtils.image(
      assetPath: path, imageData: bytes, format: format, customIconBytes: nil,
      size: Self.symbolPointSize(requested) * 1.25, color: nil
    ) else { return nil }
    // The loaded image is shared through the cache: describe a copy.
    let image = (loaded.copy() as? NSImage) ?? loaded
    image.accessibilityDescription = label.isEmpty ? nil : label
    return image
  }

  private func symbolImage(_ name: String, requestedSize: CGFloat?, description: String) -> NSImage? {
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: description) else { return nil }
    let config = NSImage.SymbolConfiguration(pointSize: Self.symbolPointSize(requestedSize), weight: .regular)
    return base.withSymbolConfiguration(config) ?? base
  }

  /// A Mac segmented control shows symbols at its label size. `CNSymbol`
  /// sizes are iOS tab bar sizes (24 by default), so they scale from there.
  private static func symbolPointSize(_ requested: CGFloat?) -> CGFloat {
    let r = requested ?? defaultRequestedIconSize
    return max(8, defaultSymbolPointSize * r / defaultRequestedIconSize)
  }

  private func applyTint() {
    // A template symbol takes the colour AppKit picks for the segment, which
    // reads on the selection; the tint goes to the selection itself.
    control.selectedSegmentBezelColor = tint
  }

  private func applyFont() {
    let size = labelFontSize ?? NSFont.systemFontSize(for: control.controlSize)
    if let family = labelFontFamily, let font = NSFont(name: family, size: size) {
      control.font = font
    } else {
      control.font = NSFont.systemFont(ofSize: size)
    }
    invalidateIntrinsicContentSize()
  }

  // MARK: - Selection

  @objc private func onChanged(_ sender: NSSegmentedControl) {
    let index = sender.selectedSegment
    if let s = searchSegment, index == s {
      if !searchActive {
        searchActive = true
        refreshImages()
        channel.invokeMethod("searchActiveChanged", arguments: ["isActive": true])
      }
      return
    }
    searchActive = false
    selectedIndex = index
    refreshImages()
    // Every tap is reported, a reselect too, as UITabBar does (#13).
    channel.invokeMethod("valueChanged", arguments: ["index": index])
  }

  private func setSearchActive(_ active: Bool) {
    searchActive = active
    if active, let s = searchSegment {
      control.selectedSegment = s
    } else if selectedIndex >= 0 && selectedIndex < itemCount {
      control.selectedSegment = selectedIndex
    }
    refreshImages()
    channel.invokeMethod("searchActiveChanged", arguments: ["isActive": active])
  }

  // MARK: - Badges

  private func applyBadges() {
    for i in 0..<itemCount {
      let value = i < badges.count ? badges[i] : ""
      if value.isEmpty {
        badgeViews.removeValue(forKey: i)?.removeFromSuperview()
        control.setToolTip(nil, forSegment: i)
        continue
      }
      let view = badgeViews[i] ?? {
        let v = CNMacTabBadgeView()
        addSubview(v, positioned: .above, relativeTo: control)
        badgeViews[i] = v
        return v
      }()
      view.value = value
      // VoiceOver reads a segment's help text after its label.
      control.setToolTip(value == CNMacTabBadgeView.dotValue ? nil : value, forSegment: i)
    }
    for key in badgeViews.keys where key >= itemCount {
      badgeViews.removeValue(forKey: key)?.removeFromSuperview()
    }
    needsLayout = true
  }

  override func layout() {
    super.layout()
    layoutBadges()
  }

  /// Puts each badge at the top-trailing corner of its tab's content (symbol
  /// and label). The segments share the control's width equally and centre
  /// their content, so the content's width gives its end.
  private func layoutBadges() {
    guard !badgeViews.isEmpty else { return }
    let count = control.segmentCount
    guard count > 0 else { return }
    let frame = control.frame
    let segmentWidth = frame.width / CGFloat(count)
    let font = control.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
    for (i, badge) in badgeViews {
      let label = control.label(forSegment: i) ?? ""
      var content: CGFloat = 0
      if let image = control.image(forSegment: i) { content += image.size.width }
      if !label.isEmpty {
        if content > 0 { content += 4 }
        content += (label as NSString).size(withAttributes: [.font: font]).width
      }
      let centerX = frame.minX + segmentWidth * (CGFloat(i) + 0.5)
      let size = badge.fittingSize
      let x = min(centerX + content / 2 - size.width / 3, frame.minX + segmentWidth * CGFloat(i + 1) - size.width / 2)
      // Flipped or not, sit across the control's top edge.
      let top = isFlipped ? frame.minY : frame.maxY
      let y = isFlipped ? top - size.height / 2 + 2 : top - size.height / 2 - 2
      badge.frame = NSRect(x: x.rounded(), y: y.rounded(), width: size.width, height: size.height)
    }
  }

  private static func colorFromARGB(_ argb: Int) -> NSColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
  }
}

/// A red badge over a tab: a capsule with the value, or a dot for
/// `CNTabBarItem.dotBadge`. Clicks go through to the tab under it.
final class CNMacTabBadgeView: NSView {
  /// `CNTabBarItem.dotBadge`.
  static let dotValue = "\u{200B}"
  private static let dotSize: CGFloat = 8
  private static let height: CGFloat = 16

  private let text = NSTextField(labelWithString: "")

  var value: String = "" {
    didSet {
      let dot = value == Self.dotValue
      text.isHidden = dot
      text.stringValue = dot ? "" : value
      invalidateIntrinsicContentSize()
      needsLayout = true
    }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.systemRed.cgColor
    // Above the control's selection, which macOS 27 draws in a raised layer.
    layer?.zPosition = 100
    text.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
    text.textColor = .white
    text.alignment = .center
    text.lineBreakMode = .byClipping
    addSubview(text)
    setAccessibilityElement(false)
  }

  required init?(coder: NSCoder) { return nil }

  override var fittingSize: NSSize { intrinsicContentSize }

  override var intrinsicContentSize: NSSize {
    if value == Self.dotValue { return NSSize(width: Self.dotSize, height: Self.dotSize) }
    let w = ceil(text.intrinsicContentSize.width) + 10
    return NSSize(width: max(Self.height, w), height: Self.height)
  }

  override func layout() {
    super.layout()
    layer?.cornerRadius = bounds.height / 2
    let h = ceil(text.intrinsicContentSize.height)
    text.frame = NSRect(x: 0, y: ((bounds.height - h) / 2).rounded(), width: bounds.width, height: h)
  }

  // Never takes a click: the tab under it does.
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
