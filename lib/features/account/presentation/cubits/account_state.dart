import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:flutter/foundation.dart';

enum AccountStatus {
  /// Reading the server mode and whoever was signed in last.
  loading,

  /// Nobody is signed in. The two buttons are on screen.
  signedOut,

  /// A provider sheet or an account route is in flight.
  working,

  /// The server asked and the person has to answer: keep both, or start
  /// fresh.
  choosing,

  signedIn,

  /// Nobody is signed in on this phone, and the account it is on holds an
  /// identity: a reinstalled iPhone whose session is gone. The card says
  /// which account it is and offers one way forward.
  unfinished,

  /// The account is gone and this phone is already on a fresh anonymous one.
  /// The confirm screen leaves as soon as it sees this.
  deleted,
}

/// Which account a phone with no usable session is on: the card's
/// "Finish signing in" state.
@immutable
final class UnfinishedSignIn {
  const UnfinishedSignIn({
    required this.provider,
    required this.offered,
    required this.others,
    required this.topics,
    this.emailHint,
    this.emailHidden = false,
  });

  /// The oldest way to sign in the account holds. Null for a provider this
  /// build does not know.
  final IdentityProvider? provider;

  /// This phone can run [provider]'s sign-in. An Apple-only account on
  /// Android cannot, and then the one way forward is another account.
  final bool offered;

  /// The masked address, `z•••@gmail.com`.
  final String? emailHint;

  /// An Apple private relay address, which has no hint.
  final bool emailHidden;

  /// How many other ways to sign in the account holds.
  final int others;

  /// The topics in the list this phone holds.
  final int topics;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnfinishedSignIn &&
          provider == other.provider &&
          offered == other.offered &&
          emailHint == other.emailHint &&
          emailHidden == other.emailHidden &&
          others == other.others &&
          topics == other.topics;

  @override
  int get hashCode =>
      Object.hash(provider, offered, emailHint, emailHidden, others, topics);
}

/// The panel that offers to leave the account this phone is on and sign in
/// to another one.
@immutable
final class LeaveOffer {
  const LeaveOffer({required this.topics});

  /// The topics in the list this phone holds. They stop sounding here and
  /// stay on that account.
  final int topics;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LeaveOffer && topics == other.topics;

  @override
  int get hashCode => topics.hashCode;
}

/// What the account screen knows.
@immutable
class AccountState {
  const AccountState({
    this.status = AccountStatus.loading,
    this.mode,
    this.identity,
    this.choice,
    this.errorMessage,
    this.liveIncidentId,
    this.holdsHosted = false,
    this.signInWays,
    this.joinToken,
    this.joinTokenMints = 0,
    this.isMintingJoinToken = false,
    this.joinTokenError,
    this.unfinished,
    this.leave,
    this.ringClaim = RingClaim.alarm,
  });

  final AccountStatus status;

  /// Null until the server has been read. `selfhosted` offers no sign-in at
  /// all, so the whole section is left out rather than greyed out.
  final ServerMode? mode;

  final AccountIdentity? identity;

  /// The 409 the prompt is built from: which account is being signed in to,
  /// and what this phone's account would bring.
  final AccountLinkChoose? choice;

  final String? errorMessage;

  /// An alarm blocked the merge or the delete. The screen links to it so the
  /// person can acknowledge it and try again.
  final String? liveIncidentId;

  /// Whether this device sits on a paid tier. The delete prompt has to warn
  /// that a store subscription keeps billing, and only a payer needs to read
  /// it.
  final bool holdsHosted;

  /// How many ways to sign in the account holds, for the "Ways to sign in"
  /// row. Null unless signed in with a session the server still takes, and
  /// then the row is not shown.
  final int? signInWays;

  /// The join code that was just minted. The server keeps a hash of it and
  /// has nothing to hand back, so this is the one place the value exists.
  final String? joinToken;

  /// How many codes this screen has minted. The second one and every one
  /// after it retired a code somebody may still be holding.
  final int joinTokenMints;

  final bool isMintingJoinToken;

  final String? joinTokenError;

  /// Set while nobody is signed in and the account holds an identity.
  final UnfinishedSignIn? unfinished;

  /// Set while the leave panel is up.
  final LeaveOffer? leave;

  /// Which words a line about ringing may use on this phone.
  final RingClaim ringClaim;

  /// Sign-in exists everywhere except on a self-hosted server, which has one
  /// operator and no accounts.
  /// About what the server is, not about plans.
  bool get isAvailable {
    if (mode == null) return false;
    return mode != ServerMode.selfhosted; // access-ok: accounts exist
  }

  bool get isBusy => status == AccountStatus.working;

  /// True once a second code has been minted here, which is the moment the
  /// earlier one stopped working.
  bool get hasRetiredAJoinToken => joinTokenMints > 1;

  AccountState copyWith({
    AccountStatus? status,
    ServerMode? mode,
    AccountIdentity? identity,
    AccountLinkChoose? choice,
    String? errorMessage,
    String? liveIncidentId,
    bool? holdsHosted,
    int? signInWays,
    String? joinToken,
    int? joinTokenMints,
    bool? isMintingJoinToken,
    String? joinTokenError,
    UnfinishedSignIn? unfinished,
    LeaveOffer? leave,
    RingClaim? ringClaim,
    bool clearIdentity = false,
    bool clearChoice = false,
    bool clearError = false,
    bool clearLiveIncident = false,
    bool clearSignInWays = false,
    bool clearJoinToken = false,
    bool clearJoinTokenError = false,
    bool clearUnfinished = false,
    bool clearLeave = false,
  }) {
    return AccountState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      identity: clearIdentity ? null : (identity ?? this.identity),
      choice: clearChoice ? null : (choice ?? this.choice),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      liveIncidentId: clearLiveIncident
          ? null
          : (liveIncidentId ?? this.liveIncidentId),
      holdsHosted: holdsHosted ?? this.holdsHosted,
      signInWays: clearSignInWays ? null : (signInWays ?? this.signInWays),
      joinToken: clearJoinToken ? null : (joinToken ?? this.joinToken),
      joinTokenMints: joinTokenMints ?? this.joinTokenMints,
      isMintingJoinToken: isMintingJoinToken ?? this.isMintingJoinToken,
      joinTokenError: clearJoinTokenError
          ? null
          : (joinTokenError ?? this.joinTokenError),
      unfinished: clearUnfinished ? null : (unfinished ?? this.unfinished),
      leave: clearLeave ? null : (leave ?? this.leave),
      ringClaim: ringClaim ?? this.ringClaim,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          mode == other.mode &&
          identity == other.identity &&
          choice == other.choice &&
          errorMessage == other.errorMessage &&
          liveIncidentId == other.liveIncidentId &&
          holdsHosted == other.holdsHosted &&
          signInWays == other.signInWays &&
          joinToken == other.joinToken &&
          joinTokenMints == other.joinTokenMints &&
          isMintingJoinToken == other.isMintingJoinToken &&
          joinTokenError == other.joinTokenError &&
          unfinished == other.unfinished &&
          leave == other.leave &&
          ringClaim == other.ringClaim;

  @override
  int get hashCode => Object.hash(
    status,
    mode,
    identity,
    choice,
    errorMessage,
    liveIncidentId,
    holdsHosted,
    signInWays,
    joinToken,
    joinTokenMints,
    isMintingJoinToken,
    joinTokenError,
    unfinished,
    leave,
    ringClaim,
  );
}
