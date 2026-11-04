import SwiftUI

/// The switch `CupertinoSwitchNSView` hosts: a SwiftUI toggle in the switch
/// style, which draws the AppKit switch and, unlike `NSSwitch`, takes a tint
/// (macOS 12+). Only changes made by the user reach `model.onChange`.
struct CupertinoSwitchView: View {
  @ObservedObject var model: SwitchModel

  var body: some View {
    let base = Toggle("", isOn: userValue)
      .labelsHidden()
      // On macOS a default Toggle renders as a checkbox; force the switch
      // style so CNSwitch is a real toggle (iOS already defaults to a switch).
      .toggleStyle(.switch)
      .disabled(!model.enabled)
      .accessibilityLabel(Text(model.label))

    if #available(macOS 12.0, *) {
      base.tint(model.tintColor)
    } else {
      base.accentColor(model.tintColor)
    }
  }

  /// Binds the toggle to `model.value`. The toggle only sets it when the
  /// user flips it, so a value set from Dart is not reported back.
  private var userValue: Binding<Bool> {
    Binding(
      get: { model.value },
      set: { newValue in
        guard newValue != model.value else { return }
        model.value = newValue
        model.onChange(newValue)
      }
    )
  }
}

class SwitchModel: ObservableObject {
  @Published var value: Bool
  @Published var enabled: Bool
  @Published var tintColor: Color = .accentColor
  /// What VoiceOver reads (`CNSwitch.semanticLabel`); empty for none.
  @Published var label: String = ""
  var onChange: (Bool) -> Void

  init(value: Bool, enabled: Bool, onChange: @escaping (Bool) -> Void) {
    self.value = value
    self.enabled = enabled
    self.onChange = onChange
  }
}
