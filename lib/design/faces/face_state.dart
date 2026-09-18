/// The seven expressive states of the Crit Alarm face character.
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
}
