import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/route_observer.dart';
import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/paywall/presentation/widgets/pro_status_badge.dart';
import 'package:critalarm/features/prompts/presentation/cubits/home_prompt_cubit.dart';
import 'package:critalarm/features/prompts/presentation/cubits/home_prompt_state.dart';
import 'package:critalarm/features/prompts/presentation/home_asks.dart';
import 'package:critalarm/features/prompts/presentation/widgets/home_prompt_slot.dart';
import 'package:critalarm/features/prompts/presentation/widgets/prompt_detail_sheet.dart';
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
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

/// HomeScreen matching docs/design-system/index.html mobile mockup.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final cubit = getIt<HomeCubit>();
            unawaited(cubit.load());
            return cubit;
          },
        ),
        BlocProvider(
          create: (context) {
            final cubit = getIt<HomePromptCubit>(
              param1: context.read<ShellCubit>(),
            );
            unawaited(cubit.load());
            return cubit;
          },
        ),
      ],
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
    with RouteAware, WidgetsBindingObserver {
  String? _selectedTopic;

  /// The incident this screen has already handed over for. Kept so backing out
  /// of the alarm screen does not bounce the user straight back into it, while
  /// a new incident still takes over.
  String? _handedOver;

  final TourCubit _tour = getIt<TourCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // First run only. The tour waits for this screen to finish arriving
    // before it points at anything, so asking straight away is fine.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tour.requestIfNew();
      unawaited(_runHomeAsk());
    });
  }

  /// The consent sheet or the review popup, when one is due. Never while
  /// the tour is pointing at things.
  Future<void> _runHomeAsk() async {
    if (_tour.state.isRunning) return;
    await runHomeAsk(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(context.read<HomePromptCubit>().onAppResumed());
      unawaited(_runHomeAsk());
    }
  }

  /// Back from creating a topic, from a topic, from anywhere. Whatever the
  /// user just did could have changed this list, so load it again.
  @override
  void didPopNext() {
    if (!mounted) return;
    unawaited(context.read<HomeCubit>().refresh());
    unawaited(context.read<HomePromptCubit>().refresh());
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

  /// Pull a row right to mark it read, left to pin or mute it.
  Widget _swipe(
    HomeCubit home,
    HomeTopicItem topic, {
    required bool enabled,
    required Widget child,
  }) {
    final key = ValueKey('topic_row_${topic.name}');
    if (!enabled) return KeyedSubtree(key: key, child: child);

    final markRead = LocaleKeys.home_swipe_mark_read.tr();
    final pin = topic.isPinned
        ? LocaleKeys.home_swipe_unpin.tr()
        : LocaleKeys.home_swipe_pin.tr();
    final mute = topic.isMuted
        ? LocaleKeys.home_swipe_unmute.tr()
        : LocaleKeys.home_swipe_mute.tr();

    // The same three actions for VoiceOver and TalkBack, which cannot swipe
    // a row open: they show up in the actions rotor on the row.
    return Semantics(
      key: key,
      customSemanticsActions: {
        CustomSemanticsAction(label: markRead): () =>
            unawaited(home.markRead(topic.name)),
        CustomSemanticsAction(label: pin): () =>
            unawaited(home.togglePin(topic.name)),
        CustomSemanticsAction(label: mute): () =>
            unawaited(home.toggleMute(topic.name)),
      },
      child: AppSwipeActions(
        groupTag: 'home_topics',
        start: [
          AppSwipeAction(
            label: markRead,
            glyph: GlyphType.check,
            isPrimary: true,
            onPressed: () => unawaited(home.markRead(topic.name)),
          ),
        ],
        end: [
          AppSwipeAction(
            label: pin,
            glyph: GlyphType.pin,
            isPrimary: true,
            onPressed: () => unawaited(home.togglePin(topic.name)),
          ),
          AppSwipeAction(
            label: mute,
            glyph: topic.isMuted ? GlyphType.bell : GlyphType.bellOff,
            onPressed: () => unawaited(home.toggleMute(topic.name)),
          ),
        ],
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = AppSize.of(context);

    return BlocConsumer<HomeCubit, HomeState>(
      listener: (context, state) => _handOverIfRinging(state),
      builder: (context, state) => BlocBuilder<TourCubit, TourState>(
        bloc: _tour,
        builder: (context, tour) =>
            BlocBuilder<HomePromptCubit, HomePromptState>(
              builder: (context, prompt) =>
                  _build(context, size, state, tour, prompt),
            ),
      ),
    );
  }

  Widget _build(
    BuildContext context,
    AppSize size,
    HomeState real,
    TourState tour,
    HomePromptState prompt,
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

    // Built once, because a list that cannot be reached shows the same rows
    // as a live one, only dimmed.
    final home = context.read<HomeCubit>();
    final rows = <Widget>[
      for (final topic in state.topicItems) ...[
        _swipe(
          home,
          topic,
          // Tour rows are examples, not topics, so there is nothing to pin.
          // Old rows from an unreachable server are look-only.
          enabled: !showExamples && !state.isStale,
          child: AppListRow(
            name: topic.name,
            meta: topic.meta,
            preview: topic.preview,
            unreadCount: topic.unreadCount,
            isPinned: topic.isPinned,
            isMuted: topic.isMuted,
            isSelected: size.isExpanded && topic.name == selected,
            faceState: topic.faceState,
            isCrit: topic.isCrit,
            isQuiet: topic.isQuiet,
            // The priority that came in is only shown while there is
            // something live. Once the alarm is acknowledged the row goes
            // back to saying how the topic is set up, so a red chip never
            // contradicts the calm face above.
            trailing: topic.isLive
                ? AppPriorityChip(priority: topic.priority)
                : AppDeliveryChip(
                    rings: topic.ringsThroughSilent,
                    label: topic.ringsThroughSilent
                        ? LocaleKeys.home_delivery_rings.tr()
                        : LocaleKeys.home_delivery_normal.tr(),
                  ),
            onTap: () {
              // Opening a topic reads it.
              if (!showExamples) unawaited(home.markRead(topic.name));
              if (size.isExpanded) {
                AppHaptics.selection();
                setState(() => _selectedTopic = topic.name);
              } else {
                unawaited(context.push('/topics/${topic.name}'));
              }
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];

    return SeverityScope(
      severity: state.severity,
      child: AppScreenScaffold(
        onFaceRefresh: () async {
          final promptCubit = context.read<HomePromptCubit>();
          final homeCubit = context.read<HomeCubit>();
          await promptCubit.refresh();
          return homeCubit.refresh();
        },
        // Search is not up here any more. It lives next to the compose
        // button on the floating bar, so it is reachable from every tab
        // rather than only this one.
        topBar: AppTopBar(
          title: LocaleKeys.topics_list_title.tr(),
          trailing: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [ProStatusBadge(), RefreshActivityIndicator()],
          ),
        ),
        // The backup nudge floats above the tab bar rather than sitting in
        // the list, so it stays put however many topics there are and never
        // pushes one off the screen.
        bottomBar: prompt.promptType != HomePromptType.accountBackup
            ? null
            : AppPinnedNudgeBar(
                face: FaceState.watching,
                title: LocaleKeys.home_account_prompt_title.tr(),
                linkLabel: LocaleKeys.home_prompt_why.tr(),
                onTap: () => unawaited(
                  showPromptDetailSheet(
                    context: context,
                    face: FaceState.watching,
                    title: LocaleKeys.home_account_prompt_title.tr(),
                    body: LocaleKeys.home_account_prompt_body.tr(),
                    actionLabel: LocaleKeys.home_account_prompt_button.tr(),
                    onAction: () => openAppPath(context, '/settings/account'),
                    onDismiss: () => unawaited(
                      context.read<HomePromptCubit>().dismissCurrent(),
                    ),
                  ),
                ),
                onDismiss: () => unawaited(
                  context.read<HomePromptCubit>().dismissCurrent(),
                ),
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
          // Single slot orchestrating blocker errors, health warnings,
          // and dismissible growth prompts above the stage.
          const SliverToBoxAdapter(child: HomePromptSlot()),
          // A failed load has something to say too, and it says it up here
          // rather than leaving the face out and the screen silent.
          if (state.topicItems.isNotEmpty || state.status == HomeStatus.failure)
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
                      // Nothing is happening, so the face gets something to
                      // do. Any other state means something real, and those
                      // faces are left alone to say it. The stage hands this
                      // to the refresh face rather than replacing it, so
                      // pulling the list still moves the face.
                      idleWhenCalm: true,
                    ),
                  ),
                  const SizedBox(height: Spacing.s4),
                ],
              ),
            ),
          // With no server saved there is nothing to list and nothing to say
          // that the red card above is not already saying, so the sheet does
          // not draw at all. An empty one is a blank white box with a shadow.
          if (state.hasServer)
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
                        if (state.isStale) ...[
                          AppToast(
                            faceState: FaceState.watching,
                            message: LocaleKeys.home_unreachable_strip.tr(
                              namedArgs: {
                                'time': DateFormat.Hm().format(
                                  state.lastKnownGoodAt!.toLocal(),
                                ),
                              },
                            ),
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
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              LocaleKeys.home_stale_list_label.tr(
                                namedArgs: {
                                  'time': DateFormat.Hm().format(
                                    state.lastKnownGoodAt!.toLocal(),
                                  ),
                                },
                              ),
                              style: AppTypography.mono(
                                context.appColors.ink3,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // The rows are the user's own, just old, so they
                          // stay. Dimmed and dead to the touch, because
                          // opening one would show numbers from then, not now.
                          Opacity(
                            opacity: 0.45,
                            child: IgnorePointer(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: rows,
                              ),
                            ),
                          ),
                        ] else if (state.status == HomeStatus.failure) ...[
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
                          // Opening one row's buttons closes any other.
                          SlidableAutoCloseBehavior(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: rows,
                            ),
                          ),
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
