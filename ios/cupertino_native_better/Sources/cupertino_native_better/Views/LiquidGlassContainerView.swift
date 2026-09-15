import Flutter
import UIKit
import SwiftUI

@available(iOS 26.0, *)
class LiquidGlassContainerPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView
  private var hostingController: UIHostingController<LiquidGlassContainerSwiftUI>
  private let channel: FlutterMethodChannel

  // Stored shape config so `applyTransitionContainment` can clip the
  // container's layer to the same rounded shape the SwiftUI glass uses.
  // Without this we clip to the rectangular layer bounds and the layer's
  // drop shadow leaks past the rounded corners — visible behind a modal
  // scrim as four square shadow nubs at the corners (Issue #36).
  private var configuredShape: String = "capsule"
  private var configuredCornerRadius: CGFloat? = nil

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeLiquidGlassContainer_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)
    self.container.backgroundColor = .clear
    
    // Parse arguments
    var effect: String = "regular"
    var shape: String = "capsule"
    var cornerRadius: CGFloat? = nil
    var tint: UIColor? = nil
    var interactive: Bool = false
    var isDark: Bool = false
    var parts: [CNGlassPart] = []
    
    if let dict = args as? [String: Any] {
      if let effectStr = dict["effect"] as? String {
        effect = effectStr
      }
      if let shapeStr = dict["shape"] as? String {
        shape = shapeStr
      }
      if let radius = dict["cornerRadius"] as? CGFloat {
        cornerRadius = radius
      }
      if let tintInt = dict["tint"] as? Int {
        tint = UIColor(
          red: CGFloat((tintInt >> 16) & 0xFF) / 255.0,
          green: CGFloat((tintInt >> 8) & 0xFF) / 255.0,
          blue: CGFloat(tintInt & 0xFF) / 255.0,
          alpha: CGFloat((tintInt >> 24) & 0xFF) / 255.0
        )
      }
      if let interactiveBool = dict["interactive"] as? Bool {
        interactive = interactiveBool
      }
      if let isDarkBool = dict["isDark"] as? Bool {
        isDark = isDarkBool
      }
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

    self.hostingController = UIHostingController(rootView: glassView)
    self.hostingController.view.backgroundColor = .clear
    self.hostingController.overrideUserInterfaceStyle = isDark ? .dark : .light
    // Don't propagate the screen's safe area into the SwiftUI glass. When the
    // container's frame reaches into the bottom safe area (e.g. a floating
    // bottom panel), UIHostingController otherwise insets the SwiftUI content
    // by the overlap, so the glass renders short of the frame's bottom edge.
    // Same issue class as the safeAreaInsets override in
    // CupertinoSwitchPlatformView.swift.
    self.hostingController.safeAreaRegions = []

    super.init()
    self.configuredShape = shape
    self.configuredCornerRadius = cornerRadius
    
    // Sync Flutter's brightness mode with Swift at initialization
    if #available(iOS 13.0, *) {
      self.hostingController.overrideUserInterfaceStyle = isDark ? .dark : .light
    }
    
    // Add hosting controller as child
    container.addSubview(hostingController.view)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
      hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    
    // Set up method channel handler
    channel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "updateConfig" {
        self?.updateConfig(args: call.arguments)
        result(nil)
      } else if call.method == "setTransitioning" {
        let active = ((call.arguments as? [String: Any])?["active"] as? NSNumber)?.boolValue ?? false
        self?.applyTransitionContainment(active)
        result(nil)
      } else if call.method == "setInteractive" {
        if let args = call.arguments as? [String: Any],
           let interactive = (args["interactive"] as? NSNumber)?.boolValue {
          NSLog("[CN Glass] setInteractive=\(interactive)")
          self?._cnSetInteractiveRecursive(self?.container, interactive)
          self?._cnSetInteractiveRecursive(self?.hostingController.view, interactive)
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Toggle Issue #29 / #36 halo containment on container + hosting view.
  /// Clips with the same rounded shape the SwiftUI glass uses so the
  /// layer's drop shadow doesn't leak past the rounded corners and show
  /// up as four square shadow nubs behind a modal scrim.
  private func applyTransitionContainment(_ active: Bool) {
    if active {
      let radius = roundedCornerRadiusForCurrentShape()
      container.isOpaque = false
      container.clipsToBounds = true
      container.layer.cornerRadius = radius
      container.layer.backgroundColor = UIColor.clear.cgColor
      container.layer.shadowOpacity = 0
      hostingController.view.clipsToBounds = true
      hostingController.view.layer.cornerRadius = radius
      hostingController.view.isOpaque = false
      hostingController.view.layer.backgroundColor = UIColor.clear.cgColor
      hostingController.view.layer.shadowOpacity = 0
    } else {
      container.clipsToBounds = false
      container.layer.cornerRadius = 0
      hostingController.view.clipsToBounds = false
      hostingController.view.layer.cornerRadius = 0
    }
  }

  private func roundedCornerRadiusForCurrentShape() -> CGFloat {
    let bounds = container.bounds
    switch configuredShape {
    case "circle":
      return min(bounds.width, bounds.height) / 2.0
    case "rect":
      return configuredCornerRadius ?? 0
    default:
      // Capsule — half of the shorter side gives the iOS pill shape.
      return min(bounds.width, bounds.height) / 2.0
    }
  }
  
  private func updateConfig(args: Any?) {
    guard let dict = args as? [String: Any] else { return }
    
    var effect: String = "regular"
    var shape: String = "capsule"
    var cornerRadius: CGFloat? = nil
    var tint: UIColor? = nil
    var interactive: Bool = false
    var isDark: Bool = false
    
    if let effectStr = dict["effect"] as? String {
      effect = effectStr
    }
    if let shapeStr = dict["shape"] as? String {
      shape = shapeStr
    }
    if let radius = dict["cornerRadius"] as? CGFloat {
      cornerRadius = radius
    }
    if let tintInt = dict["tint"] as? Int {
      tint = UIColor(
        red: CGFloat((tintInt >> 16) & 0xFF) / 255.0,
        green: CGFloat((tintInt >> 8) & 0xFF) / 255.0,
        blue: CGFloat(tintInt & 0xFF) / 255.0,
        alpha: CGFloat((tintInt >> 24) & 0xFF) / 255.0
      )
    }
    if let interactiveBool = dict["interactive"] as? Bool {
      interactive = interactiveBool
    }
    if let isDarkBool = dict["isDark"] as? Bool {
      isDark = isDarkBool
    }
    
    // Update the SwiftUI view
    let newGlassView = LiquidGlassContainerSwiftUI(
      effect: effect,
      shape: shape,
      cornerRadius: cornerRadius,
      tint: tint,
      interactive: interactive,
      parts: CNGlassPart.list(from: dict["parts"])
    )

    hostingController.rootView = newGlassView
    hostingController.overrideUserInterfaceStyle = isDark ? .dark : .light
    // Keep stored config in sync for `applyTransitionContainment`.
    self.configuredShape = shape
    self.configuredCornerRadius = cornerRadius
  }
  
  func view() -> UIView {
    return container
  }

  private func _cnSetInteractiveRecursive(_ view: UIView?, _ interactive: Bool) {
    guard let view = view else { return }
    view.isUserInteractionEnabled = interactive
    for sub in view.subviews { _cnSetInteractiveRecursive(sub, interactive) }
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

@available(iOS 26.0, *)
struct LiquidGlassContainerSwiftUI: View {
  let effect: String
  let shape: String
  let cornerRadius: CGFloat?
  let tint: UIColor?
  let interactive: Bool
  let parts: [CNGlassPart]

  /// Observe transition state to disable glass effect during navigation
  @ObservedObject private var transitionObserver = CNTransitionObserver.shared

  var body: some View {
    GeometryReader { geometry in
      shapeForConfig()
        .fill(Color.clear)
        .contentShape(shapeForConfig())
        .allowsHitTesting(false)  // Always false - let Flutter handle gestures
        .applyConditionalGlassEffectForContainer(
          isTransitioning: transitionObserver.isTransitioning,
          glass: glassEffectForConfig(),
          shape: shapeForConfig()
        )
        .frame(width: geometry.size.width, height: geometry.size.height)
        .animation(.easeInOut(duration: 0.25), value: effect)
        .animation(.easeInOut(duration: 0.25), value: shape)
        .animation(.easeInOut(duration: 0.25), value: cornerRadius)
        .animation(.easeInOut(duration: 0.25), value: tint)
        .animation(.easeInOut(duration: 0.25), value: interactive)
    }
  }
  
  private func glassEffectForConfig() -> Glass {
    // `prominent` still has no SwiftUI counterpart, so it keeps falling back to regular.
    var glass: Glass = effect == "clear" ? .clear : .regular
    
    if let tintColor = tint {
      glass = glass.tint(Color(tintColor))
    }
    
    if interactive {
      glass = glass.interactive()
    }
    
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
    default: // capsule
      return AnyShape(Capsule())
    }
  }
}

// Helper to apply glass effect conditionally based on transition state for containers
@available(iOS 26.0, *)
extension View {
  @ViewBuilder
  func applyConditionalGlassEffectForContainer<S: Shape>(isTransitioning: Bool, glass: Glass, shape: S) -> some View {
    if isTransitioning {
      // During transitions, use a simple background instead of glass to prevent sampling artifacts
      self.background(
        shape
          .fill(Color(UIColor.systemBackground).opacity(0.8))
      )
    } else {
      // Normal state - apply full glass effect
      self.glassEffect(glass, in: shape)
    }
  }
}

// Fallback for iOS < 26.
//
// Must register a MethodChannel no-op handler so Dart-side calls like
// setTransitioning (Issue #29 halo containment) and setInteractive
// (ModalHideMixin) don't throw MissingPluginException. Same fix as the
// CupertinoGlassButtonGroup fallback.
class FallbackLiquidGlassContainerView: NSObject, FlutterPlatformView {
  private let container: UIView
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.container = UIView(frame: frame)
    self.container.backgroundColor = .clear
    self.channel = FlutterMethodChannel(
      name: "CupertinoNativeLiquidGlassContainer_\(viewId)",
      binaryMessenger: messenger
    )
    super.init()
    self.channel.setMethodCallHandler { _, result in result(nil) }
  }

  func view() -> UIView {
    return container
  }
}

