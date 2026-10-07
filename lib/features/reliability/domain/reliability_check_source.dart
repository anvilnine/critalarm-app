import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';

/// One place checks come from. A source answers for the checks it owns and
/// nothing else, so a new source is a new class and one line in
/// `lib/app/di.dart`.
///
/// Rules for a source:
///
/// - Read from the phone and answer. No prompts, no network calls the user
///   would notice, nothing sent to the server.
/// - Return a check as `ReliabilityCheck.notOnThisPhone` when it has no
///   meaning here, rather than leaving it out, so the list says what was
///   asked.
/// - A source may throw. `ReliabilityCubit` drops that source's checks for
///   this read and keeps the rest.
// One method today, and it stays an interface so there is something to fake.
// ignore: one_member_abstracts
abstract interface class ReliabilityCheckSource {
  Future<List<ReliabilityCheck>> read();
}
