import FlutterMacOS
import AppKit
import SwiftUI

@available(macOS 26.0, *)
class LiquidGlassContainerNSView: NSView {
  private var hostingController: NSHostingController<LiquidGlassContainerSwiftUI>
  private let channel: FlutterMethodChannel

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeLiquidGlassContainer_\(viewId)", binaryMessenger: messenger)

    // Parse arguments
    var effect: String = "regular"
    var shape: String = "capsule"
    var cornerRadius: CGFloat? = nil
    var tint: NSColor? = nil
    var interactive: Bool = false
    var isDark: Bool = false

    if let dict = args as? [String: Any] {
      if let effectStr = dict["effect"] as? String { effect = effectStr }
      if let shapeStr = dict["shape"] as? String { shape = shapeStr }
      if let radius = dict["cornerRadius"] as? CGFloat { cornerRadius = radius }
      if let tintInt = dict["tint"] as? Int {
        tint = NSColor(
          red: CGFloat((tintInt >> 16) & 0xFF) / 255.0,
          green: CGFloat((tintInt >> 8) & 0xFF) / 255.0,
          blue: CGFloat(tintInt & 0xFF) / 255.0,
          alpha: CGFloat((tintInt >> 24) & 0xFF) / 255.0
        )
      }
      if let interactiveBool = dict["interactive"] as? Bool { interactive = interactiveBool }
      if let isDarkBool = dict["isDark"] as? Bool { isDark = isDarkBool }
    }

    // Create SwiftUI view
    let glassView = LiquidGlassContainerSwiftUI(
      effect: effect,
      shape: shape,
      cornerRadius: cornerRadius,
      tint: tint,
      interactive: interactive
    )

    self.hostingController = NSHostingController(rootView: glassView)

    super.init(frame: .zero)

    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor

    hostingController.view.wantsLayer = true
    hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
    hostingController.view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    // Add hosting controller view
    addSubview(hostingController.view)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(equalTo: topAnchor),
      hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    // Set up method channel handler
    channel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "updateConfig" {
        self?.updateConfig(args: call.arguments)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func updateConfig(args: Any?) {
    guard let dict = args as? [String: Any] else { return }

    var effect: String = "regular"
    var shape: String = "capsule"
    var cornerRadius: CGFloat? = nil
    var tint: NSColor? = nil
    var interactive: Bool = false
    var isDark: Bool = false

    if let effectStr = dict["effect"] as? String { effect = effectStr }
    if let shapeStr = dict["shape"] as? String { shape = shapeStr }
    if let radius = dict["cornerRadius"] as? CGFloat { cornerRadius = radius }
    if let tintInt = dict["tint"] as? Int {
      tint = NSColor(
        red: CGFloat((tintInt >> 16) & 0xFF) / 255.0,
        green: CGFloat((tintInt >> 8) & 0xFF) / 255.0,
        blue: CGFloat(tintInt & 0xFF) / 255.0,
        alpha: CGFloat((tintInt >> 24) & 0xFF) / 255.0
      )
    }
    if let interactiveBool = dict["interactive"] as? Bool { interactive = interactiveBool }
    if let isDarkBool = dict["isDark"] as? Bool { isDark = isDarkBool }

    let newGlassView = LiquidGlassContainerSwiftUI(
      effect: effect,
      shape: shape,
      cornerRadius: cornerRadius,
      tint: tint,
      interactive: interactive
    )

    hostingController.rootView = newGlassView
    hostingController.view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
  }
}

@available(macOS 26.0, *)
struct LiquidGlassContainerSwiftUI: View {
  let effect: String
  let shape: String
  let cornerRadius: CGFloat?
  let tint: NSColor?
  let interactive: Bool

  var body: some View {
    GeometryReader { geometry in
      shapeForConfig()
        .fill(Color.clear)
        .contentShape(shapeForConfig())
        .allowsHitTesting(false)
        .glassEffect(glassEffectForConfig(), in: shapeForConfig())
        .frame(width: geometry.size.width, height: geometry.size.height)
    }
  }

  private func glassEffectForConfig() -> Glass {
    // `prominent` still has no SwiftUI counterpart, so it keeps falling back to regular.
    var glass: Glass = effect == "clear" ? .clear : .regular
    if let tintColor = tint { glass = glass.tint(Color(tintColor)) }
    if interactive { glass = glass.interactive() }
    return glass
  }

  private func shapeForConfig() -> some Shape {
    switch shape {
    case "rect":
      if let radius = cornerRadius {
        return AnyShape(RoundedRectangle(cornerRadius: radius))
      }
      return AnyShape(RoundedRectangle(cornerRadius: 0))
    case "circle":
      return AnyShape(Circle())
    default:
      return AnyShape(Capsule())
    }
  }
}

// Fallback for macOS < 26
class FallbackLiquidGlassContainerNSView: NSView {
  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    super.init(frame: .zero)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
