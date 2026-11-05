import Flutter
import UIKit

/// `CNToolbar` on iOS 26+: a `UIToolbar` with Liquid Glass, drawn where the
/// Flutter widget is laid out (typically the bottom of a page).
///
/// The configuration is the one `CNToolbarManager` gets on macOS
/// (`toolbar.dart`, `_payload`): buttons (prominent style, tint, badge),
/// menus (`UIMenu` from `PopupMenuBuilder`), segmented groups, flexible and
/// fixed space. Search, sidebar and inspector items have no counterpart in a
/// bottom toolbar and are left out.
///
/// A `selectOne` segmented group is a `UISegmentedControl`. A `selectAny` or
/// `momentary` group is a run of bar button items set apart by zero-width
/// fixed spaces, so iOS 26 draws them on one shared glass background;
/// `selectAny` items show their selected state (`isSelected`).
///
/// `setItems` updates the toolbar in place: bar button items are kept by id
/// and get the new values, and the toolbar animates added and removed ones.
///
/// Events: `onButtonPressed {id}`, `onSegmentSelected {id, index, selected}`,
/// `onMenuSelected {id, path}`.
final class CNToolbarPlatformView: NSObject, FlutterPlatformView, UIToolbarDelegate {
  private let channel: FlutterMethodChannel
  private let container: UIView
  private let toolbar = UIToolbar()

  /// Bar button items by key (kind, id and segment), kept across updates.
  private var barItems: [String: UIBarButtonItem] = [:]
  private var segmentedControls: [String: UISegmentedControl] = [:]
  /// The values last applied to each item, to skip unchanged ones.
  private var applied: [String: NSDictionary] = [:]
  /// Per segmented group id: its segments and selection, for taps.
  private var groupSelection: [String: Set<Int>] = [:]
  private var groupModes: [String: String] = [:]

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "CNToolbar_\(viewId)", binaryMessenger: messenger)
    container = UIView(frame: frame)
    super.init()
    container.backgroundColor = .clear
    toolbar.frame = container.bounds
    toolbar.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    toolbar.delegate = self
    container.addSubview(toolbar)

    apply(args as? [String: Any] ?? [:], animated: false)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "setItems":
        self.apply(args ?? [:], animated: true)
        result(nil)
      case "setBrightness":
        if let isDark = (args?["isDark"] as? NSNumber)?.boolValue {
          self.container.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
        result(nil)
      case "setInteractive":
        // A Flutter modal above the toolbar: no taps through it.
        let interactive = (args?["interactive"] as? NSNumber)?.boolValue ?? true
        self.container.isUserInteractionEnabled = interactive
        result(nil)
      case "setTransitioning":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  // MARK: UIToolbarDelegate

  func position(for bar: UIBarPositioning) -> UIBarPosition { .bottom }

  // MARK: Configuration

  private func apply(_ config: [String: Any], animated: Bool) {
    if let isDark = (config["isDark"] as? NSNumber)?.boolValue {
      container.overrideUserInterfaceStyle = isDark ? .dark : .light
    }
    toolbar.tintColor = Self.color(config["tint"])

    let entries = ((config["items"] as? [Any]) ?? []).compactMap { $0 as? [String: Any] }
    // Only kinds a bottom toolbar has.
    let shown = entries.filter {
      ["button", "menu", "segmented", "flexibleSpace", "fixedSpace"].contains($0["kind"] as? String ?? "")
    }
    var result: [UIBarButtonItem] = []
    var used = Set<String>()
    for (index, d) in shown.enumerated() {
      let kind = d["kind"] as? String ?? ""
      let id = d["id"] as? String ?? "\(index)"
      switch kind {
      case "button":
        let key = "button:\(id)"
        used.insert(key)
        result.append(button(key: key, id: id, d))
      case "menu":
        let key = "menu:\(id)"
        used.insert(key)
        result.append(menu(key: key, id: id, d))
      case "segmented":
        let mode = d["selectionMode"] as? String ?? "selectOne"
        if mode == "selectOne" {
          let key = "segmented:\(id)"
          used.insert(key)
          result.append(segmentedControlItem(key: key, id: id, d))
        } else {
          // Its own glass group: separated from items around it.
          let previous = index > 0 ? shown[index - 1]["kind"] as? String : nil
          let next = index + 1 < shown.count ? shown[index + 1]["kind"] as? String : nil
          let isSpace: (String?) -> Bool = { $0 == "flexibleSpace" || $0 == "fixedSpace" }
          if previous != nil, !isSpace(previous) { result.append(groupSeparator(key: "sep<:\(id)", used: &used)) }
          result += segmentButtons(id: id, mode: mode, d, used: &used)
          if next != nil, !isSpace(next) { result.append(groupSeparator(key: "sep>:\(id)", used: &used)) }
        }
      case "flexibleSpace":
        let key = "flexible:\(index)"
        used.insert(key)
        result.append(cached(key) { .flexibleSpace() })
      default:
        let key = "fixed:\(index)"
        used.insert(key)
        result.append(cached(key) { Self.fixedSpace() })
      }
    }
    for key in barItems.keys where !used.contains(key) {
      barItems[key] = nil
      applied[key] = nil
      segmentedControls[key] = nil
    }
    let current = toolbar.items ?? []
    if current.count != result.count || zip(current, result).contains(where: { $0 !== $1 }) {
      toolbar.setItems(result, animated: animated)
    }
  }

  private func cached(_ key: String, _ make: () -> UIBarButtonItem) -> UIBarButtonItem {
    if let item = barItems[key] { return item }
    let item = make()
    barItems[key] = item
    return item
  }

  /// A zero-width fixed space: on iOS 26 it ends one shared glass
  /// background and starts the next.
  private static func fixedSpace() -> UIBarButtonItem {
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) { return .fixedSpace() }
    #endif
    return .fixedSpace(8)
  }

  private func groupSeparator(key: String, used: inout Set<String>) -> UIBarButtonItem {
    used.insert(key)
    return cached(key) { Self.fixedSpace() }
  }

  /// Whether [d] differs from what [key] last showed; records it.
  private func changed(_ key: String, _ d: [String: Any]) -> Bool {
    let values = d as NSDictionary
    if applied[key] == values { return false }
    applied[key] = values
    return true
  }

  // MARK: Buttons and menus

  private func button(key: String, id: String, _ d: [String: Any]) -> UIBarButtonItem {
    // UIKit does not redraw a badge changed on an item a toolbar already
    // shows (iOS 27): a new badge gets a new item, which the toolbar lays
    // out again.
    if let previous = applied[key],
      previous["badge"] as? NSDictionary != d["badge"] as? NSDictionary
    {
      barItems[key] = nil
      applied[key] = nil
    }
    let item = cached(key) {
      let item = CNToolbarBarButtonItem()
      item.target = self
      item.action = #selector(buttonTapped(_:))
      return item
    }
    (item as? CNToolbarBarButtonItem)?.cnId = id
    guard changed(key, d) else { return item }
    let label = d["label"] as? String ?? ""
    setContent(of: item, label: label, image: Self.image(d["image"], label: label))
    item.isEnabled = (d["enabled"] as? NSNumber)?.boolValue ?? true
    item.tintColor = Self.color(d["tint"])
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      item.style = (d["style"] as? String) == "prominent" ? .prominent : .plain
      // Drawn in toolbars from iOS 27; iOS 26 shows badges in navigation
      // bars only.
      item.badge = Self.badge(d["badge"])
    }
    #endif
    return item
  }

  private func menu(key: String, id: String, _ d: [String: Any]) -> UIBarButtonItem {
    let item = cached(key) { UIBarButtonItem() }
    let previous = applied[key]
    guard changed(key, d) else { return item }
    let label = d["label"] as? String ?? ""
    setContent(of: item, label: label, image: Self.image(d["image"], label: label))
    item.isEnabled = (d["enabled"] as? NSNumber)?.boolValue ?? true
    let menuDict = d["menu"] as? [String: Any] ?? [:]
    if item.menu == nil || previous?["menu"] as? NSDictionary != menuDict as NSDictionary {
      let elements = PopupMenuBuilder.elements(
        level: PopupMenuLevel(dict: menuDict), iconScale: UIScreen.main.scale
      ) { [weak self] path in
        self?.channel.invokeMethod("onMenuSelected", arguments: ["id": id, "path": path])
      }
      // No primary action: a tap opens the menu.
      item.menu = UIMenu(title: "", children: elements)
    }
    return item
  }

  /// The icon, or the label as the title when there is none. VoiceOver
  /// reads the label either way.
  private func setContent(of item: UIBarButtonItem, label: String, image: UIImage?) {
    if let image {
      item.image = image
      item.title = nil
    } else {
      item.image = nil
      item.title = label
    }
    item.accessibilityLabel = label
  }

  @objc private func buttonTapped(_ sender: CNToolbarBarButtonItem) {
    if let segment = sender.segmentIndex {
      segmentTapped(sender, index: segment)
      return
    }
    channel.invokeMethod("onButtonPressed", arguments: ["id": sender.cnId])
  }

  // MARK: Segmented groups

  private func segmentedControlItem(key: String, id: String, _ d: [String: Any]) -> UIBarButtonItem {
    let control = segmentedControls[key] ?? {
      let control = UISegmentedControl()
      control.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
      segmentedControls[key] = control
      return control
    }()
    control.accessibilityIdentifier = id
    let item = cached(key) {
      let item = UIBarButtonItem(customView: control)
      #if compiler(>=6.2)
      if #available(iOS 26.0, *) {
        // The segmented control draws its own track: no glass capsule
        // behind it as well.
        item.hidesSharedBackground = true
      }
      #endif
      return item
    }
    let previous = applied[key]
    guard changed(key, d) else { return item }
    let segments = (d["segments"] as? [[String: Any]]) ?? []
    let usesImages = (d["usesImages"] as? NSNumber)?.boolValue ?? false
    let structure: [Any] = [segments.map { [$0["label"] ?? "", $0["image"] ?? ""] }, usesImages]
    let oldStructure: [Any]? = previous.map {
      [(($0["segments"] as? [[String: Any]]) ?? []).map { [$0["label"] ?? "", $0["image"] ?? ""] },
       ($0["usesImages"] as? NSNumber)?.boolValue ?? false]
    }
    if oldStructure.map({ ($0 as NSArray) != (structure as NSArray) }) ?? true {
      control.removeAllSegments()
      for (i, segment) in segments.enumerated() {
        let label = segment["label"] as? String ?? ""
        if usesImages, let image = Self.image(segment["image"], label: label) {
          control.insertSegment(with: image, at: i, animated: false)
        } else {
          control.insertSegment(withTitle: label, at: i, animated: false)
        }
      }
      control.sizeToFit()
    }
    let enabled = (d["enabled"] as? NSNumber)?.boolValue ?? true
    control.isEnabled = enabled
    for (i, segment) in segments.enumerated() where i < control.numberOfSegments {
      control.setEnabled((segment["enabled"] as? NSNumber)?.boolValue ?? true, forSegmentAt: i)
    }
    let selected = ((d["selected"] as? [Any]) ?? []).compactMap { ($0 as? NSNumber)?.intValue }
    control.selectedSegmentIndex = selected.first.flatMap { $0 < control.numberOfSegments ? $0 : nil }
      ?? UISegmentedControl.noSegment
    control.accessibilityLabel = d["label"] as? String
    return item
  }

  @objc private func segmentChanged(_ sender: UISegmentedControl) {
    guard let id = sender.accessibilityIdentifier, sender.selectedSegmentIndex >= 0 else { return }
    // The next configuration sets the selection again, even if unchanged.
    applied["segmented:\(id)"] = nil
    let index = sender.selectedSegmentIndex
    channel.invokeMethod("onSegmentSelected", arguments: ["id": id, "index": index, "selected": [index]])
  }

  /// A `selectAny` or `momentary` group: one bar button item per segment.
  private func segmentButtons(id: String, mode: String, _ d: [String: Any], used: inout Set<String>) -> [UIBarButtonItem] {
    let segments = (d["segments"] as? [[String: Any]]) ?? []
    let enabled = (d["enabled"] as? NSNumber)?.boolValue ?? true
    let selected = Set(((d["selected"] as? [Any]) ?? []).compactMap { ($0 as? NSNumber)?.intValue })
    groupModes[id] = mode
    groupSelection[id] = mode == "selectAny" ? selected : []
    var result: [UIBarButtonItem] = []
    for (i, segment) in segments.enumerated() {
      let key = "segment:\(id)#\(i)"
      used.insert(key)
      let item = cached(key) {
        let item = CNToolbarBarButtonItem()
        item.target = self
        item.action = #selector(buttonTapped(_:))
        return item
      }
      if let item = item as? CNToolbarBarButtonItem {
        item.cnId = id
        item.segmentIndex = i
      }
      var values = segment
      values["groupEnabled"] = enabled
      values["selected"] = selected.contains(i)
      values["mode"] = mode
      if changed(key, values) {
        let label = segment["label"] as? String ?? ""
        setContent(of: item, label: label, image: Self.image(segment["image"], label: label))
        item.isEnabled = enabled && ((segment["enabled"] as? NSNumber)?.boolValue ?? true)
        item.isSelected = mode == "selectAny" && selected.contains(i)
      }
      result.append(item)
    }
    return result
  }

  private func segmentTapped(_ item: CNToolbarBarButtonItem, index: Int) {
    let id = item.cnId
    var selection = groupSelection[id] ?? []
    if groupModes[id] == "selectAny" {
      if !selection.insert(index).inserted { selection.remove(index) }
      groupSelection[id] = selection
      item.isSelected = selection.contains(index)
      // The next configuration sets the selection again, even if unchanged.
      applied["segment:\(id)#\(index)"] = nil
    }
    channel.invokeMethod(
      "onSegmentSelected", arguments: ["id": id, "index": index, "selected": selection.sorted()])
  }

  // MARK: Values

  static func color(_ value: Any?) -> UIColor? {
    (value as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
  }

  /// The icon of an item, from an image description of `_encodeImage`
  /// (toolbar.dart): image asset or bytes, then a custom icon Flutter
  /// rendered, then an SF Symbol, which the toolbar sizes itself.
  static func image(_ value: Any?, label: String) -> UIImage? {
    guard let d = value as? [String: Any] else { return nil }
    let color = color(d["color"])
    let scale = UIScreen.main.scale
    let box = CGSize(width: 22, height: 22)
    var image: UIImage?
    if let data = (d["imageData"] as? FlutterStandardTypedData)?.data {
      image = ImageUtils.createImageFromData(data, format: d["format"] as? String, size: box, color: color, scale: scale)
      if color == nil { image = ImageUtils.templatedIfMonochrome(image) }
    } else if let path = d["assetPath"] as? String, !path.isEmpty {
      image = ImageUtils.loadFlutterAsset(path, size: box, format: d["format"] as? String, color: color, scale: scale)
      if color == nil { image = ImageUtils.templatedIfMonochrome(image) }
    } else if let bytes = (d["customIconBytes"] as? FlutterStandardTypedData)?.data {
      image = UIImage(data: bytes, scale: scale)?.withRenderingMode(.alwaysTemplate)
      if let color { image = image?.withTintColor(color, renderingMode: .alwaysOriginal) }
    } else if let name = d["symbol"] as? String, !name.isEmpty {
      image = UIImage(systemName: name)
      let palette = ((d["palette"] as? [Any]) ?? []).compactMap { $0 as? NSNumber }
        .map { ImageUtils.colorFromARGB($0.intValue) }
      switch d["mode"] as? String {
      case "hierarchical":
        if let color { image = image?.applyingSymbolConfiguration(.init(hierarchicalColor: color)) }
      case "palette":
        let colors = palette.isEmpty ? (color.map { [$0] } ?? []) : palette
        if !colors.isEmpty { image = image?.applyingSymbolConfiguration(.init(paletteColors: colors)) }
      case "multicolor":
        image = image?.applyingSymbolConfiguration(.preferringMulticolor())
      default:
        if let color { image = image?.withTintColor(color, renderingMode: .alwaysOriginal) }
      }
    }
    image?.accessibilityLabel = label
    return image
  }

  #if compiler(>=6.2)
  @available(iOS 26.0, *)
  static func badge(_ value: Any?) -> UIBarButtonItem.Badge? {
    guard let d = value as? [String: Any] else { return nil }
    switch d["type"] as? String {
    case "count": return .count((d["value"] as? NSNumber)?.intValue ?? 0)
    case "text": return .string(d["value"] as? String ?? "")
    case "indicator": return .indicator()
    default: return nil
    }
  }
  #endif
}

/// A bar button item that knows the toolbar item (and segment) it shows.
final class CNToolbarBarButtonItem: UIBarButtonItem {
  var cnId = ""
  var segmentIndex: Int?
}
