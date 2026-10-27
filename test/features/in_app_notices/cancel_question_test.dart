import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_store.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_question.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Store implements CancelAnswerStore {
  String? askedFor;

  @override
  String? readAskedFor() => askedFor;

  @override
  Future<void> writeAskedFor(String key) async => askedFor = key;

  @override
  List<CancelAnswer> readPending() => const [];

  @override
  Future<void> writePending(List<CancelAnswer> entries) async {}
}

void main() {
  late _Store store;
  late CancelQuestion question;
  final endsAt = DateTime(2026, 10, 20, 9);

  // The store's expiry as an instant. `endsAt` is the same moment as wall
  // clock time on a phone in some zone; the key never reads it.
  final instant = DateTime.parse('2026-10-20T09:15:02Z');

  ProEndingView ending({DateTime? at, bool billingIssue = false}) {
    final when = at ?? instant;
    return ProEndingView(
      sheet: ProPlanSheet.ending,
      endsAt: DateTime(when.year, when.month, when.day, when.hour),
      endsAtInstant: when,
      hasBillingIssue: billingIssue,
    );
  }

  setUp(() {
    store = _Store();
    question = CancelQuestion(store: store);
  });

  test('is due on the ending sheet and on the pill that follows it', () {
    expect(question.dueFor(ending())?.endsAtInstant, instant);
    expect(
      question
          .dueFor(
            ProEndingView(
              showPill: true,
              endsAt: endsAt,
              endsAtInstant: instant,
            ),
          )
          ?.endsAtInstant,
      instant,
    );
  });

  test('is not due when the plan is not ending', () {
    expect(question.dueFor(ProEndingView.nothing), isNull);
    expect(
      question.dueFor(const ProEndingView(sheet: ProPlanSheet.ended)),
      isNull,
    );
  });

  test('is asked once per end date', () async {
    await question.ask(question.dueFor(ending())!, () async {});
    expect(question.dueFor(ending()), isNull);
  });

  test('is asked again after a new cancel', () async {
    await question.ask(question.dueFor(ending())!, () async {});
    expect(
      question.dueFor(ending(at: DateTime.parse('2026-11-20T09:15:02Z'))),
      isNotNull,
    );
  });

  test('a sheet closed any way counts as asked: it is marked first', () async {
    String? seenWhileShowing;
    await question.ask(question.dueFor(ending())!, () async {
      seenWhileShowing = store.askedFor;
    });
    expect(seenWhileShowing, isNotNull);
  });

  test('a sheet that never finishes still counts as asked', () async {
    // The app dies while the sheet is up: the mark was written before it.
    final never = question.ask(
      question.dueFor(ending())!,
      () => Future<void>.delayed(const Duration(days: 1)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(store.askedFor, isNotNull);
    expect(question.dueFor(ending()), isNull);
    never.ignore();
  });

  test('is not due while a billing issue is on record', () {
    expect(question.dueFor(ending(billingIssue: true)), isNull);
  });

  test('the same expiry read in two time zones is asked once', () async {
    // Manila reads 17:15:02 and New York 05:15:02 for the one instant. The key
    // comes from the instant, so the second phone's view is already asked.
    final manila = DateTime.parse('2026-10-20T17:15:02+08:00');
    final newYork = DateTime.parse('2026-10-20T05:15:02-04:00');
    ProEndingView read(DateTime wall, DateTime at) => ProEndingView(
      sheet: ProPlanSheet.ending,
      endsAt: wall,
      endsAtInstant: at,
    );
    final first = question.dueFor(
      read(DateTime(2026, 10, 20, 17, 15, 2), manila),
    )!;
    await question.ask(first, () async {});
    expect(
      question.dueFor(read(DateTime(2026, 10, 20, 5, 15, 2), newYork)),
      isNull,
    );
  });

  test('is not due when the instant of the end is unknown', () {
    expect(
      question.dueFor(
        ProEndingView(sheet: ProPlanSheet.ending, endsAt: endsAt),
      ),
      isNull,
    );
  });
}
