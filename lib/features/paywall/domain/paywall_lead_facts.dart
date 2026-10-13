import 'package:flutter/foundation.dart';

/// What the screen that opened the critical limit paywall knows, so the
/// paywall can show the person's own numbers: how many critical topics are
/// on, the limit, and the name of the topic they were making.
///
/// It travels in the paywall's location (`used`, `limit`, `topic`) and goes
/// nowhere else: no request, no analytics event, no log line. The topic
/// name is the person's own data and is only drawn on screen. Every value
/// is checked on the way out and on the way back in: a paywall with a junk
/// query opens with no facts.
@immutable
class PaywallLeadFacts {
  const PaywallLeadFacts({this.used, this.limit, this.topicName});

  factory PaywallLeadFacts.fromQuery(Map<String, String> query) =>
      PaywallLeadFacts(
        used: _count(query['used']),
        limit: _count(query['limit']),
        topicName: _name(query['topic']),
      );

  final int? used;
  final int? limit;
  final String? topicName;

  bool get isEmpty => used == null && limit == null && topicName == null;

  /// The location's `used`, `limit` and `topic` entries. A value the
  /// location may not hold is left out.
  Map<String, String> toQuery() {
    final count = used == null ? null : _count('$used');
    final cap = limit == null ? null : _count('$limit');
    final name = _name(topicName);
    return {
      if (count != null) 'used': '$count',
      if (cap != null) 'limit': '$cap',
      'topic': ?name,
    };
  }

  static final RegExp _digits = RegExp(r'^[0-9]{1,3}$');
  static final RegExp _topic = RegExp(r'^[a-z0-9_-]{1,64}$');

  static int? _count(String? value) =>
      value != null && _digits.hasMatch(value) ? int.parse(value) : null;

  static String? _name(String? value) {
    final name = value?.trim().toLowerCase();
    return name != null && _topic.hasMatch(name) ? name : null;
  }

  @override
  bool operator ==(Object other) =>
      other is PaywallLeadFacts &&
      other.used == used &&
      other.limit == limit &&
      other.topicName == topicName;

  @override
  int get hashCode => Object.hash(used, limit, topicName);

  /// Counts and the name stay out of a log line.
  @override
  String toString() => 'PaywallLeadFacts()';
}
