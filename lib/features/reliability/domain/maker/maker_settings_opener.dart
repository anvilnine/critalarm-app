import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';

/// Opens the nearest settings page from a list of candidates.
// One method today, and it stays an interface so there is something to fake.
// ignore: one_member_abstracts
abstract interface class MakerSettingsOpener {
  /// Tries [candidates] in order and stops at the first that opens. Returns
  /// its index, or -1 when none did. Never throws: a phone without the
  /// component, a refused start and a missing native side all answer -1.
  Future<int> open(List<MakerIntentCandidate> candidates);
}
