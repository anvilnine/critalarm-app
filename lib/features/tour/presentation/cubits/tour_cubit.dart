import 'dart:async';

import 'package:critalarm/features/tour/domain/repositories/tour_repository.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_state.dart';
import 'package:critalarm/features/tour/presentation/tour_steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Which step of the "How to use the app" tour is showing. One for the whole
/// app, because the tour walks across screens.
///
/// This only keeps count. Moving between screens, scrolling and drawing the
/// spotlight is the TourHost's job.
class TourCubit extends Cubit<TourState> {
  TourCubit(this._repository) : super(const TourState());

  final TourRepository _repository;

  /// The name the example topic goes by.
  static const exampleTopicName = 'prod-db';

  /// Asks for the tour on first run only. Home calls this every time it
  /// opens.
  void requestIfNew() {
    if (_repository.hasSeenTour()) return;
    request();
  }

  /// Asks for the tour, seen or not. Settings calls this.
  void request() {
    if (state.status != TourStatus.idle) return;
    emit(state.copyWith(status: TourStatus.requested));
  }

  /// Starts the tour. [firstTopicName] is the user's first topic, or null when
  /// they have none, in which case the tour shows example topics.
  void begin({String? firstTopicName}) {
    if (state.status != TourStatus.requested) return;
    final usingExamples = firstTopicName == null;
    emit(
      TourState(
        status: TourStatus.running,
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
  /// be shown it again unasked.
  void finish() {
    if (state.status == TourStatus.idle) return;
    unawaited(_repository.markTourSeen());
    emit(const TourState());
  }

  /// Something more important took the screen, such as an alarm. The tour
  /// goes without being marked seen, so it comes back next time Home opens.
  void stop() {
    if (state.status == TourStatus.idle) return;
    emit(const TourState());
  }

  /// Skips a step whose spot never turned up. Used when a screen is missing
  /// a piece, so the tour moves on instead of hanging on an empty spotlight.
  void skipMissing(int stepIndex) {
    if (!state.isRunning || state.stepIndex != stepIndex) return;
    next();
  }

  static int get stepCount => tourSteps.length;
}
