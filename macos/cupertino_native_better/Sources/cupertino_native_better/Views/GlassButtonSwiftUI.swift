import SwiftUI
import AppKit

/// SwiftUI button view with full Liquid Glass support using glassEffect() modifier.
/// This provides full blending and morphing capabilities when used in groups.
@available(macOS 26.0, *)
struct GlassButtonSwiftUI: View {
  let title: String?
  let iconName: String?
  let iconImage: NSImage?
  let iconSize: CGFloat
  let iconColor: Color?
  let tint: Color?
  let isRound: Bool
  let style: String
  let isEnabled: Bool
  let onPressed: () -> Void
  let glassEffectUnionId: String?
  let glassEffectId: String?
  let glassEffectInteractive: Bool
  @Namespace private var namespace
  let config: GlassButtonConfig
  let badgeCount: Int?

  /// `prominentClearGlass` tints the glass itself with [tint], so its content
  /// keeps the system's automatic foreground.
  private var isProminentClear: Bool { style == "prominentClearGlass" }

  var body: some View {
    Button(action: onPressed) {
      HStack(spacing: config.spacing) {
        if let icon = iconImage {
          Image(nsImage: icon)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .foregroundColor(isProminentClear ? iconColor : (tint != nil ? tint : iconColor))
        } else if let iconName = iconName {
          Image(systemName: iconName)
            .font(.system(size: iconSize))
            .foregroundColor(iconColor)
        }

        if let title = title {
          Text(title)
            .foregroundColor(isProminentClear ? nil : tint)
        }
      }
      .padding(config.padding)
      .frame(minHeight: config.minHeight)
      .contentShape(shapeForStyle(isRound, borderRadius: config.borderRadius))
      .glassEffect(glassEffectForStyle(style, interactive: glassEffectInteractive), in: shapeForStyle(isRound, borderRadius: config.borderRadius))
      .applyGlassEffectModifiers(unionId: glassEffectUnionId, id: glassEffectId, namespace: namespace)
    }
    .disabled(!isEnabled)
    .buttonStyle(NoHighlightButtonStyle())
    .badge(badgeCount != nil && badgeCount! > 0 ? (badgeCount! > 99 ? "99+" : "\(badgeCount!)") : nil)
  }
  
  private func glassEffectForStyle(_ style: String, interactive: Bool) -> Glass {
    // Regular glass for every style but the clear ones; `prominentClearGlass`
    // tints the clear glass, as SwiftUI's `.glassProminent` button style
    // draws its own glass and cannot join a `glassEffectUnion`.
    var glass: Glass
    switch style {
    case "clearGlass":
      glass = .clear
    case "prominentClearGlass":
      glass = Glass.clear.tint(tint)
    default:
      glass = .regular
    }
    
    // Make glass interactive if requested
    if interactive {
      glass = glass.interactive()
    }
    
    return glass
  }
  
  private func shapeForStyle(_ isRound: Bool, borderRadius: CGFloat?) -> some Shape {
    // If borderRadius is provided, use it
    if let radius = borderRadius {
      return AnyShape(RoundedRectangle(cornerRadius: radius))
    }
    // If no borderRadius provided, use capsule for round buttons
    if isRound {
      return AnyShape(Capsule())
    }
    // For non-round buttons without radius, also use capsule (as per user requirement)
    return AnyShape(Capsule())
  }
}

// Helper to apply glass effect modifiers conditionally
@available(macOS 26.0, *)
extension View {
  @ViewBuilder
  func applyGlassEffectModifiers(unionId: String?, id: String?, namespace: Namespace.ID) -> some View {
    if let unionId = unionId {
      if let id = id {
        self
          .glassEffectUnion(id: unionId, namespace: namespace)
          .glassEffectID(id, in: namespace)
      } else {
        self
          .glassEffectUnion(id: unionId, namespace: namespace)
      }
    } else if let id = id {
      self
        .glassEffectID(id, in: namespace)
    } else {
      self
    }
  }
}

// Custom button style that removes all highlights and press effects
@available(macOS 26.0, *)
struct NoHighlightButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      // No opacity or scale changes - let the glass effect handle visual feedback
  }
}

// Type erasure for Shape
@available(macOS 26.0, *)
struct AnyShape: Shape {
  private let _path: (CGRect) -> Path
  
  init<S: Shape>(_ shape: S) {
    _path = shape.path(in:)
  }
  
  func path(in rect: CGRect) -> Path {
    return _path(rect)
  }
}

