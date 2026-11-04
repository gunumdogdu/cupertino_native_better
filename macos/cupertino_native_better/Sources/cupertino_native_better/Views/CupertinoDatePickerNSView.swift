import FlutterMacOS
import Cocoa

/// `CNDatePicker` on macOS: an `NSDatePicker`.
///
/// macOS has no wheels and no compact pill; each style is the NSDatePicker
/// style closest to it. Compact is the text field, which opens a calendar
/// overlay when a date field is clicked (as the pill opens its popover);
/// wheels the text field and stepper, whose arrows step the selected field;
/// inline the clock and calendar. NSDatePicker has no minute step and no
/// accent color: values are rounded to `minuteInterval` after each change,
/// and the tint is ignored.
class CupertinoDatePickerNSView: NSView {
  private let channel: FlutterMethodChannel
  private let picker: NSDatePicker
  /// The requested style ("compact", "inline" or "wheels"). It decides how
  /// the picker is laid out, so it is fixed for the life of the view; Dart
  /// creates a new view for a new style.
  private let pickerStyle: String
  private var mode: String = "date"
  private var minuteInterval: Int = 1
  private var lastReportedSize: NSSize = .zero
  /// Room around the text field styles, whose bezel reaches past the
  /// picker's fitting size.
  private var inset: CGFloat { pickerStyle == "inline" ? 0 : 2 }

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeDatePicker_\(viewId)", binaryMessenger: messenger)
    self.picker = NSDatePicker(frame: .zero)

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
    }

    self.pickerStyle = pickerStyle
    self.mode = mode
    self.minuteInterval = minuteInterval
    super.init(frame: .zero)

    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    picker.datePickerMode = .single
    switch pickerStyle {
    case "inline":
      picker.datePickerStyle = .clockAndCalendar
    case "wheels":
      picker.datePickerStyle = .textFieldAndStepper
      picker.isBezeled = true
    default:
      picker.datePickerStyle = .textField
      picker.isBezeled = true
      // Clicking a date field opens a calendar, like the iOS pill's popover.
      picker.presentsCalendarOverlay = true
    }
    // Zone, locale, fields and range go before the date, which the picker
    // clamps against them.
    picker.timeZone = Self.timeZone(utc: utc)
    picker.locale = Self.locale(localeTag)
    applyMode()
    picker.minDate = minimumMs.map(Self.date(ms:))
    picker.maxDate = maximumMs.map(Self.date(ms:))
    if let ms = valueMs { picker.dateValue = Self.date(ms: ms) }
    picker.isEnabled = enabled
    picker.setAccessibilityLabel(semanticLabel)

    picker.target = self
    picker.action = #selector(onValueChanged(_:))

    picker.translatesAutoresizingMaskIntoConstraints = false
    addSubview(picker)
    if pickerStyle == "inline" {
      NSLayoutConstraint.activate([
        picker.leadingAnchor.constraint(equalTo: leadingAnchor),
        picker.topAnchor.constraint(equalTo: topAnchor),
      ])
    } else {
      NSLayoutConstraint.activate([
        picker.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
        picker.centerYAnchor.constraint(equalTo: centerYAnchor),
      ])
    }

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
          if let utc = (args?["utc"] as? NSNumber)?.boolValue {
            self.picker.timeZone = Self.timeZone(utc: utc)
          }
          self.picker.dateValue = Self.date(ms: ms)
          self.scheduleSizeReport()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing value", details: nil)) }
      case "setRange":
        // Null clears a limit.
        self.picker.minDate = (args?["minimumDate"] as? NSNumber).map { Self.date(ms: $0.doubleValue) }
        self.picker.maxDate = (args?["maximumDate"] as? NSNumber).map { Self.date(ms: $0.doubleValue) }
        result(nil)
      case "setMode":
        if let mode = args?["mode"] as? String {
          self.mode = mode
          self.applyMode()
          self.scheduleSizeReport()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing mode", details: nil)) }
      case "setMinuteInterval":
        if let interval = (args?["minuteInterval"] as? NSNumber)?.intValue {
          self.minuteInterval = interval
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
        let label = args?["label"] as? String
        self.picker.setAccessibilityLabel((label?.isEmpty ?? true) ? nil : label)
        result(nil)
      case "setStyle":
        // NSDatePicker has no accent color; it follows the system's.
        result(nil)
      case "setInteractive":
        result(nil)
      case "setBrightness":
        if let isDark = (args?["isDark"] as? NSNumber)?.boolValue {
          self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) {
    return nil
  }

  override func layout() {
    super.layout()
    reportSizeIfChanged()
  }

  @objc private func onValueChanged(_ sender: NSDatePicker) {
    let date = roundedToMinuteInterval(sender.dateValue)
    if date != sender.dateValue { sender.dateValue = date }
    channel.invokeMethod("valueChanged", arguments: ["value": date.timeIntervalSince1970 * 1000])
    scheduleSizeReport()
  }

  // MARK: - Mode

  /// The fields `mode` shows. Year-and-month shows the month and year
  /// fields, the closest NSDatePicker has to UIKit's month and year wheels.
  private func applyMode() {
    switch mode {
    case "time": picker.datePickerElements = [.hourMinute]
    case "dateAndTime": picker.datePickerElements = [.yearMonthDay, .hourMinute]
    case "yearAndMonth": picker.datePickerElements = [.yearMonth]
    default: picker.datePickerElements = [.yearMonthDay]
    }
  }

  /// NSDatePicker has no minute step, so the value is rounded to the nearest
  /// `minuteInterval` in the modes that show a time.
  private func roundedToMinuteInterval(_ date: Date) -> Date {
    guard minuteInterval > 1, mode == "time" || mode == "dateAndTime" else { return date }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = picker.timeZone ?? TimeZone.current
    var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    let minute = parts.minute ?? 0
    // Calendar is lenient: minute 60 rolls over into the next hour.
    parts.minute = Int((Double(minute) / Double(minuteInterval)).rounded()) * minuteInterval
    return calendar.date(from: parts) ?? date
  }

  // MARK: - Size

  private func measure() -> NSSize {
    let size = picker.fittingSize
    return NSSize(width: size.width + 2 * inset, height: size.height + 2 * inset)
  }

  private func reportSizeIfChanged() {
    let size = measure()
    guard size.width > 0, size.height > 0 else { return }
    if abs(size.width - lastReportedSize.width) < 0.5,
       abs(size.height - lastReportedSize.height) < 0.5 { return }
    lastReportedSize = size
    channel.invokeMethod("sizeChanged", arguments: ["width": Double(size.width), "height": Double(size.height)])
  }

  private func scheduleSizeReport() {
    DispatchQueue.main.async { [weak self] in self?.reportSizeIfChanged() }
  }

  // MARK: - Helpers

  /// UTC for a UTC `DateTime` in Dart, otherwise the device's zone, so the
  /// picker shows the same wall-clock fields as the Dart value.
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
}
