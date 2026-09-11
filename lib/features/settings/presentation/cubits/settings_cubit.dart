import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state and preferences on the Settings screen.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._getTopicsUsecase) : super(const SettingsState());

  final GetTopicsUsecase _getTopicsUsecase;

  Future<void> load() async {
    emit(state.copyWith(status: SettingsStatus.loading));
    final result = await _getTopicsUsecase(const NoParams());

    result.fold(
      (topicsList) {
        if (topicsList.isEmpty) {
          emit(state.copyWith(status: SettingsStatus.success));
          return;
        }

        final mapped = topicsList.map((t) {
          final priority = switch (t.name) {
            'prod-db' => PriorityLevel.critical,
            'nas-backup' => PriorityLevel.high,
            'uptime-kuma' => PriorityLevel.defaultPriority,
            'home-ha' => PriorityLevel.low,
            _ =>
              t.critical
                  ? PriorityLevel.critical
                  : PriorityLevel.defaultPriority,
          };
          return TopicPriorityItem(name: t.name, priority: priority);
        }).toList();

        emit(
          state.copyWith(
            status: SettingsStatus.success,
            topics: mapped,
          ),
        );
      },
      (failure) {
        emit(
          state.copyWith(
            status: SettingsStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }

  void toggleQuietHours({required bool isEnabled}) {
    emit(state.copyWith(quietHoursEnabled: isEnabled));
  }

  void toggleCriticalRingsQuietHours({required bool isEnabled}) {
    emit(state.copyWith(criticalRingsQuietHours: isEnabled));
  }

  void toggleEscalationCall({required bool isEnabled}) {
    emit(state.copyWith(escalationCallEnabled: isEnabled));
  }

  void setServerUrl(String url) {
    emit(state.copyWith(serverUrl: url));
  }
}
