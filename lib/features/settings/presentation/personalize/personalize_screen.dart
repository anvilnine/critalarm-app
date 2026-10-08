import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_state.dart';
import 'package:critalarm/features/settings/presentation/personalize/personalize_section.dart';
import 'package:critalarm/features/settings/presentation/personalize/ringing_preview.dart';
import 'package:critalarm/features/settings/presentation/personalize/try_bar.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Personalize: a live copy of the ringing alarm on top, and under it the
/// choices that change it.
///
/// The page is [sections] and nothing more. It sets the defaults for the
/// phone and saves to the same places the older Settings rows do.
class PersonalizeScreen extends StatelessWidget {
  const PersonalizeScreen({this.sections = personalizeSections, super.key});

  final List<PersonalizeSection> sections;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<PersonalizeCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: _PersonalizeView(sections: sections),
    );
  }
}

class _PersonalizeView extends StatefulWidget {
  const _PersonalizeView({required this.sections});

  final List<PersonalizeSection> sections;

  @override
  State<_PersonalizeView> createState() => _PersonalizeViewState();
}

class _PersonalizeViewState extends State<_PersonalizeView> {
  late final FeatureAccess _access = getIt<FeatureAccess>();
  StreamSubscription<AppFeature>? _changes;

  Set<AppFeature> get _features => {
    for (final section in widget.sections) ?section.feature,
  };

  /// What the access layer says for each section's feature, read each
  /// build: the stream only carries changes.
  Map<AppFeature, FeatureDecision> get _decisions => {
    for (final feature in _features) feature: _access.decide(feature),
  };

  @override
  void initState() {
    super.initState();
    _changes = _access.changes.listen((feature) {
      if (!mounted || !_features.contains(feature)) return;
      // A tried option that just opened is a real choice now, so the try
      // ends and the bar goes, in place.
      final cubit = context.read<PersonalizeCubit>();
      if (!tryStillStands(cubit.state.tried, _decisions)) cubit.clearTry();
      setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    final size = AppSize.of(context);
    final isWide = personalizeIsWide(
      width: size.width,
      height: size.height,
      mediumMinWidth: AppSize.mediumMinWidth,
    );
    return BlocBuilder<PersonalizeCubit, PersonalizeState>(
      builder: (context, state) {
        final cubit = context.read<PersonalizeCubit>();
        final tryBar = PersonalizeTryBar(
          bar: tryBarFor(tried: state.tried, decisions: _decisions),
          sourceFor: (bar) {
            for (final section in widget.sections) {
              if (section.feature == bar.feature) return section.lockSource;
            }
            return null;
          },
        );
        RingingPreviewFrame preview(double maxHeight) => RingingPreviewFrame(
          maxHeight: maxHeight,
          isPlaying: state.isPlaying,
          onPlay: () => unawaited(cubit.togglePlay()),
        );
        final choices = _Choices(sections: widget.sections);

        return AppScreenScaffold(
          // Full screen, on the root navigator: no tab bar to leave room for.
          hasTabBar: false,
          topBar: AppTopBar(
            title: LocaleKeys.personalize_title.tr(),
            trailing: AppDismissCross(
              onPressed: _close,
              label: LocaleKeys.common_close.tr(),
              color: colors.onCanvas,
            ),
          ),
          slivers: [
            if (isWide)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: Spacing.s2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The scaffold keeps a page to one readable column,
                      // so the two halves share that column.
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: Spacing.s4,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              preview(
                                (media.size.height - media.padding.vertical) *
                                    0.6,
                              ),
                              tryBar,
                            ],
                          ),
                        ),
                      ),
                      Expanded(child: choices),
                    ],
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.s4,
                    Spacing.s2,
                    Spacing.s4,
                    0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      preview(
                        personalizePreviewHeight(
                          viewportHeight: media.size.height,
                          textScale: media.textScaler.scale(1),
                        ),
                      ),
                      tryBar,
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: choices),
            ],
          ],
        );
      },
    );
  }
}

/// The sections under the preview: the strips, a divider, the rows.
class _Choices extends StatelessWidget {
  const _Choices({required this.sections});

  final List<PersonalizeSection> sections;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final strips = sections.where(
      (section) => section.kind == PersonalizeSectionKind.strip,
    );
    final rows = sections.where(
      (section) => section.kind == PersonalizeSectionKind.row,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final section in strips) ...[
          if (section.titleKey != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.s4,
                Spacing.s4,
                Spacing.s4,
                0,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  section.titleKey!.tr(),
                  style: AppTypography.small(
                    colors.onCanvas,
                    fontSize: 13,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          KeyedSubtree(
            key: ValueKey('personalize-${section.id}'),
            child: Builder(builder: section.builder),
          ),
        ],
        if (rows.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.s4,
              vertical: Spacing.s4,
            ),
            child: Divider(height: 1, thickness: 1, color: colors.hairline),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final section in rows)
                  KeyedSubtree(
                    key: ValueKey('personalize-${section.id}'),
                    child: Builder(builder: section.builder),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Spacing.s5),
      ],
    );
  }
}
