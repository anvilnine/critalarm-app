import 'dart:async';

import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/features/in_app_notices/domain/day0_card_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Whether Home draws the day-0 card right now. `true` is the card on screen.
///
/// `Day0CardRules` decides. This cubit stamps what the decision means: the
/// first show (which the other asks read as an ask), each further Home open,
/// and the end. Dismissing and tapping "See plans" both end the card for
/// good.
class Day0CardCubit extends Cubit<bool> {
  Day0CardCubit({
    required this.rules,
    required this.noticeRepository,
    required this.analytics,
  }) : super(false);

  final Day0CardRules rules;
  final InAppNoticeRepository noticeRepository;
  final Day0CardAnalytics analytics;

  /// Reads the rules and applies the answer. Called by `runHomeAsk` after
  /// the sheets had their turn.
  Future<void> evaluate({
    required bool isNewOpen,
    required bool isAskDue,
  }) async {
    final decision = await rules.next(
      isNewOpen: isNewOpen,
      isAskDue: isAskDue,
    );
    if (isClosed) return;
    switch (decision) {
      case Day0CardDecision.none:
        emit(false);
      case Day0CardDecision.start:
        await noticeRepository.markDay0CardShown();
        unawaited(analytics.shown());
        if (!isClosed) emit(true);
      case Day0CardDecision.keep:
        if (isNewOpen) await noticeRepository.markDay0CardOpened();
        if (!isClosed) emit(true);
      case Day0CardDecision.end:
        await noticeRepository.endDay0Card();
        if (!isClosed) emit(false);
    }
  }

  /// The close button. Ends the card for good.
  Future<void> dismiss() async {
    emit(false);
    await noticeRepository.endDay0Card();
    unawaited(analytics.dismissed());
  }

  /// "See plans". Ends the card for good. The screen opens the plans.
  Future<void> seePlans() async {
    emit(false);
    await noticeRepository.endDay0Card();
  }
}
