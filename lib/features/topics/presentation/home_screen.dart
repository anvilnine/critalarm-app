import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/route_observer.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/permissions/presentation/widgets/setup_health_banner.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:critalarm/features/topics/presentation/topic_detail_screen.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcase_tutorial/showcase_tutorial.dart';

/// HomeScreen matching docs/design-system/index.html mobile mockup.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const tourCompletedKey = 'has_completed_showcase_tour';

  static Future<void> _markTourCompleted() async {
    if (getIt.isRegistered<SharedPreferences>()) {
      await getIt<SharedPreferences>().setBool(tourCompletedKey, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<HomeCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: ShowCaseWidget(
        onFinish: _markTourCompleted,
        onDismiss: (_) => _markTourCompleted(),
        builder: Builder(
          builder: (context) => const _HomeScreenContent(),
        ),
      ),
    );
  }
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();

  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent>
    with WidgetsBindingObserver, RouteAware {
  String? _selectedTopic;

  /// The incident this screen has already handed over for. Kept so backing out
  /// of the alarm screen does not bounce the user straight back into it, while
  /// a new incident still takes over.
  String? _handedOver;

  final GlobalKey _stageKey = GlobalKey();
  final GlobalKey _topicsSheetKey = GlobalKey();
  Timer? _tourTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTourIfNew());
  }

  Future<void> _startTourIfNew() async {
    if (!getIt.isRegistered<SharedPreferences>()) return;
    final prefs = getIt<SharedPreferences>();
    final completed = prefs.getBool(HomeScreen.tourCompletedKey) ?? false;
    if (!completed && mounted) {
      _tourTimer?.cancel();
      _tourTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          ShowCaseWidget.of(
            context,
          ).startShowCase([_stageKey, _topicsSheetKey]);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    _tourTimer?.cancel();
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from creating a topic, from a topic, from anywhere. Whatever the
  /// user just did could have changed this list, so load it again.
  @override
  void didPopNext() {
    if (!mounted) return;
    unawaited(context.read<HomeCubit>().refresh());
  }

  /// Coming back to the app reloads the list. A page can land while the phone
  /// is in a pocket, and the whole point of this screen is to show it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
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
      builder: (context, state) {
        return SeverityScope(
          severity: state.severity,
          child: AppScreenScaffold(
            onRefresh: () => context.read<HomeCubit>().refresh(),
            // Search is not up here any more. It lives next to the compose
            // button on the floating bar, so it is reachable from every tab
            // rather than only this one.
            topBar: AppTopBar(title: LocaleKeys.topics_list_title.tr()),
            detail: state.topicItems.isEmpty
                ? null
                : (_selectedTopic == null
                      ? AppEmptyState(
                          title: LocaleKeys.home_detail_empty_title.tr(),
                          description: LocaleKeys.home_detail_empty_body.tr(),
                          buttonLabel: null,
                        )
                      : TopicDetailScreen(
                          key: ValueKey(_selectedTopic),
                          topicName: _selectedTopic!,
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
                      Showcase(
                        key: _stageKey,
                        title: LocaleKeys.showcase_topic_title.tr(),
                        description: LocaleKeys.showcase_topic_desc.tr(),
                        targetBorderRadius: BorderRadius.circular(16),
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
                  child: Showcase(
                    key: _topicsSheetKey,
                    title: state.topicItems.isEmpty
                        ? LocaleKeys.showcase_create_title.tr()
                        : LocaleKeys.showcase_topic_title.tr(),
                    description: state.topicItems.isEmpty
                        ? LocaleKeys.showcase_create_desc.tr()
                        : LocaleKeys.showcase_webhook_desc.tr(),
                    targetBorderRadius: BorderRadius.circular(16),
                    child: AppSheet(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.topicItems.isEmpty) ...[
                            AppEmptyState(
                              onButtonPressed: () =>
                                  context.push('/topics/new'),
                            ),
                          ] else ...[
                            for (final topic in state.topicItems) ...[
                              AppListRow(
                                name: topic.name,
                                meta: topic.meta,
                                isSelected:
                                    size.isExpanded &&
                                    topic.name == _selectedTopic,
                                faceState: topic.faceState,
                                isCrit: topic.isCrit,
                                isQuiet: topic.isQuiet,
                                trailing: AppPriorityChip(
                                  priority: topic.priority,
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
      },
    );
  }
}
