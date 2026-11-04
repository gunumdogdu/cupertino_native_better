import FlutterMacOS
import AppKit

class CupertinoGlassButtonGroupFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    #if compiler(>=6.2)
    if #available(macOS 26.0, *) {
      return GlassButtonGroupNSView(viewId: viewId, args: args, messenger: messenger)
    }
    #endif
    return FallbackGlassButtonGroupNSView(viewId: viewId, messenger: messenger)
  }
}
