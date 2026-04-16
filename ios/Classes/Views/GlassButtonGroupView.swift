import SwiftUI
import UIKit
import Flutter

@available(iOS 26.0, *)
class GlassButtonGroupViewModel: ObservableObject {
  @Published var buttons: [GlassButtonData] = []
  @Published var axis: Axis = .horizontal
  @Published var spacing: CGFloat = 8.0
  @Published var spacingForGlass: CGFloat = 40.0

  func updateButton(at index: Int, with buttonData: GlassButtonData) {
    guard index >= 0 && index < buttons.count else { return }
    buttons[index] = buttonData
  }

  func updateButtons(_ newButtons: [GlassButtonData]) {
    buttons = newButtons
  }
}

@available(iOS 26.0, *)
struct GlassButtonGroupSwiftUI: View {
  @ObservedObject var viewModel: GlassButtonGroupViewModel
  @Namespace private var namespace

  /// Barres horizontales avec plusieurs boutons : spacingForGlass plus élevé
  /// pour que le blend démarre plus tôt et réduise le rétrécissement entre icônes.
  private var effectiveSpacingForGlass: CGFloat {
    if viewModel.axis == .horizontal, viewModel.buttons.count >= 2 {
      return max(viewModel.spacingForGlass, 80)
    }
    return viewModel.spacingForGlass
  }

  @ViewBuilder
  private func buttonView(for button: GlassButtonData) -> some View {
    let baseButton = GlassButtonSwiftUI(
      title: button.title,
      iconName: button.iconName,
      iconImage: button.iconImage,
      iconSize: button.iconSize,
      iconColor: button.iconColor,
      tint: button.tint,
      isRound: button.isRound,
      style: button.style,
      isEnabled: button.isEnabled,
      isInteractive: button.isInteractive,
      onPressed: button.isPopup ? {} : button.onPressed,
      glassEffectUnionId: button.glassEffectUnionId,
      glassEffectId: button.glassEffectId,
      glassEffectInteractive: button.glassEffectInteractive,
      namespace: namespace,
      config: button.config,
      badgeCount: nil
    )
    if button.isPopup, let labels = button.menuLabels, !labels.isEmpty, let onSelected = button.onMenuSelected {
      Menu {
        ForEach(Array(labels.enumerated()), id: \.offset) { idx, label in
          Button {
            onSelected(idx)
          } label: {
            if idx < (button.menuSfSymbols?.count ?? 0), let sym = button.menuSfSymbols?[idx], !sym.isEmpty {
              Label(label, systemImage: sym)
            } else {
              Text(label)
            }
          }
        }
      } label: {
        baseButton
      }
      .menuStyle(.borderlessButton)
    } else {
      baseButton
    }
  }

  var body: some View {
    GlassEffectContainer(spacing: effectiveSpacingForGlass) {
      if viewModel.axis == .horizontal {
        HStack(alignment: .center, spacing: viewModel.spacing) {
          ForEach(Array(viewModel.buttons.enumerated()), id: \.offset) { index, button in
            buttonView(for: button)
              .fixedSize(horizontal: true, vertical: false)
          }
        }
        .frame(minHeight: 0, maxHeight: .infinity, alignment: .center)
      } else {
        VStack(alignment: .center, spacing: viewModel.spacing) {
          ForEach(Array(viewModel.buttons.enumerated()), id: \.offset) { index, button in
            buttonView(for: button)
              .fixedSize(horizontal: true, vertical: false)
          }
        }
        .frame(minHeight: 0, maxHeight: .infinity, alignment: .center)
      }
    }
    .frame(minHeight: 0, maxHeight: .infinity, alignment: .center)
    .ignoresSafeArea()
  }
}

// UIKit badge view - renders ABOVE SwiftUI to avoid glass effect sampling
@available(iOS 26.0, *)
class UIKitBadgeView: UIView {
  private let label = UILabel()
  private var count: Int = 0
  private var widthConstraint: NSLayoutConstraint?
  private var heightConstraint: NSLayoutConstraint?

  init(count: Int) {
    self.count = count
    super.init(frame: .zero)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup() {
    // Configure badge appearance
    backgroundColor = .systemRed

    // Configure label
    label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
    label.textColor = .white
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    addSubview(label)

    // Label constraints - centered with padding
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: centerXAnchor),
      label.centerYAnchor.constraint(equalTo: centerYAnchor),
      label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
      label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4)
    ])

    translatesAutoresizingMaskIntoConstraints = false
    updateCount(count)
  }

  func updateCount(_ newCount: Int) {
    count = newCount
    label.text = count > 99 ? "99+" : "\(count)"
    isHidden = count <= 0

    // Remove old constraints
    widthConstraint?.isActive = false
    heightConstraint?.isActive = false

    // Calculate size based on count
    let textSize = label.intrinsicContentSize
    let badgeSize: CGSize

    if count <= 9 {
      // Single digit - perfect circle
      let diameter: CGFloat = 18
      badgeSize = CGSize(width: diameter, height: diameter)
    } else {
      // Multiple digits - pill shape
      let width = max(textSize.width + 8, 18)
      badgeSize = CGSize(width: width, height: 18)
    }

    // Apply size constraints
    widthConstraint = widthAnchor.constraint(equalToConstant: badgeSize.width)
    heightConstraint = heightAnchor.constraint(equalToConstant: badgeSize.height)
    widthConstraint?.isActive = true
    heightConstraint?.isActive = true

    // Update corner radius to make it circular/pill-shaped
    layer.cornerRadius = badgeSize.height / 2

    // Shadow setup
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = 0.2
    layer.shadowOffset = CGSize(width: 0, height: 1)
    layer.shadowRadius = 2
    layer.masksToBounds = false

    setNeedsLayout()
  }
}

@available(iOS 26.0, *)
struct GlassButtonData: Identifiable {
  let id = UUID()
  let title: String?
  let iconName: String?
  let iconImage: UIImage?
  let iconSize: CGFloat
  let iconColor: Color?
  let tint: Color?
  let isRound: Bool
  let style: String
  let isEnabled: Bool
  let isInteractive: Bool
  let onPressed: () -> Void
  let glassEffectUnionId: String?
  let glassEffectId: String?
  let glassEffectInteractive: Bool
  let config: GlassButtonConfig
  let badgeCount: Int?
  let menuLabels: [String]?
  let menuSfSymbols: [String]?
  let onMenuSelected: ((Int) -> Void)?
  
  var isPopup: Bool {
    guard let labels = menuLabels, !labels.isEmpty else { return false }
    return onMenuSelected != nil
  }
}

@available(iOS 26.0, *)
class GlassButtonGroupPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView
  private let hostingController: UIHostingController<GlassButtonGroupSwiftUI>
  private var buttonCallbacks: [Int: (() -> Void)] = [:]
  private let viewModel: GlassButtonGroupViewModel
  private let channel: FlutterMethodChannel
  private var badgeViews: [UIKitBadgeView] = []
  private var axis: Axis = .horizontal
  private var spacing: CGFloat = 8.0
  
  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    // Initialize container with frame provided by Flutter
    // Flutter manages the frame position and size
    self.container = UIView(frame: frame)
    self.container.backgroundColor = .clear
    self.container.isOpaque = false
    // Issue #29: clip the container so the iOS 26 Liquid Glass material
    // does not render a halo outside the platform-view bounds during route
    // transitions. The UIKit badges (added in `updateBadgePositions`) sit
    // at y=0 inside the container, so clipping does not crop their tops.
    // Their X position math is a separate pre-existing layout issue (the
    // calculation assumes buttons span container width, but the SwiftUI
    // HStack is centered) — that is intentionally not fixed here.
    self.container.clipsToBounds = true
    self.container.layer.backgroundColor = UIColor.clear.cgColor
    self.container.layer.shadowOpacity = 0
    // Remove any default layout margins that could cause offset
    if #available(iOS 11.0, *) {
      self.container.insetsLayoutMarginsFromSafeArea = false
      self.container.layoutMargins = .zero
      self.container.directionalLayoutMargins = .zero
    }
    // Note: Flutter manages the container's frame directly, so we don't set
    // translatesAutoresizingMaskIntoConstraints on the container
    
    var buttons: [GlassButtonData] = []
    var axis: Axis = .horizontal
    var spacing: CGFloat = 8.0
    var spacingForGlass: CGFloat = 40.0
    var isDark: Bool = false
    
    // Set up method channel for button callbacks and updates
    let channel = FlutterMethodChannel(name: "CupertinoNativeGlassButtonGroup_\(viewId)", binaryMessenger: messenger)
    self.channel = channel
    
    // Create view model
    let viewModel = GlassButtonGroupViewModel()
    self.viewModel = viewModel
    
    if let dict = args as? [String: Any] {
      if let isDarkBool = dict["isDark"] as? Bool {
        isDark = isDarkBool
      }
      if let buttonsData = dict["buttons"] as? [[String: Any]] {
        for (index, buttonDict) in buttonsData.enumerated() {
          let title = buttonDict["label"] as? String
          let iconName = buttonDict["iconName"] as? String
          let iconSize = (buttonDict["iconSize"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 20.0
          let iconColorARGB = (buttonDict["iconColor"] as? NSNumber)?.intValue
          let iconColor = iconColorARGB.map { Color(uiColor: Self.colorFromARGB($0)) }
          let tint = (buttonDict["tint"] as? NSNumber).map { Color(uiColor: Self.colorFromARGB($0.intValue)) }
          let isEnabled = (buttonDict["enabled"] as? NSNumber)?.boolValue ?? true
          let isInteractive = (buttonDict["interaction"] as? NSNumber)?.boolValue ?? true
          let style = buttonDict["style"] as? String ?? "glass"
          let glassEffectUnionId = buttonDict["glassEffectUnionId"] as? String
          let glassEffectId = buttonDict["glassEffectId"] as? String
          let glassEffectInteractive = (buttonDict["glassEffectInteractive"] as? NSNumber)?.boolValue ?? false
          let badgeCount = (buttonDict["badgeCount"] as? NSNumber)?.intValue

          // Load image from asset path, bytes, or icon bytes
          var iconImage: UIImage? = nil
          
          // Try asset path first
          if let assetPath = buttonDict["assetPath"] as? String, !assetPath.isEmpty {
            let format = buttonDict["imageFormat"] as? String
            let size = CGSize(width: iconSize, height: iconSize)
            
            // Use utility function to load and optionally tint image
            if let argb = iconColorARGB, #available(iOS 13.0, *) {
              iconImage = ImageUtils.loadAndTintImage(
                from: assetPath,
                iconSize: iconSize,
                iconColor: argb,
                providedFormat: format,
                scale: UIScreen.main.scale
              )
            } else {
              iconImage = ImageUtils.loadFlutterAsset(assetPath, size: size, format: format, scale: UIScreen.main.scale)
            }
            
            // If no color but size is specified, scale the image
            if iconImage != nil, iconColorARGB == nil, iconImage!.size != size {
              iconImage = ImageUtils.scaleImage(iconImage!, to: size, scale: UIScreen.main.scale)
            }
          }
          
          // Fallback to imageBytes if assetPath failed or wasn't provided
          if iconImage == nil, let imageBytes = buttonDict["imageBytes"] as? FlutterStandardTypedData {
            let format = buttonDict["imageFormat"] as? String
            let size = CGSize(width: iconSize, height: iconSize)
            
            // Use utility function to create and optionally tint image
            if let argb = iconColorARGB, #available(iOS 13.0, *) {
              iconImage = ImageUtils.createAndTintImage(
                from: imageBytes.data,
                iconSize: iconSize,
                iconColor: argb,
                providedFormat: format,
                scale: UIScreen.main.scale
              )
            } else {
              iconImage = ImageUtils.createImageFromData(imageBytes.data, format: format, size: size, scale: UIScreen.main.scale)
            }
          }
          
          // Fallback to iconBytes if both assetPath and imageBytes failed
          if iconImage == nil, let iconBytes = buttonDict["iconBytes"] as? FlutterStandardTypedData {
            // iconBytes are typically PNG data from IconData rendering
            let size = CGSize(width: iconSize, height: iconSize)
            iconImage = ImageUtils.createImageFromData(iconBytes.data, format: "png", size: size, scale: UIScreen.main.scale)
          }
          
          // Create callback for this button
          let buttonIndex = index
          let menuLabels = buttonDict["menuLabels"] as? [String]
          let menuSfSymbols = buttonDict["menuSfSymbols"] as? [String]
          let isPopup = (menuLabels != nil && !(menuLabels?.isEmpty ?? true))
          
          let buttonCallback: () -> Void
          var onMenuSelected: ((Int) -> Void)? = nil
          if isPopup, let labels = menuLabels {
            onMenuSelected = { selectedIndex in
              channel.invokeMethod("buttonPressed", arguments: ["index": buttonIndex, "selectedIndex": selectedIndex], result: nil)
            }
            buttonCallback = {}
          } else {
            buttonCallback = {
              channel.invokeMethod("buttonPressed", arguments: ["index": buttonIndex], result: nil)
            }
          }
          buttonCallbacks[buttonIndex] = buttonCallback
          
          // Determine if button should be round based on style or if it's icon-only
          let isRound = (title == nil && iconName != nil) || (title == nil && iconImage != nil)
          
          // Extract config parameters from button dict
          let borderRadius = (buttonDict["borderRadius"] as? NSNumber).map { CGFloat(truncating: $0) }
          let paddingTop = (buttonDict["paddingTop"] as? NSNumber).map { CGFloat(truncating: $0) }
          let paddingBottom = (buttonDict["paddingBottom"] as? NSNumber).map { CGFloat(truncating: $0) }
          let paddingLeft = (buttonDict["paddingLeft"] as? NSNumber).map { CGFloat(truncating: $0) }
          let paddingRight = (buttonDict["paddingRight"] as? NSNumber).map { CGFloat(truncating: $0) }
          let paddingHorizontal = (buttonDict["paddingHorizontal"] as? NSNumber).map { CGFloat(truncating: $0) }
          let paddingVertical = (buttonDict["paddingVertical"] as? NSNumber).map { CGFloat(truncating: $0) }
          let minHeight = (buttonDict["minHeight"] as? NSNumber).map { CGFloat(truncating: $0) }
          let spacing = (buttonDict["imagePadding"] as? NSNumber).map { CGFloat(truncating: $0) }

          // Create GlassButtonConfig with provided values or defaults
          let config = GlassButtonConfig(
            borderRadius: borderRadius,
            top: paddingTop,
            bottom: paddingBottom,
            left: paddingLeft,
            right: paddingRight,
            horizontal: paddingHorizontal,
            vertical: paddingVertical,
            minHeight: minHeight ?? 44.0,
            spacing: spacing ?? 8.0
          )
          
          let buttonData = GlassButtonData(
            title: title,
            iconName: iconName,
            iconImage: iconImage,
            iconSize: iconSize,
            iconColor: iconColor,
            tint: tint,
            isRound: isRound,
            style: style,
            isEnabled: isEnabled,
            isInteractive: isInteractive,
            onPressed: buttonCallback,
            glassEffectUnionId: glassEffectUnionId,
            glassEffectId: glassEffectId,
            glassEffectInteractive: glassEffectInteractive,
            config: config,
            badgeCount: badgeCount,
            menuLabels: menuLabels,
            menuSfSymbols: menuSfSymbols,
            onMenuSelected: onMenuSelected
          )
          buttons.append(buttonData)
        }
      }
      
      if let axisStr = dict["axis"] as? String {
        axis = axisStr == "horizontal" ? .horizontal : .vertical
      }
      if let spacingValue = dict["spacing"] as? NSNumber {
        spacing = CGFloat(truncating: spacingValue)
      }
      if let spacingForGlassValue = dict["spacingForGlass"] as? NSNumber {
        spacingForGlass = CGFloat(truncating: spacingForGlassValue)
      }
    }

    // Update view model with initial values
    viewModel.buttons = buttons
    viewModel.axis = axis
    viewModel.spacing = spacing
    viewModel.spacingForGlass = spacingForGlass

    let swiftUIView = GlassButtonGroupSwiftUI(viewModel: viewModel)

    self.hostingController = UIHostingController(rootView: swiftUIView)

    self.hostingController.view.backgroundColor = .clear
    self.hostingController.view.isOpaque = false
    self.hostingController.view.layer.backgroundColor = UIColor.clear.cgColor
    // Configure hosting controller to ignore safe areas and remove any padding
    if #available(iOS 11.0, *) {
      self.hostingController.view.insetsLayoutMarginsFromSafeArea = false
      self.hostingController.view.layoutMargins = .zero
      self.hostingController.view.directionalLayoutMargins = .zero
      // Ignore safe area insets completely
      self.hostingController.additionalSafeAreaInsets = .zero
    }
    
    super.init()
    
    // Sync Flutter's brightness mode with Swift at initialization
    if #available(iOS 13.0, *) {
      self.hostingController.overrideUserInterfaceStyle = isDark ? .dark : .light
    }
    
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(hostingController.view)

    // Position hosting controller to leave room for badge overflow
    // - 3px down from top (badge extends above buttons)
    // - 0px from left (no left overflow)
    // - 6px inset from right (badge extends 6px beyond last button)
    // This ensures badges are positioned within container bounds for proper clipping.
    //
    // Priority is .defaultHigh (750) instead of required (1000) so UIKit can
    // silently break them during the brief moment when the parent container
    // has `_UITemporaryLayoutWidth = 0` on initial mount. With required
    // priority UIKit logs an "unsatisfiable constraints" warning every time.
    let leading = hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0)
    let trailing = hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6)
    let top = hostingController.view.topAnchor.constraint(equalTo: container.topAnchor, constant: 3)
    let bottom = hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 0)
    leading.priority = .defaultHigh
    trailing.priority = .defaultHigh
    top.priority = .defaultHigh
    bottom.priority = .defaultHigh
    NSLayoutConstraint.activate([leading, trailing, top, bottom])

    // Force immediate layout to ensure SwiftUI view calculates sizes correctly on first render
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()

    // Store axis and spacing for badge positioning
    self.axis = axis
    self.spacing = spacing

    // Observe frame changes to force layout updates
    container.addObserver(self, forKeyPath: "frame", options: [.new, .old], context: nil)
    container.addObserver(self, forKeyPath: "bounds", options: [.new, .old], context: nil)

    // Create and add UIKit badge views
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      self?.updateBadgePositions()
    }

    // Set up method channel handler for updates
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      
      switch call.method {
      case "buttonPressed":
        // This is handled by button callbacks, but we can also handle it here if needed
        result(nil)
      case "updateButton":
        if let args = call.arguments as? [String: Any],
           let index = args["index"] as? Int,
           let buttonDict = args["button"] as? [String: Any] {
          self.updateButton(at: index, with: buttonDict)
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing index or button", details: nil))
        }
      case "updateButtons":
        if let args = call.arguments as? [String: Any],
           let buttonsData = args["buttons"] as? [[String: Any]] {
          self.updateButtons(buttonsData)
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing buttons", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func updateButton(at index: Int, with buttonDict: [String: Any]) {
    guard index >= 0 && index < viewModel.buttons.count else { return }
    
    let title = buttonDict["label"] as? String
    let iconName = buttonDict["iconName"] as? String
    let iconSize = (buttonDict["iconSize"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 20.0
    let iconColorARGB = (buttonDict["iconColor"] as? NSNumber)?.intValue
    let iconColor = iconColorARGB.map { Color(uiColor: Self.colorFromARGB($0)) }
    let tint = (buttonDict["tint"] as? NSNumber).map { Color(uiColor: Self.colorFromARGB($0.intValue)) }
    let isEnabled = (buttonDict["enabled"] as? NSNumber)?.boolValue ?? true
    let isInteractive = (buttonDict["interaction"] as? NSNumber)?.boolValue ?? true
    let style = buttonDict["style"] as? String ?? "glass"
    let glassEffectUnionId = buttonDict["glassEffectUnionId"] as? String
    let glassEffectId = buttonDict["glassEffectId"] as? String
    let glassEffectInteractive = (buttonDict["glassEffectInteractive"] as? NSNumber)?.boolValue ?? false
    let badgeCount = (buttonDict["badgeCount"] as? NSNumber)?.intValue

    // Load image from asset path, bytes, or icon bytes
    var iconImage: UIImage? = nil

    // Try asset path first
    if let assetPath = buttonDict["assetPath"] as? String, !assetPath.isEmpty {
      let format = buttonDict["imageFormat"] as? String
      let size = CGSize(width: iconSize, height: iconSize)
      
      if let argb = iconColorARGB, #available(iOS 13.0, *) {
        iconImage = ImageUtils.loadAndTintImage(
          from: assetPath,
          iconSize: iconSize,
          iconColor: argb,
          providedFormat: format,
          scale: UIScreen.main.scale
        )
      } else {
        iconImage = ImageUtils.loadFlutterAsset(assetPath, size: size, format: format, scale: UIScreen.main.scale)
      }
      
      if iconImage != nil, iconColorARGB == nil, iconImage!.size != size {
        iconImage = ImageUtils.scaleImage(iconImage!, to: size, scale: UIScreen.main.scale)
      }
    }
    
    // Fallback to imageBytes
    if iconImage == nil, let imageBytes = buttonDict["imageBytes"] as? FlutterStandardTypedData {
      let format = buttonDict["imageFormat"] as? String
      let size = CGSize(width: iconSize, height: iconSize)
      
      if let argb = iconColorARGB, #available(iOS 13.0, *) {
        iconImage = ImageUtils.createAndTintImage(
          from: imageBytes.data,
          iconSize: iconSize,
          iconColor: argb,
          providedFormat: format,
          scale: UIScreen.main.scale
        )
      } else {
        iconImage = ImageUtils.createImageFromData(imageBytes.data, format: format, size: size, scale: UIScreen.main.scale)
      }
    }
    
    // Fallback to iconBytes
    if iconImage == nil, let iconBytes = buttonDict["iconBytes"] as? FlutterStandardTypedData {
      let size = CGSize(width: iconSize, height: iconSize)
      iconImage = ImageUtils.createImageFromData(iconBytes.data, format: "png", size: size, scale: UIScreen.main.scale)
    }
    
    let isRound = (title == nil && iconName != nil) || (title == nil && iconImage != nil)
    
    // Extract config parameters
    let borderRadius = (buttonDict["borderRadius"] as? NSNumber).map { CGFloat(truncating: $0) }
    let paddingTop = (buttonDict["paddingTop"] as? NSNumber).map { CGFloat(truncating: $0) }
    let paddingBottom = (buttonDict["paddingBottom"] as? NSNumber).map { CGFloat(truncating: $0) }
    let paddingLeft = (buttonDict["paddingLeft"] as? NSNumber).map { CGFloat(truncating: $0) }
    let paddingRight = (buttonDict["paddingRight"] as? NSNumber).map { CGFloat(truncating: $0) }
    let paddingHorizontal = (buttonDict["paddingHorizontal"] as? NSNumber).map { CGFloat(truncating: $0) }
    let paddingVertical = (buttonDict["paddingVertical"] as? NSNumber).map { CGFloat(truncating: $0) }
    let minHeight = (buttonDict["minHeight"] as? NSNumber).map { CGFloat(truncating: $0) }
    let spacing = (buttonDict["imagePadding"] as? NSNumber).map { CGFloat(truncating: $0) }

    let config = GlassButtonConfig(
      borderRadius: borderRadius,
      top: paddingTop,
      bottom: paddingBottom,
      left: paddingLeft,
      right: paddingRight,
      horizontal: paddingHorizontal,
      vertical: paddingVertical,
      minHeight: minHeight ?? 44.0,
      spacing: spacing ?? 8.0
    )
    
    let menuLabels = buttonDict["menuLabels"] as? [String]
    let menuSfSymbols = buttonDict["menuSfSymbols"] as? [String]
    let isPopup = (menuLabels != nil && !(menuLabels?.isEmpty ?? true))
    
    let buttonCallback: () -> Void
    var onMenuSelected: ((Int) -> Void)? = nil
    if isPopup {
      onMenuSelected = { [weak self] selectedIndex in
        self?.channel.invokeMethod("buttonPressed", arguments: ["index": index, "selectedIndex": selectedIndex], result: nil)
      }
      buttonCallback = {}
    } else {
      buttonCallback = buttonCallbacks[index] ?? { [weak self] in
        self?.channel.invokeMethod("buttonPressed", arguments: ["index": index], result: nil)
      }
    }
    buttonCallbacks[index] = buttonCallback
    
    let buttonData = GlassButtonData(
      title: title,
      iconName: iconName,
      iconImage: iconImage,
      iconSize: iconSize,
      iconColor: iconColor,
      tint: tint,
      isRound: isRound,
      style: style,
      isEnabled: isEnabled,
      isInteractive: isInteractive,
      onPressed: buttonCallback,
      glassEffectUnionId: glassEffectUnionId,
      glassEffectId: glassEffectId,
      glassEffectInteractive: glassEffectInteractive,
      config: config,
      badgeCount: badgeCount,
      menuLabels: menuLabels,
      menuSfSymbols: menuSfSymbols,
      onMenuSelected: onMenuSelected
    )

    viewModel.updateButton(at: index, with: buttonData)

    // Update badges after button update
    DispatchQueue.main.async { [weak self] in
      self?.updateBadgePositions()
    }
  }

  private func updateButtons(_ buttonsData: [[String: Any]]) {
    var newButtons: [GlassButtonData] = []

    for (index, buttonDict) in buttonsData.enumerated() {
      let title = buttonDict["label"] as? String
      let iconName = buttonDict["iconName"] as? String
      let iconSize = (buttonDict["iconSize"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 20.0
      let iconColorARGB = (buttonDict["iconColor"] as? NSNumber)?.intValue
      let iconColor = iconColorARGB.map { Color(uiColor: Self.colorFromARGB($0)) }
      let tint = (buttonDict["tint"] as? NSNumber).map { Color(uiColor: Self.colorFromARGB($0.intValue)) }
      let isEnabled = (buttonDict["enabled"] as? NSNumber)?.boolValue ?? true
      let isInteractive = (buttonDict["interaction"] as? NSNumber)?.boolValue ?? true
      let style = buttonDict["style"] as? String ?? "glass"
      let glassEffectUnionId = buttonDict["glassEffectUnionId"] as? String
      let glassEffectId = buttonDict["glassEffectId"] as? String
      let glassEffectInteractive = (buttonDict["glassEffectInteractive"] as? NSNumber)?.boolValue ?? false
      let badgeCount = (buttonDict["badgeCount"] as? NSNumber)?.intValue

      var iconImage: UIImage? = nil

      if let assetPath = buttonDict["assetPath"] as? String, !assetPath.isEmpty {
        let format = buttonDict["imageFormat"] as? String
        let size = CGSize(width: iconSize, height: iconSize)
        
        if let argb = iconColorARGB, #available(iOS 13.0, *) {
          iconImage = ImageUtils.loadAndTintImage(
            from: assetPath,
            iconSize: iconSize,
            iconColor: argb,
            providedFormat: format,
            scale: UIScreen.main.scale
          )
        } else {
          iconImage = ImageUtils.loadFlutterAsset(assetPath, size: size, format: format, scale: UIScreen.main.scale)
        }
        
        if iconImage != nil, iconColorARGB == nil, iconImage!.size != size {
          iconImage = ImageUtils.scaleImage(iconImage!, to: size, scale: UIScreen.main.scale)
        }
      }
      
      if iconImage == nil, let imageBytes = buttonDict["imageBytes"] as? FlutterStandardTypedData {
        let format = buttonDict["imageFormat"] as? String
        let size = CGSize(width: iconSize, height: iconSize)
        
        if let argb = iconColorARGB, #available(iOS 13.0, *) {
          iconImage = ImageUtils.createAndTintImage(
            from: imageBytes.data,
            iconSize: iconSize,
            iconColor: argb,
            providedFormat: format,
            scale: UIScreen.main.scale
          )
        } else {
          iconImage = ImageUtils.createImageFromData(imageBytes.data, format: format, size: size, scale: UIScreen.main.scale)
        }
      }
      
      if iconImage == nil, let iconBytes = buttonDict["iconBytes"] as? FlutterStandardTypedData {
        let size = CGSize(width: iconSize, height: iconSize)
        iconImage = ImageUtils.createImageFromData(iconBytes.data, format: "png", size: size, scale: UIScreen.main.scale)
      }
      
      let buttonIndex = index
      let menuLabels = buttonDict["menuLabels"] as? [String]
      let menuSfSymbols = buttonDict["menuSfSymbols"] as? [String]
      let isPopup = (menuLabels != nil && !(menuLabels?.isEmpty ?? true))
      
      let buttonCallback: () -> Void
      var onMenuSelected: ((Int) -> Void)? = nil
      if isPopup {
        onMenuSelected = { selectedIndex in
          self.channel.invokeMethod("buttonPressed", arguments: ["index": buttonIndex, "selectedIndex": selectedIndex], result: nil)
        }
        buttonCallback = {}
      } else {
        buttonCallback = {
          self.channel.invokeMethod("buttonPressed", arguments: ["index": buttonIndex], result: nil)
        }
      }
      buttonCallbacks[buttonIndex] = buttonCallback
      
      let isRound = (title == nil && iconName != nil) || (title == nil && iconImage != nil)
      
      let borderRadius = (buttonDict["borderRadius"] as? NSNumber).map { CGFloat(truncating: $0) }
      let paddingTop = (buttonDict["paddingTop"] as? NSNumber).map { CGFloat(truncating: $0) }
      let paddingBottom = (buttonDict["paddingBottom"] as? NSNumber).map { CGFloat(truncating: $0) }
      let paddingLeft = (buttonDict["paddingLeft"] as? NSNumber).map { CGFloat(truncating: $0) }
      let paddingRight = (buttonDict["paddingRight"] as? NSNumber).map { CGFloat(truncating: $0) }
      let paddingHorizontal = (buttonDict["paddingHorizontal"] as? NSNumber).map { CGFloat(truncating: $0) }
      let paddingVertical = (buttonDict["paddingVertical"] as? NSNumber).map { CGFloat(truncating: $0) }
      let minHeight = (buttonDict["minHeight"] as? NSNumber).map { CGFloat(truncating: $0) }
      let spacing = (buttonDict["imagePadding"] as? NSNumber).map { CGFloat(truncating: $0) }

      let config = GlassButtonConfig(
        borderRadius: borderRadius,
        top: paddingTop,
        bottom: paddingBottom,
        left: paddingLeft,
        right: paddingRight,
        horizontal: paddingHorizontal,
        vertical: paddingVertical,
        minHeight: minHeight ?? 44.0,
        spacing: spacing ?? 8.0
      )
      
      let buttonData = GlassButtonData(
        title: title,
        iconName: iconName,
        iconImage: iconImage,
        iconSize: iconSize,
        iconColor: iconColor,
        tint: tint,
        isRound: isRound,
        style: style,
        isEnabled: isEnabled,
        isInteractive: isInteractive,
        onPressed: buttonCallback,
        glassEffectUnionId: glassEffectUnionId,
        glassEffectId: glassEffectId,
        glassEffectInteractive: glassEffectInteractive,
        config: config,
        badgeCount: badgeCount,
        menuLabels: menuLabels,
        menuSfSymbols: menuSfSymbols,
        onMenuSelected: onMenuSelected
      )
      newButtons.append(buttonData)
    }

    viewModel.updateButtons(newButtons)

    // Update badges after buttons update
    DispatchQueue.main.async { [weak self] in
      self?.updateBadgePositions()
    }
  }

  func view() -> UIView {
    return container
  }
  
  private func updateBadgePositions() {
    // Remove existing badge views
    badgeViews.forEach { $0.removeFromSuperview() }
    badgeViews.removeAll()

    let buttons = viewModel.buttons
    guard !buttons.isEmpty else { return }

    let containerBounds = container.bounds
    let buttonCount = buttons.count

    // Estimate each button's rendered width based on its content + the
    // GlassButtonConfig's minHeight (capsule buttons stay >= minHeight wide).
    // The previous implementation divided the container width evenly across
    // buttons, which placed the last badge near the screen edge whenever the
    // SwiftUI HStack was centered as a tight pill instead of stretched.
    func estimatedWidth(for button: GlassButtonData) -> CGFloat {
      let padding = button.config.padding
      let horizontalPadding = padding.leading + padding.trailing
      var contentWidth: CGFloat = 0
      if let title = button.title, !title.isEmpty {
        // Approximate using the system body font; SwiftUI may render slightly
        // differently but this is close enough for badge positioning.
        let font = UIFont.systemFont(ofSize: 17)
        let textSize = (title as NSString).size(withAttributes: [.font: font])
        contentWidth = textSize.width
        if button.iconImage != nil || (button.iconName?.isEmpty == false) {
          contentWidth += button.iconSize + button.config.spacing
        }
      } else {
        contentWidth = button.iconSize
      }
      let intrinsic = contentWidth + horizontalPadding
      return max(intrinsic, button.config.minHeight)
    }

    if axis == .horizontal {
      let widths = buttons.map(estimatedWidth)
      let spacing = viewModel.spacing
      let hstackWidth = widths.reduce(0, +) + spacing * CGFloat(buttonCount - 1)
      // Hosting view is inset 6pt from container's trailing edge; HStack is
      // centered inside that.
      let hostingWidth = containerBounds.width - 6
      let hstackStart = max(0, (hostingWidth - hstackWidth) / 2)

      var cursor: CGFloat = hstackStart
      for (index, button) in buttons.enumerated() {
        let buttonWidth = widths[index]
        let buttonRight = cursor + buttonWidth
        defer { cursor += buttonWidth + spacing }

        guard let badgeCount = button.badgeCount, badgeCount > 0 else { continue }

        let badgeView = UIKitBadgeView(count: badgeCount)
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(badgeView)

        // Badge sits at button's top-right corner with slight inward overlap
        // so it visually attaches to the button corner.
        let badgeX = buttonRight - 12
        let badgeY: CGFloat = 0

        NSLayoutConstraint.activate([
          badgeView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: badgeX),
          badgeView.topAnchor.constraint(equalTo: container.topAnchor, constant: badgeY)
        ])

        badgeViews.append(badgeView)
        _ = index
      }
    } else {
      // Vertical layout — same approach: estimate heights, center the VStack
      // inside the hosting view, then place the badge at each button's
      // top-right corner.
      let heights = buttons.map { _ in CGFloat(44.0) } // minHeight default; vertical buttons rarely vary in height
      let spacing = viewModel.spacing
      let vstackHeight = heights.reduce(0, +) + spacing * CGFloat(buttonCount - 1)
      let hostingHeight = containerBounds.height
      let vstackStart = max(0, (hostingHeight - vstackHeight) / 2)
      let badgeX = containerBounds.width - 12 - 6

      var cursor: CGFloat = vstackStart
      for (index, button) in buttons.enumerated() {
        let buttonHeight = heights[index]
        defer { cursor += buttonHeight + spacing }

        guard let badgeCount = button.badgeCount, badgeCount > 0 else { continue }

        let badgeView = UIKitBadgeView(count: badgeCount)
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(badgeView)

        let badgeY = cursor

        NSLayoutConstraint.activate([
          badgeView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: badgeX),
          badgeView.topAnchor.constraint(equalTo: container.topAnchor, constant: badgeY)
        ])

        badgeViews.append(badgeView)
        _ = index
      }
    }
  }

  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if keyPath == "frame" || keyPath == "bounds" {
      if let container = object as? UIView, container === self.container {
        // Force layout update when container frame changes
        // This ensures the hosting controller view's constraints are reapplied
        DispatchQueue.main.async { [weak self] in
          guard let self = self else { return }
          self.container.setNeedsLayout()
          self.container.layoutIfNeeded()
          self.hostingController.view.setNeedsLayout()
          self.hostingController.view.layoutIfNeeded()

          // Update badge positions on layout change
          self.updateBadgePositions()

          // Force another update cycle for proper rendering
          DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hostingController.view.setNeedsDisplay()
            self.hostingController.view.setNeedsLayout()
            self.hostingController.view.layoutIfNeeded()
          }
        }
      }
    } else {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
  }

  deinit {
    badgeViews.forEach { $0.removeFromSuperview() }
    container.removeObserver(self, forKeyPath: "frame")
    container.removeObserver(self, forKeyPath: "bounds")
  }
  
  // Use shared utility functions
  private static func colorFromARGB(_ argb: Int) -> UIColor {
    return ImageUtils.colorFromARGB(argb)
  }
}

