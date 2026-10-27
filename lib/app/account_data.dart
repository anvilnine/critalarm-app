import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/sound/own_sound_lock_flag.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_sender.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:critalarm/features/search/domain/repositories/recent_searches_repository.dart';

/// What belongs to one account on this phone. This is the one list.
///
/// A sign-out, an account delete, a dead credential and a connect to a
/// different server all call [forget], so none of them can drop one thing
/// and leave another behind. Every item is dropped even when an earlier
/// one fails:
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
/// 7. The proof log: the weeks an alarm or a check got through.
/// 8. The own alarm look: the photo file, the record of how bright it is
///    (`alarm_style_own_photo`), the accent (`alarm_style_own_accent`)
///    and any copy of a picked photo a pick left in the cache
///    (`alarm_style_own_pending`). Listed last and dropped first.
/// 9. The topic list the phone kept to open with (the `topics` table of the
///    local store). It is also read only for the account and server it was
///    written for, so a copy that survives a failed drop is still never shown.
/// 10. Cancel answers still waiting for a retry. Each names the account that
///    is going.
///
/// The archive of incidents and messages is not on the list, on purpose. Its
/// rows carry the scope of the account they were read for and every read asks
/// for the current scope only, so a sign-out keeps the rows (they come back
/// when the same account signs in) and no other account is ever shown them.
/// [forgetDeleted] is the one that removes them, for an account that is gone.
///
/// Not on the list, on purpose: a person's own sound files and which sound
/// each topic rings with. Those are the person's recordings and choices,
/// not a plan state. The lock flag decides whether an own sound rings, and
/// that is the only part of sounds that follows the account.
///
/// The own photo is on the list, and that differs from own sounds on
/// purpose. A sound is heard and tells nobody anything. A photo is on
/// screen, full size, for anyone holding the phone the next time it
/// rings: a person's own picture must not stay on a phone they signed out
/// of, deleted their account on, or pointed at another server.
///
/// Settings and permissions are not here either. The connect to a different
/// server drops the whole archive, every scope of it, itself.
class AccountData {
  AccountData({
    required this._acks,
    required this._messageCursors,
    required this._recentSearches,
    required this._challenges,
    required this._alarmStyles,
    required this._soundLock,
    required this._ownLook,
    this._proofLog,
    this._cancelAnswers,
    this._heldTopics,
    this._archive,
    this._afterForget,
  });

  final AckQueue _acks;
  final MessageSyncService _messageCursors;
  final RecentSearchesRepository _recentSearches;
  final ChallengeChoices _challenges;
  final AlarmStyleChoices _alarmStyles;
  final OwnSoundLockFlag _soundLock;
  final OwnLookStore _ownLook;
  final ProofLog? _proofLog;

  /// The cancel answers still waiting for a retry.
  final CancelAnswerSender? _cancelAnswers;

  /// The topic list kept on the phone. Null where the local store is not
  /// open: the web build, or a store that would not open.
  final TopicStore? _heldTopics;

  /// The phone's archive of incidents and messages, for [forgetDeleted].
  /// Null where the local store is not open.
  final LocalStore? _archive;

  /// Runs once everything is dropped: the two flag writers check again, so
  /// native reads the cleared state, the copy in the iOS app group is made
  /// again, and a sure answer for the account the phone is on now writes
  /// the flags back.
  final Future<void> Function()? _afterForget;

  Future<void> forget() async {
    // The own photo first. It is the most private thing on the list, so
    // nothing that fails after it can leave it on the phone.
    await _quietly(_ownLook.forgetAll);
    // The three drops both callers always made, in the order they made
    // them. A failure here still stops the caller, as it did: the first
    // one is thrown again at the end. It no longer stops the rest of the
    // list from being dropped first.
    Object? failure;
    StackTrace? failedAt;
    Future<void> loudly(Future<void> Function() drop) async {
      try {
        await drop();
      } on Object catch (error, stack) {
        failure ??= error;
        failedAt ??= stack;
      }
    }

    await loudly(_acks.clear);
    await loudly(_messageCursors.resetAllCursors);
    await loudly(_recentSearches.clear);
    // The rest never stops the caller: a phone that could not drop a note
    // must still be able to register again. A flag that stays behind is
    // still not trusted, because its tag is not this account's.
    await _quietly(_challenges.forgetAll);
    await _quietly(_alarmStyles.forgetAll);
    await _quietly(_soundLock.clear);
    final proofLog = _proofLog;
    if (proofLog != null) await _quietly(proofLog.clear);
    final cancelAnswers = _cancelAnswers;
    if (cancelAnswers != null) await _quietly(cancelAnswers.clear);
    final heldTopics = _heldTopics;
    if (heldTopics != null) await _quietly(heldTopics.clear);
    final after = _afterForget;
    if (after != null) await _quietly(after);
    final failed = failure;
    if (failed != null) {
      Error.throwWithStackTrace(failed, failedAt ?? StackTrace.current);
    }
  }

  /// [forget], and the archive rows of the account that was deleted: the one
  /// named by [scope], or the account the phone is on now when none is given.
  ///
  /// Nobody can sign in to a deleted account again, so the copy of its
  /// history goes. A sign-out calls [forget] alone.
  Future<void> forgetDeleted({String? scope}) async {
    final archive = _archive;
    if (archive != null) {
      await _quietly(
        scope == null
            ? archive.deleteCurrentArchive
            : () => archive.deleteArchiveOf(scope),
      );
    }
    await forget();
  }

  Future<void> _quietly(Future<void> Function() drop) async {
    try {
      await drop();
    } on Object catch (_) {}
  }
}
