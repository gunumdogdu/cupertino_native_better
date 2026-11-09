import Flutter
import UIKit

/// `CNContextMenu(showsPreview: true)` on iOS: a clear view laid over the
/// child with a real `UIContextMenuInteraction`, so a long press lifts a
/// picture of the child above the blurred screen with the menu beside it,
/// as in Photos or Messages (#138).
///
/// A menu opened from code is a button menu, which UIKit never shows with a
/// preview; only an interaction that gets the touch itself does. Flutter
/// hands the touch over once its long-press recognizer on this view wins,
/// so a tap still reaches the child under it.
///
/// Channel `CNContextMenuPreview_<id>`:
/// - Dart → native: `setMenu {menu}` (encoded by `encodePopupMenuEntries`),
///   `setPreview {png}` (the child, drawn when the finger goes down),
///   `setBrightness {isDark}`, `setCornerRadius {radius}`.
/// - native → Dart: `selected {path}`, `opened`, `closed`.
final class CNContextMenuPreviewPlatformView: NSObject, FlutterPlatformView, UIContextMenuInteractionDelegate {
  private let channel: FlutterMethodChannel
  private let container: UIView
  /// The picture of the child, shown only while the menu is up: UIKit
  /// lifts it, and Flutter's own child is under it the rest of the time.
  private let previewImage = UIImageView()
  private var menuLevel: PopupMenuLevel?
  private var cornerRadius: CGFloat = 12

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "CNContextMenuPreview_\(viewId)", binaryMessenger: messenger)
    container = UIView(frame: frame)
    super.init()
    let dict = args as? [String: Any] ?? [:]
    if let r = dict["cornerRadius"] as? NSNumber { cornerRadius = CGFloat(r.doubleValue) }
    if let isDark = dict["isDark"] as? Bool { container.overrideUserInterfaceStyle = isDark ? .dark : .light }

    container.backgroundColor = .clear
    // The child under it is what VoiceOver reads.
    container.isAccessibilityElement = false
    container.accessibilityElementsHidden = true
    previewImage.frame = container.bounds
    previewImage.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    previewImage.contentMode = .scaleToFill
    previewImage.alpha = 0
    previewImage.isUserInteractionEnabled = false
    container.addSubview(previewImage)
    container.addInteraction(UIContextMenuInteraction(delegate: self))

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "setMenu":
        self.menuLevel = (args?["menu"] as? [String: Any]).map { PopupMenuLevel(dict: $0) }
        result(nil)
      case "setPreview":
        if let data = args?["png"] as? FlutterStandardTypedData, let image = UIImage(data: data.data) {
          let width = self.container.bounds.width
          let scale = width > 0 ? image.size.width / width : UIScreen.main.scale
          self.previewImage.image = image.cgImage.map {
            UIImage(cgImage: $0, scale: max(scale, 1), orientation: .up)
          } ?? image
        }
        result(nil)
      case "setCornerRadius":
        if let r = args?["radius"] as? NSNumber { self.cornerRadius = CGFloat(r.doubleValue) }
        result(nil)
      case "setBrightness":
        if let isDark = args?["isDark"] as? Bool {
          self.container.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  // MARK: - UIContextMenuInteractionDelegate

  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    configurationForMenuAtLocation location: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard let level = menuLevel else { return nil }
    let scale = container.window?.screen.scale ?? UIScreen.main.scale
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
      let children = PopupMenuBuilder.elements(level: level, iconScale: scale) { path in
        self?.channel.invokeMethod("selected", arguments: ["path": path])
      }
      return UIMenu(title: "", children: children)
    }
  }

  private func targetedPreview() -> UITargetedPreview? {
    guard previewImage.image != nil, container.window != nil else { return nil }
    previewImage.alpha = 1
    let parameters = UIPreviewParameters()
    parameters.backgroundColor = .clear
    parameters.visiblePath = UIBezierPath(roundedRect: previewImage.bounds, cornerRadius: cornerRadius)
    return UITargetedPreview(view: previewImage, parameters: parameters)
  }

  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
  ) -> UITargetedPreview? {
    targetedPreview()
  }

  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
  ) -> UITargetedPreview? {
    targetedPreview()
  }

  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    willDisplayMenuFor configuration: UIContextMenuConfiguration,
    animator: UIContextMenuInteractionAnimating?
  ) {
    channel.invokeMethod("opened", arguments: nil)
  }

  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    willEndFor configuration: UIContextMenuConfiguration,
    animator: UIContextMenuInteractionAnimating?
  ) {
    let done = { [weak self] in
      self?.previewImage.alpha = 0
      self?.channel.invokeMethod("closed", arguments: nil)
    }
    if let animator { animator.addCompletion(done) } else { done() }
  }
}

final class CNContextMenuPreviewViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    CNContextMenuPreviewPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }
}
