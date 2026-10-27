import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/presentation/history_pane.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryEntry _entry(String id, DateTime startedAt) => HistoryEntry(
  id: id,
  topic: 'prod-db',
  startedAt: startedAt,
  state: IncidentState.acked,
  ringDuration: const Duration(minutes: 4),
);

HistoryDay _day(List<HistoryEntry> entries) => HistoryDay(
  day: entries.first.day,
  entries: entries,
);

void main() {
  final now = DateTime(2026, 10, 27, 18);
  final newest = _entry('newest', now);
  final earlier = _entry('earlier', now.subtract(const Duration(hours: 3)));
  final lastWeek = _entry('last-week', now.subtract(const Duration(days: 6)));

  group('historyPaneEntry', () {
    test('nothing picked opens on the newest incident', () {
      final days = [
        _day([newest, earlier]),
        _day([lastWeek]),
      ];
      expect(historyPaneEntry(days, null), newest);
    });

    test('the newest wins even when the list is out of order', () {
      final days = [
        _day([lastWeek]),
        _day([earlier, newest]),
      ];
      expect(historyPaneEntry(days, null), newest);
    });

    test('a picked incident that is still listed stays picked', () {
      final days = [
        _day([newest, earlier]),
        _day([lastWeek]),
      ];
      expect(historyPaneEntry(days, 'last-week'), lastWeek);
    });

    test('a picked incident a filter took away shows the empty state', () {
      final days = [
        _day([newest]),
      ];
      expect(historyPaneEntry(days, 'last-week'), isNull);
    });

    test('the incident the pane opened on stays when a newer one lands', () {
      final days = [
        _day([newest, earlier]),
      ];
      expect(historyPaneEntry(days, null, openedId: 'earlier'), earlier);
    });

    test('an opened incident that has gone falls back to the newest', () {
      final days = [
        _day([newest]),
      ];
      expect(historyPaneEntry(days, null, openedId: 'earlier'), newest);
    });

    test('no incidents, nothing to show', () {
      expect(historyPaneEntry(const [], null), isNull);
    });
  });

  group('historyHeroFaceSize', () {
    test('120 on a tablet and a wide window', () {
      expect(historyHeroFaceSize(const AppSize(834, 1194)), 120);
      expect(historyHeroFaceSize(const AppSize(1440, 900)), 120);
    });

    test('60 on a phone, a narrow book pane and a short pane', () {
      expect(historyHeroFaceSize(const AppSize(390, 844)), 60);
      expect(historyHeroFaceSize(const AppSize(404, 701)), 60);
      expect(historyHeroFaceSize(const AppSize(841, 342)), 60);
    });

    test('120 beside the card in a tabletop stage', () {
      expect(historyHeroFaceSize(const AppSize(841, 342), isBeside: true), 120);
    });

    test('72 on a cover screen', () {
      expect(historyHeroFaceSize(const AppSize(384, 388)), 72);
    });
  });
}
