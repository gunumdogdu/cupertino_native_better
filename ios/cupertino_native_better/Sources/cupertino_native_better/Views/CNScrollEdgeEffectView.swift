import Flutter
import UIKit

/// `CNScrollEdgeEffect` (#150): the system scroll edge effect of iOS 26 over
/// Flutter content.
///
/// Flutter content isn't in a `UIScrollView`, so this view carries a clear
/// one of its own with its top or bottom edge effect on. A
/// `UIScrollEdgeElementContainerInteraction` on a text element (a label with
/// a space) shapes the effect to the band Flutter asks for: the effect
/// follows text-like elements, and reaches about 10 pt past them, so the view
/// is a little taller than the band. The system draws the effect over
/// whatever is behind the view, which is the Flutter content.
///
/// The effect shows while content is under the edge, as in a scroll view.
/// Flutter mirrors how far its content is under the edge (`underneath`); the
/// clear content of this scroll view is placed that far under the band, so
/// the system decides when to show it.
final class CNScrollEdgeEffectFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    CNScrollEdgeEffectPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }
}

final class CNScrollEdgeEffectPlatformView: NSObject, FlutterPlatformView {
  private let host: CNScrollEdgeEffectHost
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    let dict = (args as? [String: Any]) ?? [:]
    host = CNScrollEdgeEffectHost(frame: frame, bottom: (dict["edge"] as? String) == "bottom")
    channel = FlutterMethodChannel(name: "CNScrollEdgeEffect_\(viewId)", binaryMessenger: messenger)
    super.init()
    host.apply(dict)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "update":
        self?.host.apply((call.arguments as? [String: Any]) ?? [:])
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { host }
}

final class CNScrollEdgeEffectHost: UIView {
  private let scrollView = CNEdgeEffectScrollView()
  private let content = UIView()
  private let element = UIView()
  private let label = UILabel()
  private let bottom: Bool
  /// The height of the band the effect covers, from the view's edge.
  private var band: CGFloat = 0
  /// How far Flutter's content is under the edge; nil: always under.
  private var underneath: CGFloat?

  init(frame: CGRect, bottom: Bool) {
    self.bottom = bottom
    super.init(frame: frame)
    backgroundColor = .clear
    isUserInteractionEnabled = false
    scrollView.backgroundColor = .clear
    scrollView.isUserInteractionEnabled = false
    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    content.backgroundColor = .clear
    scrollView.addSubview(content)
    addSubview(scrollView)
    element.backgroundColor = .clear
    element.isUserInteractionEnabled = false
    label.text = " "
    element.addSubview(label)
    addSubview(element)
    if #available(iOS 26.0, *) {
      let effect = bottom ? scrollView.bottomEdgeEffect : scrollView.topEdgeEffect
      effect.isHidden = false
      let interaction = UIScrollEdgeElementContainerInteraction()
      interaction.scrollView = scrollView
      interaction.edge = bottom ? .bottom : .top
      element.addInteraction(interaction)
    }
  }

  required init?(coder: NSCoder) { nil }

  func apply(_ args: [String: Any]) {
    if let b = args["band"] as? NSNumber { band = CGFloat(b.doubleValue) }
    if args.keys.contains("underneath") {
      underneath = (args["underneath"] as? NSNumber).map { CGFloat($0.doubleValue) }
    }
    if let style = args["style"] as? String, #available(iOS 26.0, *) {
      let effect = bottom ? scrollView.bottomEdgeEffect : scrollView.topEdgeEffect
      effect.style = style == "hard" ? .hard : .soft
    }
    if let dark = args["isDark"] as? NSNumber {
      overrideUserInterfaceStyle = dark.boolValue ? .dark : .light
    }
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let w = bounds.width, h = bounds.height
    let band = min(self.band > 0 ? self.band : h, h)
    scrollView.frame = bounds
    element.frame = bounds
    label.frame = bottom ? CGRect(x: 0, y: h - band, width: w, height: band) : CGRect(x: 0, y: 0, width: w, height: band)
    // Clear content, long enough to scroll under the band; at rest it ends
    // at the band, so nothing is under the edge.
    let length = max(h * 4, 2000)
    content.frame = CGRect(x: 0, y: 0, width: w, height: length)
    scrollView.contentSize = content.frame.size
    let under = min(max(underneath ?? length / 2, 0), length / 2)
    if bottom {
      scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: band, right: 0)
      scrollView.contentOffset = CGPoint(x: 0, y: length - h + band - under)
    } else {
      scrollView.contentInset = UIEdgeInsets(top: band, left: 0, bottom: 0, right: 0)
      scrollView.contentOffset = CGPoint(x: 0, y: -band + under)
    }
  }
}

/// A scroll view without a safe area, so the effect covers the band from the
/// view's edge, under the status bar or the home indicator too.
final class CNEdgeEffectScrollView: UIScrollView {
  override var safeAreaInsets: UIEdgeInsets { .zero }
}
