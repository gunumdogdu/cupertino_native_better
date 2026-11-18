import Flutter
import UIKit
import SwiftUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The native reference of the #170 test screen (debug builds show it).
    engineBridge.pluginRegistry.registrar(forPlugin: "CNBReferenceSearchBar")?
      .register(CNBReferenceSearchBarFactory(), withId: "CNBReferenceSearchBar")
  }
}

/// A search capsule written in plain SwiftUI, with no plugin code, that the
/// #170 test screen shows beside `CNSearchBar` (in debug builds) as the
/// native reference.
///
/// Creation params: `placeholder` (String) and `clipped` (Bool). Clipped
/// puts the glass in a background and clips it to the capsule, as
/// `CNSearchBar` did before #170; the default applies the glass to the bar
/// itself with no clip.
final class CNBReferenceSearchBarFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    CNBReferenceSearchBarView(frame: frame, args: args)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class CNBReferenceSearchBarView: NSObject, FlutterPlatformView {
  private let container: UIView
  private let host: UIHostingController<CNBReferenceSearchBar>

  init(frame: CGRect, args: Any?) {
    let dict = args as? [String: Any] ?? [:]
    container = UIView(frame: frame)
    container.backgroundColor = .clear
    host = UIHostingController(
      rootView: CNBReferenceSearchBar(
        placeholder: dict["placeholder"] as? String ?? "Search",
        clipped: dict["clipped"] as? Bool ?? false
      )
    )
    super.init()
    host.view.backgroundColor = .clear
    host.view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(host.view)
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      host.view.topAnchor.constraint(equalTo: container.topAnchor),
      host.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
  }

  func view() -> UIView { container }
}

struct CNBReferenceSearchBar: View {
  let placeholder: String
  let clipped: Bool
  @State private var text = ""

  var body: some View {
    let bar = HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.blue)
      TextField(placeholder, text: $text)
    }
    .padding(.horizontal, 12)
    .frame(height: 36)
    .frame(maxWidth: .infinity)

    if #available(iOS 26.0, *) {
      if clipped {
        bar
          .background(Color.clear.glassEffect(.regular, in: .capsule))
          .clipShape(Capsule())
      } else {
        bar.glassEffect(.regular, in: .capsule)
      }
    } else {
      bar.background(Color(.systemGray6)).clipShape(Capsule())
    }
  }
}
