import 'dart:async';

import 'package:critalarm/core/models/cancel_reason.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_sink.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The three states of the cancel question sheet.
enum CancelQuestionStep { question, explain, thanks }

@immutable
final class CancelQuestionState {
  const CancelQuestionState({
    this.step = CancelQuestionStep.question,
    this.reason,
  });

  final CancelQuestionStep step;

  /// The chip that was tapped. Null on the question.
  final CancelReason? reason;
}

/// Runs the sheet. It never waits for a send and never shows one failing: a
/// failed send is the sender's to keep and retry.
final class CancelQuestionCubit extends Cubit<CancelQuestionState> {
  CancelQuestionCubit(this._sink) : super(const CancelQuestionState());

  final CancelAnswerSink _sink;

  /// A chip tap is a full answer. It opens the text field before the send
  /// comes back, and a second tap does nothing: the answer is one.
  void pick(CancelReason reason) {
    if (state.step != CancelQuestionStep.question) return;
    emit(CancelQuestionState(step: CancelQuestionStep.explain, reason: reason));
    unawaited(_sink.sendReason(reason));
  }

  /// The Send button. [rawText] is what the field holds. Spaces only go to
  /// thanks without a second send.
  void send(String rawText) {
    if (state.step != CancelQuestionStep.explain) return;
    final reason = state.reason!;
    final text = cleanCancelText(rawText);
    emit(CancelQuestionState(step: CancelQuestionStep.thanks, reason: reason));
    if (text != null) unawaited(_sink.sendText(reason, text));
  }
}
