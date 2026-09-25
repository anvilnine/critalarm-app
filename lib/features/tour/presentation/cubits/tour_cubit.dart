import 'dart:async';

import 'package:critalarm/features/tour/domain/repositories/tour_repository.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_state.dart';
import 'package:critalarm/features/tour/presentation/tour_steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Which "How to use the app" guide is showing, and which step of it. One
/// for the whole app, because the full replay walks across screens.
///
/// Each screen has its own short guide that plays the first time the user
/// gets there. Settings replays all of them in one go.
///
/// This only keeps count. Moving between screens, scrolling and drawing the
/// spotlight is the TourHost's job.
class TourCubit extends Cubit<TourState> {
  TourCubit(this._repository) : super(const TourState());

  final TourRepository _repository;

  /// The name the example topic goes by.
  static const exampleTopicName = 'prod-db';

  bool hasSeen(TourGuide guide) => _repository.hasSeenGuide(guide.name);

  /// True once the Topics guide has been seen or skipped. It is the first
  /// one anybody gets, straight after onboarding, so the sheets and
  /// reminders that wait for setup wait for it.
  bool get hasSeenFirstGuide => hasSeen(TourGuide.home);

  /// Asks for [guide] if this device has not seen it yet. Called as its
  /// screen comes up. Ignored while another guide is going: that screen's
  /// guide plays on the next visit instead.
  void requestIfNew(TourGuide guide) {
    if (hasSeen(guide)) return;
    _request(guide);
  }

  /// Asks for every guide back to back, seen or not. Settings calls this.
  void request() => _request(null);

  void _request(TourGuide? guide) {
    if (state.isActive) return;
    emit(TourState(status: TourStatus.requested, guide: guide));
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
  /// goes without being marked seen, so it comes back next time its screen
  /// opens.
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
