import 'dart:async';

import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/links/app_link.dart';
import 'package:critalarm/core/telemetry/connect_link_analytics.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/connect_to_server_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/connect_link_state.dart';
import 'package:critalarm/features/onboarding/presentation/model/connect_outcome_message.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Behind the sheet a connect link opens.
///
/// It connects through [ConnectToServerUsecase], the same one the setup
/// connect step calls, and only when the person taps Connect.
///
/// The token never leaves this class. It is held in a private field, handed
/// to the use case, and dropped when the connect lands or the cubit closes.
/// No state, log line or analytics event carries it, and no event carries
/// the address either.
class ConnectLinkCubit extends Cubit<ConnectLinkState> {
  ConnectLinkCubit(
    ConnectLink link, {
    required ConnectToServerUsecase connectToServer,
    GetConnectionUsecase? readConnection,
    Future<ServerMode?> Function()? readServerMode,
    ConnectLinkAnalytics? events,
    Future<void> Function()? afterConnected,
  }) : _token = link.token,
       _serverUrl = link.serverUrl.toString(),
       _connect = connectToServer,
       _getConnection = readConnection,
       _serverMode = readServerMode,
       _analytics = events,
       _onConnected = afterConnected,
       super(
         ConnectLinkState(
           host: hostLabel(link.serverUrl),
           address: link.serverUrl.toString(),
           isPlainHttp: link.serverUrl.scheme == 'http',
         ),
       );

  String? _token;
  final String _serverUrl;
  final ConnectToServerUsecase _connect;
  final GetConnectionUsecase? _getConnection;

  /// The mode the phone saved when it connected to the server it is on now.
  /// It is the same question the Account and Pro screens ask.
  final Future<ServerMode?> Function()? _serverMode;
  final ConnectLinkAnalytics? _analytics;
  final Future<void> Function()? _onConnected;

  bool _tried = false;
  bool _ended = false;

  /// The person tapped Connect at least once.
  bool get hasTried => _tried;

  /// Reports that the sheet opened, and finds the server it replaces.
  ///
  /// The saved server's address and its mode are asked for together and go
  /// into one state, so the "Replaces" line never names a host from one
  /// moment and a kind of server from another.
  Future<void> open() async {
    unawaited(_analytics?.opened());
    final getConnection = _getConnection;
    if (getConnection == null) return;
    final (result, isCloud) = await (
      getConnection(const NoParams()),
      _readIsCloud(),
    ).wait;
    final current = result.getOrNull();
    if (current == null || isClosed) return;
    final uri = Uri.tryParse(current.serverUrl);
    if (uri == null || uri.host.isEmpty) return;
    emit(state.withReplaced(host: hostLabel(uri), isCloud: isCloud));
  }

  /// False when there is no saved session to read. The host is named
  /// instead, which says more.
  Future<bool> _readIsCloud() async {
    try {
      return await _serverMode?.call() == ServerMode.hosted;
    } on Object {
      return false;
    }
  }

  /// Connects to the server in the link. Does nothing while a connect is
  /// under way or once it has landed.
  Future<void> connect() async {
    final token = _token;
    if (token == null || state.isConnecting || state.isConnected) return;
    if (state.isFailed && !state.canRetry) return;
    _tried = true;
    emit(
      state.copyWith(
        phase: ConnectLinkPhase.connecting,
        clearErrorMessage: true,
      ),
    );
    final ConnectOutcome outcome;
    try {
      outcome = await _connect(
        serverUrl: _serverUrl,
        adminToken: token,
        // The sheet shows one address and connects to that one.
        pinToAddress: true,
      );
    } on Object {
      // The use case answers with an outcome and does not throw. This is
      // for a failure outside it. Its text is dropped: it is not a sentence,
      // and nothing that might hold the token is shown.
      _fail(LocaleKeys.api_errors_unknown.tr(), token);
      return;
    }
    if (outcome is Connected) {
      _token = null;
      await _onConnected?.call();
      _report(ConnectLinkEnd.connected);
      if (!isClosed) emit(state.copyWith(phase: ConnectLinkPhase.connected));
      return;
    }
    // A link always carries a token, so a server that asks for one has
    // nothing to ask. The line is for the day that changes.
    _fail(
      connectOutcomeMessage(outcome) ??
          LocaleKeys.onboarding_connect_admin_token_error_empty.tr(),
      token,
      // Asking the same server again gets the same answer.
      canRetry: outcome is! ServerAddressDiffers && outcome is! ServerDowngrade,
    );
  }

  /// Shows [message], unless it holds the token, which a wrapped exception
  /// could. That one gets the plain unknown-error line.
  void _fail(String message, String token, {bool canRetry = true}) {
    if (isClosed) return;
    emit(
      state.copyWith(
        phase: ConnectLinkPhase.failed,
        errorMessage: _holdsToken(message, token)
            ? LocaleKeys.api_errors_unknown.tr()
            : message,
        canRetry: canRetry,
      ),
    );
  }

  /// True when [message] holds [token] in any form an error could echo it:
  /// as the link gave it, as the request sent it (trimmed), and percent
  /// encoded either way. Case is ignored, because `%2F` and `%2f` are one
  /// thing.
  static bool _holdsToken(String message, String token) {
    final text = message.toLowerCase();
    final plain = {token, token.trim()}..removeWhere((form) => form.isEmpty);
    final forms = {
      for (final form in plain) ...[
        form,
        Uri.encodeComponent(form),
        Uri.encodeQueryComponent(form),
      ],
    };
    return forms.any((form) => text.contains(form.toLowerCase()));
  }

  /// The person answered Not now, or swiped the sheet away.
  void notNow() => _report(
    state.isFailed ? ConnectLinkEnd.failed : ConnectLinkEnd.notNow,
  );

  /// An alarm took the screen.
  void interrupted() => _report(ConnectLinkEnd.interrupted);

  void _report(ConnectLinkEnd end) {
    if (_ended) return;
    _ended = true;
    unawaited(_analytics?.ended(end));
  }

  @override
  Future<void> close() {
    // A sheet that closes by any road other than the ones above (the route
    // went away under it) still counts as left.
    if (!state.isConnected) {
      _report(state.isFailed ? ConnectLinkEnd.failed : ConnectLinkEnd.notNow);
    }
    _token = null;
    return super.close();
  }

  /// The part of [uri] a person recognises: the host, with the port when it
  /// is not the usual one. An IPv6 host keeps its brackets.
  static String hostLabel(Uri uri) {
    final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    return uri.hasPort ? '$host:${uri.port}' : host;
  }
}
