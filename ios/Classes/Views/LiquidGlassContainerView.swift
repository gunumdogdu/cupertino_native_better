import Flutter
import UIKit
import SwiftUI

@available(iOS 26.0, *)
class LiquidGlassContainerPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView
  private var hostingController: UIHostingController<LiquidGlassContainerSwiftUI>
  private let channel: FlutterMethodChannel
  
  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeLiquidGlassContainer_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)
    self.container.backgroundColor = .clear
    self.container.isOpaque = false
    // Issue #29: clip + clear shadow sources so iOS 26 Liquid Glass effects
    // do not render a halo outside the platform-view bounds during route
    // transitions (same containment pattern as Issue #2).
    self.container.clipsToBounds = true
    self.container.layer.backgroundColor = UIColor.clear.cgColor
    self.container.layer.shadowOpacity = 0

    // Parse arguments
    var effect: String = "regular"
    var shape: String = "capsule"
    var cornerRadius: CGFloat? = nil
    var tint: UIColor? = nil
    var interactive: Bool = false
    var isDark: Bool = false
    
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
    }
    
    // Create SwiftUI view
    let glassView = LiquidGlassContainerSwiftUI(
      effect: effect,
      shape: shape,
      cornerRadius: cornerRadius,
      tint: tint,
      interactive: interactive
    )
    
    self.hostingController = UIHostingController(rootView: glassView)
    // Transparent hosting view (Issue #29: prevent white placeholder during route transitions)
    self.hostingController.view.backgroundColor = .clear
    self.hostingController.view.isOpaque = false
    self.hostingController.view.layer.backgroundColor = UIColor.clear.cgColor
    self.hostingController.view.layer.shadowOpacity = 0
    self.hostingController.view.clipsToBounds = true
    self.hostingController.overrideUserInterfaceStyle = isDark ? .dark : .light
    
    super.init()
    
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
      } else {
        result(FlutterMethodNotImplemented)
      }
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
      interactive: interactive
    )
    
    hostingController.rootView = newGlassView
    hostingController.overrideUserInterfaceStyle = isDark ? .dark : .light
  }
  
  func view() -> UIView {
    return container
  }
}

@available(iOS 26.0, *)
struct LiquidGlassContainerSwiftUI: View {
  let effect: String
  let shape: String
  let cornerRadius: CGFloat?
  let tint: UIColor?
  let interactive: Bool

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
    // Always use .regular for now - prominent glass API may be available in future
    var glass = Glass.regular
    
    if let tintColor = tint {
      glass = glass.tint(Color(tintColor))
    }
    
    if interactive {
      glass = glass.interactive()
    }
    
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

// Fallback for iOS < 26
class FallbackLiquidGlassContainerView: NSObject, FlutterPlatformView {
  private let container: UIView

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.container = UIView(frame: frame)
    self.container.backgroundColor = .clear
    super.init()
  }

  func view() -> UIView {
    return container
  }
}

