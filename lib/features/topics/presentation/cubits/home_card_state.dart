import 'package:critalarm/features/topics/domain/home_card/home_card_model.dart';
import 'package:flutter/foundation.dart';

/// What the screen draws for Home's dark card.
@immutable
class HomeCardState {
  const HomeCardState({required this.model, this.readinessLoaded = false});

  /// Everything the card draws, as values.
  final HomeCardModel model;

  /// The first read of the phone's checks has ended. Until then the card
  /// draws no count (`Dots`), so "fine" is never claimed before it is known.
  final bool readinessLoaded;

  @override
  bool operator ==(Object other) =>
      other is HomeCardState &&
      other.model == model &&
      other.readinessLoaded == readinessLoaded;

  @override
  int get hashCode => Object.hash(model, readinessLoaded);

  @override
  String toString() => 'HomeCardState($model, loaded: $readinessLoaded)';
}
