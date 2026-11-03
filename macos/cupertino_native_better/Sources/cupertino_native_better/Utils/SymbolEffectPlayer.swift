import Cocoa
import Symbols

/// Plays the SF Symbol effects Flutter sends as `CNSymbolEffect.toMap()` on a
/// `NSImageView`.
///
/// The macOS port of the iOS `SymbolEffectPlayer`. Every effect is gated by
/// the macOS version that introduced it (14, 15 or 26). Where it is missing the call does nothing, so the symbol stays still.
enum SymbolEffectPlayer {
  /// Whether `effect` is `drawOn` or `drawOff`, which show or hide the symbol
  /// instead of animating it in place.
  static func isDraw(_ effect: [String: Any]?) -> Bool {
    let type = effect?["type"] as? String
    return type == "drawOn" || type == "drawOff"
  }

  // MARK: - Running effects (`CNIcon.effect`)

  /// Starts `effect` as a running effect that lasts until it is removed.
  @available(macOS 14.0, *)
  static func start(_ effect: [String: Any], on view: NSImageView, animated: Bool = true) {
    let opts = options(effect)
    switch effect["type"] as? String {
    case "bounce":
      // Bounce only runs indefinitely from macOS 15 on.
      if #available(macOS 15.0, *) {
        view.addSymbolEffect(bounce(effect), options: opts, animated: animated)
      }
    case "pulse":
      view.addSymbolEffect(pulse(effect), options: opts, animated: animated)
    case "variableColor":
      view.addSymbolEffect(variableColor(effect), options: opts, animated: animated)
    case "scale":
      view.addSymbolEffect(scale(effect), options: opts, animated: animated)
    case "wiggle":
      if #available(macOS 15.0, *) { view.addSymbolEffect(wiggle(effect), options: opts, animated: animated) }
    case "breathe":
      if #available(macOS 15.0, *) { view.addSymbolEffect(breathe(effect), options: opts, animated: animated) }
    case "rotate":
      if #available(macOS 15.0, *) { view.addSymbolEffect(rotate(effect), options: opts, animated: animated) }
    case "drawOn":
      if #available(macOS 26.0, *) { view.addSymbolEffect(drawOn(effect), options: opts, animated: animated) }
    case "drawOff":
      if #available(macOS 26.0, *) { view.addSymbolEffect(drawOff(effect), options: opts, animated: animated) }
    default:
      break
    }
  }

  /// Replaces the running effect `old` with `new` (either may be nil).
  ///
  /// Switching between the draw effects adds the new one on top, so the
  /// symbol draws in from where `drawOff` left it; removing every effect
  /// first would show it again at once.
  @available(macOS 14.0, *)
  static func transition(from old: [String: Any]?, to new: [String: Any]?, on view: NSImageView) {
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
  @available(macOS 14.0, *)
  static func play(_ effect: [String: Any], on view: NSImageView) {
    let opts = options(effect, oneShot: true)
    switch effect["type"] as? String {
    case "bounce":
      view.addSymbolEffect(bounce(effect), options: opts)
    case "pulse":
      view.addSymbolEffect(pulse(effect), options: opts)
    case "variableColor":
      view.addSymbolEffect(variableColor(effect), options: opts)
    case "wiggle":
      if #available(macOS 15.0, *) { view.addSymbolEffect(wiggle(effect), options: opts) }
    case "breathe":
      if #available(macOS 15.0, *) { view.addSymbolEffect(breathe(effect), options: opts) }
    case "rotate":
      if #available(macOS 15.0, *) { view.addSymbolEffect(rotate(effect), options: opts) }
    case "drawOn":
      // Hide the symbol at once, then draw it in.
      if #available(macOS 26.0, *) {
        view.addSymbolEffect(DrawOffSymbolEffect.drawOff, options: .default, animated: false)
        view.addSymbolEffect(drawOn(effect), options: options(effect))
      }
    default:
      break
    }
  }

  // MARK: - Replace transition (`CNIcon.replaceTransition`)

  /// Shows `image` with the content transition Flutter calls `transition`.
  @available(macOS 14.0, *)
  static func replace(with image: NSImage, on view: NSImageView, transition: String) {
    switch transition {
    case "downUp":
      view.setSymbolImage(image, contentTransition: ReplaceSymbolEffect.replace.downUp)
    case "upUp":
      view.setSymbolImage(image, contentTransition: ReplaceSymbolEffect.replace.upUp)
    case "offUp":
      view.setSymbolImage(image, contentTransition: ReplaceSymbolEffect.replace.offUp)
    case "magic":
      if #available(macOS 15.0, *) {
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

  /// Speed and repeat behaviour. A one-shot effect without a repeat of its
  /// own is asked to play once, so effects that can also run indefinitely,
  /// such as pulse, stop after one play.
  @available(macOS 14.0, *)
  private static func options(_ m: [String: Any], oneShot: Bool = false) -> SymbolEffectOptions {
    var opts = SymbolEffectOptions.default
    if let speed = (m["speed"] as? NSNumber)?.doubleValue, speed > 0 {
      opts = opts.speed(speed)
    }
    switch m["repeat"] as? String {
    case "once":
      opts = opts.nonRepeating
    case "continuous":
      if #available(macOS 15.0, *) { opts = opts.repeat(.continuous) } else { opts = opts.repeating }
    case "periodic":
      let count = (m["repeatCount"] as? NSNumber)?.intValue
      let delay = (m["repeatDelay"] as? NSNumber)?.doubleValue
      if #available(macOS 15.0, *) {
        opts = opts.repeat(.periodic(count, delay: delay))
      } else {
        opts = count != nil ? opts.repeat(count) : opts.repeating
      }
    default:
      if oneShot { opts = opts.nonRepeating }
    }
    return opts
  }

  // MARK: - Effects

  private static func isByLayer(_ m: [String: Any]) -> Bool { m["scope"] as? String == "byLayer" }
  private static func isWhole(_ m: [String: Any]) -> Bool { m["scope"] as? String == "wholeSymbol" }

  @available(macOS 14.0, *)
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

  @available(macOS 14.0, *)
  private static func pulse(_ m: [String: Any]) -> PulseSymbolEffect {
    var e = PulseSymbolEffect.pulse
    if isByLayer(m) { e = e.byLayer } else if isWhole(m) { e = e.wholeSymbol }
    return e
  }

  @available(macOS 14.0, *)
  private static func variableColor(_ m: [String: Any]) -> VariableColorSymbolEffect {
    var e = VariableColorSymbolEffect.variableColor
    if (m["cumulative"] as? NSNumber)?.boolValue == true { e = e.cumulative }
    if (m["reversing"] as? NSNumber)?.boolValue == true { e = e.reversing }
    if (m["hideInactiveLayers"] as? NSNumber)?.boolValue == true { e = e.hideInactiveLayers }
    return e
  }

  @available(macOS 14.0, *)
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

  @available(macOS 15.0, *)
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

  @available(macOS 15.0, *)
  private static func breathe(_ m: [String: Any]) -> BreatheSymbolEffect {
    var e = BreatheSymbolEffect.breathe
    if (m["pulse"] as? NSNumber)?.boolValue == true { e = e.pulse }
    if isByLayer(m) { e = e.byLayer } else if isWhole(m) { e = e.wholeSymbol }
    return e
  }

  @available(macOS 15.0, *)
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

  @available(macOS 26.0, *)
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

  @available(macOS 26.0, *)
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
