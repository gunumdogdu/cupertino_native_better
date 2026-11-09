import FlutterMacOS
import Cocoa

/// `CNSegmentedControl` on macOS: an `NSSegmentedControl`.
///
/// Segments share the width equally, as `UISegmentedControl`'s do; a segment
/// with a symbol shows the symbol, as on iOS, and its label becomes the
/// symbol's accessibility description. The control keeps its own height and
/// is centred in the box Flutter gives it. `color` tints the selected
/// segment (`selectedSegmentBezelColor`). Symbol sizes are iOS sizes
/// (`CNSymbol` defaults to 24); they scale so that the default matches the
/// control's 13 pt label text.
class CupertinoSegmentedControlNSView: NSView {
  private let channel: FlutterMethodChannel
  private let control: NSSegmentedControl
  private var labels: [String] = []
  private var symbols: [String] = []
  private var perSymbolSizes: [CGFloat?] = []
  private var perSymbolColors: [NSColor?] = []
  private var perSymbolPalettes: [[NSColor]] = []
  private var perSymbolModes: [String?] = []
  private var defaultIconSize: CGFloat? = nil
  private var defaultIconColor: NSColor? = nil
  private var defaultIconPalette: [NSColor] = []
  private var defaultIconRenderingMode: String? = nil

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeSegmentedControl_\(viewId)", binaryMessenger: messenger)
    self.control = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)

    super.init(frame: .zero)

    var selectedIndex: Int = -1
    var enabled: Bool = true
    var isDark: Bool = false
    var tint: NSColor? = nil
    var semanticLabel: String? = nil

    if let dict = args as? [String: Any] {
      if let arr = dict["labels"] as? [String] { labels = arr }
      if let arr = dict["sfSymbols"] as? [String] { symbols = arr }
      readSymbolOptions(dict)
      if let v = dict["selectedIndex"] as? NSNumber { selectedIndex = v.intValue }
      if let v = dict["enabled"] as? NSNumber { enabled = v.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let v = dict["semanticLabel"] as? String, !v.isEmpty { semanticLabel = v }
      if let style = dict["style"] as? [String: Any] {
        if let n = style["tint"] as? NSNumber { tint = Self.colorFromARGB(n.intValue) }
        readIconStyle(style)
      }
    }

    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    control.segmentDistribution = .fillEqually
    control.segmentCount = max(labels.count, symbols.count)
    if selectedIndex >= 0 { control.selectedSegment = selectedIndex }
    configureSegments()
    control.isEnabled = enabled
    control.selectedSegmentBezelColor = tint
    // What VoiceOver reads for the group (`CNSegmentedControl.semanticLabel`);
    // each segment reads its own label.
    control.setAccessibilityLabel(semanticLabel)

    control.target = self
    control.action = #selector(onChanged(_:))
    applyLabelStyle((args as? [String: Any])?["labelStyle"] as? [String: Any] ?? [:])
    CNLayoutDirection.apply(CNLayoutDirection.read(args as? [String: Any]), to: control)

    addSubview(control)
    control.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      control.leadingAnchor.constraint(equalTo: leadingAnchor),
      control.trailingAnchor.constraint(equalTo: trailingAnchor),
      control.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "getIntrinsicSize":
        let size = self.control.intrinsicContentSize
        result(["width": Double(size.width), "height": Double(size.height)])
      case "setSelectedIndex":
        if let idx = (args?["index"] as? NSNumber)?.intValue {
          self.control.selectedSegment = idx
          self.configureSegments()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing index", details: nil)) }
      case "setEnabled":
        if let e = (args?["enabled"] as? NSNumber)?.boolValue {
          self.control.isEnabled = e
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setStyle":
        if let args = args {
          if args.keys.contains("tint") {
            // A null tint restores the system accent colour.
            self.control.selectedSegmentBezelColor = (args["tint"] as? NSNumber).map { Self.colorFromARGB($0.intValue) }
          }
          self.readIconStyle(args)
          self.configureSegments()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setItems":
        // New labels or symbols, e.g. after a language switch (#143).
        let dict = args ?? [:]
        self.labels = (dict["labels"] as? [String]) ?? []
        self.symbols = (dict["sfSymbols"] as? [String]) ?? []
        self.readSymbolOptions(dict)
        let selected = (dict["selectedIndex"] as? NSNumber)?.intValue ?? self.control.selectedSegment
        self.control.segmentCount = max(self.labels.count, self.symbols.count)
        self.control.selectedSegment = selected < self.control.segmentCount ? selected : -1
        self.configureSegments()
        result(nil)
      case "setLabelStyle":
        self.applyLabelStyle(args ?? [:])
        result(nil)
      case "setLayoutDirection":
        CNLayoutDirection.apply(CNLayoutDirection.read(args), to: self.control)
        result(nil)
      case "setSemanticLabel":
        let label = args?["label"] as? String
        self.control.setAccessibilityLabel((label?.isEmpty ?? true) ? nil : label)
        result(nil)
      case "setBrightness":
        if let isDark = (args?["isDark"] as? NSNumber)?.boolValue {
          self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setInteractive":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) { return nil }

  private func readSymbolOptions(_ dict: [String: Any]) {
    perSymbolSizes = ((dict["sfSymbolSizes"] as? [Any]) ?? []).map { ($0 as? NSNumber).map { CGFloat(truncating: $0) } }
    perSymbolColors = ((dict["sfSymbolColors"] as? [Any]) ?? []).map { ($0 as? NSNumber).map { Self.colorFromARGB($0.intValue) } }
    perSymbolPalettes = ((dict["sfSymbolPaletteColors"] as? [Any]) ?? []).map {
      (($0 as? [Any]) ?? []).compactMap { ($0 as? NSNumber).map { Self.colorFromARGB($0.intValue) } }
    }
    perSymbolModes = ((dict["sfSymbolRenderingModes"] as? [Any]) ?? []).map { $0 as? String }
  }

  /// The label font (#143). An `NSSegmentedControl` has one font for all
  /// its segments and no title colour, so the selected segment's own
  /// family, weight and the colours stay iOS-only.
  private func applyLabelStyle(_ style: [String: Any]) {
    let family = (style["fontFamily"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    let size = (style["fontSize"] as? NSNumber).map { CGFloat($0.doubleValue) }
    let weightValue = (style["fontWeight"] as? NSNumber)?.intValue
    guard family != nil || size != nil || weightValue != nil else {
      control.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: control.controlSize))
      invalidateIntrinsicContentSize()
      return
    }
    let pointSize = size ?? NSFont.systemFontSize(for: control.controlSize)
    let weight = weightValue.map { NativeButtonHost.fontWeight($0) }
    if let family, let font = CNFontResolver.font(family: family, size: pointSize, weight: weight) {
      control.font = font
    } else {
      control.font = NSFont.systemFont(ofSize: pointSize, weight: weight ?? .regular)
    }
    invalidateIntrinsicContentSize()
  }

  private func readIconStyle(_ style: [String: Any]) {
    if let s = style["iconSize"] as? NSNumber { defaultIconSize = CGFloat(truncating: s) }
    if let n = style["iconColor"] as? NSNumber { defaultIconColor = Self.colorFromARGB(n.intValue) }
    if let arr = style["iconPaletteColors"] as? [NSNumber] { defaultIconPalette = arr.map { Self.colorFromARGB($0.intValue) } }
    if let mode = style["iconRenderingMode"] as? String { defaultIconRenderingMode = mode }
  }

  private func configureSegments() {
    let count = max(labels.count, symbols.count)
    if control.segmentCount != count { control.segmentCount = count }
    let selected = control.selectedSegment
    for i in 0..<count {
      let label = i < labels.count ? labels[i] : ""
      if i < symbols.count, !symbols[i].isEmpty,
         let image = symbolImage(i, description: label.isEmpty ? symbols[i] : label, selected: i == selected) {
        control.setImage(image, forSegment: i)
        control.setLabel("", forSegment: i)
      } else {
        control.setImage(nil, forSegment: i)
        control.setLabel(label, forSegment: i)
      }
    }
    invalidateIntrinsicContentSize()
  }

  /// The symbol of segment [i] with its size and rendering mode. The
  /// selected segment, and a symbol without a colour, keep a template
  /// image, which AppKit colours to read on the selection: a coloured
  /// symbol would vanish on a bezel of the same accent colour.
  private func symbolImage(_ i: Int, description: String, selected: Bool) -> NSImage? {
    guard let image = NSImage(systemSymbolName: symbols[i], accessibilityDescription: description) else { return nil }
    let requested = (i < perSymbolSizes.count ? perSymbolSizes[i] : nil) ?? defaultIconSize ?? 24
    let size = NSImage.SymbolConfiguration(pointSize: max(8, 13 * requested / 24), weight: .regular, scale: .large)
    guard !selected, let colors = colorConfiguration(i) else {
      return image.withSymbolConfiguration(size) ?? image
    }
    return image.withSymbolConfiguration(size.applying(colors)) ?? image
  }

  /// The colours of segment [i]'s symbol, or nil for a template symbol.
  private func colorConfiguration(_ i: Int) -> NSImage.SymbolConfiguration? {
    let mode = (i < perSymbolModes.count ? perSymbolModes[i] : nil) ?? defaultIconRenderingMode
    let color = (i < perSymbolColors.count ? perSymbolColors[i] : nil) ?? defaultIconColor
    let palette = (i < perSymbolPalettes.count && !perSymbolPalettes[i].isEmpty) ? perSymbolPalettes[i] : defaultIconPalette
    switch mode {
    case "hierarchical":
      return color.map { NSImage.SymbolConfiguration(hierarchicalColor: $0) }
    case "palette":
      return palette.isEmpty ? nil : NSImage.SymbolConfiguration(paletteColors: palette)
    case "multicolor":
      return NSImage.SymbolConfiguration.preferringMulticolor()
    default:
      return color.map { NSImage.SymbolConfiguration(paletteColors: [$0]) }
    }
  }

  @objc private func onChanged(_ sender: NSSegmentedControl) {
    configureSegments()
    channel.invokeMethod("valueChanged", arguments: ["index": sender.selectedSegment])
  }

  private static func colorFromARGB(_ argb: Int) -> NSColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
  }
}
