import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:critalarm/features/topics/presentation/widgets/token_actions.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// CreateTopicScreen matching docs/design-system/index.html mobile mockup.
class CreateTopicScreen extends StatelessWidget {
  const CreateTopicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<CreateTopicCubit>();
        unawaited(cubit.loadConnection());
        return cubit;
      },
      child: const _CreateTopicScreenContent(),
    );
  }
}

class _CreateTopicScreenContent extends StatefulWidget {
  const _CreateTopicScreenContent();

  @override
  State<_CreateTopicScreenContent> createState() =>
      _CreateTopicScreenContentState();
}

class _CreateTopicScreenContentState extends State<_CreateTopicScreenContent> {
  /// Shown just above the pinned button, in the layout rather than floating
  /// over it. A SnackBar is a Material idea and lands on top of the button
  /// the user is reaching for.
  String? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocConsumer<CreateTopicCubit, CreateTopicState>(
      listener: (context, state) {
        if (state.status == CreateTopicStatus.success) {
          AppHaptics.success();
          _showToast(
            '${LocaleKeys.create_topic_toast_created.tr()} ${state.name}',
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<CreateTopicCubit>();
        final token = state.createdToken;
        // One face for the whole screen. It is the only thing that reacts to
        // an error, so the card below it renders without one.
        final stageFace = state.errorMessage != null
            ? FaceState.worried
            : FaceState.watching;

        // Tapping anywhere outside a field puts the keyboard away. Translucent
        // so the button and the text field still get their own taps.
        final content = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: AppScreenScaffold(
            hasTabBar: false,
            resizeForKeyboard: true,
            topBar: AppTopBar(
              title: LocaleKeys.create_topic_title.tr(),
              trailing: AppIconButton(
                glyph: GlyphType.close,
                ariaLabel: LocaleKeys.create_topic_cancel_aria_label.tr(),
                onPressed: () {
                  // After the topic exists, closing is the same move as
                  // Done. The X used to pop straight out and drop the
                  // one-time token the card says to save.
                  final created = state.createdTopic;
                  if (created != null) {
                    if (context.canPop()) {
                      context.pop();
                      unawaited(context.push('/topics/${created.name}'));
                    } else {
                      context.go('/topics/${created.name}');
                    }
                    return;
                  }
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
            ),
            bottomBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_toast case final message?) ...[
                  AppToast(message: message),
                  const SizedBox(height: Spacing.s2),
                ],
                AppButton(
                  label: state.status == CreateTopicStatus.success
                      ? 'Done'
                      : LocaleKeys.create_topic_create_button.tr(),
                  isFullWidth: true,
                  isLoading: state.status == CreateTopicStatus.submitting,
                  onPressed: () {
                    AppHaptics.capture();
                    if (state.status == CreateTopicStatus.success) {
                      final name = state.createdTopic!.name;
                      // Pop back to the list first so it reloads and the new
                      // topic is on it, then open the topic. Going straight
                      // there replaces this route instead of popping it, and
                      // the list never hears that anything changed.
                      if (context.canPop()) {
                        context.pop();
                        unawaited(context.push('/topics/$name'));
                      } else {
                        context.go('/topics/$name');
                      }
                    } else {
                      unawaited(cubit.createTopic());
                    }
                  },
                ),
              ],
            ),
            slivers: [
              SliverToBoxAdapter(
                child: AppStage(
                  faceState: stageFace,
                  faceSize: 110,
                  isLive: true,
                  padding: const EdgeInsets.fromLTRB(24, Spacing.s3, 24, 0),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, Spacing.s4, 12, 16),
                  child: AppSheet(
                    border: Border.all(color: colors.hairline, width: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.capReached != null)
                          AppEmptyState(
                            title: state.capReached!.message,
                            description:
                                'Review your plan to increase this limit.',
                            buttonLabel: null,
                            showFace: false,
                          ),
                        if (state.status != CreateTopicStatus.success) ...[
                          AppTextField(
                            label: LocaleKeys.create_topic_name_label.tr(),
                            initialValue: state.name,
                            placeholder: LocaleKeys
                                .create_topic_name_placeholder
                                .tr(),
                            helperText: LocaleKeys.create_topic_name_helper
                                .tr(),
                            errorText: state.errorMessage,
                            onChanged: cubit.nameChanged,
                          ),
                          const SizedBox(height: 14),
                          AppToggleRow(
                            title: LocaleKeys.create_topic_critical_toggle_title
                                .tr(),
                            subtitle: LocaleKeys
                                .create_topic_critical_toggle_subtitle
                                .tr(),
                            value: state.isCritical,
                            onChanged: (val) {
                              AppHaptics.selection();
                              cubit.criticalToggled(isCritical: val);
                            },
                          ),
                        ],
                        if (token != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            LocaleKeys.create_topic_generated_label.tr(),
                            style: TextStyle(
                              fontFamily: AppTypography.fontBody,
                              fontFamilyFallback:
                                  AppTypography.fontBodyFallbacks,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.ink3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // The card used to show the token alone, so the
                          // user finished setup with no address to point a
                          // script at.
                          if (state.serverUrl.isNotEmpty) ...[
                            AppKeyValueRow(
                              value: '${state.serverUrl}/${state.name}',
                              trailing: TokenActions(
                                value: '${state.serverUrl}/${state.name}',
                                onCopied: _showToast,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          AppKeyValueRow(
                            value: token,
                            trailing: TokenActions(
                              value: token,
                              onCopied: _showToast,
                            ),
                          ),
                          ...[
                            const SizedBox(height: 6),
                            Text(
                              LocaleKeys.create_topic_token_warning.tr(),
                              style: TextStyle(
                                fontFamily: AppTypography.fontBody,
                                fontFamilyFallback:
                                    AppTypography.fontBodyFallbacks,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.ink3,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        final profile = AmbientAppProfiles.createTopic(colors);

        return AmbientScope(
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: AmbientCanvas(
                    key: const ValueKey('create-topic-ambient-canvas'),
                    profile: profile,
                    direction: AmbientDirection.push,
                    variant: AmbientMotionVariant.drift,
                    reduceMotion: context.reduceMotion,
                  ),
                ),
              ),
              Positioned.fill(child: content),
            ],
          ),
        );
      },
    );
  }
}
