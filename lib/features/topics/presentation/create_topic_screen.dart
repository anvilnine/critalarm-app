import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

/// CreateTopicScreen matching docs/design-system/index.html mobile mockup.
class CreateTopicScreen extends StatelessWidget {
  const CreateTopicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CreateTopicCubit>(),
      child: const _CreateTopicScreenContent(),
    );
  }
}

class _CreateTopicScreenContent extends StatelessWidget {
  const _CreateTopicScreenContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocConsumer<CreateTopicCubit, CreateTopicState>(
      listener: (context, state) {
        if (state.status == CreateTopicStatus.success) {
          AppHaptics.success();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              content: Center(
                child: AppToast(
                  message: LocaleKeys.create_topic_toast_created.tr(),
                  boldText: state.name,
                ),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<CreateTopicCubit>();
        final token = state.createdToken;

        // Tapping anywhere outside a field puts the keyboard away. Translucent
        // so the button and the text field still get their own taps.
        return GestureDetector(
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
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
            ),
            bottomBar: AppButton(
              label: state.status == CreateTopicStatus.success
                  ? 'Done'
                  : LocaleKeys.create_topic_create_button.tr(),
              isFullWidth: true,
              isLoading: state.status == CreateTopicStatus.submitting,
              onPressed: () {
                AppHaptics.capture();
                if (state.status == CreateTopicStatus.success) {
                  context.go('/topics/${state.createdTopic!.name}');
                } else {
                  unawaited(cubit.createTopic());
                }
              },
            ),
            slivers: [
              const SliverToBoxAdapter(
                child: AppStage(
                  faceState: FaceState.watching,
                  faceSize: 110,
                  isLive: true,
                  padding: EdgeInsets.fromLTRB(24, Spacing.s3, 24, 0),
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
                            faceState: FaceState.worried,
                            buttonLabel: null,
                            isLive: false,
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
                          AppKeyValueRow(
                            value: token,
                            trailing: _ShareButton(value: token),
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
      },
    );
  }
}

/// Small pill button that opens the system share sheet with an endpoint or
/// token value, matching index.html .kv .copy.
class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        unawaited(SharePlus.instance.share(ShareParams(text: value)));
      },
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: Radii.fullAll,
          border: Border.all(color: colors.hairline, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          LocaleKeys.create_topic_share_button.tr(),
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.ink,
          ),
        ),
      ),
    );
  }
}
