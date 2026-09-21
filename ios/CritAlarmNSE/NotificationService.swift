import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Turns a `relay_content: none` push into the real thing.
///
/// api.md §5.1 sends the alarm with placeholder text and `mutable-content: 1`.
/// This reads `incident_id` and `server` off the payload, fetches the incident
/// with the credentials in the shared keychain (§3.2), and swaps in the real
/// title and body. Ten seconds is the budget: past that the placeholder goes
/// up, because a late alarm is worse than a vague one.
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var pending: UNMutableNotificationContent?
    private var deadline: DispatchWorkItem?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        pending = content

        guard let push = IncidentPush(payload: request.content.userInfo) else {
            NSLog("CritAlarmNSE push_dropped reason=unparseable")
            PushEventLog.record("push_dropped", ["reason": "unparseable"])
            contentHandler(content)
            return
        }

        content.interruptionLevel = interruptionLevel(for: push, content: content)
        PushEventLog.record("push_received", ["kind": push.kind.rawValue, "priority": push.priority])
        NSLog(
            "CritAlarmNSE push_received kind=%@ priority=%d incident_id=%@ fetch=%@",
            push.kind.rawValue, push.priority, push.incidentId ?? "-",
            push.needsContentFetch ? "yes" : "no"
        )

        // SPIKE (docs/specs/remote-alarm-ios-spike.md): can a Notification
        // Service Extension schedule an AlarmKit alarm? Everything else in
        // Part A hangs off the answer.
        scheduleAlarmSpike(push)

        // The fetch has to finish inside the budget or the placeholder wins.
        let timeout = DispatchWorkItem { [weak self] in
            NSLog("CritAlarmNSE incident_fetch_timeout after=%.0fs", IncidentContentFetcher.timeout)
            PushEventLog.record("push_dropped", ["reason": "fetch_timeout"])
            self?.deliver(nil, push: push)
        }
        deadline = timeout
        DispatchQueue.main.asyncAfter(
            deadline: .now() + IncidentContentFetcher.timeout,
            execute: timeout
        )

        IncidentContentFetcher.resolve(push, session: NseCredentials.read()) { [weak self] resolved, usedFallback in
            if usedFallback {
                NSLog("CritAlarmNSE incident_fetch_fallback incident_id=%@", push.incidentId ?? "-")
                PushEventLog.record("push_dropped", ["reason": "fetch_failed"])
            }
            self?.deliver(resolved, push: push)
        }
    }

    /// Called when the system is about to take the extension down. Whatever is
    /// in hand goes out.
    override func serviceExtensionTimeWillExpire() {
        NSLog("CritAlarmNSE extension_time_expired")
        deliver(nil, push: nil)
    }

    /// api.md §5.1 sets `interruption-level` on the way out; only a critical
    /// topic with the entitlement gets `critical`, and that one is left alone.
    /// Everything else follows the priority: 4 and non-critical 5 break through
    /// a Focus, 1-3 do not.
    private func interruptionLevel(
        for push: IncidentPush,
        content: UNMutableNotificationContent
    ) -> UNNotificationInterruptionLevel {
        let aps = content.userInfo["aps"] as? [AnyHashable: Any]
        if (aps?["interruption-level"] as? String) == "critical" { return .critical }
        return push.priority >= 4 ? .timeSensitive : .active
    }

    private func deliver(_ resolved: IncidentContent?, push: IncidentPush?) {
        guard let handler = contentHandler, let content = pending else { return }
        contentHandler = nil
        pending = nil
        deadline?.cancel()
        deadline = nil

        if let resolved {
            content.title = NtfyEmoji.prefixTitle(resolved.title, tags: resolved.tags)
            content.body = resolved.body

            var info = content.userInfo
            if let click = resolved.click { info["click"] = click }
            if let topic = resolved.topic { info["topic"] = topic }
            if let id = push?.incidentId { info["incident_id"] = id }
            content.userInfo = info
        }

        applyPickedSound(to: content, topic: resolved?.topic)

        NSLog("CritAlarmNSE delivered title=%@", content.title)
        handler(content)
    }

    /// Swaps the payload's `alarm.caf` for the sound the user picked for this
    /// topic, or their default when the topic is not known (the payload has no
    /// topic; it only arrives with the fetched incident).
    ///
    /// Only a push that already carries a sound is touched, so a quiet push
    /// stays quiet. No published choice, or a file that is not in the app
    /// group's `Library/Sounds`, leaves `alarm.caf` in place.
    private func applyPickedSound(to content: UNMutableNotificationContent, topic: String?) {
        guard content.sound != nil,
              let name = SharedSounds.fileName(
                  forTopic: topic,
                  defaults: SharedSounds.groupDefaults,
                  fileExists: SharedSounds.existsInGroup
              )
        else { return }
        content.sound = UNNotificationSound(named: UNNotificationSoundName(name))
        NSLog("CritAlarmNSE sound_applied name=%@ topic=%@", name, topic ?? "-")
    }

    /// Spike only. Calls the same scheduler the app would, from inside the
    /// extension, and logs whatever comes back.
    private func scheduleAlarmSpike(_ push: IncidentPush) {
        guard push.priority >= 5, let incidentId = push.incidentId else { return }

        // Quiet hours holds the ring and nothing else. The notification has
        // already been handed its interruption level and is on its way out
        // with whatever text the fetch finds; only the alarm is skipped.
        let window = QuietHours.read(from: QuietHours.groupDefaults)
        if window.holdsRing(
            minuteOfDay: QuietHours.minuteOf(Date()),
            priority: push.priority
        ) {
            NSLog(
                "CritAlarmNSE alarm_skipped reason=quiet_hours incident_id=%@",
                incidentId
            )
            return
        }

        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let state = IncidentAlarmScheduler.authorization
            NSLog("CritAlarmSPIKE nse_alarmkit_reachable authorization=%@", "\(state)")
            Task {
                let ok = await IncidentAlarmScheduler.schedule(
                    incidentId: "\(incidentId)-nse-spike",
                    topic: push.title ?? "spike",
                    server: push.server.absoluteString,
                    title: push.title ?? "Crit Alarm spike"
                )
                NSLog(
                    "CritAlarmSPIKE nse_schedule_result ok=%@ alarm_id=%@",
                    ok ? "yes" : "no",
                    IncidentAlarmScheduler.alarmId(for: "\(incidentId)-nse-spike").uuidString
                )
            }
        } else {
            NSLog("CritAlarmSPIKE nse_alarmkit_unavailable os_too_old")
        }
        #else
        NSLog("CritAlarmSPIKE nse_alarmkit_not_linked")
        #endif
    }
}
