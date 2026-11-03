import Flutter
import UIKit

/// Hosts the date picker and runs a callback after each layout pass, so the
/// platform view can report a new size to Dart: the compact pill widens with
/// its text, and the inline calendar's height follows the width it gets (and
/// may follow the shown month's week rows; iOS 27 keeps one height). Both
/// invalidate the picker's intrinsic size, which lays this view out again.
class CNDatePickerContainerView: UIView {
  var onLayout: (() -> Void)?

  override func layoutSubviews() {
    super.layoutSubviews()
    onLayout?()
  }
}

class CupertinoDatePickerPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let container: CNDatePickerContainerView
  private let picker: UIDatePicker
  /// The requested style ("compact", "inline" or "wheels"). It decides how
  /// the picker is laid out in the container, so it is fixed for the life of
  /// the view; Dart creates a new view for a new style.
  private let pickerStyle: String
  private var mode: String = "date"
  private var lastReportedSize: CGSize = .zero

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeDatePicker_\(viewId)", binaryMessenger: messenger)
    self.container = CNDatePickerContainerView(frame: frame)
    self.picker = UIDatePicker(frame: .zero)

    var valueMs: Double? = nil
    var utc: Bool = false
    var mode: String = "date"
    var pickerStyle: String = "compact"
    var minimumMs: Double? = nil
    var maximumMs: Double? = nil
    var minuteInterval: Int = 1
    var enabled: Bool = true
    var isDark: Bool = false
    var localeTag: String? = nil
    var semanticLabel: String? = nil
    var tint: UIColor? = nil

    if let dict = args as? [String: Any] {
      if let v = dict["value"] as? NSNumber { valueMs = v.doubleValue }
      if let v = dict["utc"] as? NSNumber { utc = v.boolValue }
      if let v = dict["mode"] as? String { mode = v }
      if let v = dict["pickerStyle"] as? String { pickerStyle = v }
      if let v = dict["minimumDate"] as? NSNumber { minimumMs = v.doubleValue }
      if let v = dict["maximumDate"] as? NSNumber { maximumMs = v.doubleValue }
      if let v = dict["minuteInterval"] as? NSNumber { minuteInterval = v.intValue }
      if let v = dict["enabled"] as? NSNumber { enabled = v.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let v = dict["locale"] as? String, !v.isEmpty { localeTag = v }
      if let v = dict["semanticLabel"] as? String, !v.isEmpty { semanticLabel = v }
      if let style = dict["style"] as? [String: Any], let n = style["tint"] as? NSNumber {
        tint = Self.colorFromARGB(n.intValue)
      }
    }

    self.pickerStyle = pickerStyle
    self.mode = mode
    super.init()

    container.backgroundColor = .clear
    container.overrideUserInterfaceStyle = isDark ? .dark : .light

    // Zone, locale, mode and range go before the date, which the picker
    // clamps and rounds against them.
    picker.timeZone = Self.timeZone(utc: utc)
    picker.locale = Self.locale(localeTag)
    applyModeAndStyle()
    picker.minuteInterval = minuteInterval
    picker.minimumDate = minimumMs.map(Self.date(ms:))
    picker.maximumDate = maximumMs.map(Self.date(ms:))
    if let ms = valueMs { picker.date = Self.date(ms: ms) }
    picker.isEnabled = enabled
    if let tint = tint { picker.tintColor = tint }
    applySemanticLabel(semanticLabel)

    picker.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(picker)
    switch pickerStyle {
    case "wheels":
      // The wheels stretch to the width Flutter gives them, centred.
      NSLayoutConstraint.activate([
        picker.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        picker.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        picker.topAnchor.constraint(equalTo: container.topAnchor),
        picker.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      ])
    case "inline":
      // The calendar fills the width; its height is its own and is reported
      // to Dart, which sizes the view to it. Pinning the bottom too would
      // hold it at the old height whenever its own height changes.
      NSLayoutConstraint.activate([
        picker.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        picker.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        picker.topAnchor.constraint(equalTo: container.topAnchor),
      ])
    default:
      // The pill keeps its own size, at the leading edge, until Dart has
      // sized the view to it.
      NSLayoutConstraint.activate([
        picker.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        picker.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      ])
    }

    picker.addTarget(self, action: #selector(onValueChanged(_:)), for: .valueChanged)
    picker.addTarget(self, action: #selector(onEditingDidBegin(_:)), for: .editingDidBegin)
    container.onLayout = { [weak self] in self?.reportSizeIfChanged() }

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "getIntrinsicSize":
        let size = self.measure()
        self.lastReportedSize = size
        result(["width": Double(size.width), "height": Double(size.height)])
      case "setValue":
        if let ms = (args?["value"] as? NSNumber)?.doubleValue {
          let animated = (args?["animated"] as? NSNumber)?.boolValue ?? false
          if let utc = (args?["utc"] as? NSNumber)?.boolValue {
            self.picker.timeZone = Self.timeZone(utc: utc)
          }
          self.picker.setDate(Self.date(ms: ms), animated: animated)
          self.scheduleSizeReport()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing value", details: nil)) }
      case "setRange":
        // Null clears a limit.
        self.picker.minimumDate = (args?["minimumDate"] as? NSNumber).map { Self.date(ms: $0.doubleValue) }
        self.picker.maximumDate = (args?["maximumDate"] as? NSNumber).map { Self.date(ms: $0.doubleValue) }
        result(nil)
      case "setMode":
        if let mode = args?["mode"] as? String {
          self.mode = mode
          self.applyModeAndStyle()
          self.scheduleSizeReport()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing mode", details: nil)) }
      case "setMinuteInterval":
        if let interval = (args?["minuteInterval"] as? NSNumber)?.intValue {
          self.picker.minuteInterval = interval
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing minuteInterval", details: nil)) }
      case "setLocale":
        self.picker.locale = Self.locale(args?["locale"] as? String)
        self.scheduleSizeReport()
        result(nil)
      case "setEnabled":
        if let enabled = (args?["enabled"] as? NSNumber)?.boolValue {
          self.picker.isEnabled = enabled
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setSemanticLabel":
        self.applySemanticLabel(args?["label"] as? String)
        result(nil)
      case "setStyle":
        if let n = args?["tint"] as? NSNumber {
          self.picker.tintColor = Self.colorFromARGB(n.intValue)
        }
        result(nil)
      case "setBrightness":
        if let isDark = (args?["isDark"] as? NSNumber)?.boolValue {
          self.container.overrideUserInterfaceStyle = isDark ? .dark : .light
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setInteractive":
        // Issue #53 follow-up: see button view's setInteractive for the
        // rationale. Flutter's AbsorbPointer can't block native UIView
        // touches; only isUserInteractionEnabled does.
        if let interactive = (args?["interactive"] as? NSNumber)?.boolValue {
          NSLog("[CN DatePicker] setInteractive=\(interactive)")
          self._cnSetInteractiveRecursive(self.container, interactive)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  @objc private func onValueChanged(_ sender: UIDatePicker) {
    channel.invokeMethod("valueChanged", arguments: ["value": sender.date.timeIntervalSince1970 * 1000])
    scheduleSizeReport()
  }

  /// The compact pill's popover is presented by the Flutter view controller,
  /// so it takes the system appearance, not the app theme this view follows
  /// through `overrideUserInterfaceStyle`: a dark app on a light phone got a
  /// light popover. Gives the popover this view's appearance as it opens.
  @objc private func onEditingDidBegin(_ sender: UIDatePicker) {
    if !matchPopoverAppearance() {
      // Not presented yet; UIKit presents it in the same turn of the run loop.
      DispatchQueue.main.async { [weak self] in _ = self?.matchPopoverAppearance() }
    }
  }

  /// Finds the date picker's own presented controller above this view and
  /// sets its appearance. Returns false when there is none yet.
  private func matchPopoverAppearance() -> Bool {
    var controller = container.window?.rootViewController
    while let presented = controller?.presentedViewController {
      if NSStringFromClass(type(of: presented)).contains("DatePicker") {
        presented.overrideUserInterfaceStyle = container.overrideUserInterfaceStyle
        return true
      }
      controller = presented
    }
    return false
  }

  // MARK: - Mode and style

  /// Applies `mode` and the requested style. Year-and-month is wheels only:
  /// UIKit does not support it in the compact or inline style, so the style
  /// is switched to wheels before the mode. Dart creates a wheels view for
  /// that mode anyway; this keeps a compact or inline view safe if it is
  /// ever asked for it.
  private func applyModeAndStyle() {
    if mode == "yearAndMonth", #available(iOS 17.4, *) {
      picker.preferredDatePickerStyle = .wheels
      picker.datePickerMode = .yearAndMonth
      return
    }
    switch mode {
    case "time": picker.datePickerMode = .time
    case "dateAndTime": picker.datePickerMode = .dateAndTime
    default: picker.datePickerMode = .date
    }
    switch pickerStyle {
    case "inline": picker.preferredDatePickerStyle = .inline
    case "wheels": picker.preferredDatePickerStyle = .wheels
    default: picker.preferredDatePickerStyle = .compact
    }
  }

  // MARK: - Size

  /// The size the picker needs. The pill and the wheels have a size of their
  /// own; the calendar's height depends on the width it gets, so it is
  /// measured at the container's width once Flutter has laid that out.
  private func measure() -> CGSize {
    let natural = picker.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    guard pickerStyle == "inline", container.bounds.width > 0 else { return natural }
    let fitted = picker.systemLayoutSizeFitting(
      CGSize(width: container.bounds.width, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    )
    return CGSize(width: natural.width, height: fitted.height)
  }

  private func reportSizeIfChanged() {
    let size = measure()
    guard size.width > 0, size.height > 0 else { return }
    if abs(size.width - lastReportedSize.width) < 0.5,
       abs(size.height - lastReportedSize.height) < 0.5 { return }
    lastReportedSize = size
    channel.invokeMethod("sizeChanged", arguments: ["width": Double(size.width), "height": Double(size.height)])
  }

  /// A new value, mode or locale changes the pill's text or the calendar's
  /// month; measure once the picker has applied it.
  private func scheduleSizeReport() {
    DispatchQueue.main.async { [weak self] in self?.reportSizeIfChanged() }
  }

  // MARK: - Helpers

  /// The picker is made of several accessibility elements (the pill's
  /// buttons, the wheels, the calendar's days) and is not one itself, so a
  /// label on it alone is never read. Naming the container as a semantic
  /// group makes VoiceOver read the label when focus enters the picker
  /// (`CNDatePicker.semanticLabel`).
  private func applySemanticLabel(_ label: String?) {
    let label = (label?.isEmpty ?? true) ? nil : label
    picker.accessibilityLabel = label
    container.accessibilityLabel = label
    container.accessibilityContainerType = label == nil ? .none : .semanticGroup
  }

  /// UTC for a UTC `DateTime` in Dart, otherwise the device's zone (nil), so
  /// the picker shows the same wall-clock fields as the Dart value.
  private static func timeZone(utc: Bool) -> TimeZone? {
    return utc ? TimeZone(identifier: "UTC") : nil
  }

  private static func locale(_ tag: String?) -> Locale? {
    guard let tag = tag, !tag.isEmpty else { return nil }
    return Locale(identifier: tag)
  }

  private static func date(ms: Double) -> Date {
    return Date(timeIntervalSince1970: ms / 1000)
  }

  // Use shared utility functions
  private static func colorFromARGB(_ argb: Int) -> UIColor {
    return ImageUtils.colorFromARGB(argb)
  }

  private func _cnSetInteractiveRecursive(_ view: UIView?, _ interactive: Bool) {
    guard let view = view else { return }
    view.isUserInteractionEnabled = interactive
    for sub in view.subviews { _cnSetInteractiveRecursive(sub, interactive) }
  }
}
