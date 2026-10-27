import SwiftUI

struct CupertinoSwitchView: View {
  @ObservedObject var model: SwitchModel

  var body: some View {
    configuredToggle
      // Prevent SwiftUI's automatic keyboard-avoidance from pushing the
      // switch upward when the on-screen keyboard appears (Issue #4).
      .ignoresSafeArea(.keyboard)
  }

  @ViewBuilder
  private var configuredToggle: some View {
    // The label is hidden on screen but is what VoiceOver reads
    // (`CNSwitch.semanticLabel`).
    let base = Toggle(model.label, isOn: $model.value)
      .labelsHidden()
      .disabled(!model.enabled)

    if #available(iOS 14.0, *) {
      if #available(iOS 15.0, *) {
        base
          .onChange(of: model.value) { newValue in
            model.onChange(newValue)
          }
          .tint(model.tintColor)
      } else {
        base
          .onChange(of: model.value) { newValue in
            model.onChange(newValue)
          }
          .accentColor(model.tintColor)
      }
    } else {
      if #available(iOS 15.0, *) {
        base
          .onReceive(model.$value) { newValue in
            model.onChange(newValue)
          }
          .tint(model.tintColor)
      } else {
        base
          .onReceive(model.$value) { newValue in
            model.onChange(newValue)
          }
          .accentColor(model.tintColor)
      }
    }
  }
}

class SwitchModel: ObservableObject {
  @Published var value: Bool
  @Published var enabled: Bool
  @Published var tintColor: Color = .accentColor
  @Published var label: String = ""
  var onChange: (Bool) -> Void

  init(value: Bool, enabled: Bool, onChange: @escaping (Bool) -> Void) {
    self.value = value
    self.enabled = enabled
    self.onChange = onChange
  }
}
