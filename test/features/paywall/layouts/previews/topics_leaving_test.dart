import 'package:critalarm/features/paywall/presentation/layouts/previews/topics_preview.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('topicsLeavingRowsFor', () {
    int on(List<TopicsLeavingRow> rows) =>
        rows.where((r) => r == TopicsLeavingRow.on).length;

    test('one critical topic: one row on, then the new topic', () {
      expect(topicsLeavingRowsFor(critical: 1, fit: 4), [
        TopicsLeavingRow.on,
        TopicsLeavingRow.fresh,
      ]);
    });

    test('two critical topics: two rows on, then the new topic', () {
      expect(topicsLeavingRowsFor(critical: 2, fit: 4), [
        TopicsLeavingRow.on,
        TopicsLeavingRow.on,
        TopicsLeavingRow.fresh,
      ]);
    });

    test('three critical topics: three rows on, then the new topic', () {
      expect(topicsLeavingRowsFor(critical: 3, fit: 4), [
        TopicsLeavingRow.on,
        TopicsLeavingRow.on,
        TopicsLeavingRow.on,
        TopicsLeavingRow.fresh,
      ]);
    });

    test('seven critical topics: the rows that fit are on, new topic last', () {
      expect(topicsLeavingRowsFor(critical: 7, fit: 4), [
        TopicsLeavingRow.on,
        TopicsLeavingRow.on,
        TopicsLeavingRow.on,
        TopicsLeavingRow.fresh,
      ]);
      expect(topicsLeavingRowsFor(critical: 7, fit: 3), [
        TopicsLeavingRow.on,
        TopicsLeavingRow.on,
        TopicsLeavingRow.fresh,
      ]);
    });

    test('no critical topic: only the new topic, off', () {
      expect(topicsLeavingRowsFor(critical: 0, fit: 4), [
        TopicsLeavingRow.fresh,
      ]);
    });

    test('no existing row is ever off, and the last row is always new', () {
      for (final critical in [0, 1, 2, 3, 4, 7, 40]) {
        for (final fit in [1, 2, 3, 4]) {
          final rows = topicsLeavingRowsFor(critical: critical, fit: fit);
          expect(rows, hasLength(lessThanOrEqualTo(fit)));
          expect(rows.last, TopicsLeavingRow.fresh);
          expect(
            rows.take(rows.length - 1).every((r) => r == TopicsLeavingRow.on),
            isTrue,
            reason: '$critical critical, room for $fit',
          );
          // The rows that are on are the count, until the card has no room.
          expect(on(rows), critical < fit ? critical : fit - 1);
        }
      }
    });
  });

  group('topicsLeavingLayoutFor', () {
    test('a card draws a row for every count the sentence can say', () {
      for (final edge in [160.0, 180.0, 197.0, 200.0]) {
        for (final (critical, rows) in [(1, 2), (2, 3), (3, 4), (7, 4)]) {
          final layout = topicsLeavingLayoutFor(
            Size.square(edge),
            critical: critical,
          );
          expect(layout.rows, rows, reason: '$critical on a $edge card');
          // The names are drawn where they read, bars where they do not.
          expect(layout.showsNames, edge >= 197 || critical < 3);
          expect(
            layout.rowHeight * layout.rows,
            lessThanOrEqualTo(edge - 2 * layout.padding + 0.001),
          );
        }
      }
    });

    test('the rows drawn and the rows that are on agree with the count', () {
      for (final critical in [1, 2, 3, 7]) {
        final layout = topicsLeavingLayoutFor(
          const Size.square(197),
          critical: critical,
        );
        final rows = topicsLeavingRowsFor(critical: critical, fit: layout.rows);
        final on = rows.where((r) => r == TopicsLeavingRow.on).length;
        expect(on, critical > 3 ? 3 : critical);
        expect(rows, hasLength(layout.rows));
      }
    });
  });

  test('the names are made up, the new topic has its own', () {
    expect(
      topicsLeavingNames(
        topicsLeavingRowsFor(critical: 2, fit: 4),
      ),
      ['prod-db', 'uptime-kuma', topicsLeavingNewName],
    );
  });
}
