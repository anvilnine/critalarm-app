import 'package:critalarm/core/access/holding.dart';
import 'package:flutter/foundation.dart';

/// The answer to "may this install use this feature".
///
/// One of [FeatureOpen], [FeatureLocked], [FeatureConfirming],
/// [FeatureUnread] and [FeatureNotOffered]. A caller that only needs yes or
/// no reads [isUsable].
@immutable
sealed class FeatureDecision {
  const FeatureDecision();

  /// Use it.
  const factory FeatureDecision.open() = FeatureOpen;

  /// Not held. [offer] is the holding to sell.
  const factory FeatureDecision.locked(Holding offer) = FeatureLocked;

  /// A purchase of [holding] is waiting to be confirmed. The feature is
  /// usable and the screen may say the purchase is being confirmed.
  const factory FeatureDecision.confirming(Holding holding) = FeatureConfirming;

  /// Whether [holding], which would unlock the feature, could not be read.
  /// Nothing is taken away and nothing is sold: the paywall door opens
  /// nothing for it. The feature is usable only when the last sure answer
  /// for it was open ([wasOpenWhenLastSure]). With no sure answer ever, it
  /// is not.
  const factory FeatureDecision.unread(
    Holding holding, {
    bool wasOpenWhenLastSure,
  }) = FeatureUnread;

  /// The feature does not exist on the server this phone is connected to,
  /// whatever is held. It is not usable and there is nothing to sell: a
  /// screen says so in plain words and never opens a paywall for it.
  const factory FeatureDecision.notOffered() = FeatureNotOffered;

  /// True for [FeatureOpen] and [FeatureConfirming]. True for
  /// [FeatureUnread] only when the last sure answer was open. False for
  /// [FeatureLocked] and [FeatureNotOffered].
  bool get isUsable;
}

final class FeatureOpen extends FeatureDecision {
  const FeatureOpen();

  @override
  bool get isUsable => true;

  @override
  bool operator ==(Object other) => other is FeatureOpen;

  @override
  int get hashCode => (FeatureOpen).hashCode;

  @override
  String toString() => 'FeatureDecision.open';
}

final class FeatureLocked extends FeatureDecision {
  const FeatureLocked(this.offer);

  /// The holding to sell: `FeatureRule.offered` for the feature.
  final Holding offer;

  @override
  bool get isUsable => false;

  @override
  bool operator ==(Object other) =>
      other is FeatureLocked && other.offer == offer;

  @override
  int get hashCode => Object.hash(FeatureLocked, offer);

  @override
  String toString() => 'FeatureDecision.locked(${offer.name})';
}

final class FeatureConfirming extends FeatureDecision {
  const FeatureConfirming(this.holding);

  /// The holding whose purchase is waiting.
  final Holding holding;

  @override
  bool get isUsable => true;

  @override
  bool operator ==(Object other) =>
      other is FeatureConfirming && other.holding == holding;

  @override
  int get hashCode => Object.hash(FeatureConfirming, holding);

  @override
  String toString() => 'FeatureDecision.confirming(${holding.name})';
}

final class FeatureUnread extends FeatureDecision {
  const FeatureUnread(this.holding, {this.wasOpenWhenLastSure = false});

  /// The holding that could not be read.
  final Holding holding;

  /// Whether the last sure answer for the feature was open: the plan had
  /// been read, and the answer was open or a purchase being confirmed.
  /// False when the last sure answer was a lock, and when there was none.
  final bool wasOpenWhenLastSure;

  @override
  bool get isUsable => wasOpenWhenLastSure;

  @override
  bool operator ==(Object other) =>
      other is FeatureUnread &&
      other.holding == holding &&
      other.wasOpenWhenLastSure == wasOpenWhenLastSure;

  @override
  int get hashCode => Object.hash(FeatureUnread, holding, wasOpenWhenLastSure);

  @override
  String toString() => wasOpenWhenLastSure
      ? 'FeatureDecision.unread(${holding.name}, was open)'
      : 'FeatureDecision.unread(${holding.name})';
}

final class FeatureNotOffered extends FeatureDecision {
  const FeatureNotOffered();

  @override
  bool get isUsable => false;

  @override
  bool operator ==(Object other) => other is FeatureNotOffered;

  @override
  int get hashCode => (FeatureNotOffered).hashCode;

  @override
  String toString() => 'FeatureDecision.notOffered';
}

/// What [decision] says for certain: true for open or a purchase being
/// confirmed, false for locked or not offered, and null when it says
/// nothing for certain (unread, or no decision at all).
///
/// The one rule for what moves a "last sure answer". The alarm screen's
/// note (`openNoteAfter`) and `FeatureAccess` both follow it.
bool? lastSureAnswerOf(FeatureDecision? decision) => switch (decision) {
  FeatureOpen() || FeatureConfirming() => true,
  FeatureLocked() || FeatureNotOffered() => false,
  FeatureUnread() || null => null,
};
