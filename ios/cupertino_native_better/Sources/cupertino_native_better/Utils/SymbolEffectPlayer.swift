import UIKit
import Symbols

/// Plays the SF Symbol effects Flutter sends as `CNSymbolEffect.toMap()` on a
/// `UIImageView`.
///
/// Every effect is gated by the iOS version that introduced it (17, 18 or
/// 26). Where it is missing the call does nothing, so the symbol stays still.
enum SymbolEffectPlayer {
  /// Whether `effect` is `drawOn` or `drawOff`, which show or hide the symbol
  /// instead of animating it in place.
  static func isDraw(_ effect: [String: Any]?) -> Bool {
    let type = effect?["type"] as? String
    return type == "drawOn" || type == "drawOff"
  }

  // MARK: - Running effects (`CNIcon.effect`)

  /// Starts `effect` as a running effect that lasts until it is removed.
  @available(iOS 17.0, *)
  static func start(_ effect: [String: Any], on view: UIImageView, animated: Bool = true) {
    let opts = options(effect, defaultRepeat: .forever)
    switch effect["type"] as? String {
    case "bounce":
      // Bounce only runs indefinitely from iOS 18 on.
      if #available(iOS 18.0, *) {
        indefinite(bounce(effect), on: view, options: opts, animated: animated)
      }
    case "pulse":
      indefinite(pulse(effect), on: view, options: opts, animated: animated)
    case "variableColor":
      indefinite(variableColor(effect), on: view, options: opts, animated: animated)
    case "scale":
      indefinite(scale(effect), on: view, options: opts, animated: animated)
    case "wiggle":
      if #available(iOS 18.0, *) { indefinite(wiggle(effect), on: view, options: opts, animated: animated) }
    case "breathe":
      if #available(iOS 18.0, *) { indefinite(breathe(effect), on: view, options: opts, animated: animated) }
    case "rotate":
      if #available(iOS 18.0, *) { indefinite(rotate(effect), on: view, options: opts, animated: animated) }
    case "drawOn":
      if #available(iOS 26.0, *) { indefinite(drawOn(effect), on: view, options: opts, animated: animated) }
    case "drawOff":
      if #available(iOS 26.0, *) { indefinite(drawOff(effect), on: view, options: opts, animated: animated) }
    default:
      break
    }
  }

  /// Replaces the running effect `old` with `new` (either may be nil).
  ///
  /// Switching between the draw effects adds the new one on top, so the
  /// symbol draws in from where `drawOff` left it; removing every effect
  /// first would show it again at once.
  @available(iOS 17.0, *)
  static func transition(from old: [String: Any]?, to new: [String: Any]?, on view: UIImageView) {
    if let new = new {
      if old != nil && !(isDraw(old) && isDraw(new)) {
        view.removeAllSymbolEffects(animated: true)
      }
      start(new, on: view)
    } else if let old = old {
      if old["type"] as? String == "drawOff" {
        // Draw the hidden symbol back in rather than popping it back.
        var back: [String: Any] = ["type": "drawOn"]
        back["scope"] = old["scope"]
        back["speed"] = old["speed"]
        start(back, on: view)
      } else {
        view.removeAllSymbolEffects(animated: true)
      }
    }
  }

  // MARK: - One-shot effects (`CNIcon.triggeredEffect`)

  /// Plays `effect` once. `scale` and `drawOff`, which have no one-shot form,
  /// do nothing.
  @available(iOS 17.0, *)
  static func play(_ effect: [String: Any], on view: UIImageView) {
    let opts = options(effect, defaultRepeat: .once)
    switch effect["type"] as? String {
    case "bounce":
      discrete(bounce(effect), on: view, options: opts)
    case "pulse":
      discrete(pulse(effect), on: view, options: opts)
    case "variableColor":
      discrete(variableColor(effect), on: view, options: opts)
    case "wiggle":
      if #available(iOS 18.0, *) { discrete(wiggle(effect), on: view, options: opts) }
    case "breathe":
      if #available(iOS 18.0, *) { discrete(breathe(effect), on: view, options: opts) }
    case "rotate":
      if #available(iOS 18.0, *) { discrete(rotate(effect), on: view, options: opts) }
    case "drawOn":
      // Hide the symbol at once, then draw it in.
      if #available(iOS 26.0, *) {
        indefinite(DrawOffSymbolEffect.drawOff, on: view, options: .default, animated: false)
        indefinite(drawOn(effect), on: view, options: options(effect), animated: true)
      }
    default:
      break
    }
  }

  // MARK: - Replace transition (`CNIcon.replaceTransition`)

  /// Shows `image` with the content transition Flutter calls `transition`.
  @available(iOS 17.0, *)
  static func replace(with image: UIImage, on view: UIImageView, transition: String) {
    switch transition {
    case "downUp":
      view.setSymbolImage(image, contentTransition: ReplaceSymbolEffect.replace.downUp)
    case "upUp":
      view.setSymbolImage(image, contentTransition: ReplaceSymbolEffect.replace.upUp)
    case "offUp":
      view.setSymbolImage(image, contentTransition: ReplaceSymbolEffect.replace.offUp)
    case "magic":
      if #available(iOS 18.0, *) {
        view.setSymbolImage(
          image,
          contentTransition: ReplaceSymbolEffect.replace.magic(fallback: ReplaceSymbolEffect.replace)
        )
      } else {
        view.setSymbolImage(image, contentTransition: ReplaceSymbolEffect.replace)
      }
    default:
      view.setSymbolImage(image, contentTransition: ReplaceSymbolEffect.replace)
    }
  }

  // MARK: - Options

  /// What an effect that can repeat does when Flutter sets no repeat.
  private enum DefaultRepeat { case system, forever, once }

  /// The effects whose repeat behaviour can be chosen. The system defaults
  /// differ per effect (a running breathe plays once and stops, a triggered
  /// pulse keeps going), so these get an explicit one.
  private static let repeatable: Set<String> = ["bounce", "pulse", "variableColor", "wiggle", "breathe", "rotate"]

  /// Speed and repeat behaviour. Without a repeat from Flutter, a running
  /// effect repeats until it is removed and a triggered one plays once.
  @available(iOS 17.0, *)
  private static func options(_ m: [String: Any], defaultRepeat: DefaultRepeat = .system) -> SymbolEffectOptions {
    var opts = SymbolEffectOptions.default
    if let speed = (m["speed"] as? NSNumber)?.doubleValue, speed > 0 {
      opts = opts.speed(speed)
    }
    switch m["repeat"] as? String {
    case "once":
      opts = opts.nonRepeating
    case "continuous":
      if #available(iOS 18.0, *) { opts = opts.repeat(.continuous) } else { opts = opts.repeating }
    case "periodic":
      let count = (m["repeatCount"] as? NSNumber)?.intValue
      let delay = (m["repeatDelay"] as? NSNumber)?.doubleValue
      if #available(iOS 18.0, *) {
        opts = opts.repeat(.periodic(count, delay: delay))
      } else {
        opts = count != nil ? opts.repeat(count) : opts.repeating
      }
    default:
      guard repeatable.contains(m["type"] as? String ?? "") else { break }
      switch defaultRepeat {
      case .forever:
        if #available(iOS 18.0, *) { opts = opts.repeat(.continuous) } else { opts = opts.repeating }
      case .once:
        if #available(iOS 18.0, *) { opts = opts.repeat(.periodic(1)) } else { opts = opts.repeat(1) }
      case .system:
        break
      }
    }
    return opts
  }

  // MARK: - Adding

  // UIKit takes every effect through one method; which overload of
  // `addSymbolEffect` Swift picks decides whether an effect that is both
  // discrete and indefinite (pulse, variableColor, and from iOS 18 bounce,
  // wiggle, breathe and rotate) plays once or keeps running. Calling it from
  // a generic function that only knows one of the two protocols picks that
  // overload, whatever else the effect conforms to.

  @available(iOS 17.0, *)
  private static func discrete<E: SymbolEffect & DiscreteSymbolEffect>(
    _ effect: E, on view: UIImageView, options: SymbolEffectOptions
  ) {
    view.addSymbolEffect(effect, options: options, animated: true)
  }

  @available(iOS 17.0, *)
  private static func indefinite<E: SymbolEffect & IndefiniteSymbolEffect>(
    _ effect: E, on view: UIImageView, options: SymbolEffectOptions, animated: Bool
  ) {
    view.addSymbolEffect(effect, options: options, animated: animated)
  }

  // MARK: - Effects

  private static func isByLayer(_ m: [String: Any]) -> Bool { m["scope"] as? String == "byLayer" }
  private static func isWhole(_ m: [String: Any]) -> Bool { m["scope"] as? String == "wholeSymbol" }

  @available(iOS 17.0, *)
  private static func bounce(_ m: [String: Any]) -> BounceSymbolEffect {
    var e = BounceSymbolEffect.bounce
    switch m["direction"] as? String {
    case "up": e = e.up
    case "down": e = e.down
    default: break
    }
    if isByLayer(m) { e = e.byLayer } else if isWhole(m) { e = e.wholeSymbol }
    return e
  }

  @available(iOS 17.0, *)
  private static func pulse(_ m: [String: Any]) -> PulseSymbolEffect {
    var e = PulseSymbolEffect.pulse
    if isByLayer(m) { e = e.byLayer } else if isWhole(m) { e = e.wholeSymbol }
    return e
  }

  @available(iOS 17.0, *)
  private static func variableColor(_ m: [String: Any]) -> VariableColorSymbolEffect {
    var e = VariableColorSymbolEffect.variableColor
    if (m["cumulative"] as? NSNumber)?.boolValue == true { e = e.cumulative }
    if (m["reversing"] as? NSNumber)?.boolValue == true { e = e.reversing }
    if (m["hideInactiveLayers"] as? NSNumber)?.boolValue == true { e = e.hideInactiveLayers }
    return e
  }

  @available(iOS 17.0, *)
  private static func scale(_ m: [String: Any]) -> ScaleSymbolEffect {
    var e = ScaleSymbolEffect.scale
    switch m["direction"] as? String {
    case "up": e = e.up
    case "down": e = e.down
    default: break
    }
    if isByLayer(m) { e = e.byLayer } else if isWhole(m) { e = e.wholeSymbol }
    return e
  }

  @available(iOS 18.0, *)
  private static func wiggle(_ m: [String: Any]) -> WiggleSymbolEffect {
    var e = WiggleSymbolEffect.wiggle
    if let angle = (m["angle"] as? NSNumber)?.doubleValue {
      e = e.custom(angle: angle)
    } else {
      switch m["direction"] as? String {
      case "up": e = e.up
      case "down": e = e.down
      case "left": e = e.left
      case "right": e = e.right
      case "forward": e = e.forward
      case "backward": e = e.backward
      case "clockwise": e = e.clockwise
      case "counterClockwise": e = e.counterClockwise
      default: break
      }
    }
    if isByLayer(m) { e = e.byLayer } else if isWhole(m) { e = e.wholeSymbol }
    return e
  }

  @available(iOS 18.0, *)
  private static func breathe(_ m: [String: Any]) -> BreatheSymbolEffect {
    var e = BreatheSymbolEffect.breathe
    if (m["pulse"] as? NSNumber)?.boolValue == true { e = e.pulse }
    if isByLayer(m) { e = e.byLayer } else if isWhole(m) { e = e.wholeSymbol }
    return e
  }

  @available(iOS 18.0, *)
  private static func rotate(_ m: [String: Any]) -> RotateSymbolEffect {
    var e = RotateSymbolEffect.rotate
    switch m["direction"] as? String {
    case "clockwise": e = e.clockwise
    case "counterClockwise": e = e.counterClockwise
    default: break
    }
    if isByLayer(m) { e = e.byLayer } else if isWhole(m) { e = e.wholeSymbol }
    return e
  }

  @available(iOS 26.0, *)
  private static func drawOn(_ m: [String: Any]) -> DrawOnSymbolEffect {
    var e = DrawOnSymbolEffect.drawOn
    switch m["scope"] as? String {
    case "byLayer": e = e.byLayer
    case "wholeSymbol": e = e.wholeSymbol
    case "individually": e = e.individually
    default: break
    }
    return e
  }

  @available(iOS 26.0, *)
  private static func drawOff(_ m: [String: Any]) -> DrawOffSymbolEffect {
    var e = DrawOffSymbolEffect.drawOff
    switch m["scope"] as? String {
    case "byLayer": e = e.byLayer
    case "wholeSymbol": e = e.wholeSymbol
    case "individually": e = e.individually
    default: break
    }
    if (m["reversed"] as? NSNumber)?.boolValue == true { e = e.reversed }
    return e
  }
}
