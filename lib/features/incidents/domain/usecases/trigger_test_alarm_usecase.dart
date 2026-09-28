import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_store.dart';
import 'package:flutter/foundation.dart';

/// Usecase to trigger a test alarm on a critical topic.
///
/// A test the server accepted is what the fire drill (idea 1) counts from,
/// so a success stamps `lastTestAt` for the topic. Onboarding, Settings and
/// the test ring screen all come through here. [onTested] then runs, so the
/// app can plan the reminders again.
class TriggerTestAlarmUsecase implements UseCase<String, String> {
  TriggerTestAlarmUsecase(
    this._repository, {
    LocalReminderStore? localReminderStore,
    DateTime Function()? now,
    this.onTested,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _localReminderStore = localReminderStore,
       _now = now ?? DateTime.now;

  final IncidentRepository _repository;
  final LocalReminderStore? _localReminderStore;
  final DateTime Function() _now;

  /// Told about a topic whose test ring the server accepted.
  final void Function(String topic)? onTested;

  @override
  Future<AppResult<String>> call(String topic) async {
    final result = await _repository.triggerTest(topic: topic);
    if (result.isSuccess()) {
      await _localReminderStore?.markTested(topic, _now());
      // A failing hook must not turn a rung test into a thrown error.
      try {
        onTested?.call(topic);
      } on Object catch (error) {
        debugPrint(
          'TriggerTestAlarmUsecase: onTested failed: ${error.runtimeType}',
        );
      }
    }
    return result;
  }
}
