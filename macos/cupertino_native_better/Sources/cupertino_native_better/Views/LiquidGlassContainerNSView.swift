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
    var parts: [CNGlassPart] = []

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
      parts = CNGlassPart.list(from: dict["parts"])
    }

    // Create SwiftUI view
    let glassView = LiquidGlassContainerSwiftUI(
      effect: effect,
      shape: shape,
      cornerRadius: cornerRadius,
      tint: tint,
      interactive: interactive,
      parts: parts
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
      interactive: interactive,
      parts: CNGlassPart.list(from: dict["parts"])
    )

    hostingController.rootView = newGlassView
    hostingController.view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
  }
}

/// One rounded rectangle of a multi-part glass shape, in points relative to the container's top-left.
struct CNGlassPart: Equatable {
  let left: CGFloat
  let top: CGFloat
  let width: CGFloat
  let height: CGFloat
  let radius: CGFloat

  var rect: CGRect { CGRect(x: left, y: top, width: width, height: height) }

  /// Never rounder than a capsule of that part, so a full-radius square reads as a circle.
  var clampedRadius: CGFloat { min(radius, min(width, height) / 2.0) }

  static func list(from raw: Any?) -> [CNGlassPart] {
    guard let entries = raw as? [[String: Any]] else { return [] }
    return entries.compactMap { entry in
      guard let left = entry["left"] as? CGFloat,
            let top = entry["top"] as? CGFloat,
            let width = entry["width"] as? CGFloat,
            let height = entry["height"] as? CGFloat,
            let radius = entry["radius"] as? CGFloat,
            width > 0, height > 0
      else { return nil }
      return CNGlassPart(left: left, top: top, width: width, height: height, radius: radius)
    }
  }
}

/// The parts as one `Shape`. `glassEffect(_:in:)` rims whatever outline it is handed, so a path of
/// disjoint parts is rimmed on each of them while staying a single effect — one backdrop sample, so
/// the parts cannot drift apart in colour.
struct CNGlassPartsShape: Shape, Equatable {
  let parts: [CNGlassPart]

  func path(in rect: CGRect) -> Path {
    var path = Path()
    for part in parts {
      path.addRoundedRect(
        in: part.rect,
        cornerSize: CGSize(width: part.clampedRadius, height: part.clampedRadius)
      )
    }
    return path
  }
}

@available(macOS 26.0, *)
struct LiquidGlassContainerSwiftUI: View {
  let effect: String
  let shape: String
  let cornerRadius: CGFloat?
  let tint: NSColor?
  let interactive: Bool
  let parts: [CNGlassPart]

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
    if !parts.isEmpty {
      return AnyShape(CNGlassPartsShape(parts: parts))
    }
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
