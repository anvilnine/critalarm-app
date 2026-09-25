/// The ways the face can ring. Each one is a looping animation built from
/// the same rig as every other face, plus the extras in `ringing_frame.dart`.
enum RingingStyle {
  /// The alarm face as it has always been, with a proper shout and shake.
  classic,

  /// Pupils darting, sweat flying, a wobbling scream.
  panic,

  /// Red in the face, teeth gritted, steam off both sides.
  rage,

  /// Head rocking side to side under a stream of question marks.
  confused,

  /// Swirl eyes and stars circling a wobbling head.
  dizzy,

  /// Wailing, with tears arcing out of both eyes.
  sobbing,

  /// Stretched tall, pinprick pupils, mouth wide open.
  scream,

  /// Alarm clock bells on top of the head, wincing at every hit.
  bellHead,

  /// Eyes boinging out of the head and the jaw hitting the floor.
  eyesPop,

  /// Heavy lids, a long eye roll and a sigh.
  annoyed,

  /// Dozing, then launched off the ground by the ring.
  startled,

  /// Short fast breaths, cheeks puffing in and out.
  hyperventilating,

  /// Flickering between light and dark with bolts all around, then smoking.
  zapped,

  /// Bouncing off the floor, squashing on every landing.
  bouncing,

  /// Shrunk down, shaking, teeth chattering.
  terrified,

  /// A siren on its head and a mouth going wee-oo.
  siren,

  /// Melting into a puddle of drips, then snapping back.
  meltdown,

  /// A full spin, then wobbling to a stop with swirling eyes.
  spinOut,
}

/// Names, notes and timing for [RingingStyle].
extension RingingStylePresentation on RingingStyle {
  /// What the style is called in the developer screens.
  String get label => switch (this) {
    RingingStyle.classic => 'Classic ring',
    RingingStyle.panic => 'Panic',
    RingingStyle.rage => 'Rage',
    RingingStyle.confused => 'Confused',
    RingingStyle.dizzy => 'Dizzy',
    RingingStyle.sobbing => 'Sobbing',
    RingingStyle.scream => 'Scream',
    RingingStyle.bellHead => 'Alarm clock',
    RingingStyle.eyesPop => 'Eyes pop',
    RingingStyle.annoyed => 'Annoyed',
    RingingStyle.startled => 'Startled awake',
    RingingStyle.hyperventilating => 'Hyperventilating',
    RingingStyle.zapped => 'Zapped',
    RingingStyle.bouncing => 'Bouncing',
    RingingStyle.terrified => 'Terrified',
    RingingStyle.siren => 'Siren',
    RingingStyle.meltdown => 'Meltdown',
    RingingStyle.spinOut => 'Spin out',
  };

  /// One line on what the animation does.
  String get description => switch (this) {
    RingingStyle.classic =>
      'Slammed brows, ringed eyes, a pulsing shout and sound waves.',
    RingingStyle.panic =>
      'Pupils darting side to side, sweat flying, a wobbling scream.',
    RingingStyle.rage =>
      'Flushing red, gritted teeth, steam jets and a throbbing vein.',
    RingingStyle.confused =>
      'Head rocking under popping question marks, eyes out of step.',
    RingingStyle.dizzy =>
      'Spinning swirl eyes, stars in orbit, head wobbling in circles.',
    RingingStyle.sobbing =>
      'Wailing sobs that heave the head, tears arcing out both sides.',
    RingingStyle.scream =>
      'Head stretched tall, pinprick pupils, a huge open scream.',
    RingingStyle.bellHead =>
      'Two bells on its head and a striker, wincing at every clang.',
    RingingStyle.eyesPop =>
      'Eyes boing out of the head, brows fly off, jaw drops.',
    RingingStyle.annoyed =>
      'Heavy lids, a slow eye roll up and over, then a long sigh.',
    RingingStyle.startled =>
      'Snoozing until the ring launches it into the air.',
    RingingStyle.hyperventilating =>
      'Short fast breaths, cheeks puffing, sweat on the brow.',
    RingingStyle.zapped =>
      'Flickering light and dark between bolts, then smoking.',
    RingingStyle.bouncing =>
      'Bouncing off the floor, squashing flat on every landing.',
    RingingStyle.terrified =>
      'Shrunk down, trembling, teeth chattering, eyes darting.',
    RingingStyle.siren =>
      'A spinning siren on top, mouth going wee-oo, flushing red.',
    RingingStyle.meltdown =>
      'Melting into drips under the heat, then snapping back.',
    RingingStyle.spinOut =>
      'A full spin, then wobbling to a stop with swirling eyes.',
  };

  /// How long one loop of the animation takes at normal speed.
  Duration get period => Duration(
    milliseconds: switch (this) {
      RingingStyle.classic => 1200,
      RingingStyle.panic => 1600,
      RingingStyle.rage => 1400,
      RingingStyle.confused => 2400,
      RingingStyle.dizzy => 2000,
      RingingStyle.sobbing => 1800,
      RingingStyle.scream => 1000,
      RingingStyle.bellHead => 1200,
      RingingStyle.eyesPop => 1800,
      RingingStyle.annoyed => 2800,
      RingingStyle.startled => 2600,
      RingingStyle.hyperventilating => 900,
      RingingStyle.zapped => 1600,
      RingingStyle.bouncing => 800,
      RingingStyle.terrified => 1200,
      RingingStyle.siren => 1600,
      RingingStyle.meltdown => 3200,
      RingingStyle.spinOut => 2000,
    },
  );

  /// The moment of the loop shown when motion is off: the one that reads
  /// best standing still.
  double get stillT => switch (this) {
    RingingStyle.startled => 0.55,
    RingingStyle.eyesPop => 0.4,
    RingingStyle.annoyed => 0.4,
    RingingStyle.meltdown => 0.65,
    RingingStyle.spinOut => 0.7,
    RingingStyle.zapped => 0.2,
    RingingStyle.bouncing => 0.5,
    _ => 0.25,
  };
}
