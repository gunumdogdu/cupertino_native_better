import FlutterMacOS
import Cocoa
import SwiftUI

/// What the progress indicator shows; SwiftUI redraws on each change.
final class ProgressIndicatorModel: ObservableObject {
  @Published var value: Double?
  @Published var isBar = true
  @Published var tint: Color?
  @Published var controlSize: ControlSize = .regular
  @Published var label: String?
}

/// SwiftUI's `ProgressView`, which on macOS draws AppKit's
/// `NSProgressIndicator` (bar or spinning) and, unlike the AppKit control,
/// takes a tint. A bar animates value changes itself.
struct ProgressIndicatorSwiftUI: View {
  @ObservedObject var model: ProgressIndicatorModel

  var body: some View {
    indicator
      .controlSize(model.controlSize)
      .tint(model.tint)
      .modifier(OptionalAccessibilityLabel(label: model.label))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var indicator: some View {
    if let value = model.value {
      if model.isBar {
        ProgressView(value: value).progressViewStyle(.linear)
      } else {
        ProgressView(value: value).progressViewStyle(.circular)
      }
    } else if model.isBar {
      ProgressView().progressViewStyle(.linear)
    } else {
      ProgressView().progressViewStyle(.circular)
    }
  }
}

/// Sets the accessibility label only when there is one, so an indicator
/// without a `semanticLabel` keeps SwiftUI's own.
private struct OptionalAccessibilityLabel: ViewModifier {
  let label: String?

  func body(content: Content) -> some View {
    if let label = label {
      content.accessibilityLabel(Text(label))
    } else {
      content
    }
  }
}

/// `CNProgressIndicator` on macOS.
class CupertinoProgressIndicatorNSView: NSView {
  private let channel: FlutterMethodChannel
  private let model = ProgressIndicatorModel()
  private let hostingView: NSHostingView<ProgressIndicatorSwiftUI>

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: "CupertinoNativeProgressIndicator_\(viewId)", binaryMessenger: messenger)
    self.hostingView = NSHostingView(rootView: ProgressIndicatorSwiftUI(model: model))

    super.init(frame: .zero)

    let dict = args as? [String: Any] ?? [:]
    model.value = Self.clamped(dict["value"] as? NSNumber)
    applyConfig(dict)
    let isDark = (dict["isDark"] as? NSNumber)?.boolValue ?? false
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    hostingView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hostingView)
    NSLayoutConstraint.activate([
      hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
      hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
      hostingView.topAnchor.constraint(equalTo: topAnchor),
      hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "setValue":
        self.model.value = Self.clamped(args?["value"] as? NSNumber)
        result(nil)
      case "setConfig":
        self.applyConfig(args ?? [:])
        result(nil)
      case "setBrightness":
        if let isDark = (args?["isDark"] as? NSNumber)?.boolValue {
          self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil))
        }
      case "setInteractive", "setTransitioning":
        // A progress indicator takes no clicks and draws no halo.
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) { return nil }

  /// The indicator takes no clicks; they reach the Flutter view under it.
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  private func applyConfig(_ dict: [String: Any]) {
    if let style = dict["style"] as? String { model.isBar = style != "spinner" }
    if dict.keys.contains("tint") {
      model.tint = (dict["tint"] as? NSNumber).map { Color(nsColor: Self.colorFromARGB($0.intValue)) }
    }
    if let size = dict["controlSize"] as? String { model.controlSize = Self.controlSize(size) }
    if dict.keys.contains("semanticLabel") {
      let label = dict["semanticLabel"] as? String
      model.label = (label?.isEmpty ?? true) ? nil : label
    }
  }

  private static func controlSize(_ name: String) -> ControlSize {
    switch name {
    case "mini": return .mini
    case "small": return .small
    case "large": return .large
    case "extraLarge":
      if #available(macOS 14.0, *) { return .extraLarge }
      return .large
    default: return .regular
    }
  }

  private static func clamped(_ number: NSNumber?) -> Double? {
    guard let v = number?.doubleValue else { return nil }
    return min(max(v, 0), 1)
  }

  private static func colorFromARGB(_ argb: Int) -> NSColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
  }
}
