import Flutter
import UIKit

/// `CNProgressIndicator` on iOS: a `UIProgressView` when the progress of a
/// bar is known, else a `UIActivityIndicatorView` (iOS has no indeterminate
/// bar and no determinate circle).
class CupertinoProgressIndicatorPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let container: UIView
  private let bar = UIProgressView(progressViewStyle: .default)
  private let spinner = UIActivityIndicatorView(style: .medium)

  private var value: Double?
  private var style = "bar"
  private var tint: UIColor?
  private var controlSize = "regular"
  private var semanticLabel: String?

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: "CupertinoNativeProgressIndicator_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)

    var isDark = false
    if let dict = args as? [String: Any] {
      value = (dict["value"] as? NSNumber)?.doubleValue
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
    }

    super.init()

    container.backgroundColor = .clear
    container.overrideUserInterfaceStyle = isDark ? .dark : .light
    for view in [bar, spinner] as [UIView] {
      view.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(view)
    }
    NSLayoutConstraint.activate([
      bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      bar.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])
    spinner.hidesWhenStopped = true

    applyConfig(args as? [String: Any] ?? [:])
    apply(animated: false)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "setValue":
        self.value = (args?["value"] as? NSNumber)?.doubleValue
        self.apply(animated: (args?["animated"] as? NSNumber)?.boolValue ?? true)
        result(nil)
      case "setConfig":
        self.applyConfig(args ?? [:])
        self.apply(animated: false)
        result(nil)
      case "setBrightness":
        if let isDark = (args?["isDark"] as? NSNumber)?.boolValue {
          self.container.overrideUserInterfaceStyle = isDark ? .dark : .light
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil))
        }
      case "setInteractive", "setTransitioning":
        // A progress indicator takes no touches and draws no halo.
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  private func applyConfig(_ dict: [String: Any]) {
    if let v = dict["style"] as? String { style = v }
    if dict.keys.contains("tint") {
      tint = (dict["tint"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
    }
    if let v = dict["controlSize"] as? String { controlSize = v }
    if dict.keys.contains("semanticLabel") {
      let label = dict["semanticLabel"] as? String
      semanticLabel = (label?.isEmpty ?? true) ? nil : label
    }
    bar.progressTintColor = tint
    spinner.color = tint ?? .secondaryLabel
    spinner.style = (controlSize == "large" || controlSize == "extraLarge") ? .large : .medium
    bar.accessibilityLabel = semanticLabel
    spinner.accessibilityLabel = semanticLabel
  }

  /// Shows the bar or the spinner for the current style and value.
  private func apply(animated: Bool) {
    let showBar = style == "bar" && value != nil
    bar.isHidden = !showBar
    if showBar {
      spinner.stopAnimating()
      let progress = Float(min(max(value ?? 0, 0), 1))
      bar.setProgress(progress, animated: animated)
    } else {
      // A determinate spinner still reads its progress.
      spinner.accessibilityValue = value.map { "\(Int(($0 * 100).rounded()))%" }
      spinner.startAnimating()
    }
  }
}
