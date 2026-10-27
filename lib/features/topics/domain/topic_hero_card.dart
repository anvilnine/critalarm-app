import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:flutter/foundation.dart';

/// What the foot of the Topic screen's dark card says.
enum TopicHeroFoot {
  /// An alarm rings through silent mode and Do Not Disturb.
  ringsThroughSilent,

  /// A Time-Sensitive notification with sound. The silent switch mutes it,
  /// so the words never claim more than that.
  timeSensitive,

  /// A plain push. Critical delivery is off.
  normalPush,

  /// The phone does not let the app set alarms, so the switch cannot be used.
  needsAlarm,
}

/// What the dark card on the Topic screen says, as plain values.
///
/// The switch is the topic's `critical` flag as the server holds it, and
/// nothing here turns it on. The words about ringing come from [RingClaim],
/// so a phone that cannot ring through silent mode never reads that it does.
@immutable
class TopicHeroCard {
  const TopicHeroCard({
    required this.isOn,
    required this.isLoading,
    required this.canSwitch,
    required this.foot,
  });

  /// Critical delivery is on for this topic.
  final bool isOn;

  /// The topic has not answered yet. The numeral is dots and the switch is
  /// still.
  final bool isLoading;

  /// The switch takes a tap.
  final bool canSwitch;

  /// Null while loading.
  final TopicHeroFoot? foot;

  /// The disc behind the face is quiet while Critical delivery is off.
  bool get hasQuietDisc => !isOn;

  @override
  bool operator ==(Object other) =>
      other is TopicHeroCard &&
      other.isOn == isOn &&
      other.isLoading == isLoading &&
      other.canSwitch == canSwitch &&
      other.foot == foot;

  @override
  int get hashCode => Object.hash(isOn, isLoading, canSwitch, foot);
}

/// The card for a topic whose Critical delivery is [critical].
///
/// - [isLoading]: the topic has not been read yet.
/// - [canEditCritical]: the phone lets the app set alarms. Without that a
///   push arrives as a quiet notification and never rings, so the switch
///   stays still and the foot says why.
TopicHeroCard topicHeroCardFor({
  required bool critical,
  required bool canEditCritical,
  required RingClaim claim,
  bool isLoading = false,
}) {
  if (isLoading) {
    return const TopicHeroCard(
      isOn: false,
      isLoading: true,
      canSwitch: false,
      foot: null,
    );
  }
  final TopicHeroFoot foot;
  if (!canEditCritical) {
    foot = TopicHeroFoot.needsAlarm;
  } else if (!critical) {
    foot = TopicHeroFoot.normalPush;
  } else {
    foot = switch (claim) {
      RingClaim.alarm => TopicHeroFoot.ringsThroughSilent,
      RingClaim.timeSensitive => TopicHeroFoot.timeSensitive,
    };
  }
  return TopicHeroCard(
    isOn: critical,
    isLoading: false,
    canSwitch: canEditCritical,
    foot: foot,
  );
}
