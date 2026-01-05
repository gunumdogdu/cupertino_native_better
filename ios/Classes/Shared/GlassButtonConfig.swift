import SwiftUI
import UIKit

/// Configuration for GlassButtonSwiftUI with default values.
/// This is shared between iOS and macOS implementations.
@available(iOS 26.0, macOS 26.0, *)
public struct GlassButtonConfig {
  let borderRadius: CGFloat?
  let padding: EdgeInsets
  let minHeight: CGFloat
  let spacing: CGFloat
  let flexible: Bool?

  public init(
    borderRadius: CGFloat? = nil,
    padding: EdgeInsets = EdgeInsets(top: 8.0, leading: 12.0, bottom: 8.0, trailing: 12.0),
    minHeight: CGFloat = 44.0,
    spacing: CGFloat = 8.0,
    flexible: Bool? = nil
  ) {
    self.borderRadius = borderRadius
    self.padding = padding
    self.minHeight = minHeight
    self.spacing = spacing
    self.flexible = flexible
  }

  /// Convenience initializer for individual padding values
  public init(
    borderRadius: CGFloat? = nil,
    top: CGFloat? = nil,
    bottom: CGFloat? = nil,
    left: CGFloat? = nil,
    right: CGFloat? = nil,
    horizontal: CGFloat? = nil,
    vertical: CGFloat? = nil,
    minHeight: CGFloat = 44.0,
    spacing: CGFloat = 8.0,
    flexible: Bool? = nil
  ) {
    self.borderRadius = borderRadius
    self.minHeight = minHeight
    self.spacing = spacing
    self.flexible = flexible

    // Build EdgeInsets from provided values
    let defaultPadding = EdgeInsets(top: 8.0, leading: 12.0, bottom: 8.0, trailing: 12.0)
    self.padding = EdgeInsets(
      top: top ?? vertical ?? defaultPadding.top,
      leading: left ?? horizontal ?? defaultPadding.leading,
      bottom: bottom ?? vertical ?? defaultPadding.bottom,
      trailing: right ?? horizontal ?? defaultPadding.trailing
    )
  }
}

