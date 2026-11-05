import Cocoa
import FlutterMacOS
import SwiftUI

/// `CNSidebar` (and `CNTabRail`) on macOS: a native sidebar list in a
/// platform view, so Flutter keeps the layout. SwiftUI's `List` in the
/// sidebar style on Liquid Glass on macOS 26 and later, and on the sidebar
/// material of `NSVisualEffectView` before.
final class CNSidebarNSView: NSView {
  private let channel: FlutterMethodChannel
  private let model = MacSidebarModel()
  private let hostingView: NSHostingView<MacSidebarList>
  private var background: NSView?

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "CNSidebar_\(viewId)", binaryMessenger: messenger)
    hostingView = NSHostingView(rootView: MacSidebarList(model: model))
    super.init(frame: .zero)

    let dict = args as? [String: Any] ?? [:]
    apply(sections: dict)
    apply(style: dict)
    model.selection = (dict["selectedIndex"] as? NSNumber)?.intValue
    model.onSelect = { [weak self] index in
      self?.channel.invokeMethod("valueChanged", arguments: ["index": index])
    }

    installBackground(cornerRadius: CGFloat((dict["cornerRadius"] as? NSNumber)?.doubleValue ?? 16))

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "setSelectedIndex":
        self.model.selection = (args["index"] as? NSNumber)?.intValue
        result(nil)
      case "setSections":
        self.apply(sections: args)
        result(nil)
      case "setStyle":
        self.apply(style: args)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private func apply(sections dict: [String: Any]) {
    if let sections = dict["sections"] as? [[String: Any]] {
      model.sections = MacSidebarModel.sections(from: sections)
    }
  }

  private func apply(style dict: [String: Any]) {
    if let argb = dict["tint"] as? Int {
      model.tint = Color(ImageUtils.colorFromARGB(argb))
    } else if dict.keys.contains("tint") {
      model.tint = nil
    }
    if let iconsOnly = dict["iconsOnly"] as? Bool { model.iconsOnly = iconsOnly }
    if let isDark = dict["isDark"] as? Bool {
      appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    }
    if let label = dict["semanticLabel"] as? String {
      // VoiceOver announces the sidebar as a labeled group of its rows.
      setAccessibilityElement(true)
      setAccessibilityRole(.group)
      setAccessibilityLabel(label)
    }
  }

  /// Glass on macOS 26 and later; the vibrant sidebar material before. The
  /// list draws no background of its own in the sidebar style.
  private func installBackground(cornerRadius: CGFloat) {
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    // The list's own (faint) background stays inside the rounded panel.
    hostingView.wantsLayer = true
    hostingView.layer?.cornerRadius = cornerRadius
    hostingView.layer?.cornerCurve = .continuous
    hostingView.layer?.masksToBounds = cornerRadius > 0
    #if compiler(>=6.2)
    if #available(macOS 26.0, *) {
      let glass = NSGlassEffectView()
      glass.cornerRadius = cornerRadius
      glass.contentView = hostingView
      embed(glass)
      background = glass
      return
    }
    #endif
    let material = NSVisualEffectView()
    material.material = .sidebar
    material.blendingMode = .behindWindow
    material.state = .followsWindowActiveState
    material.wantsLayer = true
    material.layer?.cornerRadius = cornerRadius
    material.layer?.cornerCurve = .continuous
    material.layer?.masksToBounds = cornerRadius > 0
    material.addSubview(hostingView)
    NSLayoutConstraint.activate([
      hostingView.topAnchor.constraint(equalTo: material.topAnchor),
      hostingView.bottomAnchor.constraint(equalTo: material.bottomAnchor),
      hostingView.leadingAnchor.constraint(equalTo: material.leadingAnchor),
      hostingView.trailingAnchor.constraint(equalTo: material.trailingAnchor),
    ])
    embed(material)
    background = material
  }

  private func embed(_ view: NSView) {
    view.translatesAutoresizingMaskIntoConstraints = false
    addSubview(view)
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: topAnchor),
      view.bottomAnchor.constraint(equalTo: bottomAnchor),
      view.leadingAnchor.constraint(equalTo: leadingAnchor),
      view.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])
  }
}
