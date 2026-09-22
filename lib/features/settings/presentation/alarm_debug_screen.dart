import 'dart:async';
import 'dart:convert';

import 'package:critalarm/app/route_observer.dart';
import 'package:critalarm/core/alarm/alarm_debug_snapshot.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/cubits/alarm_debug_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/alarm_debug_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AlarmDebugScreen extends StatefulWidget {
  const AlarmDebugScreen({super.key});

  @override
  State<AlarmDebugScreen> createState() => _AlarmDebugScreenState();
}

class _AlarmDebugScreenState extends State<AlarmDebugScreen> with RouteAware {
  Timer? _timer;
  ModalRoute<void>? _route;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) unawaited(context.read<AlarmDebugCubit>().refresh());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    if (_route != null) appRouteObserver.unsubscribe(this);
    _route = route;
    if (route != null) appRouteObserver.subscribe(this, route);
    _startTimer();
  }

  @override
  void didPushNext() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didPopNext() => _startTimer();

  void _startTimer() {
    unawaited(context.read<AlarmDebugCubit>().refresh());
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) unawaited(context.read<AlarmDebugCubit>().refresh());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AlarmDebugCubit, AlarmDebugState>(
    builder: (context, state) {
      final snapshot = state.snapshot;
      return AppScreenScaffold(
        hasTabBar: false,
        onRefresh: context.read<AlarmDebugCubit>().refresh,
        topBar: AppTopBar(
          title: LocaleKeys.settings_alarm_debug_header.tr(),
          leading: AppIconButton(
            glyph: GlyphType.back,
            ariaLabel: LocaleKeys.common_back.tr(),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/settings/developer');
              }
            },
          ),
        ),
        slivers: [
          if (state.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: AppListRow(
                  name: LocaleKeys.settings_alarm_debug_error.tr(
                    args: [state.error!],
                  ),
                  meta: '',
                  faceState: null,
                  isQuiet: true,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Column(
                children: [
                  if (snapshot == null && state.loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  _section(context, LocaleKeys.settings_alarm_debug_now.tr(), [
                    if (snapshot != null) ..._nowRows(snapshot),
                  ]),
                  _section(
                    context,
                    LocaleKeys.settings_alarm_debug_incidents.tr(),
                    [
                      if (snapshot == null || snapshot.incidents.isEmpty)
                        _nothing()
                      else
                        ...snapshot.incidents.map(_incidentRow),
                    ],
                  ),
                  _section(
                    context,
                    LocaleKeys.settings_alarm_debug_ack_queue.tr(),
                    [
                      if (snapshot == null || snapshot.ackQueue.isEmpty)
                        _nothing()
                      else
                        ...snapshot.ackQueue.map(_ackRow),
                      _button(
                        LocaleKeys.settings_alarm_debug_flush_now.tr(),
                        () => context.read<AlarmDebugCubit>().performAction(
                          AlarmDebugAction.flushNow,
                        ),
                        busy:
                            state.actionInProgress ==
                            AlarmDebugAction.flushNow.wireName,
                      ),
                    ],
                  ),
                  _section(
                    context,
                    LocaleKeys.settings_alarm_debug_acked_set.tr(),
                    [
                      if (snapshot == null || snapshot.ackedSet.isEmpty)
                        _nothing()
                      else
                        ...snapshot.ackedSet.map(
                          (mark) => _row(
                            mark.incidentId,
                            _dateText(mark.markedAt),
                          ),
                        ),
                      _button(
                        LocaleKeys.settings_alarm_debug_clear_acked.tr(),
                        () => context.read<AlarmDebugCubit>().performAction(
                          AlarmDebugAction.clearAckedSet,
                        ),
                        busy:
                            state.actionInProgress ==
                            AlarmDebugAction.clearAckedSet.wireName,
                      ),
                    ],
                  ),
                  _section(
                    context,
                    LocaleKeys.settings_alarm_debug_scheduled.tr(),
                    [
                      if (snapshot == null || snapshot.scheduled.isEmpty)
                        _nothing()
                      else
                        ...snapshot.scheduled.map(
                          (item) => _row(
                            '${item.kind} · ${item.identifier}',
                            _dateText(item.firesAt),
                          ),
                        ),
                    ],
                  ),
                  _section(
                    context,
                    LocaleKeys.settings_alarm_debug_push_events.tr(),
                    [
                      if (snapshot == null || snapshot.pushEvents.isEmpty)
                        _nothing()
                      else
                        ...snapshot.pushEvents.map(
                          (event) => _row(
                            event.name ??
                                LocaleKeys.settings_alarm_debug_nothing.tr(),
                            const JsonEncoder().convert(event.values),
                          ),
                        ),
                    ],
                  ),
                  _section(
                    context,
                    LocaleKeys.settings_alarm_debug_launch_calls.tr(),
                    [
                      if (snapshot == null || snapshot.launchCalls.isEmpty)
                        _nothing()
                      else
                        ...snapshot.launchCalls.map(
                          (call) => _row(
                            '${call.name}${call.attempt == null ? '' : ' #${call.attempt}'}',
                            '${call.succeeded ? 'success' : call.error} · ${_dateText(call.at)}',
                          ),
                        ),
                    ],
                  ),
                  _section(
                    context,
                    LocaleKeys.settings_alarm_debug_local_store.tr(),
                    [
                      if (snapshot == null)
                        _nothing()
                      else
                        ..._storeRows(snapshot.store),
                    ],
                  ),
                  _section(
                    context,
                    LocaleKeys.settings_alarm_debug_actions.tr(),
                    [
                      _button(
                        LocaleKeys.settings_alarm_debug_refresh.tr(),
                        () => context.read<AlarmDebugCubit>().refresh(),
                        busy: state.loading,
                      ),
                      _button(
                        LocaleKeys.settings_alarm_debug_copy_report.tr(),
                        _copyReport,
                      ),
                      _button(
                        LocaleKeys.settings_alarm_debug_cancel_rearms.tr(),
                        () => context.read<AlarmDebugCubit>().performAction(
                          AlarmDebugAction.cancelAllRearms,
                        ),
                        busy:
                            state.actionInProgress ==
                            AlarmDebugAction.cancelAllRearms.wireName,
                      ),
                      _button(
                        LocaleKeys.settings_alarm_debug_clear_content.tr(),
                        () => context.read<AlarmDebugCubit>().performAction(
                          AlarmDebugAction.clearContentCache,
                        ),
                        busy:
                            state.actionInProgress ==
                            AlarmDebugAction.clearContentCache.wireName,
                      ),
                      _button(
                        LocaleKeys.settings_alarm_debug_reconcile.tr(),
                        () => context.read<AlarmDebugCubit>().performAction(
                          AlarmDebugAction.reconcileNow,
                        ),
                        busy:
                            state.actionInProgress ==
                            AlarmDebugAction.reconcileNow.wireName,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  List<Widget> _nowRows(AlarmDebugSnapshot snapshot) => [
    _row(
      LocaleKeys.settings_alarm_debug_device_time.tr(),
      _dateText(snapshot.takenAt),
    ),
    _row(LocaleKeys.settings_alarm_debug_ringing.tr(), '${snapshot.ringing}'),
    _row(
      LocaleKeys.settings_alarm_debug_server.tr(),
      '${snapshot.environment.serverMode ?? '—'} · ${snapshot.environment.baseUrl ?? '—'}',
    ),
    _row(
      LocaleKeys.settings_alarm_debug_tier.tr(),
      snapshot.environment.tier ?? '—',
    ),
    _row(
      LocaleKeys.settings_alarm_debug_history_window.tr(),
      snapshot.environment.historyDays?.toString() ?? '—',
    ),
    _row(
      LocaleKeys.settings_alarm_debug_quiet_hours.tr(),
      '${snapshot.environment.quietHoursEnabled ? 'on' : 'off'} · ${snapshot.environment.quietHoursStart ?? '—'}–${snapshot.environment.quietHoursEnd ?? '—'} · ${snapshot.environment.quietHoursHolding ? 'holding' : 'not holding'}',
    ),
    _row(
      LocaleKeys.settings_alarm_debug_alarmkit.tr(),
      snapshot.permissions.alarmkit,
    ),
    _row(
      LocaleKeys.settings_alarm_debug_notifications.tr(),
      snapshot.permissions.notifications,
    ),
    _row(
      LocaleKeys.settings_alarm_debug_battery_exemption.tr(),
      snapshot.permissions.batteryExempt?.toString() ?? 'unsupported',
    ),
  ];

  List<Widget> _storeRows(DebugStoreStats store) => [
    _row(
      LocaleKeys.settings_alarm_debug_incident_count.tr(),
      '${store.incidentCount}',
    ),
    _row(
      LocaleKeys.settings_alarm_debug_message_count.tr(),
      '${store.messageCount}',
    ),
    _row(
      LocaleKeys.settings_alarm_debug_oldest_incident.tr(),
      _dateText(store.oldestIncidentAt),
    ),
    _row(
      LocaleKeys.settings_alarm_debug_database_size.tr(),
      store.databaseBytes == null ? '—' : '${store.databaseBytes} bytes',
    ),
    _row(
      LocaleKeys.settings_alarm_debug_last_sync.tr(),
      _dateText(store.lastSyncAt),
    ),
    _row(
      LocaleKeys.settings_alarm_debug_last_since.tr(),
      store.lastSince ?? '—',
    ),
  ];

  Widget _section(BuildContext context, String title, List<Widget> rows) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppSheet(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (rows.isEmpty) _nothing() else ...rows,
            ],
          ),
        ),
      );

  Widget _nothing() => AppListRow(
    name: LocaleKeys.settings_alarm_debug_nothing.tr(),
    meta: '',
    faceState: null,
    isQuiet: true,
  );

  Widget _row(String name, String value) => AppListRow(
    name: name,
    meta: '',
    faceState: null,
    trailing: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
      ),
    ),
  );

  Widget _incidentRow(DebugIncident incident) => _row(
    '${incident.topic ?? '—'} · ${incident.id}',
    '${incident.phoneState} · ring until ${_dateText(incident.ringUntil)}'
        '${incident.rearmPending ? ' · re-arm ${_dateText(incident.rearmFiresAt)}' : ''}',
  );

  Widget _ackRow(DebugAckEntry entry) => _row(
    '${entry.action} · ${entry.incidentId}',
    '${entry.source.name} · attempts ${entry.attempts} · next ${_dateText(entry.nextAttemptAt)}${entry.lastError == null ? '' : ' · ${entry.lastError}'}',
  );

  Widget _button(
    String label,
    Future<void> Function() onPressed, {
    bool busy = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: AppButton(
      label: label,
      size: AppButtonSize.sm,
      variant: AppButtonVariant.ghost,
      isLoading: busy,
      onPressed: () => unawaited(onPressed()),
    ),
  );

  Future<void> _copyReport() async {
    final text = context.read<AlarmDebugCubit>().copyReportJson();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocaleKeys.settings_alarm_debug_report_copied.tr()),
        ),
      );
    }
  }
}

String _dateText(DateTime? time) {
  if (time == null) return '—';
  final local = time.toLocal();
  final difference = local.difference(DateTime.now());
  final absolute = DateFormat.yMMMd().add_jm().format(local);
  final duration = difference.abs();
  final relative = duration.inDays > 0
      ? '${duration.inDays}d'
      : duration.inHours > 0
      ? '${duration.inHours}h'
      : '${duration.inMinutes}m';
  return '$absolute · ${difference.isNegative ? '$relative ago' : 'in $relative'}';
}
