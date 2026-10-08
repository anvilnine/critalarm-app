import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/sound/own_sound_lock_flag.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/search/domain/repositories/recent_searches_repository.dart';

/// What belongs to one account on this phone. This is the one list.
///
/// A sign-out, an account delete, a dead credential and a connect to a
/// different server all call [forget], so none of them can drop one thing
/// and leave another behind:
///
/// 1. Acknowledgements still waiting to be sent. Each names an incident on
///    the account that is going.
/// 2. The poll cursors, one per topic.
/// 3. The recent searches. They can name a topic that is gone.
/// 4. Wake-up challenges: every topic's choice, the default for new
///    topics, and every `topic_challenge_owed.<topic>` flag with its tag.
/// 5. Alarm looks: the phone's look, every topic's look, and the note
///    `alarm_style_open_when_last_sure`.
/// 6. The own sounds lock flag `alarm_sound_own_locked` with its tag.
///
/// Not on the list, on purpose: a person's own sound files and which sound
/// each topic rings with. Those are the person's recordings and choices,
/// not a plan state. The lock flag decides whether an own sound rings, and
/// that is the only part of sounds that follows the account.
///
/// Settings, permissions and the archive are not here either. The connect
/// to a different server drops the archive itself.
class AccountData {
  AccountData({
    required this._acks,
    required this._messageCursors,
    required this._recentSearches,
    required this._challenges,
    required this._alarmStyles,
    required this._soundLock,
    this._afterForget,
  });

  final AckQueue _acks;
  final MessageSyncService _messageCursors;
  final RecentSearchesRepository _recentSearches;
  final ChallengeChoices _challenges;
  final AlarmStyleChoices _alarmStyles;
  final OwnSoundLockFlag _soundLock;

  /// Runs once everything is dropped: the two flag writers check again, so
  /// native reads the cleared state, the copy in the iOS app group is made
  /// again, and a sure answer for the account the phone is on now writes
  /// the flags back.
  final Future<void> Function()? _afterForget;

  Future<void> forget() async {
    // The three drops both callers already made, in the order they made
    // them. A failure here still stops the caller, as it did.
    await _acks.clear();
    await _messageCursors.resetAllCursors();
    await _recentSearches.clear();
    // The rest never stops the caller: a phone that could not drop a note
    // must still be able to register again. A flag that stays behind is
    // still not trusted, because its tag is not this account's.
    await _quietly(_challenges.forgetAll);
    await _quietly(_alarmStyles.forgetAll);
    await _quietly(_soundLock.clear);
    final after = _afterForget;
    if (after != null) await _quietly(after);
  }

  Future<void> _quietly(Future<void> Function() drop) async {
    try {
      await drop();
    } on Object catch (_) {}
  }
}
