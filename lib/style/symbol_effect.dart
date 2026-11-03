/// SF Symbol animations for [CNIcon].
///
/// {@category Styles}
library;

import 'package:flutter/foundation.dart';

/// The animations an SF Symbol can play, as listed by Apple's Symbols
/// framework.
///
/// Each one needs a minimum OS version; on an older one the icon stays still.
enum CNSymbolEffectType {
  /// Scales the symbol briefly up or down and back (iOS 17+, macOS 14+).
  ///
  /// Plays once when triggered; as a running effect it repeats, which needs
  /// iOS 18+ / macOS 15+.
  bounce,

  /// Fades the symbol's opacity in and out (iOS 17+, macOS 14+).
  pulse,

  /// Lights up the variable layers of a symbol one after another, such as
  /// the arcs of `wifi` or the waves of `speaker.wave.3` (iOS 17+,
  /// macOS 14+). Symbols without variable layers do not move.
  variableColor,

  /// Scales the symbol up or down and keeps it there while the effect runs
  /// (iOS 17+, macOS 14+). It has no one-shot form, so it does nothing as a
  /// triggered effect.
  scale,

  /// Shakes the symbol along a direction or around its centre (iOS 18+,
  /// macOS 15+).
  wiggle,

  /// Scales the symbol smoothly up and down, like breathing (iOS 18+,
  /// macOS 15+).
  breathe,

  /// Turns the symbol, or the layers the symbol marks as rotating, such as
  /// the blades of `fan` (iOS 18+, macOS 15+).
  rotate,

  /// Draws the symbol's strokes in, as if with a pen (iOS 26+, macOS 26+).
  ///
  /// As a running effect it draws a hidden symbol back in; as a triggered
  /// effect it hides the symbol and draws it in again.
  drawOn,

  /// Draws the symbol's strokes out and keeps it hidden while the effect runs
  /// (iOS 26+, macOS 26+). It has no one-shot form, so it does nothing as a
  /// triggered effect.
  drawOff,
}

/// Which way a [CNSymbolEffect] moves. Each effect takes only some of them;
/// see its constructor.
enum CNSymbolEffectDirection {
  /// Upwards (bounce, scale, wiggle).
  up,

  /// Downwards (bounce, scale, wiggle).
  down,

  /// To the left (wiggle).
  left,

  /// To the right (wiggle).
  right,

  /// Towards the reading direction's end (wiggle).
  forward,

  /// Towards the reading direction's start (wiggle).
  backward,

  /// Clockwise (wiggle, rotate).
  clockwise,

  /// Counter-clockwise (wiggle, rotate).
  counterClockwise,
}

/// What part of the symbol a [CNSymbolEffect] animates.
enum CNSymbolEffectScope {
  /// Each layer, or motion group, separately, as the symbol's design marks
  /// them.
  byLayer,

  /// The whole symbol at once.
  wholeSymbol,

  /// Each motion group separately, one at a time. Only the draw effects
  /// support it (iOS 26+, macOS 26+).
  individually,
}

/// How often a [CNSymbolEffect] plays.
@immutable
class CNSymbolEffectRepeat {
  const CNSymbolEffectRepeat._(this._kind, {this.count, this.delay});

  /// Plays at regular intervals, starting and stopping each time.
  ///
  /// [count] is how many times it plays; null leaves it to the system, which
  /// repeats a running effect until it is removed and plays a triggered one
  /// once. [delay] is the pause between plays and needs iOS 18+ / macOS 15+.
  const CNSymbolEffectRepeat.periodic({int? count, Duration? delay})
    : this._('periodic', count: count, delay: delay);

  /// Plays once.
  static const CNSymbolEffectRepeat once = CNSymbolEffectRepeat._('once');

  /// Loops without a pause between plays (iOS 18+, macOS 15+; before that,
  /// repeats periodically).
  static const CNSymbolEffectRepeat continuous = CNSymbolEffectRepeat._(
    'continuous',
  );

  final String _kind;

  /// How many times a periodic repeat plays; null leaves it to the system.
  final int? count;

  /// The pause between periodic plays.
  final Duration? delay;

  Map<String, Object> _encode() => <String, Object>{
    'repeat': _kind,
    if (count != null) 'repeatCount': count!,
    if (delay != null) 'repeatDelay': delay!.inMicroseconds / 1e6,
  };

  @override
  bool operator ==(Object other) =>
      other is CNSymbolEffectRepeat &&
      other._kind == _kind &&
      other.count == count &&
      other.delay == delay;

  @override
  int get hashCode => Object.hash(_kind, count, delay);
}

/// An SF Symbol animation for [CNIcon], played by the native image view with
/// Apple's Symbols framework.
///
/// Use it two ways:
///
/// * As [CNIcon.effect], it runs for as long as it is set — a pulsing
///   recording dot, a `wifi` symbol searching with [variableColor]. Set the
///   property to null to stop it.
/// * As [CNIcon.triggeredEffect], it plays once every time
///   [CNIcon.effectTrigger] changes — a bell that bounces on each new
///   notification.
///
/// ```dart
/// CNIcon(
///   symbol: const CNSymbol('wifi'),
///   effect: searching ? const CNSymbolEffect.variableColor() : null,
/// )
///
/// CNIcon(
///   symbol: const CNSymbol('bell'),
///   triggeredEffect: const CNSymbolEffect.wiggle(),
///   effectTrigger: unreadCount,
/// )
/// ```
///
/// Each effect needs a minimum OS version, listed on [CNSymbolEffectType];
/// where it is missing, and on platforms without SF Symbols, the icon stays
/// still. Effects apply to SF Symbols only, not to image assets or
/// `customIcon`s.
@immutable
class CNSymbolEffect {
  const CNSymbolEffect._(
    this.type, {
    this.direction,
    this.scope,
    this.speed,
    this.repeat,
    this.cumulative = false,
    this.reversing = false,
    this.hideInactiveLayers = false,
    this.pulse = false,
    this.angle,
    this.reversed = false,
  }) : assert(
         direction == null ||
             type == CNSymbolEffectType.wiggle ||
             ((type == CNSymbolEffectType.bounce ||
                     type == CNSymbolEffectType.scale) &&
                 (direction == CNSymbolEffectDirection.up ||
                     direction == CNSymbolEffectDirection.down)) ||
             (type == CNSymbolEffectType.rotate &&
                 (direction == CNSymbolEffectDirection.clockwise ||
                     direction == CNSymbolEffectDirection.counterClockwise)),
         'bounce and scale take up or down, rotate takes clockwise or '
         'counterClockwise',
       );

  /// Bounces the symbol [CNSymbolEffectDirection.up] or
  /// [CNSymbolEffectDirection.down]; the symbol chooses when null.
  const CNSymbolEffect.bounce({
    CNSymbolEffectDirection? direction,
    CNSymbolEffectScope? scope,
    double? speed,
    CNSymbolEffectRepeat? repeat,
  }) : this._(
         CNSymbolEffectType.bounce,
         direction: direction,
         scope: scope,
         speed: speed,
         repeat: repeat,
       );

  /// Pulses the symbol's opacity.
  const CNSymbolEffect.pulse({
    CNSymbolEffectScope? scope,
    double? speed,
    CNSymbolEffectRepeat? repeat,
  }) : this._(
         CNSymbolEffectType.pulse,
         scope: scope,
         speed: speed,
         repeat: repeat,
       );

  /// Lights up the symbol's variable layers in turn.
  ///
  /// [cumulative] keeps each layer lit until all are, instead of lighting
  /// one at a time; [reversing] plays the sequence back down after it goes
  /// up; [hideInactiveLayers] hides the unlit layers instead of dimming them.
  const CNSymbolEffect.variableColor({
    bool cumulative = false,
    bool reversing = false,
    bool hideInactiveLayers = false,
    double? speed,
    CNSymbolEffectRepeat? repeat,
  }) : this._(
         CNSymbolEffectType.variableColor,
         cumulative: cumulative,
         reversing: reversing,
         hideInactiveLayers: hideInactiveLayers,
         speed: speed,
         repeat: repeat,
       );

  /// Scales the symbol [CNSymbolEffectDirection.up] or
  /// [CNSymbolEffectDirection.down] while the effect runs.
  ///
  /// Only works as [CNIcon.effect]; it has no one-shot form.
  const CNSymbolEffect.scale({
    CNSymbolEffectDirection? direction,
    CNSymbolEffectScope? scope,
    double? speed,
  }) : this._(
         CNSymbolEffectType.scale,
         direction: direction,
         scope: scope,
         speed: speed,
       );

  /// Shakes the symbol along [direction], or along the axis at [angle]
  /// degrees when it is set, measured clockwise from pointing right (90 is
  /// down). Without either, the symbol chooses.
  const CNSymbolEffect.wiggle({
    CNSymbolEffectDirection? direction,
    double? angle,
    CNSymbolEffectScope? scope,
    double? speed,
    CNSymbolEffectRepeat? repeat,
  }) : this._(
         CNSymbolEffectType.wiggle,
         direction: direction,
         angle: angle,
         scope: scope,
         speed: speed,
         repeat: repeat,
       );

  /// Breathes the symbol; [pulse] also fades its opacity with each breath.
  const CNSymbolEffect.breathe({
    bool pulse = false,
    CNSymbolEffectScope? scope,
    double? speed,
    CNSymbolEffectRepeat? repeat,
  }) : this._(
         CNSymbolEffectType.breathe,
         pulse: pulse,
         scope: scope,
         speed: speed,
         repeat: repeat,
       );

  /// Turns the symbol [CNSymbolEffectDirection.clockwise] or
  /// [CNSymbolEffectDirection.counterClockwise].
  const CNSymbolEffect.rotate({
    CNSymbolEffectDirection? direction,
    CNSymbolEffectScope? scope,
    double? speed,
    CNSymbolEffectRepeat? repeat,
  }) : this._(
         CNSymbolEffectType.rotate,
         direction: direction,
         scope: scope,
         speed: speed,
         repeat: repeat,
       );

  /// Draws the symbol in (iOS 26+, macOS 26+).
  ///
  /// As [CNIcon.effect] after [CNSymbolEffect.drawOff], it draws the hidden
  /// symbol back in. As [CNIcon.triggeredEffect], it hides the symbol and
  /// draws it in again.
  const CNSymbolEffect.drawOn({CNSymbolEffectScope? scope, double? speed})
    : this._(CNSymbolEffectType.drawOn, scope: scope, speed: speed);

  /// Draws the symbol out and keeps it hidden while it is [CNIcon.effect]
  /// (iOS 26+, macOS 26+). [reversed] erases the strokes from their end
  /// instead of their start.
  ///
  /// Only works as [CNIcon.effect]; it has no one-shot form.
  const CNSymbolEffect.drawOff({
    bool reversed = false,
    CNSymbolEffectScope? scope,
    double? speed,
  }) : this._(
         CNSymbolEffectType.drawOff,
         reversed: reversed,
         scope: scope,
         speed: speed,
       );

  /// Which animation this is.
  final CNSymbolEffectType type;

  /// Which way it moves; null lets the symbol choose.
  final CNSymbolEffectDirection? direction;

  /// What part of the symbol it animates; null lets the symbol choose.
  final CNSymbolEffectScope? scope;

  /// Playback speed; 1 is normal, 2 twice as fast. Null is normal speed.
  final double? speed;

  /// How often it plays; null leaves it to the system.
  final CNSymbolEffectRepeat? repeat;

  /// [CNSymbolEffect.variableColor]: lit layers stay lit.
  final bool cumulative;

  /// [CNSymbolEffect.variableColor]: plays back down after going up.
  final bool reversing;

  /// [CNSymbolEffect.variableColor]: hides unlit layers instead of dimming.
  final bool hideInactiveLayers;

  /// [CNSymbolEffect.breathe]: also fades the opacity.
  final bool pulse;

  /// [CNSymbolEffect.wiggle]: the direction as an angle in degrees.
  final double? angle;

  /// [CNSymbolEffect.drawOff]: erases strokes from their end.
  final bool reversed;

  /// The platform channel encoding of this effect. Only options that are set
  /// are included.
  Map<String, Object> toMap() => <String, Object>{
    'type': type.name,
    if (direction != null) 'direction': direction!.name,
    if (scope != null) 'scope': scope!.name,
    if (speed != null) 'speed': speed!,
    if (repeat != null) ...repeat!._encode(),
    if (cumulative) 'cumulative': true,
    if (reversing) 'reversing': true,
    if (hideInactiveLayers) 'hideInactiveLayers': true,
    if (pulse) 'pulse': true,
    if (angle != null) 'angle': angle!,
    if (reversed) 'reversed': true,
  };

  @override
  bool operator ==(Object other) =>
      other is CNSymbolEffect &&
      other.type == type &&
      other.direction == direction &&
      other.scope == scope &&
      other.speed == speed &&
      other.repeat == repeat &&
      other.cumulative == cumulative &&
      other.reversing == reversing &&
      other.hideInactiveLayers == hideInactiveLayers &&
      other.pulse == pulse &&
      other.angle == angle &&
      other.reversed == reversed;

  @override
  int get hashCode => Object.hash(
    type,
    direction,
    scope,
    speed,
    repeat,
    cumulative,
    reversing,
    hideInactiveLayers,
    pulse,
    angle,
    reversed,
  );
}

/// How [CNIcon] animates from one SF Symbol to another when
/// [CNSymbol.name] changes (iOS 17+, macOS 14+).
enum CNSymbolReplaceTransition {
  /// The old symbol scales out while the new one scales in, in the direction
  /// the symbols choose.
  replace,

  /// The old symbol scales down and the new one scales up.
  downUp,

  /// Both symbols scale up.
  upUp,

  /// The old symbol disappears at once and the new one scales up.
  offUp,

  /// Shared parts stay in place and only the parts that differ animate, such
  /// as the slash of `bell` → `bell.slash` (iOS 18+, macOS 15+; [replace]
  /// before, and for symbol pairs without shared parts).
  magic,
}
