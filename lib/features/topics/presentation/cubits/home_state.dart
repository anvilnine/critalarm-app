import 'package:critalarm/features/topics/domain/home_card/home_facts.dart';
import 'package:critalarm/features/topics/domain/home_card/inbox_order.dart';
import 'package:flutter/foundation.dart';

enum HomeStatus { initial, loading, success, failure }

/// View model for a topic row in the Home screen sheet.
@immutable
class HomeTopicItem {
  const HomeTopicItem({
    required this.name,
    this.ringsThroughSilent = false,
    this.preview,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.lastMessageAt,
    this.rowKind = InboxRowKind.normal,
  });

  final String name;

  /// True when critical delivery is on for this topic, so a page rings
  /// through the silent switch.
  final bool ringsThroughSilent;

  /// The newest message on the topic, cut to one line. Null when the topic
  /// has no message yet.
  final String? preview;

  /// Messages that came in since the user last read this topic on this phone.
  final int unreadCount;

  /// Pinned to the top of the list on this phone.
  final bool isPinned;

  /// Muted on this phone. Greyed out and moved below the rest.
  final bool isMuted;

  /// When the newest message held for this topic came in. Null when the
  /// topic has none.
  final DateTime? lastMessageAt;

  /// What state the row is in: a sounding alarm, a warning, an acknowledged
  /// alarm, a missed one, a handled one, or none of them.
  final InboxRowKind rowKind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeTopicItem &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          ringsThroughSilent == other.ringsThroughSilent &&
          preview == other.preview &&
          unreadCount == other.unreadCount &&
          isPinned == other.isPinned &&
          isMuted == other.isMuted &&
          lastMessageAt == other.lastMessageAt &&
          rowKind == other.rowKind;

  @override
  int get hashCode => Object.hash(
    name,
    ringsThroughSilent,
    preview,
    unreadCount,
    isPinned,
    isMuted,
    lastMessageAt,
    rowKind,
  );
}

/// State for the Home screen.
@immutable
class HomeState {
  const HomeState({
    this.status = HomeStatus.initial,
    this.topicItems = const [],
    this.ringingIncidentId,
    this.errorMessage,
    this.isStale = false,
    this.lastKnownGoodAt,
    this.hasServer = true,
    this.facts = HomeFacts.none,
  });

  final HomeStatus status;
  final List<HomeTopicItem> topicItems;

  /// The open incident that is ringing right now, if there is one. The app is
  /// the alarm while this is set: the list hands the user to the takeover
  /// screen instead of making them hunt for a way to stop it.
  final String? ringingIncidentId;
  final String? errorMessage;

  /// True when the rows on screen are an old copy: a server is set up, the app
  /// cannot reach it right now, and this is what the list looked like the last
  /// time it answered. False whenever the list is live, and false when there
  /// is no old copy to show.
  final bool isStale;

  /// When the list on screen last came back from the server. Set on every good
  /// build, so a later failure can say how old the rows are.
  final DateTime? lastKnownGoodAt;

  /// False when no server is saved at all. The screen has one job then, which
  /// the red card above already does, so the list below it draws nothing.
  /// True by default, because every other state has a server to talk about.
  final bool hasServer;

  /// What Home knows about alarms and messages, for the card.
  final HomeFacts facts;

  bool get isEmpty => topicItems.isEmpty && status == HomeStatus.success;

  HomeState copyWith({
    HomeStatus? status,
    List<HomeTopicItem>? topicItems,
    String? ringingIncidentId,
    bool clearRinging = false,
    String? errorMessage,
    bool clearError = false,
    bool? isStale,
    DateTime? lastKnownGoodAt,
    bool clearLastKnownGood = false,
    bool? hasServer,
    HomeFacts? facts,
  }) {
    return HomeState(
      status: status ?? this.status,
      topicItems: topicItems ?? this.topicItems,
      ringingIncidentId: clearRinging
          ? null
          : (ringingIncidentId ?? this.ringingIncidentId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isStale: isStale ?? this.isStale,
      lastKnownGoodAt: clearLastKnownGood
          ? null
          : (lastKnownGoodAt ?? this.lastKnownGoodAt),
      hasServer: hasServer ?? this.hasServer,
      facts: facts ?? this.facts,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          listEquals(topicItems, other.topicItems) &&
          ringingIncidentId == other.ringingIncidentId &&
          errorMessage == other.errorMessage &&
          isStale == other.isStale &&
          lastKnownGoodAt == other.lastKnownGoodAt &&
          hasServer == other.hasServer &&
          facts == other.facts;

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAll(topicItems),
    ringingIncidentId,
    errorMessage,
    isStale,
    lastKnownGoodAt,
    hasServer,
    facts,
  );
}
