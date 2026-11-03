import SwiftUI

struct CupertinoSliderView: View {
  @ObservedObject var model: SliderModel

  var body: some View {
    Group {
      if #available(macOS 26.0, *), model.usesTrackOptions {
        // macOS 26 slider ticks and neutral value (`CNSlider.numberOfTicks`,
        // `tickValues`, `allowsTickValuesOnly`, `neutralValue`).
        Slider(
          value: model.tickSnappingValue,
          in: model.min...model.max,
          neutralValue: model.clampedNeutralValue,
          label: { EmptyView() },
          ticks: {
            SliderTickContentForEach(model.resolvedTickValues, id: \.self) { value in
              SliderTick(value)
            }
          }
        )
      } else if let s = model.step, s > 0 {
        Slider(value: $model.value, in: model.min...model.max, step: s)
      } else {
        Slider(value: $model.value, in: model.min...model.max)
      }
    }
    .disabled(!model.enabled)
    .onChange(of: model.value) { newValue in
      model.onChange(newValue)
    }
    .accentColor(model.tintColor)
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
  var onChange: (Double) -> Void

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

  /// Binds the slider to `value`, moving it to the nearest tick when
  /// `allowsTickValuesOnly` is set and there are ticks.
  var tickSnappingValue: Binding<Double> {
    Binding(
      get: { self.value },
      set: { newValue in
        let ticks = self.resolvedTickValues
        guard self.allowsTickValuesOnly, !ticks.isEmpty else {
          self.value = newValue
          return
        }
        self.value = ticks.min { abs($0 - newValue) < abs($1 - newValue) } ?? newValue
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
