import Flutter
import UIKit

class CupertinoSegmentedControlPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let container: UIView
  private let control: UISegmentedControl
  private var labels: [String] = []
  private var symbols: [String] = []
  private var perSymbolSizes: [CGFloat?] = []
  private var perSymbolColors: [UIColor?] = []
  private var perSymbolPalettes: [[UIColor]] = []
  private var perSymbolModes: [String?] = []
  private var perSymbolGradientEnabled: [NSNumber?] = []
  private var defaultIconSize: CGFloat? = nil
  private var defaultIconColor: UIColor? = nil
  private var defaultIconPalette: [UIColor] = []
  private var defaultIconRenderingMode: String? = nil
  private var defaultIconGradientEnabled: Bool = false
  /// `CNSegmentedControl.labelFontFamily` and the rest of the label style,
  /// as Dart sends it in `labelStyle` (#143).
  private var labelStyle: [String: Any] = [:]

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeSegmentedControl_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)
    self.control = UISegmentedControl(items: [])

    var labels: [String] = []
    var sfSymbols: [String] = []
    var selectedIndex: Int = UISegmentedControl.noSegment
    var enabled: Bool = true
    var isDark: Bool = false
    var tint: UIColor? = nil
    var semanticLabel: String? = nil

    if let dict = args as? [String: Any] {
      if let v = dict["semanticLabel"] as? String, !v.isEmpty { semanticLabel = v }
      if let arr = dict["labels"] as? [String] { labels = arr }
      if let arr = dict["sfSymbols"] as? [String] { sfSymbols = arr }
      if let style = dict["labelStyle"] as? [String: Any] { self.labelStyle = style }
      if let v = dict["selectedIndex"] as? NSNumber { selectedIndex = v.intValue }
      if let v = dict["enabled"] as? NSNumber { enabled = v.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let style = dict["style"] as? [String: Any] {
        if let n = style["tint"] as? NSNumber { tint = Self.colorFromARGB(n.intValue) }
        if let n = style["iconColor"] as? NSNumber { self.defaultIconColor = Self.colorFromARGB(n.intValue) }
        if let s = style["iconSize"] as? NSNumber { self.defaultIconSize = CGFloat(truncating: s) }
        if let arr = style["iconPaletteColors"] as? [NSNumber] { self.defaultIconPalette = arr.map { Self.colorFromARGB($0.intValue) } }
        if let mode = style["iconRenderingMode"] as? String { self.defaultIconRenderingMode = mode }
        if let g = style["iconGradientEnabled"] as? NSNumber { self.defaultIconGradientEnabled = g.boolValue }
      }
    }

    super.init()
    if let dict = args as? [String: Any] { readSymbolOptions(dict) }

    // Flutter's text direction (#142): the segment order follows it.
    CNLayoutDirection.apply(CNLayoutDirection.read(args as? [String: Any]), to: container)
    container.backgroundColor = .clear
    if #available(iOS 13.0, *) {
      container.overrideUserInterfaceStyle = isDark ? .dark : .light
    }

    self.labels = labels
    self.symbols = sfSymbols
    rebuildSegments()
    applyLabelStyle()
    control.selectedSegmentIndex = selectedIndex
    control.isEnabled = enabled
    if #available(iOS 13.0, *), let c = tint { control.selectedSegmentTintColor = c }
    // What VoiceOver reads for the control (`CNSegmentedControl.semanticLabel`);
    // each segment reads its own title.
    applySemanticLabel(semanticLabel)

    control.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(control)
    NSLayoutConstraint.activate([
      control.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      control.topAnchor.constraint(equalTo: container.topAnchor),
      control.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])

    control.addTarget(self, action: #selector(onChanged(_:)), for: .valueChanged)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "getIntrinsicSize":
        let size = self.control.intrinsicContentSize
        result(["width": Double(size.width), "height": Double(size.height)])
      case "setSelectedIndex":
        if let args = call.arguments as? [String: Any], let idx = (args["index"] as? NSNumber)?.intValue {
          UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            self.control.selectedSegmentIndex = idx
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing index", details: nil)) }
      case "setEnabled":
        if let args = call.arguments as? [String: Any], let e = (args["enabled"] as? NSNumber)?.boolValue {
          UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            self.control.isEnabled = e
            self.control.alpha = e ? 1.0 : 0.5
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setStyle":
        if let args = call.arguments as? [String: Any] {
          UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            if #available(iOS 13.0, *), let n = args["tint"] as? NSNumber {
              self.control.selectedSegmentTintColor = Self.colorFromARGB(n.intValue)
            }
          }
          if let n = args["iconColor"] as? NSNumber { self.defaultIconColor = Self.colorFromARGB(n.intValue) }
          if let s = args["iconSize"] as? NSNumber { self.defaultIconSize = CGFloat(truncating: s) }
          self.rebuildSegments()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          if #available(iOS 13.0, *) {
            self.container.overrideUserInterfaceStyle = isDark ? .dark : .light
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setItems":
        // New labels or symbols, e.g. after a language switch (#143): the
        // segments are built again in place, keeping the selection.
        let args = call.arguments as? [String: Any] ?? [:]
        self.labels = (args["labels"] as? [String]) ?? []
        self.symbols = (args["sfSymbols"] as? [String]) ?? []
        self.readSymbolOptions(args)
        let selected = (args["selectedIndex"] as? NSNumber)?.intValue ?? self.control.selectedSegmentIndex
        self.rebuildSegments()
        self.control.selectedSegmentIndex = selected < self.control.numberOfSegments ? selected : UISegmentedControl.noSegment
        self.control.invalidateIntrinsicContentSize()
        result(nil)
      case "setLabelStyle":
        self.labelStyle = (call.arguments as? [String: Any]) ?? [:]
        self.applyLabelStyle()
        self.control.invalidateIntrinsicContentSize()
        result(nil)
      case "setLayoutDirection":
        CNLayoutDirection.apply(CNLayoutDirection.read(call.arguments as? [String: Any]), to: self.container)
        result(nil)
      case "setSemanticLabel":
        let label = (call.arguments as? [String: Any])?["label"] as? String
        self.applySemanticLabel((label?.isEmpty ?? true) ? nil : label)
        result(nil)
      case "setInteractive":
        if let args = call.arguments as? [String: Any],
           let interactive = (args["interactive"] as? NSNumber)?.boolValue {
          NSLog("[CN Seg] setInteractive=\(interactive)")
          self._cnSetInteractiveRecursive(self.container, interactive)
          self._cnSetInteractiveRecursive(self.control, interactive)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  /// Names the control as a group, which VoiceOver reads when it moves into
  /// the segments.
  private func applySemanticLabel(_ label: String?) {
    control.accessibilityLabel = label
    if #available(iOS 13.0, *) {
      control.accessibilityContainerType = label == nil ? .none : .semanticGroup
    }
  }

  private func _cnSetInteractiveRecursive(_ view: UIView?, _ interactive: Bool) {
    guard let view = view else { return }
    view.isUserInteractionEnabled = interactive
    for sub in view.subviews { _cnSetInteractiveRecursive(sub, interactive) }
  }

  @objc private func onChanged(_ sender: UISegmentedControl) {
    channel.invokeMethod("valueChanged", arguments: ["index": sender.selectedSegmentIndex])
  }

  /// The per-symbol options, from creation params or `setItems`.
  private func readSymbolOptions(_ dict: [String: Any]) {
    perSymbolSizes = ((dict["sfSymbolSizes"] as? [Any]) ?? []).map { ($0 as? NSNumber).map { CGFloat(truncating: $0) } }
    perSymbolColors = ((dict["sfSymbolColors"] as? [Any]) ?? []).map { ($0 as? NSNumber).map { Self.colorFromARGB($0.intValue) } }
    perSymbolPalettes = ((dict["sfSymbolPaletteColors"] as? [[NSNumber]]) ?? []).map { $0.map { Self.colorFromARGB($0.intValue) } }
    perSymbolModes = ((dict["sfSymbolRenderingModes"] as? [Any]) ?? []).map { $0 as? String }
    perSymbolGradientEnabled = ((dict["sfSymbolGradientEnabled"] as? [Any]) ?? []).map { $0 as? NSNumber }
  }

  /// The label style on this control only, for its normal and selected
  /// segments (#143). A font is set only when a family, size or weight is;
  /// otherwise the segments keep the system font and only take the colours.
  private func applyLabelStyle() {
    let style = labelStyle
    func int(_ key: String) -> Int? { (style[key] as? NSNumber)?.intValue }
    let family = (style["fontFamily"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    let selectedFamily = (style["selectedFontFamily"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? family
    let size = (style["fontSize"] as? NSNumber).map { CGFloat($0.doubleValue) }
    let weight = CNFontResolver.weight(fromFlutterValue: int("fontWeight"))
    let selectedWeight = CNFontResolver.weight(fromFlutterValue: int("selectedFontWeight"))
    let color = int("color").map(Self.colorFromARGB)
    let selectedColor = int("selectedColor").map(Self.colorFromARGB) ?? color

    func font(_ family: String?, _ weight: UIFont.Weight?, fallback: UIFont.Weight) -> UIFont? {
      guard family != nil || size != nil || weight != nil else { return nil }
      let pointSize = size ?? 13
      if let family, let resolved = CNFontResolver.font(family: family, size: pointSize, weight: weight ?? fallback) {
        return resolved
      }
      return UIFont.systemFont(ofSize: pointSize, weight: weight ?? fallback)
    }
    var normal: [NSAttributedString.Key: Any] = [:]
    var selected: [NSAttributedString.Key: Any] = [:]
    // The system draws the selected segment's title heavier.
    if let f = font(family, weight, fallback: .regular) { normal[.font] = f }
    let emphasized: UIFont.Weight = weight.map { $0 > .semibold ? $0 : .semibold } ?? .semibold
    if let f = font(selectedFamily, selectedWeight, fallback: emphasized) ?? font(family, weight, fallback: emphasized) {
      selected[.font] = f
    }
    if let color { normal[.foregroundColor] = color }
    if let selectedColor { selected[.foregroundColor] = selectedColor }
    control.setTitleTextAttributes(normal.isEmpty ? nil : normal, for: .normal)
    control.setTitleTextAttributes(selected.isEmpty ? nil : selected, for: .selected)
    control.setTitleTextAttributes(selected.isEmpty ? nil : selected, for: [.selected, .highlighted])
  }

  // Use shared utility functions
  private static func colorFromARGB(_ argb: Int) -> UIColor {
    return ImageUtils.colorFromARGB(argb)
  }

  private func rebuildSegments() {
    control.removeAllSegments()
    let count = max(labels.count, symbols.count)
    for idx in 0..<count {
      if idx < symbols.count, var image = UIImage(systemName: symbols[idx]) {
        if let size = (idx < perSymbolSizes.count ? perSymbolSizes[idx] : nil) ?? defaultIconSize {
          let cfg = UIImage.SymbolConfiguration(pointSize: size)
          if let newImg = image.applyingSymbolConfiguration(cfg) { image = newImg }
        }
        // Rendering mode selection
        let mode = (idx < perSymbolModes.count ? perSymbolModes[idx] : nil) ?? defaultIconRenderingMode
        if let mode = mode {
          switch mode {
          case "hierarchical":
            if #available(iOS 15.0, *), let color = (idx < perSymbolColors.count ? perSymbolColors[idx] : nil) ?? defaultIconColor {
              let cfg = UIImage.SymbolConfiguration(hierarchicalColor: color)
              if let newImg = image.applyingSymbolConfiguration(cfg) { image = newImg }
            }
          case "palette":
            if #available(iOS 15.0, *), !((idx < perSymbolPalettes.count) ? perSymbolPalettes[idx].isEmpty : defaultIconPalette.isEmpty) {
              let colors = (idx < perSymbolPalettes.count && !perSymbolPalettes[idx].isEmpty) ? perSymbolPalettes[idx] : defaultIconPalette
              let cfg = UIImage.SymbolConfiguration(paletteColors: colors)
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
        } else if let color = (idx < perSymbolColors.count ? perSymbolColors[idx] : nil) ?? defaultIconColor {
          if #available(iOS 13.0, *) {
            image = image.withTintColor(color, renderingMode: .alwaysOriginal)
          }
        }
        // Gradient toggle (built-in in SF Symbols 7). If available, prefer gradient.
        let gradientEnabled = (idx < perSymbolGradientEnabled.count ? perSymbolGradientEnabled[idx]?.boolValue : nil) ?? defaultIconGradientEnabled
        if gradientEnabled {
          // Note: Using future API for built-in gradients when available. Currently no-op on older SDKs.
          // if #available(iOS 18.0, *), let cfg = UIImage.SymbolConfiguration.preferringGradient() { image = image.applyingSymbolConfiguration(cfg) ?? image }
        }
        control.insertSegment(with: image, at: idx, animated: false)
      } else if idx < labels.count {
        control.insertSegment(withTitle: labels[idx], at: idx, animated: false)
      } else {
        control.insertSegment(withTitle: "", at: idx, animated: false)
      }
    }
  }
}
