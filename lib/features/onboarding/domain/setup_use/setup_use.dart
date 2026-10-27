/// What the user says they will mostly send alarms from.
///
/// Picked on the `use` step. The [wire] id is what the phone stores and the
/// only thing that leaves it (as a closed analytics word), so a shipped id
/// never changes. [other] is also what a skip and a missing answer read as.
enum SetupUse {
  servers,
  homelab,
  jobs,
  home,
  other;

  /// Saved on the phone. Equal to the enum name. Never changes once shipped.
  String get wire => name;

  /// The answer saved as [wire], or null for anything else, including a
  /// different case and an empty string.
  static SetupUse? tryParse(String? wire) {
    for (final use in values) {
      if (use.wire == wire) return use;
    }
    return null;
  }
}
