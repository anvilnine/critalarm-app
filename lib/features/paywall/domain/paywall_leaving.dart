import 'package:critalarm/features/paywall/domain/leaving_numbers.dart';
import 'package:critalarm/features/paywall/domain/leaving_seen.dart';
import 'package:flutter/foundation.dart';

/// What the leaving paywall knows besides its layout: the day the plan
/// ends, whether the sad opening was already shown for that day, and the
/// person's numbers.
///
/// It travels in the paywall's location and goes nowhere else. The numbers
/// are the person's own: nothing here is sent, counted or logged.
@immutable
class PaywallLeaving {
  const PaywallLeaving({
    required this.endsOn,
    this.atRest = false,
    this.facts,
  });

  /// The day the plan ends: a calendar date in the phone's zone, at 00:00.
  final DateTime endsOn;

  /// True when the sad opening was shown for [endsOn] already: the layout
  /// opens at rest, with no tear and no print.
  final bool atRest;

  /// Null when the numbers could not be counted.
  final LeavingFacts? facts;

  Map<String, String> toQuery() => {
    'ends': leavingSeenKeyFor(endsOn),
    if (atRest) 'rest': '1',
    ...?facts?.toQuery(),
  };

  static final RegExp _date = RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$');

  /// The leaving part of a location, or null without a valid `ends`.
  static PaywallLeaving? fromQuery(Map<String, String> query) {
    final text = query['ends'];
    if (text == null || !_date.hasMatch(text)) return null;
    final parts = text.split('-').map(int.parse).toList();
    final date = DateTime(parts[0], parts[1], parts[2]);
    // 2026-02-30 would read as 2 March. Only a date that reads back is one.
    if (leavingSeenKeyFor(date) != text) return null;
    return PaywallLeaving(
      endsOn: date,
      atRest: query['rest'] == '1',
      facts: LeavingFacts.fromQuery(query),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PaywallLeaving &&
      other.endsOn == endsOn &&
      other.atRest == atRest &&
      other.facts == facts;

  @override
  int get hashCode => Object.hash(endsOn, atRest, facts);
}
