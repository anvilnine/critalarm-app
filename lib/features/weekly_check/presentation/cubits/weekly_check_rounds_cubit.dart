import 'package:critalarm/core/api/weekly_check_api.dart';
import 'package:critalarm/core/models/weekly_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The list of rounds: loading, the rounds, or a read that failed.
@immutable
final class WeeklyCheckRoundsState {
  const WeeklyCheckRoundsState({
    this.rounds,
    this.isLoading = false,
    this.didFail = false,
  });

  /// Newest first. Null until the relay has answered.
  final List<WeeklyCheckRound>? rounds;
  final bool isLoading;
  final bool didFail;

  @override
  bool operator ==(Object other) =>
      other is WeeklyCheckRoundsState &&
      listEquals(other.rounds, rounds) &&
      other.isLoading == isLoading &&
      other.didFail == didFail;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(rounds ?? const []), isLoading, didFail);
}

/// Reads `GET .../checks`. The list is the relay's and is not kept on the
/// phone. It answers with or without the pack.
class WeeklyCheckRoundsCubit extends Cubit<WeeklyCheckRoundsState> {
  WeeklyCheckRoundsCubit(this._api) : super(const WeeklyCheckRoundsState());

  /// How many rounds the page asks for. The relay keeps 90 days of them.
  static const limit = 50;

  final WeeklyCheckApi _api;

  Future<void> load() async {
    if (state.isLoading) return;
    emit(WeeklyCheckRoundsState(rounds: state.rounds, isLoading: true));
    try {
      final rounds = await _api.listWeeklyCheckRounds(limit: limit);
      if (isClosed) return;
      emit(WeeklyCheckRoundsState(rounds: rounds));
    } on Object catch (error) {
      debugPrint('weekly_check_rounds_failed error=${error.runtimeType}');
      if (isClosed) return;
      emit(WeeklyCheckRoundsState(rounds: state.rounds, didFail: true));
    }
  }
}
