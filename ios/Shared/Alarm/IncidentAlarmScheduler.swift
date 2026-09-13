import Foundation
import CryptoKit

#if canImport(AlarmKit)
import AlarmKit
#endif
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Schedules, re-schedules and cancels the AlarmKit alarm for one incident.
///
/// The alarm is a three-second countdown rather than a clock alarm, because
/// `Alarm.Schedule.Relative` only resolves to an hour and a minute and the
/// push has to ring now. Everything is keyed off a UUID derived from the
/// incident id, so a repeat push can replace the alarm it already scheduled
/// and a close can cancel it without keeping a table anywhere.
public enum IncidentAlarmScheduler {
    /// How far out the alarm is set. Long enough for the countdown to be
    /// registered, short enough that nobody notices the wait.
    public static let leadTime: TimeInterval = 3

    /// The bundled sound. api.md §5.1 already names it for the APNs payload,
    /// so the alarm uses the same file. AlarmKit reads sounds out of the app
    /// bundle only.
    public static let soundName = "alarm.caf"

    /// Same incident, same alarm. A repeat push overwrites its own alarm
    /// instead of stacking a second one.
    public static func alarmId(for incidentId: String) -> UUID {
        var digest = Array(SHA256.hash(data: Data(incidentId.utf8)).prefix(16))
        // Stamp it as a version-4 UUID so the value is a legal one.
        digest[6] = (digest[6] & 0x0F) | 0x40
        digest[8] = (digest[8] & 0x3F) | 0x80
        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        ))
    }

    #if canImport(AlarmKit)
    /// Whether the user has said yes. A denied state is why the critical
    /// toggle on a topic is greyed out.
    @available(iOS 26.0, *)
    public static var authorization: AlarmManager.AuthorizationState {
        AlarmManager.shared.authorizationState
    }

    @available(iOS 26.0, *)
    @discardableResult
    public static func requestAuthorization() async -> AlarmManager.AuthorizationState {
        do {
            let state = try await AlarmManager.shared.requestAuthorization()
            NSLog("CritAlarmAlarm: alarmkit_authorization state=%@", "\(state)")
            return state
        } catch {
            NSLog("CritAlarmAlarm: alarmkit_authorization_failed error=%@", "\(error)")
            return .denied
        }
    }

    /// The whole job: cancel anything already ringing for this incident, then
    /// put a fresh alarm three seconds out.
    ///
    /// Returns false when the alarm did not get scheduled, which is the signal
    /// to leave the plain notification as the only surface (spec Part A,
    /// "fall back to a normal notification and log the reason").
    @available(iOS 26.0, *)
    @discardableResult
    public static func schedule(
        incidentId: String,
        topic: String,
        server: String,
        title: String,
        sound: String? = nil
    ) async -> Bool {
        guard AlarmManager.shared.authorizationState == .authorized else {
            NSLog(
                "CritAlarmAlarm: alarm_not_scheduled reason=unauthorized state=%@ incident_id=%@",
                "\(AlarmManager.shared.authorizationState)", incidentId
            )
            return false
        }

        let id = alarmId(for: incidentId)
        // A repeat push lands here while the first alarm may still be
        // alerting. Cancelling first is what makes it ring again after the
        // system auto-muted it.
        try? AlarmManager.shared.cancel(id: id)

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            stopButton: AlarmButton(
                text: "Stop",
                textColor: .white,
                systemImageName: "bell.slash.fill"
            )
            // No secondary button: the spec says no snooze.
        )
        let countdown = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: title)
        )
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert, countdown: countdown),
            metadata: IncidentAlarmMetadata(incidentId: incidentId, topic: topic, server: server),
            tintColor: Color(red: 0.961, green: 0.278, blue: 0.227)  // crit #F5473A
        )

        let configuration = AlarmManager.AlarmConfiguration.timer(
            duration: leadTime,
            attributes: attributes,
            stopIntent: StopAlarmIntent(incidentId: incidentId),
            sound: .named(sound ?? soundName)
        )

        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            NSLog(
                "CritAlarmAlarm: alarm_scheduled incident_id=%@ alarm_id=%@ in=%.0fs sound=%@",
                incidentId, id.uuidString, leadTime, sound ?? soundName
            )
            PendingIncidentStore.write(
                incidentId: incidentId, topic: topic, server: server,
                title: title, openedAt: Date()
            )
            if #available(iOS 16.2, *) {
                await IncidentActivityCoordinator.shared.setAlarmActive(true, incidentId: incidentId)
            }
            return true
        } catch {
            NSLog(
                "CritAlarmAlarm: alarm_schedule_failed incident_id=%@ error=%@",
                incidentId, "\(error)"
            )
            return false
        }
    }

    /// The incident closed or expired, so nothing should ring for it.
    @available(iOS 26.0, *)
    public static func cancel(incidentId: String) async {
        let id = alarmId(for: incidentId)
        do {
            try AlarmManager.shared.cancel(id: id)
            NSLog("CritAlarmAlarm: alarm_cancelled incident_id=%@ alarm_id=%@", incidentId, id.uuidString)
        } catch {
            NSLog("CritAlarmAlarm: alarm_cancel_failed incident_id=%@ error=%@", incidentId, "\(error)")
        }
        if #available(iOS 16.2, *) {
            await IncidentActivityCoordinator.shared.setAlarmActive(false, incidentId: incidentId)
        }
    }

    /// Keeps the coordinator's idea of "an alarm is up for this incident" in
    /// step with AlarmKit's. Without this, an alarm the user stopped from
    /// Control Center would still block our card.
    @available(iOS 26.0, *)
    public static func observeAlarmUpdates() -> Task<Void, Never> {
        Task {
            for await alarms in AlarmManager.shared.alarmUpdates {
                let live = Set(
                    alarms
                        .filter { $0.state == .scheduled || $0.state == .countdown || $0.state == .alerting }
                        .map(\.id)
                )
                let described = alarms
                    .map { "\($0.id.uuidString):\($0.state)" }
                    .joined(separator: ",")
                NSLog(
                    "CritAlarmAlarm: alarm_updates count=%d live=%d alarms=%@",
                    alarms.count, live.count, described
                )
                if #available(iOS 16.2, *) {
                    await IncidentActivityCoordinator.shared.syncAlarms(liveAlarmIds: live)
                }
            }
        }
    }
    #endif
}
