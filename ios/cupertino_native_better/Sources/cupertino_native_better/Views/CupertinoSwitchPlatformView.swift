import Flutter
import UIKit
import SwiftUI

class CupertinoSwitchPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let hostingController: UIHostingController<CupertinoSwitchView>

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "CupertinoNativeSwitch_\(viewId)", binaryMessenger: messenger)
    self.channel = channel

    var initialValue: Bool = false
    var enabled: Bool = true
    var isDark: Bool = false
    var initialTint: UIColor? = nil
    if let dict = args as? [String: Any] {
      if let v = dict["value"] as? NSNumber { initialValue = v.boolValue }
      if let v = dict["enabled"] as? NSNumber { enabled = v.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let style = dict["style"] as? [String: Any], let tintNum = style["tint"] as? NSNumber {
        initialTint = Self.colorFromARGB(tintNum.intValue)
      }
    }

    let model = SwitchModel(value: initialValue, enabled: enabled) { newValue in
      channel.invokeMethod("valueChanged", arguments: ["value": newValue])
    }
    self.hostingController = UIHostingController(rootView: CupertinoSwitchView(model: model))
    self.hostingController.view.backgroundColor = .clear
    self.hostingController.view.isOpaque = false
    if #available(iOS 13.0, *) {
      self.hostingController.overrideUserInterfaceStyle = isDark ? .dark : .light
    }

    // Prevent keyboard from pushing the switch upward (Issue #4).
    // iOS 16.4+ has an official API; older versions need the runtime fix.
    if #available(iOS 16.4, *) {
      self.hostingController.safeAreaRegions.remove(.keyboard)
    } else {
      Self.disableKeyboardAvoidance(on: self.hostingController)
    }

    super.init()

    if let tint = initialTint {
      model.tintColor = Color(tint)
    }

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setValue":
        if let args = call.arguments as? [String: Any], let value = (args["value"] as? NSNumber)?.boolValue {
          model.value = value
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing value", details: nil)) }
      case "setEnabled":
        if let args = call.arguments as? [String: Any], let enabled = (args["enabled"] as? NSNumber)?.boolValue {
          model.enabled = enabled
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setStyle":
        if let args = call.arguments as? [String: Any] {
          if let tintNum = args["tint"] as? NSNumber {
            let ui = Self.colorFromARGB(tintNum.intValue)
            model.tintColor = Color(ui)
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setInteractive":
        // Issue #53 follow-up: see button view's setInteractive for the
        // rationale. Flutter's AbsorbPointer can't block native UIView
        // touches; only isUserInteractionEnabled does.
        if let args = call.arguments as? [String: Any],
           let interactive = (args["interactive"] as? NSNumber)?.boolValue {
          NSLog("[CN CNSwitch] setInteractive=\(interactive)")
          self._cnSetInteractiveRecursive(self.hostingController.view, interactive)
        }
        result(nil)
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          if #available(iOS 13.0, *) {
            self.hostingController.overrideUserInterfaceStyle = isDark ? .dark : .light
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView {
    return hostingController.view
  }

  // MARK: - Keyboard avoidance fix (pre-iOS 16.4)

  /// Disables keyboard avoidance on the hosting controller's internal view
  /// by dynamically subclassing it and replacing the private
  /// `keyboardWillShowWithNotification:` method with a no-op.
  /// Based on https://steipete.me/posts/2020/disabling-keyboard-avoidance-in-swiftui-uihostingcontroller
  private static func disableKeyboardAvoidance(on hostingController: UIHostingController<CupertinoSwitchView>) {
    guard let viewClass = object_getClass(hostingController.view) else { return }
    let viewSubclassName = String(cString: class_getName(viewClass)).appending("_IgnoreKeyboard")

    if let viewSubclass = NSClassFromString(viewSubclassName) {
      object_setClass(hostingController.view, viewSubclass)
    } else {
      guard let viewClassNameUtf8 = (viewSubclassName as NSString).utf8String else { return }
      guard let viewSubclass = objc_allocateClassPair(viewClass, viewClassNameUtf8, 0) else { return }

      // Override safeAreaInsets to return .zero
      if let method = class_getInstanceMethod(UIView.self, #selector(getter: UIView.safeAreaInsets)) {
        let safeAreaInsets: @convention(block) (AnyObject) -> UIEdgeInsets = { _ in .zero }
        class_addMethod(viewSubclass, #selector(getter: UIView.safeAreaInsets),
                        imp_implementationWithBlock(safeAreaInsets), method_getTypeEncoding(method))
      }

      // Replace keyboardWillShowWithNotification: with a no-op
      let keyboardSelector = NSSelectorFromString("keyboardWillShowWithNotification:")
      if let method = class_getInstanceMethod(viewClass, keyboardSelector) {
        let noOp: @convention(block) (AnyObject, AnyObject) -> Void = { _, _ in }
        class_addMethod(viewSubclass, keyboardSelector,
                        imp_implementationWithBlock(noOp), method_getTypeEncoding(method))
      }

      objc_registerClassPair(viewSubclass)
      object_setClass(hostingController.view, viewSubclass)
    }
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
