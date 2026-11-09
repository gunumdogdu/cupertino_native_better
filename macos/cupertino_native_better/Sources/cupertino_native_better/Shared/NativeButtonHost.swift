import AppKit

/// The AppKit button behind `CNButton` and `CNPopupMenuButton`: an `NSButton`
/// drawn in the bezel that matches a `CNButtonStyle`.
///
/// An icon-only button is a circle; a button with a title (with or without an
/// image) is a capsule, as on iOS. On macOS 26 and later the styles map to
/// the system's own bezels:
///
/// | CNButtonStyle          | macOS 26+                                     | macOS 12–15            |
/// |------------------------|-----------------------------------------------|------------------------|
/// | plain                  | borderless, tint on title and image           | same                   |
/// | gray, bordered         | push bezel, tint on title and image           | push bezel             |
/// | tinted                 | push bezel, `bezelColor`, secondary prominence | push bezel, tinted title |
/// | filled, borderedProminent | push bezel, `bezelColor`, primary prominence | push bezel, `bezelColor` |
/// | glass                  | `.glass` bezel                                | push bezel             |
/// | prominentGlass         | `.glass` bezel, `bezelColor`, primary prominence | push bezel, `bezelColor` |
/// | clearGlass             | `NSGlassEffectView` (`.clear`) around a borderless button | push bezel |
/// | prominentClearGlass    | the same, tinted with the tint                | push bezel, `bezelColor` |
///
/// The push bezel uses `flexiblePush` on macOS 26 so it fills the height
/// Flutter gives it, with `borderShape` making it a capsule or circle.
/// `controlSize` follows that height (up to `.extraLarge` on macOS 26), so
/// the title's font grows with the button.
final class NativeButtonHost: NSView {
  let button: NSButton
  private var glassView: NSView?

  // MARK: Content

  var title: String? { didSet { needsContentUpdate() } }
  var image: NSImage? { didSet { needsContentUpdate() } }
  /// Where the image sits next to a title: leading, trailing, top or bottom.
  var imagePlacement: String = "leading" { didSet { needsContentUpdate() } }
  /// Space between image and title, in points.
  var imagePadding: CGFloat? { didSet { needsContentUpdate() } }

  // MARK: Style

  var style: String = "automatic" { didSet { needsStyleUpdate() } }
  /// The tint Flutter resolved for this style; nil for glass without one.
  var tint: NSColor? { didSet { needsStyleUpdate() } }
  /// `CNButtonConfig.borderRadius`: a rounded rectangle instead of a capsule.
  var borderRadius: CGFloat? { didSet { needsStyleUpdate() } }
  /// The height Flutter lays the button out at, used before the first layout.
  var expectedHeight: CGFloat = 44 { didSet { needsStyleUpdate() } }
  /// Horizontal padding around the content, from `CNButtonConfig.padding`.
  var paddingLeft: CGFloat?
  var paddingRight: CGFloat?

  // MARK: Label style (CNButtonConfig.label*)

  var labelColor: NSColor? { didSet { needsContentUpdate() } }
  var labelFontSize: CGFloat? { didSet { needsContentUpdate() } }
  var labelFontFamily: String? { didSet { needsContentUpdate() } }
  /// Flutter's `FontWeight.value` (100–900).
  var labelFontWeight: Int? { didSet { needsContentUpdate() } }

  // MARK: State

  var isEnabled: Bool = true {
    didSet {
      button.isEnabled = isEnabled
      needsContentUpdate()
    }
  }
  /// `CNButtonConfig.interaction`: false lets clicks pass through without
  /// changing how the button looks.
  var isInteractive: Bool = true
  /// `semanticLabel`: what VoiceOver reads instead of the title or symbol.
  var accessibilityText: String? {
    didSet { button.setAccessibilityLabel(accessibilityText) }
  }

  private var updating = false
  private var lastLayoutHeight: CGFloat = 0

  init(target: AnyObject?, action: Selector?) {
    button = NSButton(title: "", target: target, action: action)
    super.init(frame: .zero)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    button.setButtonType(.momentaryPushIn)
    addSubview(button)
  }

  required init?(coder: NSCoder) { return nil }

  override var isFlipped: Bool { true }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard isInteractive else { return nil }
    return super.hitTest(point)
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    if abs(newSize.height - lastLayoutHeight) > 0.5 {
      lastLayoutHeight = newSize.height
      applyStyle()
    } else {
      layoutButton()
    }
  }

  // MARK: - Derived values

  /// Icon only: a circle. With a title: a capsule.
  var isIconOnly: Bool { (title ?? "").isEmpty && image != nil }

  private var height: CGFloat { bounds.height > 0 ? bounds.height : expectedHeight }

  static let prominentStyles: Set<String> = ["filled", "borderedProminent", "prominentGlass", "prominentClearGlass"]

  private var isProminent: Bool { Self.prominentStyles.contains(style) }

  private var usesClearGlass: Bool {
    Self.hasGlass && (style == "clearGlass" || style == "prominentClearGlass")
  }

  /// Whether this build and this macOS have the macOS 26 bezels and glass.
  static var hasGlass: Bool {
    #if compiler(>=6.2)
    if #available(macOS 26.0, *) { return true }
    #endif
    return false
  }

  /// The colour of the title and image when the bezel does not pick it: the
  /// tint, on the styles iOS paints the foreground with it.
  private var styleForeground: NSColor? {
    switch style {
    case "plain", "gray", "bordered", "glass", "clearGlass":
      return tint
    case "tinted":
      // The tinted bezel colours its content on macOS 26; before, nothing does.
      return Self.hasGlass ? nil : tint
    case "prominentClearGlass":
      return Self.hasGlass ? .white : nil
    default:
      return nil
    }
  }

  /// The title colour to state when an attributed title replaces the plain
  /// one, which would otherwise lose the colour the bezel picks.
  private var bezelForeground: NSColor? {
    if style == "tinted" { return tint }
    if isProminent, tint != nil { return .white }
    return nil
  }

  private var controlSize: NSControl.ControlSize {
    let h = height
    #if compiler(>=6.2)
    if #available(macOS 26.0, *), h >= 40 { return .extraLarge }
    #endif
    if h >= 28 { return .large }
    if h >= 22 { return .regular }
    if h >= 18 { return .small }
    return .mini
  }

  // MARK: - Updates

  private func needsStyleUpdate() {
    guard !updating else { return }
    applyStyle()
  }

  private func needsContentUpdate() {
    guard !updating else { return }
    applyContent()
  }

  /// Makes several changes and applies them once.
  func update(_ changes: (NativeButtonHost) -> Void = { _ in }) {
    let wasUpdating = updating
    updating = true
    changes(self)
    updating = wasUpdating
    if !updating { applyStyle() }
  }

  private func applyStyle() {
    let wasUpdating = updating
    updating = true
    defer { updating = wasUpdating }

    installGlassIfNeeded()
    button.controlSize = controlSize
    button.bezelColor = nil
    button.contentTintColor = nil
    button.isBordered = true
    if !applyModernStyle() {
      if style == "plain" {
        button.isBordered = false
        button.contentTintColor = tint
      } else {
        // macOS 12–15: the standard push button, or a circular one for an
        // icon.
        button.bezelStyle = isIconOnly ? .circular : .push
        if isProminent, let tint = tint { button.bezelColor = tint }
      }
    }
    applyContent()
    layoutButton()
  }

  /// The macOS 26 bezels; false where they do not exist.
  private func applyModernStyle() -> Bool {
    #if compiler(>=6.2)
    guard #available(macOS 26.0, *) else { return false }
    button.tintProminence = .automatic
    button.borderShape = .automatic
    if style == "plain" || usesClearGlass {
      button.isBordered = false
      button.contentTintColor = usesClearGlass ? (styleForeground ?? .labelColor) : tint
      return true
    }
    let isGlass = style == "glass" || style == "prominentGlass"
    button.bezelStyle = isGlass ? .glass : .flexiblePush
    button.borderShape = shape
    switch style {
    case "tinted":
      if let tint = tint {
        button.bezelColor = tint
        button.tintProminence = .secondary
      }
    case "filled", "borderedProminent", "prominentGlass":
      if let tint = tint {
        button.bezelColor = tint
        button.tintProminence = .primary
      }
    default:
      break
    }
    return true
    #else
    return false
    #endif
  }

  #if compiler(>=6.2)
  @available(macOS 26.0, *)
  private var shape: NSControl.BorderShape {
    if isIconOnly { return .circle }
    if let r = borderRadius, r < height / 2 - 0.5 { return .roundedRectangle }
    return .capsule
  }
  #endif

  /// Puts the button inside a clear `NSGlassEffectView` for the clear glass
  /// styles, and back out of it for the others.
  private func installGlassIfNeeded() {
    #if compiler(>=6.2)
    if #available(macOS 26.0, *), usesClearGlass {
      let glass = (glassView as? NSGlassEffectView) ?? NSGlassEffectView()
      glass.style = .clear
      glass.tintColor = style == "prominentClearGlass" ? tint : nil
      glass.cornerRadius = glassCornerRadius
      if glassView == nil {
        glass.frame = bounds
        button.removeFromSuperview()
        glass.contentView = button
        addSubview(glass)
        glassView = glass
      }
      return
    }
    #endif
    if let glass = glassView {
      button.removeFromSuperview()
      glass.removeFromSuperview()
      glassView = nil
      addSubview(button)
    }
  }

  private var glassCornerRadius: CGFloat {
    if !isIconOnly, let r = borderRadius { return min(r, height / 2) }
    return height / 2
  }

  /// A push button keeps its fixed height before macOS 26, centred; every
  /// other bezel fills the view.
  private func layoutButton() {
    if let glass = glassView {
      glass.frame = bounds
      button.frame = glass.bounds
      #if compiler(>=6.2)
      if #available(macOS 26.0, *), let g = glass as? NSGlassEffectView {
        g.cornerRadius = glassCornerRadius
      }
      #endif
      return
    }
    var frame = bounds
    if !Self.hasGlass, button.isBordered, button.bezelStyle == .push {
      let h = min(bounds.height, button.intrinsicContentSize.height)
      frame = NSRect(x: 0, y: (bounds.height - h) / 2, width: bounds.width, height: h)
    }
    button.frame = frame
  }

  private func applyContent() {
    let iconOnly = isIconOnly
    var shown = image
    // A bezel draws a template image in its own label colour and ignores
    // `contentTintColor`, so paint the image when the style has a colour.
    if let img = shown, img.isTemplate, button.isBordered, glassView == nil,
       let fg = styleForeground {
      shown = ImageUtils.tinted(img, with: fg)
    }
    button.image = shown
    if iconOnly {
      button.imagePosition = .imageOnly
      button.title = ""
    } else if shown != nil {
      switch imagePlacement {
      case "trailing": button.imagePosition = .imageTrailing
      case "top": button.imagePosition = .imageAbove
      case "bottom": button.imagePosition = .imageBelow
      default: button.imagePosition = .imageLeading
      }
      button.imageHugsTitle = true
    } else {
      button.imagePosition = .noImage
    }

    let text = iconOnly ? "" : (title ?? "")
    let font = labelFont
    let color = labelColor ?? styleForeground
    if !text.isEmpty, font != nil || color != nil || (imagePadding ?? 0) > 0 {
      let color = color ?? bezelForeground
      var attributes: [NSAttributedString.Key: Any] = [:]
      attributes[.font] = font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize(for: button.controlSize))
      if let color = color {
        // An attributed title keeps its colour when disabled; dim it as the
        // system does.
        attributes[.foregroundColor] = isEnabled ? color : color.withAlphaComponent(0.35)
      }
      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .center
      paragraph.lineBreakMode = .byTruncatingTail
      attributes[.paragraphStyle] = paragraph
      var string = text
      // NSButton has no image-to-title spacing; widen it with leading or
      // trailing space, as the image hugs the title.
      if shown != nil, let pad = imagePadding, pad > 0 {
        let space = String(repeating: "\u{2009}", count: max(1, Int((pad / 3).rounded())))
        switch imagePlacement {
        case "trailing": string = text + space
        case "leading": string = space + text
        default: break
        }
      }
      button.attributedTitle = NSAttributedString(string: string, attributes: attributes)
    } else {
      button.title = text
    }
    button.setAccessibilityLabel(accessibilityText)
  }

  /// The font `labelFontSize`, `labelFontFamily` and `labelFontWeight` ask
  /// for, or nil for the control's own.
  private var labelFont: NSFont? {
    guard labelFontSize != nil || labelFontFamily != nil || labelFontWeight != nil else { return nil }
    let size = labelFontSize ?? NSFont.systemFontSize(for: button.controlSize)
    // A pubspec font is registered with AppKit the first time (#142).
    if let family = labelFontFamily,
       let font = CNFontResolver.font(family: family, size: size,
                                      weight: labelFontWeight.map { Self.fontWeight($0) }) {
      return font
    }
    return NSFont.systemFont(ofSize: size, weight: Self.fontWeight(labelFontWeight))
  }

  /// AppKit's weight for Flutter's `FontWeight.value` (100–900); also takes
  /// the 0–8 index older callers sent.
  static func fontWeight(_ value: Int?) -> NSFont.Weight {
    guard var v = value else { return .regular }
    if v <= 8 { v = (v + 1) * 100 }
    switch v {
    case ..<150: return .ultraLight
    case ..<250: return .thin
    case ..<350: return .light
    case ..<450: return .regular
    case ..<550: return .medium
    case ..<650: return .semibold
    case ..<750: return .bold
    case ..<850: return .heavy
    default: return .black
    }
  }

  // MARK: - Size

  /// The size Flutter should give the button: the bezel's own size, widened
  /// so a capsule taller than the bezel's natural height keeps its content
  /// clear of the rounded ends, or the content plus `padding` when Flutter
  /// set one.
  func preferredSize() -> CGSize {
    let natural = button.intrinsicContentSize
    if isIconOnly { return CGSize(width: max(natural.width, height), height: natural.height) }
    var width = natural.width
    if Self.hasGlass, button.isBordered || glassView != nil {
      width += max(0, height - natural.height)
    }
    if paddingLeft != nil || paddingRight != nil {
      var content: CGFloat = 0
      let title = button.attributedTitle
      if title.length > 0 { content += ceil(title.size().width) }
      if let img = button.image, button.imagePosition != .noImage {
        if button.imagePosition == .imageAbove || button.imagePosition == .imageBelow {
          content = max(content, img.size.width)
        } else {
          content += img.size.width + 4
        }
      }
      width = max(content + (paddingLeft ?? 0) + (paddingRight ?? 0), height)
    }
    return CGSize(width: ceil(width), height: natural.height)
  }
}
