import 'package:critalarm/core/notifications/app_badge.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';

/// Puts the number of open incidents on the app icon.
///
/// Closing the last one leaves zero, which clears the badge. A failed read
/// leaves the badge alone rather than guessing at zero.
final class UpdateIncidentBadgeUsecase {
  const UpdateIncidentBadgeUsecase(this._incidents, this._badge);

  final IncidentRepository _incidents;
  final AppBadge _badge;

  Future<int?> call() async {
    final result = await _incidents.getIncidents(state: 'open');
    final incidents = result.getOrNull();
    if (incidents == null) return null;
    await _badge.setCount(incidents.length);
    return incidents.length;
  }
}
