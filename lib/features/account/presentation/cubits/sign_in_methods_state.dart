import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:flutter/foundation.dart';

/// Where the "Ways to sign in" page stands.
enum SignInMethodsStatus {
  /// The list has not come back yet.
  loading,

  /// The list is on screen and nothing is running.
  ready,

  /// An add or a remove is running.
  working,

  /// The phone holds no session of an identity on the account, so there is
  /// nothing to manage here. The page goes back to the account card.
  signedOut,

  /// The list could not be read.
  failed,
}

/// One way to sign in, as the page draws it.
@immutable
final class SignInMethodRow {
  const SignInMethodRow({
    required this.id,
    required this.provider,
    required this.linkedAt,
    this.email,
    this.emailHidden = false,
    this.current = false,
    this.showsDate = false,
  });

  final String id;

  /// Null for a provider this build does not know.
  final IdentityProvider? provider;
  final String? email;
  final bool emailHidden;
  final DateTime linkedAt;

  /// The one this phone signed in with.
  final bool current;

  /// Another row would read the same, so this one says when it was added.
  final bool showsDate;

  @override
  bool operator ==(Object other) =>
      other is SignInMethodRow &&
      other.id == id &&
      other.provider == provider &&
      other.email == email &&
      other.emailHidden == emailHidden &&
      other.linkedAt == linkedAt &&
      other.current == current &&
      other.showsDate == showsDate;

  @override
  int get hashCode => Object.hash(
    id,
    provider,
    email,
    emailHidden,
    linkedAt,
    current,
    showsDate,
  );
}

@immutable
final class SignInMethodsState {
  const SignInMethodsState({
    this.status = SignInMethodsStatus.loading,
    this.rows = const [],
    this.offered = const [],
    this.errorMessage,
    this.liveIncidentId,
  });

  final SignInMethodsStatus status;

  /// Oldest first.
  final List<SignInMethodRow> rows;

  /// The providers this platform can sign in with.
  final List<IdentityProvider> offered;
  final String? errorMessage;

  /// An alarm that blocked a remove.
  final String? liveIncidentId;

  /// The most ways to sign in one account holds (api.md §3.7).
  static const maxRows = 6;

  bool get isBusy => status == SignInMethodsStatus.working;

  /// The last way to sign in is never removed.
  bool get canRemove => rows.length > 1;

  /// What the add card offers: every provider this platform signs in with,
  /// a second of one the account already holds included, until it is full.
  List<IdentityProvider> get addable =>
      rows.length >= maxRows ? const [] : offered;

  SignInMethodsState copyWith({
    SignInMethodsStatus? status,
    List<SignInMethodRow>? rows,
    List<IdentityProvider>? offered,
    String? errorMessage,
    String? liveIncidentId,
    bool clearError = false,
    bool clearLiveIncident = false,
  }) => SignInMethodsState(
    status: status ?? this.status,
    rows: rows ?? this.rows,
    offered: offered ?? this.offered,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    liveIncidentId: clearLiveIncident
        ? null
        : (liveIncidentId ?? this.liveIncidentId),
  );

  @override
  bool operator ==(Object other) =>
      other is SignInMethodsState &&
      other.status == status &&
      listEquals(other.rows, rows) &&
      listEquals(other.offered, offered) &&
      other.errorMessage == errorMessage &&
      other.liveIncidentId == liveIncidentId;

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAll(rows),
    Object.hashAll(offered),
    errorMessage,
    liveIncidentId,
  );
}
