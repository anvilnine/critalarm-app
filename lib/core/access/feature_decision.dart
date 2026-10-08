import 'package:critalarm/core/access/holding.dart';
import 'package:flutter/foundation.dart';

/// The answer to "may this install use this feature".
///
/// One of [FeatureOpen], [FeatureLocked], [FeatureConfirming] and
/// [FeatureUnread]. A caller that only needs yes or no reads [isUsable].
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
  /// Nothing is taken away and nothing is sold: the feature is usable and
  /// the paywall door opens nothing for it.
  const factory FeatureDecision.unread(Holding holding) = FeatureUnread;

  /// True for everything but [FeatureLocked].
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

  /// The holding to sell: the first entry of the feature's `unlockedBy`.
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
  const FeatureUnread(this.holding);

  /// The holding that could not be read.
  final Holding holding;

  @override
  bool get isUsable => true;

  @override
  bool operator ==(Object other) =>
      other is FeatureUnread && other.holding == holding;

  @override
  int get hashCode => Object.hash(FeatureUnread, holding);

  @override
  String toString() => 'FeatureDecision.unread(${holding.name})';
}
