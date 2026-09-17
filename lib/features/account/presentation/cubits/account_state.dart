import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
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

  /// An alarm blocked the merge. The screen links to it so the person can
  /// acknowledge it and try again.
  final String? liveIncidentId;

  /// Sign-in exists everywhere except on a self-hosted server, which has one
  /// operator and no accounts.
  bool get isAvailable => mode != null && mode != ServerMode.selfhosted;

  bool get isBusy => status == AccountStatus.working;

  AccountState copyWith({
    AccountStatus? status,
    ServerMode? mode,
    AccountIdentity? identity,
    AccountLinkChoose? choice,
    String? errorMessage,
    String? liveIncidentId,
    bool clearIdentity = false,
    bool clearChoice = false,
    bool clearError = false,
    bool clearLiveIncident = false,
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
          liveIncidentId == other.liveIncidentId;

  @override
  int get hashCode => Object.hash(
    status,
    mode,
    identity,
    choice,
    errorMessage,
    liveIncidentId,
  );
}
