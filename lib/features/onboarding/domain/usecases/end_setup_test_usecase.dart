import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';

/// How ending one setup test on the server went.
enum SetupTestEnd {
  /// The server closed it.
  closed,

  /// The server has nothing left to close: it does not know the incident,
  /// or had already finished with it.
  gone,

  /// The server could not be asked, or refused. The incident may ring again.
  failed,
}

/// Ends a test incident setup asked the server for, so it cannot ring again.
///
/// A test that was acknowledged and left open rings again when its desk
/// timer runs out, and one that was never answered keeps repeating. Either
/// way it would arrive later looking like a real alarm. This acknowledges
/// the incident when it still needs it, closes it, and tries the close a
/// second time if the first fails.
///
/// When it still fails the id is handed to [SetupTestRing.markUnclosed]: it
/// stops counting as a setup test, so a later ring from it proves nothing,
/// and it is kept so [closeLeftovers] can close it when the app next opens.
///
/// Only ever called with an id [SetupTestRing] holds. Never throws.
class EndSetupTestUsecase {
  const EndSetupTestUsecase(this._ring, this._acknowledge, this._close);

  final SetupTestRing _ring;
  final AcknowledgeIncidentUsecase _acknowledge;
  final CloseIncidentUsecase _close;

  /// [isAcknowledged] true skips the acknowledge, for the test the user has
  /// just answered on the alarm screen. [onClosed] gets the server's copy.
  Future<SetupTestEnd> call(
    String incidentId, {
    bool isAcknowledged = false,
    void Function(Incident closed)? onClosed,
  }) async {
    final end = await _end(
      incidentId,
      isAcknowledged: isAcknowledged,
      onClosed: onClosed,
    );
    try {
      if (end == SetupTestEnd.failed) {
        await _ring.markUnclosed(incidentId);
      } else {
        await _ring.markClosed(incidentId);
      }
    } on Object catch (_) {
      // The phone would not save it. Nothing more can be done here.
    }
    return end;
  }

  /// Closes every test an earlier try could not. Run when the app opens.
  Future<void> closeLeftovers() async {
    // A copy: ending one takes it out of the set being walked.
    for (final id in {..._ring.unclosedIds}) {
      await call(id);
    }
  }

  Future<SetupTestEnd> _end(
    String incidentId, {
    required bool isAcknowledged,
    void Function(Incident closed)? onClosed,
  }) async {
    try {
      if (!isAcknowledged) {
        final acked = await _acknowledge(incidentId);
        final failure = acked.exceptionOrNull();
        if (failure != null) {
          if (_isUnknown(failure)) return SetupTestEnd.gone;
          // A state conflict means it is already past open, which is fine.
          // Anything else and the close below could not work either.
          if (!_isStateConflict(failure)) return SetupTestEnd.failed;
        }
      }
      var result = await _close(incidentId);
      if (_shouldRetry(result)) result = await _close(incidentId);
      final failure = result.exceptionOrNull();
      if (failure == null) {
        final closed = result.getOrNull();
        if (closed != null) onClosed?.call(closed);
        return SetupTestEnd.closed;
      }
      // Acknowledged above or by the user, so a state conflict on the close
      // can only mean the incident is already closed or expired.
      if (_isUnknown(failure) || _isStateConflict(failure)) {
        return SetupTestEnd.gone;
      }
      return SetupTestEnd.failed;
    } on Object catch (_) {
      return SetupTestEnd.failed;
    }
  }

  static bool _shouldRetry(AppResult<Incident> result) {
    final failure = result.exceptionOrNull();
    return failure != null &&
        !_isUnknown(failure) &&
        !_isStateConflict(failure);
  }

  static bool _isStateConflict(Failure failure) =>
      failure is ConflictFailure ||
      (failure is ApiFailure && failure.statusCode == 409);

  static bool _isUnknown(Failure failure) =>
      failure is NotFoundFailure ||
      (failure is ApiFailure &&
          (failure.statusCode == 404 || failure.statusCode == 410));
}
