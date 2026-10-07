import 'dart:async';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/connect_link_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/connect_link_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// How long the sheet stays on "Connected" before it closes by itself.
const Duration connectLinkDoneHold = Duration(milliseconds: 1200);

/// Opens the sheet for [cubit] and completes when it closes: true once the
/// connect landed and the sheet closed itself, otherwise null.
///
/// [onShown] gets the sheet's own context, so the caller can close exactly
/// this sheet and nothing else.
Future<bool?> showConnectLinkSheet(
  BuildContext context, {
  required ConnectLinkCubit cubit,
  void Function(BuildContext sheetContext)? onShown,
}) {
  return showAppSheet<bool>(
    context: context,
    content: (sheetContext) {
      onShown?.call(sheetContext);
      return BlocProvider.value(
        value: cubit,
        child: const ConnectLinkSheetBody(),
      );
    },
  );
}

/// Which "Replaces" line the sheet draws.
enum ConnectReplaces {
  /// This phone is on no server. No line.
  none,

  /// The server being replaced is Crit Alarm Cloud, which a cloud user does
  /// not know by its host name.
  cloud,

  /// Any other server, named by its host.
  host,
}

/// The "Replaces" line for a phone connected to [replacingHost], where
/// [replacesCloud] is true when that server is Crit Alarm Cloud.
@visibleForTesting
ConnectReplaces connectReplaces({
  required String? replacingHost,
  required bool replacesCloud,
}) {
  if (replacingHost == null) return ConnectReplaces.none;
  return replacesCloud ? ConnectReplaces.cloud : ConnectReplaces.host;
}

/// True when the only button that leaves the sheet should read "Close": the
/// server refused, and asking again would get the same answer, so "Not now"
/// would suggest a later that does not exist.
@visibleForTesting
bool connectLeaveIsClose(ConnectLinkState state) =>
    state.isFailed && !state.canRetry;

/// A host longer than this keeps its address line, so a long name is shown
/// twice, as before, in case the large type has to be set small.
const int connectHostLongLength = 40;

/// True when the address line under the host says something the host does
/// not already say. A person must never see less of the address than they
/// are agreeing to, so this answers false only for an `https` address that is
/// exactly `https://` and the host, with at most a closing slash. A path, a
/// query, a fragment, user info, a port the host does not carry, `http`, a
/// long host and every failed state show the whole address.
@visibleForTesting
bool connectShowsAddress(ConnectLinkState state) {
  if (state.isPlainHttp || state.isFailed) return true;
  if (state.host.length > connectHostLongLength) return true;
  final bare = 'https://${state.host}';
  return state.address != bare && state.address != '$bare/';
}

/// [host] cut after each dot, so a line can only break between labels. The
/// pieces joined are always [host] again.
@visibleForTesting
List<String> hostLabels(String host) {
  final labels = <String>[];
  var start = 0;
  for (var i = 0; i < host.length; i++) {
    if (host[i] == '.') {
      labels.add(host.substring(start, i + 1));
      start = i + 1;
    }
  }
  if (start < host.length) labels.add(host.substring(start));
  return labels;
}

/// The face and the host, the address under it, one line on what connecting
/// does, and the two ways out. It reads [ConnectLinkCubit] and never sees
/// the token.
class ConnectLinkSheetBody extends StatefulWidget {
  const ConnectLinkSheetBody({super.key});

  @override
  State<ConnectLinkSheetBody> createState() => _ConnectLinkSheetBodyState();
}

class _ConnectLinkSheetBodyState extends State<ConnectLinkSheetBody> {
  Timer? _closeTimer;

  /// Whether the server this phone is on now is Crit Alarm Cloud. Null until
  /// the saved session answers. It is the same question the Account and Pro
  /// screens ask: the mode the phone saved when it connected.
  bool? _replacesCloud;

  @override
  void initState() {
    super.initState();
    unawaited(_readReplacesCloud());
  }

  Future<void> _readReplacesCloud() async {
    var cloud = false;
    try {
      cloud =
          await getIt<AccountRepository>().readServerMode() ==
          ServerMode.hosted;
    } on Object {
      // No saved session to read. The host is named instead, which says more.
    }
    if (mounted) setState(() => _replacesCloud = cloud);
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  void _holdThenClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(connectLinkDoneHold, () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectLinkCubit, ConnectLinkState>(
      listenWhen: (before, after) => !before.isConnected && after.isConnected,
      listener: (context, state) => _holdThenClose(),
      builder: (context, state) {
        final cubit = context.read<ConnectLinkCubit>();
        final actions = _actions(context, state, cubit);
        // The words scroll and the buttons stay put, so a large text size on
        // a small phone never pushes Connect off the sheet. The sheet is a
        // column in the sheet's column, hence the Flexible around it.
        return Flexible(
          child: PopScope(
            // The connect is under way and cannot be taken back, so the
            // sheet stays until it answers.
            canPop: !state.isConnecting,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Head(state: state),
                        const SizedBox(height: Spacing.s4),
                        ..._words(context, state),
                      ],
                    ),
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: Spacing.s4),
                  ...actions,
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// What the sheet says under the host.
  List<Widget> _words(BuildContext context, ConnectLinkState state) {
    final colors = context.appColors;
    if (state.isConnected) {
      return [
        Semantics(
          liveRegion: true,
          child: Text(
            LocaleKeys.onboarding_connect_self_host_connected_title.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.small(colors.ink2, fontSize: 15),
          ),
        ),
      ];
    }
    if (state.isConnecting) {
      return [
        Semantics(
          liveRegion: true,
          child: Text(
            LocaleKeys.onboarding_connect_self_host_connecting.tr(
              namedArgs: {'host': state.host},
            ),
            textAlign: TextAlign.center,
            style: AppTypography.small(colors.ink2, fontSize: 15),
          ),
        ),
      ];
    }
    if (state.isFailed) {
      return [
        Semantics(
          liveRegion: true,
          child: Text(
            state.errorMessage ?? '',
            textAlign: TextAlign.center,
            style: AppTypography.small(colors.ink2, fontSize: 15),
          ),
        ),
      ];
    }
    return [
      Text(
        LocaleKeys.connect_link_what.tr(),
        textAlign: TextAlign.center,
        style: AppTypography.small(colors.ink2, fontSize: 15),
      ),
      if (_replacesCloud != null &&
          connectReplaces(
                replacingHost: state.replacingHost,
                replacesCloud: _replacesCloud!,
              ) !=
              ConnectReplaces.none) ...[
        const SizedBox(height: Spacing.s2),
        Text(
          _replacesCloud!
              ? LocaleKeys.connect_link_replaces_cloud.tr()
              : LocaleKeys.connect_link_replaces.tr(
                  namedArgs: {'host': state.replacingHost!},
                ),
          textAlign: TextAlign.center,
          style: AppTypography.small(colors.ink3),
        ),
      ],
      if (state.isPlainHttp) ...[
        const SizedBox(height: Spacing.s3),
        AppNote(text: LocaleKeys.connect_link_not_encrypted.tr()),
      ],
    ];
  }

  /// The two buttons. None while the connect is under way or done.
  List<Widget> _actions(
    BuildContext context,
    ConnectLinkState state,
    ConnectLinkCubit cubit,
  ) {
    if (state.isConnecting || state.isConnected) return const [];
    return [
      if (!state.isFailed || state.canRetry) ...[
        AppButton(
          label: state.isFailed
              ? LocaleKeys.common_retry.tr()
              : LocaleKeys.onboarding_connect_connect_button.tr(),
          isFullWidth: true,
          onPressed: () => unawaited(cubit.connect()),
        ),
        const SizedBox(height: Spacing.s2),
      ],
      AppButton(
        label: connectLeaveIsClose(state)
            ? LocaleKeys.connect_link_close.tr()
            : LocaleKeys.common_not_now.tr(),
        variant: AppButtonVariant.ghost,
        isFullWidth: true,
        onPressed: () {
          cubit.notNow();
          Navigator.of(context).pop();
        },
      ),
    ];
  }
}

/// The face, the host and the address. The face changes with the state, so
/// the sheet is never the same face twice in a row: a question, a wary
/// look at an unencrypted address, a wait, a failure, a done.
class _Head extends StatelessWidget {
  const _Head({required this.state});

  final ConnectLinkState state;

  FaceState get _face {
    if (state.isConnected) return FaceState.happy;
    if (state.isFailed) return FaceState.worried;
    if (state.isConnecting) return FaceState.watching;
    return state.isPlainHttp ? FaceState.skeptical : FaceState.curious;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      container: true,
      label: state.host,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: FaceWidget(state: _face, size: 72, isLive: true),
          ),
          const SizedBox(height: Spacing.s3),
          ExcludeSemantics(
            child: _HostName(
              state.host,
              style: AppTypography.headline(colors.ink, fontSize: 28),
            ),
          ),
          // An address is a machine string, so it is set in mono. It is
          // shown whole whenever it holds more than the host above it.
          if (connectShowsAddress(state)) ...[
            const SizedBox(height: Spacing.s1),
            ExcludeSemantics(
              child: Text(
                state.address,
                textAlign: TextAlign.center,
                textDirection: ui.TextDirection.ltr,
                style: AppTypography.mono(colors.ink3, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The host, large. It wraps only between labels (after a dot), so a label is
/// never cut in two, and the type is scaled down until the longest label fits
/// the line.
///
/// `AppFittedTitle` does this for words split by spaces. A host has none, so
/// it would see one very long word, shrink to its floor and let the line
/// break inside a label ("alarm.example.co" then "m" at 2.0x text). This uses
/// the same `fittedFontSize` with the labels as the words and a floor low
/// enough that every label fits.
class _HostName extends StatelessWidget {
  const _HostName(this.host, {required this.style});

  final String host;
  final TextStyle style;

  /// A DNS label is at most 63 characters, which fits a 343 point line at
  /// about this size, so no label has to break.
  static const double _floor = 9;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // An address reads left to right in every language. Without this a
    // right-to-left app would set the labels in the opposite order.
    const direction = ui.TextDirection.ltr;
    final fontSize = style.fontSize!;
    final labels = hostLabels(host);
    return LayoutBuilder(
      builder: (context, constraints) {
        var longest = 0.0;
        for (final label in labels) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (painter.width > longest) longest = painter.width;
          painter.dispose();
        }
        final fitted = fittedFontSize(
          fontSize: fontSize,
          // A hair of slack, so rounding never tips a label over the edge.
          longestWordWidth: longest + 1,
          maxWidth: constraints.maxWidth,
          minFontSize: _floor,
        );
        final spacing = style.letterSpacing;
        final fittedStyle = style.copyWith(
          fontSize: fitted,
          letterSpacing: spacing == null ? null : spacing * fitted / fontSize,
        );
        return Wrap(
          textDirection: direction,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final label in labels)
              Text(
                label,
                softWrap: false,
                textDirection: direction,
                style: fittedStyle,
              ),
          ],
        );
      },
    );
  }
}
