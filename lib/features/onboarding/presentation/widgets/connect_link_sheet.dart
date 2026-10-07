import 'dart:async';
import 'dart:ui' as ui;

import 'package:critalarm/design/design.dart';
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

/// The smallest size the large host is set in: the smallest body size the
/// design system has (`bodySmall`). The system text size scales it up from
/// there.
const double connectHostMinFontSize = 12;

/// How the large host is set in the room it has.
@immutable
class HostFit {
  const HostFit({
    required this.fontSize,
    required this.atFloor,
    required this.breaksInsideLabel,
  });

  /// The size to set the host in.
  final double fontSize;

  /// The host had to be scaled all the way down to
  /// [connectHostMinFontSize].
  final bool atFloor;

  /// A label is wider than the line even at the smallest size, so it wraps
  /// letter by letter. Nothing is cut off and nothing is set smaller.
  final bool breaksInsideLabel;

  /// The large host is harder to read than it should be, so the whole
  /// address is shown under it whatever else is true.
  bool get isCramped => atFloor || breaksInsideLabel;

  @override
  bool operator ==(Object other) =>
      other is HostFit &&
      other.fontSize == fontSize &&
      other.atFloor == atFloor &&
      other.breaksInsideLabel == breaksInsideLabel;

  @override
  int get hashCode => Object.hash(fontSize, atFloor, breaksInsideLabel);

  @override
  String toString() =>
      'HostFit($fontSize, atFloor: $atFloor, breaks: $breaksInsideLabel)';
}

/// Fits the host's longest label to the line.
///
/// [fontSize] is the size the host wants, [longestLabelWidth] how wide its
/// longest label is at that size, [maxWidth] the room it has. The type is
/// scaled down until that label fits, but never below [minFontSize]. A label
/// that still does not fit there wraps inside itself: the host is always
/// readable in full.
@visibleForTesting
HostFit hostFit({
  required double fontSize,
  required double longestLabelWidth,
  required double maxWidth,
  double minFontSize = connectHostMinFontSize,
}) {
  final fits =
      longestLabelWidth <= 0 ||
      !maxWidth.isFinite ||
      longestLabelWidth <= maxWidth;
  if (fits) {
    return HostFit(
      fontSize: fontSize,
      atFloor: fontSize <= minFontSize,
      breaksInsideLabel: false,
    );
  }
  final scaled = maxWidth <= 0 ? 0.0 : fontSize * maxWidth / longestLabelWidth;
  if (scaled > minFontSize) {
    return HostFit(fontSize: scaled, atFloor: false, breaksInsideLabel: false);
  }
  return HostFit(
    fontSize: minFontSize < fontSize ? minFontSize : fontSize,
    atFloor: true,
    breaksInsideLabel: scaled < minFontSize,
  );
}

/// True when the address line under the host says something the host does
/// not already say. A person must never see less of the address than they
/// are agreeing to, so this answers false only for an `https` address that is
/// exactly `https://` and the host, with at most a closing slash. A path, a
/// query, a fragment, user info, a port the host does not carry, `http`, a
/// long host and every failed state show the whole address. So does a host
/// that had to be set at its smallest size or wrapped inside a label
/// ([hostIsCramped], from [HostFit.isCramped]).
@visibleForTesting
bool connectShowsAddress(ConnectLinkState state, {bool hostIsCramped = false}) {
  if (hostIsCramped) return true;
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
    // Both come from one state, which the cubit sets in one step.
    final replaces = connectReplaces(
      replacingHost: state.replacingHost,
      replacesCloud: state.replacesCloud,
    );
    return [
      Text(
        LocaleKeys.connect_link_what.tr(),
        textAlign: TextAlign.center,
        style: AppTypography.small(colors.ink2, fontSize: 15),
      ),
      if (replaces != ConnectReplaces.none) ...[
        const SizedBox(height: Spacing.s2),
        Text(
          replaces == ConnectReplaces.cloud
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
    final style = AppTypography.headline(colors.ink, fontSize: 28);
    final fontSize = style.fontSize!;
    final scaler = MediaQuery.textScalerOf(context);
    final labels = hostLabels(state.host);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = hostFit(
          fontSize: fontSize,
          // A hair of slack, so rounding never tips a label over the edge.
          longestLabelWidth: _longestWidth(labels, style, scaler) + 1,
          maxWidth: constraints.maxWidth,
        );
        final spacing = style.letterSpacing;
        final showsAddress = connectShowsAddress(
          state,
          hostIsCramped: fit.isCramped,
        );
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
                  labels,
                  style: style.copyWith(
                    fontSize: fit.fontSize,
                    letterSpacing: spacing == null
                        ? null
                        : spacing * fit.fontSize / fontSize,
                  ),
                  breaksInsideLabel: fit.breaksInsideLabel,
                ),
              ),
              // An address is a machine string, so it is set in mono. It is
              // shown whole whenever it holds more than the host above it, and
              // whenever the host above it had to be set small or wrapped.
              if (showsAddress) ...[
                const SizedBox(height: Spacing.s1),
                ExcludeSemantics(
                  child: Text(
                    state.address,
                    textAlign: TextAlign.center,
                    textDirection: _ltr,
                    style: AppTypography.mono(colors.ink3, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// How wide the widest of [labels] is on one line in [style].
  static double _longestWidth(
    List<String> labels,
    TextStyle style,
    TextScaler scaler,
  ) {
    var longest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: _ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > longest) longest = painter.width;
      painter.dispose();
    }
    return longest;
  }
}

/// An address reads left to right in every language. Without this a
/// right-to-left app would set the host's labels in the opposite order.
const ui.TextDirection _ltr = ui.TextDirection.ltr;

/// The host, large. It wraps between labels (after a dot), and [style] is
/// already scaled down so the longest label fits the line, see [hostFit].
///
/// `AppFittedTitle` does this for words split by spaces. A host has none, so
/// it would see one very long word, shrink to its floor and let the line
/// break inside a label ("alarm.example.co" then "m" at 2.0x text).
///
/// A label is cut in two only when [breaksInsideLabel] is set: it does not
/// fit the line at the smallest size, so it wraps letter by letter there
/// instead of running off the sheet.
class _HostName extends StatelessWidget {
  const _HostName(
    this.labels, {
    required this.style,
    required this.breaksInsideLabel,
  });

  final List<String> labels;
  final TextStyle style;
  final bool breaksInsideLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      textDirection: _ltr,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final label in labels)
          Text(
            label,
            softWrap: breaksInsideLabel,
            textAlign: TextAlign.center,
            textDirection: _ltr,
            style: style,
          ),
      ],
    );
  }
}
