/// The looks the in-app alarm screen can be drawn in.
///
/// A look changes how the ringing and acknowledged screens are drawn and
/// nothing else: never a button's place, size or label, never sound,
/// vibration or timing, and never what is sent to a server.
///
/// [id] is saved on phones, as the phone's default and per topic, so a
/// shipped id never changes. An id this build does not know draws as
/// [standard].
enum AlarmStyleId {
  /// The look the alarm screen has always had. Free on every plan.
  standard('standard'),

  /// A plain canvas, no shapes behind it and no pulse ring, the face
  /// small, the topic and the time large.
  minimal('minimal'),

  /// A dark console: mono type, phosphor green, a prompt with a block
  /// cursor that blinks.
  terminal('terminal'),

  /// Battle stations: a deep red room, a light bar sweeping down it, the
  /// stage word large.
  redAlert('red_alert'),

  /// Crit's own yellow turned up: ink on yellow, rays behind the face
  /// that jolt with the ring.
  critPanic('crit_panic');

  const AlarmStyleId(this.id);

  final String id;

  /// True for the one look that needs no plan.
  bool get isFree => this == AlarmStyleId.standard;

  /// The look saved as [id], or null for none, or for an id from a build
  /// that knows more looks than this one.
  static AlarmStyleId? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final style in values) {
      if (style.id == id) return style;
    }
    return null;
  }
}
