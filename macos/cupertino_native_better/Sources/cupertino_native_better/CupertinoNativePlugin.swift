import Cocoa
import FlutterMacOS

public class CupertinoNativePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "cupertino_native", binaryMessenger: registrar.messenger)
    let instance = CupertinoNativePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    // Window-level presenters (no platform view): NSAlert sheets for CNAlert
    // and CNActionSheet, NSMenus for anchored action sheets and context menus.
    MacFlutterWindow.registrar = registrar
    CNAlertManager.shared.setup(messenger: registrar.messenger)
    CNActionSheetManager.shared.setup(messenger: registrar.messenger)
    CNContextMenuManager.shared.setup(messenger: registrar.messenger)

    let sliderFactory = CupertinoSliderViewFactory(messenger: registrar.messenger)
    registrar.register(sliderFactory, withId: "CupertinoNativeSlider")

    let switchFactory = CupertinoSwitchViewFactory(messenger: registrar.messenger)
    registrar.register(switchFactory, withId: "CupertinoNativeSwitch")

    let datePickerFactory = CupertinoDatePickerViewFactory(messenger: registrar.messenger)
    registrar.register(datePickerFactory, withId: "CupertinoNativeDatePicker")
    let stepperFactory = CupertinoStepperViewFactory(messenger: registrar.messenger)
    registrar.register(stepperFactory, withId: "CupertinoNativeStepper")

    let colorWellFactory = CupertinoColorWellViewFactory(messenger: registrar.messenger)
    registrar.register(colorWellFactory, withId: "CupertinoNativeColorWell")

    let segmentedFactory = CupertinoSegmentedControlViewFactory(messenger: registrar.messenger)
    registrar.register(segmentedFactory, withId: "CupertinoNativeSegmentedControl")

    let iconFactory = CupertinoIconViewFactory(messenger: registrar.messenger)
    registrar.register(iconFactory, withId: "CupertinoNativeIcon")

    let tabBarFactory = CupertinoTabBarViewFactory(messenger: registrar.messenger)
    registrar.register(tabBarFactory, withId: "CupertinoNativeTabBar")

    let popupMenuFactory = CupertinoPopupMenuButtonViewFactory(messenger: registrar.messenger)
    registrar.register(popupMenuFactory, withId: "CupertinoNativePopupMenuButton")

    let buttonFactory = CupertinoButtonViewFactory(messenger: registrar.messenger)
    registrar.register(buttonFactory, withId: "CupertinoNativeButton")
    
    let liquidGlassContainerFactory = LiquidGlassContainerFactory(messenger: registrar.messenger)
    registrar.register(liquidGlassContainerFactory, withId: "CupertinoNativeLiquidGlassContainer")

    // Liquid Glass on macOS 26+; below it Flutter draws the group itself.
    let glassButtonGroupFactory = CupertinoGlassButtonGroupFactory(messenger: registrar.messenger)
    registrar.register(glassButtonGroupFactory, withId: "CupertinoNativeGlassButtonGroup")

    let searchBarFactory = CupertinoSearchBarViewFactory(messenger: registrar.messenger)
    registrar.register(searchBarFactory, withId: "CNSearchBar")

    let progressFactory = CupertinoProgressIndicatorViewFactory(messenger: registrar.messenger)
    registrar.register(progressFactory, withId: "CupertinoNativeProgressIndicator")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case "getMajorOSVersion":
      let version = ProcessInfo.processInfo.operatingSystemVersion
      result(Int(version.majorVersion))
    case "beginTransition", "endTransition":
      // CNTransitionObserver sends these on every route change, unawaited.
      // On iOS they switch Liquid Glass off during the transition; no macOS
      // view reacts to them, but an unanswered call would be an uncaught
      // MissingPluginException on each navigation (#47).
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
