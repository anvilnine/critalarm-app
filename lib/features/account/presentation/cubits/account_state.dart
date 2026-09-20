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

  /// The account is gone and this phone is already on a fresh anonymous one.
  /// The confirm screen leaves as soon as it sees this.
  deleted,
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
    this.isPaid = false,
    this.linkingProvider,
    this.joinToken,
    this.joinTokenMints = 0,
    this.isMintingJoinToken = false,
    this.joinTokenError,
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
  final bool isPaid;

  /// The provider whose add-row is waiting on its sheet, so one row spins
  /// instead of the whole screen.
  final IdentityProvider? linkingProvider;

  /// The join code that was just minted. The server keeps a hash of it and
  /// has nothing to hand back, so this is the one place the value exists.
  final String? joinToken;

  /// How many codes this screen has minted. The second one and every one
  /// after it retired a code somebody may still be holding.
  final int joinTokenMints;

  final bool isMintingJoinToken;

  final String? joinTokenError;

  /// Sign-in exists everywhere except on a self-hosted server, which has one
  /// operator and no accounts.
  bool get isAvailable => mode != null && mode != ServerMode.selfhosted;

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
    bool? isPaid,
    IdentityProvider? linkingProvider,
    String? joinToken,
    int? joinTokenMints,
    bool? isMintingJoinToken,
    String? joinTokenError,
    bool clearIdentity = false,
    bool clearChoice = false,
    bool clearError = false,
    bool clearLiveIncident = false,
    bool clearLinkingProvider = false,
    bool clearJoinToken = false,
    bool clearJoinTokenError = false,
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
      isPaid: isPaid ?? this.isPaid,
      linkingProvider: clearLinkingProvider
          ? null
          : (linkingProvider ?? this.linkingProvider),
      joinToken: clearJoinToken ? null : (joinToken ?? this.joinToken),
      joinTokenMints: joinTokenMints ?? this.joinTokenMints,
      isMintingJoinToken: isMintingJoinToken ?? this.isMintingJoinToken,
      joinTokenError: clearJoinTokenError
          ? null
          : (joinTokenError ?? this.joinTokenError),
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
          isPaid == other.isPaid &&
          linkingProvider == other.linkingProvider &&
          joinToken == other.joinToken &&
          joinTokenMints == other.joinTokenMints &&
          isMintingJoinToken == other.isMintingJoinToken &&
          joinTokenError == other.joinTokenError;

  @override
  int get hashCode => Object.hash(
    status,
    mode,
    identity,
    choice,
    errorMessage,
    liveIncidentId,
    isPaid,
    linkingProvider,
    joinToken,
    joinTokenMints,
    isMintingJoinToken,
    joinTokenError,
  );
}
