import FlutterMacOS
import AppKit

class LiquidGlassContainerFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    // Liquid Glass on macOS 26+, the translucent material before.
    return LiquidGlassContainerNSView(viewId: viewId, args: args, messenger: messenger)
  }
}
