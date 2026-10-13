/// The key that says the sad opening was shown for one end date: the date
/// itself, as `yyyy-MM-dd` in the phone's zone.
String leavingSeenKeyFor(DateTime endsOn) {
  String two(int n) => n.toString().padLeft(2, '0');
  final year = endsOn.year.toString().padLeft(4, '0');
  return '$year-${two(endsOn.month)}-${two(endsOn.day)}';
}

/// Whether the sad opening was already shown for [endsOn]. [stored] is the
/// date last written, null when none was.
bool leavingWasShown(String? stored, DateTime endsOn) =>
    stored != null && stored == leavingSeenKeyFor(endsOn);
