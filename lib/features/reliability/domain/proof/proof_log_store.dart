import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';

/// Where the proof log is kept on the phone.
abstract interface class ProofLogStore {
  /// The kept entries, oldest first, at most 12 weeks. A value that cannot
  /// be read is an empty list.
  List<ProofEntry> read();

  /// Replaces the log. The store keeps the newest 12 weeks.
  Future<void> write(List<ProofEntry> entries);

  Future<void> clear();
}
