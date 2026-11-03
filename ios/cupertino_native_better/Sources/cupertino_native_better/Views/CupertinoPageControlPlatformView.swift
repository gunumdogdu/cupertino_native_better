import Flutter
import UIKit

class CupertinoPageControlPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let container: UIView
  private let pageControl: UIPageControl

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativePageControl_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)
    self.pageControl = UIPageControl(frame: .zero)

    var numberOfPages = 0
    var currentPage = 0
    var backgroundStyle = "automatic"
    var hidesForSinglePage = false
    var allowsContinuous = true
    var enabled = true
    var isDark = false
    var semanticLabel: String? = nil
    var style: [String: Any] = [:]

    if let dict = args as? [String: Any] {
      if let v = dict["numberOfPages"] as? NSNumber { numberOfPages = v.intValue }
      if let v = dict["currentPage"] as? NSNumber { currentPage = v.intValue }
      if let v = dict["backgroundStyle"] as? String { backgroundStyle = v }
      if let v = dict["hidesForSinglePage"] as? NSNumber { hidesForSinglePage = v.boolValue }
      if let v = dict["allowsContinuousInteraction"] as? NSNumber { allowsContinuous = v.boolValue }
      if let v = dict["enabled"] as? NSNumber { enabled = v.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let v = dict["semanticLabel"] as? String, !v.isEmpty { semanticLabel = v }
      if let v = dict["style"] as? [String: Any] { style = v }
    }

    super.init()

    container.backgroundColor = .clear
    container.overrideUserInterfaceStyle = isDark ? .dark : .light

    // The count first: UIPageControl clamps the page to it.
    pageControl.numberOfPages = numberOfPages
    pageControl.currentPage = currentPage
    applyOptions(backgroundStyle: backgroundStyle, hidesForSinglePage: hidesForSinglePage,
                 allowsContinuous: allowsContinuous)
    applyStyle(style)
    pageControl.isEnabled = enabled
    // What VoiceOver reads before "page 2 of 5" (`CNPageControl.semanticLabel`).
    pageControl.accessibilityLabel = semanticLabel

    // The control fills the box Flutter gives it and centres its dots; taps
    // on either side of the current dot move one page.
    pageControl.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(pageControl)
    NSLayoutConstraint.activate([
      pageControl.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      pageControl.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      pageControl.topAnchor.constraint(equalTo: container.topAnchor),
      pageControl.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])

    pageControl.addTarget(self, action: #selector(onPageChanged(_:)), for: .valueChanged)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "setNumberOfPages":
        if let n = (args?["numberOfPages"] as? NSNumber)?.intValue {
          self.pageControl.numberOfPages = n
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing numberOfPages", details: nil)) }
      case "setCurrentPage":
        if let page = (args?["currentPage"] as? NSNumber)?.intValue {
          // Setting the page does not send .valueChanged, so a page that
          // follows a PageView is not reported back as a pick.
          self.pageControl.currentPage = page
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing currentPage", details: nil)) }
      case "setOptions":
        self.applyOptions(
          backgroundStyle: args?["backgroundStyle"] as? String ?? "automatic",
          hidesForSinglePage: (args?["hidesForSinglePage"] as? NSNumber)?.boolValue ?? false,
          allowsContinuous: (args?["allowsContinuousInteraction"] as? NSNumber)?.boolValue ?? true
        )
        result(nil)
      case "setStyle":
        self.applyStyle(args ?? [:])
        result(nil)
      case "setEnabled":
        if let enabled = (args?["enabled"] as? NSNumber)?.boolValue {
          self.pageControl.isEnabled = enabled
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setSemanticLabel":
        let label = args?["label"] as? String
        self.pageControl.accessibilityLabel = (label?.isEmpty ?? true) ? nil : label
        result(nil)
      case "setBrightness":
        if let isDark = (args?["isDark"] as? NSNumber)?.boolValue {
          self.container.overrideUserInterfaceStyle = isDark ? .dark : .light
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setInteractive":
        // Issue #53 follow-up: only isUserInteractionEnabled blocks native
        // touches while a Flutter modal is up.
        if let interactive = (args?["interactive"] as? NSNumber)?.boolValue {
          self.container.isUserInteractionEnabled = interactive
          self.pageControl.isUserInteractionEnabled = interactive
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  @objc private func onPageChanged(_ sender: UIPageControl) {
    // A scrub (press and drag along the dots) reports every page it passes;
    // Dart jumps a PageView for those instead of animating it.
    channel.invokeMethod("pageChanged", arguments: [
      "page": sender.currentPage,
      "continuous": sender.interactionState == .continuous,
    ])
  }

  private func applyOptions(backgroundStyle: String, hidesForSinglePage: Bool, allowsContinuous: Bool) {
    switch backgroundStyle {
    case "prominent": pageControl.backgroundStyle = .prominent
    case "minimal": pageControl.backgroundStyle = .minimal
    default: pageControl.backgroundStyle = .automatic
    }
    pageControl.hidesForSinglePage = hidesForSinglePage
    pageControl.allowsContinuousInteraction = allowsContinuous
  }

  /// Dot colours; a missing or null value restores the system colour.
  private func applyStyle(_ style: [String: Any]) {
    pageControl.pageIndicatorTintColor =
      (style["pageIndicatorTint"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
    pageControl.currentPageIndicatorTintColor =
      (style["currentPageIndicatorTint"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
  }
}
