import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/route_observer.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/permissions/presentation/widgets/setup_health_banner.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:critalarm/features/topics/presentation/topic_detail_screen.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_cubit.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_state.dart';
import 'package:critalarm/features/tour/presentation/tour_anchor.dart';
import 'package:critalarm/features/tour/presentation/tour_examples.dart';
import 'package:critalarm/features/tour/presentation/tour_steps.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// HomeScreen matching docs/design-system/index.html mobile mockup.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<HomeCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _HomeScreenContent(),
    );
  }
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();

  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent>
    with RouteAware {
  String? _selectedTopic;

  /// The incident this screen has already handed over for. Kept so backing out
  /// of the alarm screen does not bounce the user straight back into it, while
  /// a new incident still takes over.
  String? _handedOver;

  final TourCubit _tour = getIt<TourCubit>();

  @override
  void initState() {
    super.initState();
    // First run only. The tour waits for this screen to finish arriving
    // before it points at anything, so asking straight away is fine.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tour.requestIfNew();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// Back from creating a topic, from a topic, from anywhere. Whatever the
  /// user just did could have changed this list, so load it again.
  @override
  void didPopNext() {
    if (!mounted) return;
    unawaited(context.read<HomeCubit>().refresh());
  }

  /// While anything is ringing, the app is the alarm. The list is no use to
  /// someone being screamed at, so hand them the screen with the stop control
  /// on it. Only once per incident, so leaving it is allowed.
  void _handOverIfRinging(HomeState state) {
    final id = state.ringingIncidentId;
    if (id == null) {
      if (_handedOver != null) _handedOver = null;
      return;
    }
    if (id == _handedOver) return;
    _handedOver = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.push('/incidents/$id'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = AppSize.of(context);

    return BlocConsumer<HomeCubit, HomeState>(
      listener: (context, state) => _handOverIfRinging(state),
      builder: (context, state) => BlocBuilder<TourCubit, TourState>(
        bloc: _tour,
        builder: (context, tour) => _build(context, size, state, tour),
      ),
    );
  }

  Widget _build(
    BuildContext context,
    AppSize size,
    HomeState real,
    TourState tour,
  ) {
    // While the tour runs, the list gets an example topic that is ringing,
    // so the user sees what trouble looks like before it happens. Someone
    // with no topics yet also gets two calm ones. They all go when the tour
    // does.
    final showExamples = tour.isRunning && real.status == HomeStatus.success;
    final state = !showExamples
        ? real
        : real.isEmpty
        ? real.copyWith(
            topicItems: [
              TourExamples.troubleTopic(),
              ...TourExamples.homeTopics(),
            ],
            faceState: FaceState.calm,
            word: LocaleKeys.home_stage_word_clear.tr(),
            subText: LocaleKeys.tour_example_topic_sub.tr(),
          )
        : real.copyWith(
            topicItems: [TourExamples.troubleTopic(), ...real.topicItems],
          );
    // A deleted topic leaves the pane pointing at a name the list no
    // longer has, so the selection is read back off the list every build
    // rather than trusted.
    final selected = state.topicItems.any((t) => t.name == _selectedTopic)
        ? _selectedTopic
        : null;

    return SeverityScope(
      severity: state.severity,
      child: AppScreenScaffold(
        onFaceRefresh: () => context.read<HomeCubit>().refresh(),
        // Search is not up here any more. It lives next to the compose
        // button on the floating bar, so it is reachable from every tab
        // rather than only this one.
        topBar: AppTopBar(
          title: LocaleKeys.topics_list_title.tr(),
          trailing: const RefreshActivityIndicator(),
        ),
        detail: state.topicItems.isEmpty
            ? null
            : (selected == null
                  ? AppEmptyState(
                      title: LocaleKeys.home_detail_empty_title.tr(),
                      description: LocaleKeys.home_detail_empty_body.tr(),
                      buttonLabel: null,
                    )
                  : TopicDetailScreen(
                      key: ValueKey(selected),
                      topicName: selected,
                      isPane: true,
                    )),
        slivers: [
          // Ahead of everything: if a device setting is off, no page on
          // this list can actually reach the user.
          const SliverToBoxAdapter(child: SetupHealthBanner()),
          if (state.topicItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: Spacing.s3),
                  TourAnchor(
                    id: TourAnchorId.homeStage,
                    child: AppStage(
                      faceState: state.faceState,
                      word: state.word,
                      sub: state.subText,
                    ),
                  ),
                  const SizedBox(height: Spacing.s4),
                ],
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                state.topicItems.isEmpty ? Spacing.s3 : 0,
                12,
                16,
              ),
              child: TourAnchor(
                id: TourAnchorId.topicList,
                child: AppSheet(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Loading and failure both used to fall through to
                      // the empty state, so a slow network or a dead
                      // server told the user every topic they own was
                      // gone, and the error was never shown at all.
                      if (state.status == HomeStatus.failure) ...[
                        AppToast(
                          faceState: FaceState.worried,
                          message:
                              state.errorMessage ??
                              LocaleKeys.home_load_failed.tr(),
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: LocaleKeys.home_retry_button.tr(),
                          variant: AppButtonVariant.ghost,
                          size: AppButtonSize.sm,
                          isFullWidth: true,
                          onPressed: () => unawaited(
                            context.read<HomeCubit>().refresh(),
                          ),
                        ),
                      ] else if (state.topicItems.isEmpty &&
                          state.status != HomeStatus.success) ...[
                        AppEmptyState(
                          title: LocaleKeys.home_loading_title.tr(),
                          description: '',
                          buttonLabel: null,
                          followsRefresh: true,
                        ),
                      ] else if (state.isEmpty) ...[
                        AppEmptyState(
                          onButtonPressed: () => context.push('/topics/new'),
                          followsRefresh: true,
                        ),
                      ] else ...[
                        for (final topic in state.topicItems) ...[
                          AppListRow(
                            name: topic.name,
                            meta: topic.meta,
                            isSelected:
                                size.isExpanded && topic.name == selected,
                            faceState: topic.faceState,
                            isCrit: topic.isCrit,
                            isQuiet: topic.isQuiet,
                            // The priority that came in is only shown
                            // while there is something live. Once the
                            // alarm is acknowledged the row goes back to
                            // saying how the topic is set up, so a red
                            // chip never contradicts the calm face above.
                            trailing: topic.isLive
                                ? AppPriorityChip(
                                    priority: topic.priority,
                                  )
                                : AppDeliveryChip(
                                    rings: topic.ringsThroughSilent,
                                    label: topic.ringsThroughSilent
                                        ? LocaleKeys.home_delivery_rings.tr()
                                        : LocaleKeys.home_delivery_normal.tr(),
                                  ),
                            onTap: () {
                              if (size.isExpanded) {
                                AppHaptics.selection();
                                setState(
                                  () => _selectedTopic = topic.name,
                                );
                              } else {
                                unawaited(
                                  context.push('/topics/${topic.name}'),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
