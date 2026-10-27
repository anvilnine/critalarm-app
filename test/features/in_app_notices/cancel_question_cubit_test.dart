import 'package:critalarm/core/models/cancel_reason.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_sink.dart';
import 'package:critalarm/features/in_app_notices/presentation/cancel_question/cancel_question_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Sink implements CancelAnswerSink {
  final reasons = <CancelReason>[];
  final texts = <(CancelReason, String)>[];

  @override
  Future<void> sendReason(CancelReason reason) async => reasons.add(reason);

  @override
  Future<void> sendText(CancelReason reason, String text) async =>
      texts.add((reason, text));
}

void main() {
  late _Sink sink;
  late CancelQuestionCubit cubit;

  setUp(() {
    sink = _Sink();
    cubit = CancelQuestionCubit(sink);
  });

  tearDown(() => cubit.close());

  test('starts on the question', () {
    expect(cubit.state.step, CancelQuestionStep.question);
    expect(cubit.state.reason, isNull);
  });

  test('a chip tap opens the text field and sends the reason at once', () {
    cubit.pick(CancelReason.selfhost);
    expect(cubit.state.step, CancelQuestionStep.explain);
    expect(cubit.state.reason, CancelReason.selfhost);
    expect(sink.reasons, [CancelReason.selfhost]);
    expect(sink.texts, isEmpty);
  });

  test('a second tap changes nothing and sends nothing', () {
    cubit
      ..pick(CancelReason.price)
      ..pick(CancelReason.broken);
    expect(cubit.state.reason, CancelReason.price);
    expect(sink.reasons, hasLength(1));
  });

  test('Send sends the cleaned text as a second send', () {
    cubit
      ..pick(CancelReason.missing)
      ..send('  a dark theme for the alarm screen  ');
    expect(cubit.state.step, CancelQuestionStep.thanks);
    expect(sink.texts, [
      (CancelReason.missing, 'a dark theme for the alarm screen'),
    ]);
  });

  test('Send with only spaces ends on thanks and sends no text', () {
    cubit
      ..pick(CancelReason.other)
      ..send('   ');
    expect(cubit.state.step, CancelQuestionStep.thanks);
    expect(sink.texts, isEmpty);
  });

  test('long text is cut to 500 characters', () {
    cubit
      ..pick(CancelReason.other)
      ..send('z' * 900);
    expect(sink.texts.single.$2.length, 500);
  });

  test('Send before a chip does nothing', () {
    cubit.send('hello');
    expect(cubit.state.step, CancelQuestionStep.question);
    expect(sink.texts, isEmpty);
  });

  test('Send twice sends the text once', () {
    cubit
      ..pick(CancelReason.other)
      ..send('first')
      ..send('second');
    expect(sink.texts, hasLength(1));
  });

  test(
    'closing after a chip leaves the chip answer sent and no text',
    () async {
      cubit.pick(CancelReason.unused);
      await cubit.close();
      expect(sink.reasons, hasLength(1));
      expect(sink.texts, isEmpty);
    },
  );
}
