import 'dart:async';

import 'package:critalarm/features/tour/domain/repositories/tour_repository.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_state.dart';
import 'package:critalarm/features/tour/presentation/tour_steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Which "How to use the app" guide is showing, and which step of it. One
/// for the whole app, because the full tour walks across screens.
///
/// Home first offers a tour. Until the user answers, no guide plays. After
/// that each screen has its own short guide that plays the first time the
/// user gets there. Settings can start the full tour or any single guide.
///
/// This only keeps count. Moving between screens, scrolling and drawing the
/// spotlight is the TourHost's job.
class TourCubit extends Cubit<TourState> {
  TourCubit(this._repository) : super(const TourState());

  final TourRepository _repository;

  /// The name the example topic goes by.
  static const exampleTopicName = 'prod-db';

  bool hasSeen(TourGuide guide) => _repository.hasSeenGuide(guide.name);

  /// True once the offer on Topics was answered, by taking it, declining it,
  /// or finishing the Topics guide. The sheets and reminders that wait for
  /// setup wait for it.
  bool get hasSeenFirstGuide => hasSeen(TourGuide.home);

  /// Called as a screen comes up. While the offer is unanswered, Topics
  /// raises it and every other screen waits. After that, asks for [guide] if
  /// this device has not seen it yet. Ignored while something else is going:
  /// that screen's guide plays on the next visit instead.
  void requestIfNew(TourGuide guide) {
    if (state.isActive) return;
    if (!hasSeenFirstGuide) {
      if (guide == TourGuide.home) {
        emit(
          const TourState(status: TourStatus.offering, guide: TourGuide.home),
        );
      }
      return;
    }
    if (hasSeen(guide)) return;
    _request(guide);
  }

  /// The user said yes to the offer. Plays the short Topics guide, not the
  /// full tour. Does nothing unless the offer is up.
  void acceptOffer() {
    if (state.status != TourStatus.offering) return;
    emit(const TourState(status: TourStatus.requested, guide: TourGuide.home));
  }

  /// The user said no to the offer, or dismissed it. Every guide counts as
  /// seen, so none plays on its own again. Settings still has them all.
  void declineOffer() {
    if (state.status != TourStatus.offering) return;
    unawaited(_repository.markGuidesSeen(TourGuide.values.map((g) => g.name)));
    emit(const TourState());
  }

  /// Asks for what the Settings list picked, seen or not: [guide], or the
  /// full tour when it is null. A single guide moves to its own screen and
  /// ends back on Settings.
  void requestGuide(TourGuide? guide) =>
      _request(guide, fromMenu: guide != null);

  /// Asks for the full tour, seen or not.
  void request() => requestGuide(null);

  void _request(TourGuide? guide, {bool fromMenu = false}) {
    if (state.isActive) return;
    emit(
      TourState(
        status: TourStatus.requested,
        guide: guide,
        fromMenu: fromMenu,
      ),
    );
  }

  /// Starts what was asked for. [firstTopicName] is the user's first topic,
  /// or null when they have none, in which case the tour shows example
  /// topics.
  void begin({String? firstTopicName}) {
    if (state.status != TourStatus.requested) return;
    final usingExamples = firstTopicName == null;
    emit(
      TourState(
        status: TourStatus.running,
        guide: state.guide,
        topicName: firstTopicName ?? exampleTopicName,
        usingExamples: usingExamples,
        fromMenu: state.fromMenu,
      ),
    );
  }

  void next() {
    if (!state.isRunning) return;
    if (state.isLastStep) {
      finish();
      return;
    }
    emit(state.copyWith(stepIndex: state.stepIndex + 1));
  }

  void back() {
    if (!state.isRunning || state.isFirstStep) return;
    emit(state.copyWith(stepIndex: state.stepIndex - 1));
  }

  /// Skip and Done both land here. Either way the user has seen enough not to
  /// be shown it again unasked. The full replay counts for every guide.
  void finish() {
    if (!state.isActive) return;
    final guide = state.guide;
    unawaited(
      _repository.markGuidesSeen(
        guide == null ? TourGuide.values.map((g) => g.name) : [guide.name],
      ),
    );
    emit(const TourState());
  }

  /// Something more important took the screen, such as an alarm. The guide
  /// or the offer goes without being marked seen, so it comes back next time
  /// its screen opens.
  void stop() {
    if (!state.isActive) return;
    emit(const TourState());
  }

  /// Skips a step whose spot never turned up. Used when a screen is missing
  /// a piece, so the tour moves on instead of hanging on an empty spotlight.
  void skipMissing(int stepIndex) {
    if (!state.isRunning || state.stepIndex != stepIndex) return;
    next();
  }
}
