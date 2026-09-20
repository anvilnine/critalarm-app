import 'dart:math' as math;
import 'dart:ui' show Color;

/// Expressive states of the Crit Alarm face character.
enum FaceState {
  /// All clear / normal state. Round eyes, easy mouth.
  calm,

  /// Waiting on input or initial setup. Eyes drift, raised brow.
  watching,

  /// High priority message open. Pinching brows, wavering mouth.
  worried,

  /// Critical alarm ringing. Wide eyes, open mouth, heavy stroke, shaking.
  alarmed,

  /// Alarm acknowledged. Closed eyes arches, gentle mouth, cobalt canvas.
  acked,

  /// Refreshing. Squeezed `> <` eyes, wiggly mouth, small shake.
  working,

  /// A refresh finished. Dot eyes, small `v` mouth, lines popping above.
  success,

  /// Wide open eyes with brow furrow and open screaming mouth with tongue.
  shocked,

  /// Joyful squeezed `> <` eyes, wide open laughing grin with tongue.
  laughing,

  /// High arched brows, glossy eyes with shine highlights, round open 'O'
  /// mouth.
  surprised,

  /// Asymmetrical cocked brow with raised inquisitiveness, slanted smirk line.
  skeptical,

  /// Drooping worried brows, hypnotic spiral swirl eyes, wavy wobble mouth.
  dizzy,

  /// Fierce V-brows, sparkling glossy anime eyes, yelling mouth with tongue.
  determined,

  /// Inquisitive head tilt, asymmetrical puzzled brows, flat slanted mouth.
  confused,

  /// Downward drooping sad brows, deep frown mouth.
  sad,

  /// Eyes shut mid blink, everything else where calm leaves it.
  blink,

  /// Delighted. Eyes curved shut with a warm smile.
  happy,

  /// Relaxed. Eyes gently closed, small easy smile.
  content,

  /// Eyes up and over, one brow lifted, soft smile.
  curious,

  /// Pupils slid to the left, noticing something.
  lookLeft,

  /// Pupils slid to the right, noticing something.
  lookRight,

  /// One brow up, eyes off to the side, mouth flat.
  thinking,

  /// Wide eyes, both brows up, small open mouth.
  interested,

  /// Brows tipped in, eyes down, mouth curved down.
  concerned,

  /// Eyes wide, brows up, small round mouth, pop lines.
  realization,

  /// Eyes squeezed shut, mouth stretched wide open.
  yawn,

  /// Heavy lids drooping, small pursed mouth.
  sleepy,

  /// Eyes shut, small round mouth, Zzz drifting up.
  dozing,

  /// Eyes snapped open, brows up, small round mouth.
  wakesUp,

  /// Eyes squeezed shut, wavy mouth, head rocked over.
  shakeHead,

  /// Eyes closed, small round mouth drawing air in.
  breatheIn,

  /// Eyes closed, mouth pursed, a puff beside it.
  breatheOut,

  /// Brows up, eyes up and away, pleased little smile.
  proud,

  /// One eye winked shut, the other open, smirking.
  cheeky,

  /// Brows level and low, eyes to one side, smirk.
  confident,

  /// Soft eyes, warm smile, a heart above the head.
  love,
}

/// Metadata and presentation helpers for [FaceState].
extension FaceStatePresentation on FaceState {
  /// User-facing display title for the expression.
  String get label => switch (this) {
    FaceState.calm => 'Calm',
    FaceState.watching => 'Watching',
    FaceState.worried => 'Worried',
    FaceState.alarmed => 'Alarmed',
    FaceState.acked => 'Acknowledged',
    FaceState.working => 'Working',
    FaceState.success => 'Success',
    FaceState.shocked => 'Shocked',
    FaceState.laughing => 'Laughing',
    FaceState.surprised => 'Surprised',
    FaceState.skeptical => 'Skeptical',
    FaceState.dizzy => 'Dizzy',
    FaceState.determined => 'Determined',
    FaceState.confused => 'Confused',
    FaceState.sad => 'Sad',
    FaceState.blink => 'Blink',
    FaceState.happy => 'Happy',
    FaceState.content => 'Content',
    FaceState.curious => 'Curious',
    FaceState.lookLeft => 'Look left',
    FaceState.lookRight => 'Look right',
    FaceState.thinking => 'Thinking',
    FaceState.interested => 'Interested',
    FaceState.concerned => 'Concerned',
    FaceState.realization => 'Realization',
    FaceState.yawn => 'Yawn',
    FaceState.sleepy => 'Sleepy',
    FaceState.dozing => 'Dozing',
    FaceState.wakesUp => 'Wakes up',
    FaceState.shakeHead => 'Shake head',
    FaceState.breatheIn => 'Breathe in',
    FaceState.breatheOut => 'Breathe out',
    FaceState.proud => 'Proud',
    FaceState.cheeky => 'Cheeky',
    FaceState.confident => 'Confident',
    FaceState.love => 'Love',
  };

  /// A short descriptive summary of the expression's features.
  String get description => switch (this) {
    FaceState.calm => 'Round dot eyes and an easy smile.',
    FaceState.watching => 'Raised eyebrow with drifting pupils.',
    FaceState.worried => 'Pinching brows and a wavering mouth.',
    FaceState.alarmed => 'Wide outer eyes, ringing open mouth.',
    FaceState.acked => 'Closed eye arches and calm expression.',
    FaceState.working => 'Squeezed chevron eyes and wavy mouth.',
    FaceState.success => 'Pop lines bursting above a smiling face.',
    FaceState.shocked => 'Wide white eyes, brow furrow, open scream.',
    FaceState.laughing => 'Squeezed eyes, wide grin with bottom tongue.',
    FaceState.surprised => 'Raised brows, shiny pupil highlights, O-mouth.',
    FaceState.skeptical => 'Cocked raised eyebrow, slanted smirk line.',
    FaceState.dizzy => 'Drooping brows, hypnotic swirl eyes, wavy mouth.',
    FaceState.determined => 'Sharp V-brows, sparkly manga eyes, open shout.',
    FaceState.confused => 'Asymmetrical brows, slanted mouth, tilted head.',
    FaceState.sad => 'Drooping inverted brows, downward curved frown.',
    FaceState.blink => 'Eyes shut mid blink, the rest left alone.',
    FaceState.happy => 'Delighted. Eyes curved shut with a warm smile.',
    FaceState.content => 'Relaxed. Eyes gently closed, small easy smile.',
    FaceState.curious => 'Eyes up and over, one brow lifted, soft smile.',
    FaceState.lookLeft => 'Pupils slid to the left, noticing something.',
    FaceState.lookRight => 'Pupils slid to the right, noticing something.',
    FaceState.thinking => 'One brow up, eyes off to the side, mouth flat.',
    FaceState.interested => 'Wide eyes, both brows up, small open mouth.',
    FaceState.concerned => 'Brows tipped in, eyes down, mouth curved down.',
    FaceState.realization =>
      'Eyes wide, brows up, small round mouth, pop lines.',
    FaceState.yawn => 'Eyes squeezed shut, mouth stretched wide open.',
    FaceState.sleepy => 'Heavy lids drooping, small pursed mouth.',
    FaceState.dozing => 'Eyes shut, small round mouth, Zzz drifting up.',
    FaceState.wakesUp => 'Eyes snapped open, brows up, small round mouth.',
    FaceState.shakeHead => 'Eyes squeezed shut, wavy mouth, head rocked over.',
    FaceState.breatheIn => 'Eyes closed, small round mouth drawing air in.',
    FaceState.breatheOut => 'Eyes closed, mouth pursed, a puff beside it.',
    FaceState.proud => 'Brows up, eyes up and away, pleased little smile.',
    FaceState.cheeky => 'One eye winked shut, the other open, smirking.',
    FaceState.confident => 'Brows level and low, eyes to one side, smirk.',
    FaceState.love => 'Soft eyes, warm smile, a heart above the head.',
  };

  /// Authentic sample screenshot accent color (e.g. Cyan Blue for laughing,
  /// Warm Orange for surprised, Fresh Green for dizzy, Yellow for others).
  Color get characteristicColor => switch (this) {
    FaceState.laughing => const Color(0xFF4EAAD8),
    FaceState.surprised => const Color(0xFFE2673D),
    FaceState.dizzy => const Color(0xFF3FA652),
    _ => const Color(0xFFFFC93C),
  };

  /// Natural expression head tilt angle in radians.
  /// Confused has an endearing -8 degree inquisitiveness tilt.
  double get defaultTilt => switch (this) {
    FaceState.confused => -8.0 * math.pi / 180.0,
    _ => 0.0,
  };
}
