import FlutterMacOS
import AppKit

/// The glass behind a `LiquidGlassContainer`'s child on macOS.
///
/// macOS 26 and later: AppKit's own Liquid Glass, an `NSGlassEffectView`
/// (`.regular` or `.clear`, tinted with `tint`). Earlier: an
/// `NSVisualEffectView`, the translucent material macOS used before Liquid
/// Glass, with the tint laid over it. Both take the container's shape:
/// a capsule, a circle, or a rectangle with `cornerRadius`.
///
/// `CNGlassEffect.prominent` draws as regular glass, as in SwiftUI. The
/// glass is not interactive on macOS: the container passes pointer events
/// to its child, and AppKit's glass view has no interactive variant.
class LiquidGlassContainerNSView: NSView {
  private let channel: FlutterMethodChannel
  private var effect = "regular"
  private var shape = "capsule"
  private var cornerRadius: CGFloat?
  private var tint: NSColor?
  /// How far the glass sits inside the view on each side: Flutter makes the
  /// view that much larger than the child so the glass's shadow has room.
  private var inset: CGFloat = 0

  /// The `NSGlassEffectView` (macOS 26+) or `NSVisualEffectView`.
  private var glassView: NSView?
  /// The tint over the `NSVisualEffectView` below macOS 26.
  private var tintView: NSView?

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeLiquidGlassContainer_\(viewId)", binaryMessenger: messenger)
    super.init(frame: .zero)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    read(args)
    buildGlass()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "updateConfig":
        self.read(call.arguments)
        self.buildGlass()
        result(nil)
      case "setTransitioning", "setInteractive":
        // Nothing to contain or block: the glass draws inside its bounds and
        // never takes pointer events.
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) { return nil }

  override var isFlipped: Bool { true }

  /// The child above handles the pointer.
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    layoutGlass()
  }

  private func read(_ args: Any?) {
    guard let dict = args as? [String: Any] else { return }
    effect = (dict["effect"] as? String) ?? "regular"
    shape = (dict["shape"] as? String) ?? "capsule"
    cornerRadius = (dict["cornerRadius"] as? NSNumber).map { CGFloat(truncating: $0) }
    tint = (dict["tint"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
    inset = (dict["inset"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 0
    if let isDark = (dict["isDark"] as? NSNumber)?.boolValue {
      appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    }
  }

  /// The glass frame: a centred square for a circle, else the whole view.
  private var glassFrame: NSRect {
    let area = bounds.insetBy(dx: inset, dy: inset)
    guard shape == "circle" else { return area }
    let side = min(area.width, area.height)
    return NSRect(x: area.midX - side / 2, y: area.midY - side / 2, width: side, height: side)
  }

  private var radius: CGFloat {
    let frame = glassFrame
    switch shape {
    case "rect": return min(cornerRadius ?? 0, min(frame.width, frame.height) / 2)
    default: return min(frame.width, frame.height) / 2
    }
  }

  private func buildGlass() {
    #if compiler(>=6.2)
    if #available(macOS 26.0, *) {
      let glass = (glassView as? NSGlassEffectView) ?? NSGlassEffectView()
      glass.style = effect == "clear" ? .clear : .regular
      glass.tintColor = tint
      if glassView == nil {
        addSubview(glass)
        glassView = glass
      }
      layoutGlass()
      return
    }
    #endif
    let material = (glassView as? NSVisualEffectView) ?? NSVisualEffectView()
    material.material = effect == "clear" ? .hudWindow : .popover
    material.blendingMode = .withinWindow
    material.state = .active
    if glassView == nil {
      addSubview(material)
      glassView = material
    }
    if let tint = tint {
      let overlay = tintView ?? NSView()
      overlay.wantsLayer = true
      overlay.layer?.backgroundColor = tint.withAlphaComponent(tint.alphaComponent * 0.55).cgColor
      if tintView == nil {
        material.addSubview(overlay)
        tintView = overlay
      }
    } else {
      tintView?.removeFromSuperview()
      tintView = nil
    }
    layoutGlass()
  }

  private func layoutGlass() {
    guard let glass = glassView else { return }
    glass.frame = glassFrame
    #if compiler(>=6.2)
    if #available(macOS 26.0, *), let g = glass as? NSGlassEffectView {
      g.cornerRadius = radius
      return
    }
    #endif
    if let material = glass as? NSVisualEffectView {
      material.maskImage = Self.roundedMask(radius: radius)
      // The mask shapes the material only; round the tint the same way.
      if let overlay = tintView {
        overlay.frame = material.bounds
        overlay.layer?.cornerRadius = radius
        overlay.layer?.masksToBounds = true
      }
    }
  }

  /// A stretchable rounded-rectangle mask: the documented way to round an
  /// `NSVisualEffectView`.
  private static func roundedMask(radius: CGFloat) -> NSImage? {
    guard radius > 0 else { return nil }
    let edge = radius * 2 + 1
    let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
      NSColor.black.set()
      NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
      return true
    }
    image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
    image.resizingMode = .stretch
    return image
  }
}
