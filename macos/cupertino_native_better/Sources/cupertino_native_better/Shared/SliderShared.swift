import SwiftUI

/// The SwiftUI slider `CupertinoSliderNSView` shows for tick values that
/// NSSlider cannot draw (unevenly spaced ones, macOS 26+). Changes made by
/// the user reach `model.onChange`; values set in code do not.
struct CupertinoSliderView: View {
  @ObservedObject var model: SliderModel

  var body: some View {
    Group {
      #if compiler(>=6.2)
      if #available(macOS 26.0, *), model.usesTrackOptions {
        // macOS 26 slider ticks and neutral value (`CNSlider.numberOfTicks`,
        // `tickValues`, `allowsTickValuesOnly`, `neutralValue`).
        Slider(
          value: model.userValue(snappingToTicks: true),
          in: model.min...model.max,
          neutralValue: model.clampedNeutralValue,
          label: { EmptyView() },
          ticks: {
            SliderTickContentForEach(model.resolvedTickValues, id: \.self) { value in
              SliderTick(value)
            }
          },
          onEditingChanged: { model.onEditing($0) }
        )
      } else {
        plainSlider
      }
      #else
      plainSlider
      #endif
    }
    .disabled(!model.enabled)
    .accentColor(model.tintColor)
    .accessibilityLabel(Text(model.label))
  }

  @ViewBuilder private var plainSlider: some View {
    if let s = model.step, s > 0 {
      Slider(value: model.userValue(snappingToTicks: false), in: model.min...model.max, step: s) {
        model.onEditing($0)
      }
    } else {
      Slider(value: model.userValue(snappingToTicks: false), in: model.min...model.max) {
        model.onEditing($0)
      }
    }
  }
}

class SliderModel: ObservableObject {
  @Published var value: Double
  @Published var min: Double
  @Published var max: Double
  @Published var enabled: Bool
  @Published var tintColor: Color = .accentColor
  @Published var step: Double? = nil
  @Published var numberOfTicks: Int? = nil
  @Published var tickValues: [Double]? = nil
  @Published var allowsTickValuesOnly: Bool = true
  @Published var neutralValue: Double? = nil
  /// What VoiceOver reads (`CNSlider.semanticLabel`); empty for none.
  @Published var label: String = ""
  /// Called with each value the user picks.
  var onChange: (Double) -> Void
  /// Called with true when a drag starts and false when it ends
  /// (`CNSlider.onChangeStart` / `onChangeEnd`).
  var onEditing: (Bool) -> Void = { _ in }

  init(value: Double, min: Double, max: Double, enabled: Bool, onChange: @escaping (Double) -> Void) {
    self.value = value
    self.min = min
    self.max = max
    self.enabled = enabled
    self.onChange = onChange
  }

  /// Whether any of the macOS 26 track options is set.
  var usesTrackOptions: Bool {
    numberOfTicks != nil || tickValues != nil || neutralValue != nil
  }

  /// The tick positions: `tickValues`, or `numberOfTicks` evenly spaced
  /// from `min` to `max`.
  var resolvedTickValues: [Double] {
    if let values = tickValues { return values }
    guard let n = numberOfTicks, n > 1 else { return [] }
    return (0..<n).map { min + (max - min) * Double($0) / Double(n - 1) }
  }

  var clampedNeutralValue: Double? {
    guard let v = neutralValue else { return nil }
    return Swift.max(min, Swift.min(v, max))
  }

  /// Binds a slider to `value`. Only the user sets it, so the setter
  /// reports the change; with `snappingToTicks` and `allowsTickValuesOnly`
  /// the value moves to the nearest tick first.
  func userValue(snappingToTicks: Bool) -> Binding<Double> {
    Binding(
      get: { self.value },
      set: { newValue in
        var v = newValue
        let ticks = self.resolvedTickValues
        if snappingToTicks, self.allowsTickValuesOnly, !ticks.isEmpty {
          v = ticks.min { abs($0 - newValue) < abs($1 - newValue) } ?? newValue
        }
        guard v != self.value else { return }
        self.value = v
        self.onChange(v)
      }
    )
  }

  /// Reads the track options from creation params or `setTrackConfiguration`,
  /// which always sends all of them; a missing key clears that option.
  func readTrackConfiguration(_ dict: [String: Any]) {
    numberOfTicks = (dict["numberOfTicks"] as? NSNumber)?.intValue
    tickValues = (dict["tickValues"] as? [NSNumber])?.map { $0.doubleValue }
    allowsTickValuesOnly = (dict["allowsTickValuesOnly"] as? NSNumber)?.boolValue ?? true
    neutralValue = (dict["neutralValue"] as? NSNumber)?.doubleValue
  }
}
