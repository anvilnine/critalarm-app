import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/route_observer.dart';
import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_state.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_anchor.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_examples.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:critalarm/features/in_app_notices/domain/day0_card_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/day0_card_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_state.dart';
import 'package:critalarm/features/in_app_notices/presentation/home_asks.dart';
import 'package:critalarm/features/in_app_notices/presentation/notice_return_rule.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/in_app_notice_slot.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/notice_detail_sheet.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/pro_plan_sheet.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/paywall/presentation/widgets/pro_status_badge.dart';
import 'package:critalarm/features/topics/domain/home_face_rule.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:critalarm/features/topics/domain/setup_finish_glow.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:critalarm/features/topics/presentation/topic_detail_screen.dart';
import 'package:critalarm/features/topics/presentation/widgets/home_day0_card.dart';
import 'package:critalarm/features/topics/presentation/widgets/home_setup_pill.dart';
import 'package:critalarm/features/topics/presentation/widgets/home_setup_preview.dart';
import 'package:critalarm/features/topics/presentation/widgets/home_setup_section.dart';
import 'package:critalarm/features/topics/presentation/widgets/home_widgets_sheet.dart';
import 'package:critalarm/features/topics/presentation/widgets/setup_glow.dart';
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
            final cubit = getIt<InAppNoticeCubit>(
              param1: context.read<ShellCubit>(),
            );
            unawaited(cubit.load());
            return cubit;
          },
        ),
        // The setup checklist and the widgets card. Home content: it is
        // fed by the list above and never by the notice slot.
        BlocProvider(create: (_) => getIt<HomeSetupCubit>()),
        // The day-0 card. Decided after the asks, in `runHomeAsk`.
        BlocProvider(create: (_) => getIt<Day0CardCubit>()),
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

  final FeatureGuideCubit _guides = getIt<FeatureGuideCubit>();
  StreamSubscription<FeatureGuideState>? _guideSub;
  StreamSubscription<FeatureGuideState>? _guideSetupSub;

  /// Another screen is on top of Home.
  bool _isCovered = false;

  /// The app is open and at the front.
  bool _isResumed = true;

  /// Bumped on every cover and uncover, so a late "back in view" from an
  /// earlier pop is dropped.
  int _viewChange = 0;

  /// The topic setup made, when setup ended a moment ago and handed over to
  /// this screen. Its row glows once. Null on every other opening of Home.
  String? _glowTopic;

  /// The glow has started. It then runs to its end by itself.
  bool _glowPlays = false;

  /// Lets the glow go once it has run, so a row that is built again later
  /// never plays it a second time.
  Timer? _glowEnds;

  /// Starts the glow once it can be seen, or lets it go. See
  /// [setupGlowStepFor].
  void _updateSetupGlow() {
    final topic = _glowTopic;
    if (!mounted || topic == null || _glowPlays) return;
    final home = context.read<HomeCubit>().state;
    final guide = _guides.state;
    final isOffered = guide.status == FeatureGuideStatus.offering;
    final step = setupGlowStepFor(
      isHomeInFront:
          !_isCovered &&
          !_isRouteElsewhere &&
          isHomeFrontScreen(
            location: _routerLocation(),
            isAppResumed: _isResumed,
          ),
      isGuideOffered: isOffered,
      isGuideRunning: guide.isActive && !isOffered,
      isListLoaded: home.status == HomeStatus.success && !home.isStale,
      hasTopicRow: home.topicItems.any((item) => item.name == topic),
    );
    switch (step) {
      case SetupGlowStep.wait:
        break;
      case SetupGlowStep.play:
        setState(() => _glowPlays = true);
        _glowEnds = Timer(setupGlowTakes(isStill: context.reduceMotion), () {
          if (!mounted) return;
          setState(() {
            _glowTopic = null;
            _glowPlays = false;
          });
        });
      case SetupGlowStep.drop:
        setState(() => _glowTopic = null);
    }
  }

  @override
  void initState() {
    super.initState();
    // Taken once: only the Home that setup hands over to finds a topic here.
    _glowTopic = setupFinishSignal.take();
    WidgetsBinding.instance.addObserver(this);
    homeSetupPreview.addListener(_onSetupPreview);
    // The FeatureGuideHost asks for this screen's guide on the first visit.
    // The notices and the asks hold off until no guide is running, and come
    // back once one ends.
    _guideSub = _guides.stream.where((guide) => !guide.isActive).listen((_) {
      if (!mounted) return;
      unawaited(context.read<InAppNoticeCubit>().load());
      unawaited(_runHomeAsk());
    });
    // The setup checklist hears every guide change, the offer included: it
    // holds still while one is up.
    _guideSetupSub = _guides.stream.listen((_) => _tellSetup());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_runHomeAsk(isNewOpen: true));
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      _isResumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
      unawaited(
        context.read<HomeSetupCubit>().homeChanged(
          context.read<HomeCubit>().state,
        ),
      );
      _tellSetup();
    });
  }

  /// A developer asked for a look at the setup pill, or closed it.
  void _onSetupPreview() {
    if (mounted) setState(() {});
  }

  /// Tells the setup checklist whether the user is looking at Home. It
  /// ticks rows, celebrates and polls for the first message only while they
  /// are.
  void _tellSetup() {
    if (!mounted) return;
    // The same changes decide whether the glow from setup can be seen.
    _updateSetupGlow();
    unawaited(
      context.read<HomeSetupCubit>().screenChanged(
        // Both have to agree. The route observer only hears about pages
        // on this tab's own navigator, so the router's location is what
        // says an alarm, the new-topic screen, the plans or another tab
        // is on top.
        isInFront: isSetupChecklistInFront(
          isCovered: _isCovered,
          isRouteElsewhere: _isRouteElsewhere,
          // A pinned notice holds the checklist's spot. Nothing ticks or
          // celebrates behind it: that waits until the checklist is back.
          hasPinnedNotice: _isPinnedNotice(
            context.read<InAppNoticeCubit>().state,
          ),
          isHomeFront: isHomeFrontScreen(
            location: _routerLocation(),
            isAppResumed: _isResumed,
          ),
        ),
        isGuideActive: _guides.state.isActive,
      ),
    );
  }

  /// The Pro, Reminders and consent sheets and the review popup, when one is
  /// due. Never while a guide is up or about to be: they wait for it to end.
  ///
  /// [isNewOpen] is true when Home just opened or came back to the front,
  /// which is what counts toward the day-0 card's three opens.
  Future<void> _runHomeAsk({bool isNewOpen = false}) async {
    if (!mounted || _guides.state.isActive) return;
    await runHomeAsk(context, isNewOpen: isNewOpen);
  }

  GoRouter? _router;

  /// The router showed something other than Home and has not been back
  /// long enough for that screen to have slid away.
  bool _isRouteElsewhere = false;

  /// The path the router is showing right now, the top of anything pushed
  /// included.
  String _routerLocation() {
    final router = _router;
    if (router == null) return '/';
    final shown = router.routerDelegate.currentConfiguration;
    if (shown.isEmpty) return '/';
    final last = shown.last;
    return last is ImperativeRouteMatch
        ? last.matches.uri.path
        : shown.uri.path;
  }

  /// The router moved. Leaving Home counts at once. Coming back counts once
  /// the screen above has slid away, so a row that turned true over there
  /// ticks where it can be seen.
  void _onRouterMoved() {
    if (!mounted) return;
    final isHome = isHomeFrontScreen(
      location: _routerLocation(),
      isAppResumed: true,
    );
    if (!isHome) {
      _viewChange++;
      _isRouteElsewhere = true;
      _tellSetup();
      return;
    }
    if (!_isRouteElsewhere) return;
    // Back from another tab: what happened there (a missed alarm closed on
    // the Reliability screen) shows now, not at the next resume. The card
    // has the same key, so one that is still due does not slide in again.
    if (readsNoticeOnReturn(
      wasElsewhere: _isRouteElsewhere,
      isCovered: _isCovered,
    )) {
      unawaited(context.read<InAppNoticeCubit>().load());
    }
    final change = ++_viewChange;
    unawaited(
      Future<void>.delayed(AppDurations.slow, () {
        if (!mounted || change != _viewChange) return;
        _isRouteElsewhere = false;
        _isCovered = false;
        _tellSetup();
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
    final router = GoRouter.maybeOf(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_onRouterMoved);
      _router = router;
      router?.routerDelegate.addListener(_onRouterMoved);
      _isRouteElsewhere = !isHomeFrontScreen(
        location: _routerLocation(),
        isAppResumed: true,
      );
    }
  }

  @override
  void dispose() {
    _glowEnds?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    homeSetupPreview.removeListener(_onSetupPreview);
    unawaited(_guideSub?.cancel());
    unawaited(_guideSetupSub?.cancel());
    appRouteObserver.unsubscribe(this);
    _router?.routerDelegate.removeListener(_onRouterMoved);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isResumed = state == AppLifecycleState.resumed;
    _tellSetup();
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(context.read<InAppNoticeCubit>().onAppResumed());
      // Only a resume with Home in front counts as one of the card's opens.
      unawaited(
        _runHomeAsk(
          isNewOpen: countsAsHomeOpen(
            isCovered: _isCovered,
            isRouteElsewhere: _isRouteElsewhere,
            isTabShown: TickerMode.valuesOf(context).enabled,
          ),
        ),
      );
    }
  }

  /// Back from creating a topic, from a topic, from anywhere. Whatever the
  /// user just did could have changed this list, so load it again.
  @override
  void didPopNext() {
    if (!mounted) return;
    unawaited(context.read<HomeCubit>().refresh());
    unawaited(context.read<InAppNoticeCubit>().refresh());
    // Home counts as back in view once the screen above has slid away, so a
    // row that turned true over there ticks where it can be seen.
    final change = ++_viewChange;
    unawaited(
      Future<void>.delayed(AppDurations.slow, () {
        if (!mounted || change != _viewChange) return;
        _isCovered = false;
        _isRouteElsewhere = !isHomeFrontScreen(
          location: _routerLocation(),
          isAppResumed: true,
        );
        _tellSetup();
      }),
    );
  }

  @override
  void didPushNext() {
    _viewChange++;
    _isCovered = true;
    _tellSetup();
  }

  void _openSetupRoute(String route) => unawaited(context.push(route));

  void _openWidgetsPaywall() {
    unawaited(context.read<HomeSetupCubit>().widgetsPlansOpened());
    unawaited(
      openPaywallFor(
        context,
        getIt<FeatureAccess>().decide(AppFeature.widgets),
        LockSource.homeWidgets,
      ),
    );
  }

  void _openDay0Plans() {
    unawaited(context.read<Day0CardCubit>().seePlans());
    unawaited(context.push(hostedPaywallLocation(PaywallSource.homeDay0Card)));
  }

  void _showWidgetsHowTo(HomeWidgetsPlan plan) {
    final setup = context.read<HomeSetupCubit>();
    unawaited(setup.widgetsHowToOpened());
    unawaited(
      showHomeWidgetsSheet(
        context: context,
        platform: setup.platform,
        plan: plan,
        onSeeHosted: () {
          if (!mounted) return;
          unawaited(
            openPaywallFor(
              context,
              getIt<FeatureAccess>().decide(AppFeature.widgets),
              LockSource.homeWidgets,
            ),
          );
        },
      ),
    );
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

  /// [row] with the one-time glow over it when [topicName] is the topic
  /// setup just made. Every other row is handed back as it is.
  Widget _glowIfFromSetup(String topicName, Widget row) =>
      topicName == _glowTopic
      ? SetupGlow(isPlaying: _glowPlays, child: row)
      : row;

  /// Pull a row right to mark it read, left to pin or mute it.
  Widget _swipe(
    HomeCubit home,
    HomeTopicItem topic, {
    required bool enabled,
    required Widget child,
  }) {
    final key = ValueKey('topic_row_${topic.name}');
    final row = _glowIfFromSetup(topic.name, child);
    if (!enabled) return KeyedSubtree(key: key, child: row);

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
        child: row,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = AppSize.of(context);

    return BlocConsumer<HomeCubit, HomeState>(
      listener: (context, state) {
        _handOverIfRinging(state);
        _updateSetupGlow();
        unawaited(context.read<HomeSetupCubit>().homeChanged(state));
      },
      builder: (context, state) =>
          BlocBuilder<FeatureGuideCubit, FeatureGuideState>(
            bloc: _guides,
            builder: (context, guide) =>
                BlocConsumer<InAppNoticeCubit, InAppNoticeState>(
                  listenWhen: (previous, current) =>
                      _isPinnedNotice(previous) != _isPinnedNotice(current),
                  listener: (context, notice) => _tellSetup(),
                  builder: (context, notice) =>
                      BlocBuilder<HomeSetupCubit, HomeSetupState>(
                        builder: (context, setup) => _build(
                          context,
                          size,
                          state,
                          guide,
                          notice,
                          setup,
                        ),
                      ),
                ),
          ),
    );
  }

  Widget _build(
    BuildContext context,
    AppSize size,
    HomeState real,
    FeatureGuideState guide,
    InAppNoticeState notice,
    HomeSetupState setup,
  ) {
    // While the guide runs, the list gets an example topic that is ringing,
    // so the user sees what trouble looks like before it happens. Someone
    // with no topics yet also gets two calm ones. They all go when the guide
    // does.
    final showExamples =
        guide.showsHomeExamples && real.status == HomeStatus.success;
    // The stage says what the list says: the example is ringing, so the face
    // is alarmed too. It has no ringing incident, so it hands nothing to the
    // takeover screen.
    final exampleStage = showExamples
        ? FeatureGuideExamples.troubleStage()
        : null;
    final staged = !showExamples
        ? real
        : real.isEmpty
        ? real.copyWith(
            topicItems: [
              FeatureGuideExamples.troubleTopic(),
              ...FeatureGuideExamples.homeTopics(),
            ],
            faceState: exampleStage!.faceState,
            word: exampleStage.word,
            subText: exampleStage.subText,
            severity: exampleStage.severity,
          )
        : real.copyWith(
            topicItems: [
              FeatureGuideExamples.troubleTopic(),
              ...real.topicItems,
            ],
            faceState: exampleStage!.faceState,
            word: exampleStage.word,
            subText: exampleStage.subText,
            severity: exampleStage.severity,
          );
    // While a notice that asks for a look is up (a missed alarm, missed
    // weekly checks, a phone update), the stage does not say "All clear" over
    // a glad face. It wears the look face. A live alarm keeps the stage as
    // it is.
    final state =
        _lookNoticeShows(notice, guide) && staged.status == HomeStatus.success
        ? _lookStage(staged)
        : staged;
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
          // Guide rows are examples, not topics, so there is nothing to pin.
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

    // The setup checklist, its finished line or the widgets card, at the
    // top of the list sheet. Home content, drawn here and nowhere else.
    // Only over a list that loaded, and never beside a running guide's
    // example rows. The offer sheet is not a guide yet, so the checklist
    // stays put under it instead of jumping when it closes.
    final showsSetup =
        real.status == HomeStatus.success &&
        !real.isStale &&
        (!guide.isActive || guide.status == FeatureGuideStatus.offering);
    final setupState = showsSetup ? setup : const HomeSetupState();
    // The day-0 card, under the same conditions as the setup content.
    final showsDay0Card = showsSetup && context.watch<Day0CardCubit>().state;

    // The one card floating above the tab bar. A pinned notice has it
    // first; the setup checklist takes it when no notice does. Nothing but
    // the guide while one is up: the card comes back after.
    final noticeBar = guide.isActive ? null : _noticeBar(context, notice);
    final preview = buildHasOnboardingDeveloperTools
        ? homeSetupPreview.value
        : null;
    final pillState = preview != null ? homeSetupPreviewState : setupState;
    final showsPill =
        (pillState.phase == HomeSetupPhase.checklist ||
            pillState.phase == HomeSetupPhase.celebration) &&
        setupPillHasTheSpot(
          hasPinnedNotice: noticeBar != null,
          isGuideRunning:
              guide.isActive && guide.status != FeatureGuideStatus.offering,
        );
    final setupPill = showsPill
        ? HomeSetupPill(
            // A preview is its own widget, so it opens the way it was asked.
            key: ValueKey(preview),
            state: pillState,
            startsOpen: preview == HomeSetupPreview.open,
            onRowTap: _openSetupRoute,
            onDismiss: () {
              if (preview != null) {
                homeSetupPreview.value = null;
                return;
              }
              unawaited(context.read<HomeSetupCubit>().checklistDismissed());
            },
          )
        : null;

    final screen = SeverityScope(
      severity: state.severity,
      child: AppScreenScaffold(
        onFaceRefresh: () async {
          final noticeCubit = context.read<InAppNoticeCubit>();
          final homeCubit = context.read<HomeCubit>();
          await noticeCubit.refresh();
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
        // Narrower than the topics card and wider than the tab bar, so the
        // three step in towards the bottom.
        bottomBar: switch (noticeBar ?? setupPill) {
          final bar? => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: bar,
          ),
          null => null,
        },
        detail: state.topicItems.isEmpty
            ? null
            : (selected == null
                  ? AppEmptyState(
                      title: LocaleKeys.home_detail_empty_title.tr(),
                      description: LocaleKeys.home_detail_empty_body.tr(),
                    )
                  : TopicDetailScreen(
                      key: ValueKey(selected),
                      topicName: selected,
                      isPane: true,
                    )),
        slivers: [
          // Single slot orchestrating blocker errors, health warnings,
          // and dismissible growth notices above the stage.
          // Hidden while a guide is up, so no card slides in under it.
          SliverToBoxAdapter(
            child: guide.isActive
                ? const SizedBox.shrink()
                : const InAppNoticeSlot(),
          ),
          // A failed load has something to say too, and it says it up here
          // rather than leaving the face out and the screen silent.
          if (state.topicItems.isNotEmpty || state.status == HomeStatus.failure)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: Spacing.s3),
                  FeatureGuideAnchor(
                    id: FeatureGuideAnchorId.homeStage,
                    child: AppStage(
                      faceState: state.faceState,
                      faceSize: _stageFaceSize(context),
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
                child: FeatureGuideAnchor(
                  id: FeatureGuideAnchorId.topicList,
                  child: AppSheet(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HomeSetupSection(
                          state: setupState,
                          hasRowsBelow: true,
                          onShowWidgetsHowTo: () =>
                              _showWidgetsHowTo(setupState.widgetsPlan),
                          onSeeHosted: _openWidgetsPaywall,
                          onDismissWidgetsCard: () => unawaited(
                            context
                                .read<HomeSetupCubit>()
                                .widgetsCardDismissed(),
                          ),
                        ),
                        // One card at a time: the widgets card goes first.
                        if (showsDay0Card &&
                            setupState.phase != HomeSetupPhase.widgetsCard)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Spacing.s4),
                            child: HomeDay0Card(
                              onSeePlans: _openDay0Plans,
                              onDismiss: () => unawaited(
                                context.read<Day0CardCubit>().dismiss(),
                              ),
                            ),
                          ),
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
                            followsRefresh: true,
                            radius: Radii.md,
                          ),
                        ] else if (state.isEmpty) ...[
                          AppEmptyState(
                            title: LocaleKeys.home_stage_word_no_topics.tr(),
                            description: LocaleKeys.home_empty_body.tr(),
                            buttonLabel: LocaleKeys.home_empty_button.tr(),
                            onButtonPressed: () => context.push('/topics/new'),
                            followsRefresh: true,
                            // The sheet is Radii.xl (32) with 16 of padding, so
                            // the dashed card inside is Radii.md (18) to sit
                            // concentric rather than 32 on 32.
                            radius: Radii.md,
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

    // One short throw of confetti when the checklist finishes, over the
    // whole screen and dead to the touch.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        screen,
        if (setupState.phase == HomeSetupPhase.celebration)
          const Positioned.fill(child: HomeSetupConfetti()),
      ],
    );
  }

  /// The face on the stage. At the larger text sizes its words take more
  /// room, so the face gives some back and the line under it stays clear of
  /// the tab bar. The normal size is unchanged up to 1.3x.
  static double _stageFaceSize(BuildContext context) {
    const normal = 190.0;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    if (scale <= kChromeMaxTextScale) return normal;
    return (normal * kChromeMaxTextScale / scale).clamp(96.0, normal);
  }

  /// True while a card that asks for a look is drawn in the notice slot. The
  /// slot is hidden under a running guide and while a card is closing.
  static bool _lookNoticeShows(
    InAppNoticeState notice,
    FeatureGuideState guide,
  ) => !guide.isActive && notice.asksForLook;

  /// [home] with its stage changed by `heroWhileLookNoticeShows`.
  static HomeState _lookStage(HomeState home) {
    final hero = heroWhileLookNoticeShows(
      HomeHero(
        faceState: home.faceState,
        word: home.word,
        subText: home.subText,
        severity: home.severity,
        ringingIncidentId: home.ringingIncidentId,
      ),
    );
    return home.copyWith(
      faceState: hero.faceState,
      word: hero.word,
      subText: hero.subText,
      severity: hero.severity,
    );
  }

  /// Whether [notice] is one of the notices [_noticeBar] pins above the tab
  /// bar. The rest are cards in the list, or nothing.
  static bool _isPinnedNotice(InAppNoticeState notice) =>
      switch (notice.noticeType) {
        InAppNoticeType.proEnding ||
        InAppNoticeType.batteryOptimization ||
        InAppNoticeType.accountBackup => true,
        InAppNoticeType.none ||
        InAppNoticeType.noServer ||
        InAppNoticeType.systemUpdate ||
        InAppNoticeType.missedAlarm ||
        InAppNoticeType.weeklyCheck ||
        InAppNoticeType.criticalHealth => false,
      };

  /// The one pill floating above the tab bar: battery first, then Pro ending,
  /// then the sign-in notice.
  Widget? _noticeBar(BuildContext context, InAppNoticeState notice) {
    final cubit = context.read<InAppNoticeCubit>();
    switch (notice.noticeType) {
      case InAppNoticeType.proEnding:
        final endsAt = notice.proEndsAt!;
        return AppPinnedNoticeBar(
          face: FaceState.watching,
          title: LocaleKeys.notices_pro_ending_pill.tr(
            namedArgs: {'weekday': DateFormat('EEEE').format(endsAt)},
          ),
          linkLabel: LocaleKeys.notices_why.tr(),
          onTap: () => unawaited(
            showProPlanSheet(
              context,
              ProEndingView(sheet: ProPlanSheet.ending, endsAt: endsAt),
              onDismiss: () => unawaited(cubit.dismissCurrent()),
            ),
          ),
          onDismiss: () => unawaited(cubit.dismissCurrent()),
        );
      case InAppNoticeType.batteryOptimization:
        return AppPinnedNoticeBar(
          face: FaceState.watching,
          title: LocaleKeys.notices_battery_title.tr(),
          linkLabel: LocaleKeys.notices_why.tr(),
          onTap: () => unawaited(
            showNoticeDetailSheet(
              context: context,
              face: FaceState.watching,
              title: LocaleKeys.notices_battery_title.tr(),
              body: LocaleKeys.notices_battery_body.tr(),
              actionLabel: LocaleKeys.notices_battery_button.tr(),
              onAction: () {
                unawaited(cubit.dismissCurrent());
                openAppPath(context, '/settings/permissions');
              },
              onDismiss: () => unawaited(cubit.dismissCurrent()),
            ),
          ),
          onDismiss: () => unawaited(cubit.dismissCurrent()),
        );
      case InAppNoticeType.accountBackup:
        return AppPinnedNoticeBar(
          face: FaceState.watching,
          title: LocaleKeys.notices_account_backup_title.tr(),
          linkLabel: LocaleKeys.notices_why.tr(),
          onTap: () => unawaited(
            showNoticeDetailSheet(
              context: context,
              face: FaceState.watching,
              title: LocaleKeys.notices_account_backup_title.tr(),
              body: LocaleKeys.notices_account_backup_body.tr(),
              actionLabel: LocaleKeys.notices_account_backup_button.tr(),
              onAction: () => openAppPath(context, '/settings/account'),
              onDismiss: () => unawaited(cubit.dismissCurrent()),
            ),
          ),
          onDismiss: () => unawaited(cubit.dismissCurrent()),
        );
      case InAppNoticeType.none:
      case InAppNoticeType.noServer:
      case InAppNoticeType.systemUpdate:
      case InAppNoticeType.missedAlarm:
      case InAppNoticeType.weeklyCheck:
      case InAppNoticeType.criticalHealth:
        return null;
    }
  }
}
