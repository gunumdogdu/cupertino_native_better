import Flutter
import UIKit

public class CupertinoGlassButtonGroupFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  public init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    if #available(iOS 26.0, *) {
      return GlassButtonGroupPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
    } else {
      // Fallback for iOS < 26: return a simple container view
      return FallbackGlassButtonGroupView(frame: frame, viewId: viewId, args: args, messenger: messenger)
    }
  }
}

// Fallback for iOS < 26.
//
// IMPORTANT: must register a MethodChannel handler that no-ops every
// method the Dart side might call (setTransitioning, setInteractive,
// updateButton, updateButtons, etc.). Without this handler, Flutter
// throws MissingPluginException — and several Dart paths (Issue #29
// halo containment via setTransitioning, ModalHideMixin via
// setInteractive) WILL call into this channel even on iOS < 26 because
// CN-widgets can't tell at construction time which platform-view class
// the factory picked.
class FallbackGlassButtonGroupView: NSObject, FlutterPlatformView {
  private let container: UIView
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.container = UIView(frame: frame)
    self.channel = FlutterMethodChannel(
      name: "CupertinoNativeGlassButtonGroup_\(viewId)",
      binaryMessenger: messenger
    )
    super.init()
    // No-op every call so MissingPluginException never fires.
    self.channel.setMethodCallHandler { _, result in result(nil) }
  }

  func view() -> UIView {
    return container
  }
}

