import 'dart:async';

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
    return [
      Text(
        LocaleKeys.connect_link_what.tr(),
        textAlign: TextAlign.center,
        style: AppTypography.small(colors.ink2, fontSize: 15),
      ),
      if (state.replacingHost != null) ...[
        const SizedBox(height: Spacing.s2),
        Text(
          LocaleKeys.connect_link_replaces.tr(
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
      AppButton(
        label: state.isFailed
            ? LocaleKeys.common_retry.tr()
            : LocaleKeys.onboarding_connect_connect_button.tr(),
        isFullWidth: true,
        onPressed: () => unawaited(cubit.connect()),
      ),
      const SizedBox(height: Spacing.s2),
      AppButton(
        label: LocaleKeys.common_not_now.tr(),
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
          AppFittedTitle(
            state.host,
            minFontSize: 18,
            style: AppTypography.headline(colors.ink, fontSize: 28),
          ),
          const SizedBox(height: Spacing.s1),
          // An address is a machine string, so it is set in mono. It is
          // shown whole, because the host alone is not the whole story.
          ExcludeSemantics(
            child: Text(
              state.address,
              textAlign: TextAlign.center,
              style: AppTypography.mono(colors.ink3, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
