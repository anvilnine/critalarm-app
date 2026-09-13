import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
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

          final targetName = state.createdTopic?.name ?? state.name;
          context.go('/topics/$targetName');
        }
      },
      builder: (context, state) {
        final cubit = context.read<CreateTopicCubit>();
        final name = state.name.isEmpty ? 'prod-db' : state.name;
        final token = state.createdToken ?? 'ca_live_7Hq2mN9xPz4wKd8';

        final bottomInset = MediaQuery.paddingOf(context).bottom;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: colors.canvas,
          body: GhostField(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                AppSliverTopBar(
                  leading: AppIconButton(
                    glyph: GlyphType.back,
                    ariaLabel: LocaleKeys.create_topic_back_aria_label.tr(),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                  ),
                  title: LocaleKeys.create_topic_title.tr(),
                ),
                const SliverToBoxAdapter(
                  child: AppStage(
                    faceState: FaceState.watching,
                    faceSize: 110,
                    isLive: true,
                    padding: EdgeInsets.fromLTRB(24, Spacing.s3, 24, 0),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        Spacing.s4,
                        12,
                        16 + bottomInset,
                      ),
                      child: AppSheet(
                        border: Border.all(color: colors.hairline, width: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                            Text(
                              LocaleKeys.create_topic_priority_label.tr(),
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
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final p in [
                                  PriorityLevel.min,
                                  PriorityLevel.low,
                                  PriorityLevel.defaultPriority,
                                  PriorityLevel.high,
                                  PriorityLevel.critical,
                                ])
                                  AppPriorityChip(
                                    priority: p,
                                    isSelected: state.defaultPriority == p,
                                    onTap: () => cubit.priorityChanged(p),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            AppToggleRow(
                              title: LocaleKeys
                                  .create_topic_critical_toggle_title
                                  .tr(),
                              subtitle: LocaleKeys
                                  .create_topic_critical_toggle_subtitle
                                  .tr(),
                              value: state.isCritical,
                              onChanged: (val) {
                                cubit.criticalToggled(isCritical: val);
                              },
                            ),
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
                              value: 'https://api.critalarm.app/t/$name',
                              showCopyButton: true,
                            ),
                            const SizedBox(height: 8),
                            AppKeyValueRow(
                              value: token,
                              showCopyButton: true,
                            ),
                            if (state.createdToken != null) ...[
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
                            const SizedBox(height: 16),
                            AppButton(
                              label: LocaleKeys.create_topic_create_button.tr(),
                              isFullWidth: true,
                              isLoading:
                                  state.status == CreateTopicStatus.submitting,
                              onPressed: cubit.createTopic,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
