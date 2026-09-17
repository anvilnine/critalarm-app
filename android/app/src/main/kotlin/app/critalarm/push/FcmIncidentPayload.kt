package app.critalarm.push

import java.net.URI

enum class IncidentPushKind(val wireValue: String) {
    OPEN("open"),
    REPEAT("repeat"),
    REOPEN("reopen"),
    P4("p4"),
    P5("p5"),
    ;

    /**
     * True when this kind never opens or continues an alarm, so it carries no
     * incident id of its own and lands on the high channel as a heads-up.
     *
     * `p5` is priority 5 on a topic whose critical switch is off (api.md §4.1).
     * It can still carry an incident id: the server names one when the message
     * joined an incident that was already live.
     */
    val isForward: Boolean get() = this == P4 || this == P5

    /** Priority the contract implies when the payload does not carry one. */
    val impliedPriority: Int get() = if (this == P4) 4 else 5
}

/**
 * One FCM data message, api.md §5.2.
 *
 * `incident_id` is absent on a `p4` forward: api.md §4.1 sends no incident id
 * for those, because priority 4 never opens an incident. A `p5` forward may or
 * may not carry one, so neither kind requires it.
 */
data class FcmIncidentPayload(
    val incidentId: String?,
    val server: URI,
    val kind: IncidentPushKind,
    val priority: Int,
    val title: String?,
    val body: String?,
) {
    /** The relay stripped the content, so the app has to fetch it. */
    val needsContentFetch: Boolean get() = title == null && body == null

    /** This push opens or continues an incident, so the alarm path owns it. */
    val isIncident: Boolean get() = !kind.isForward && incidentId != null

    companion object {
        fun fromData(data: Map<String, String>): FcmIncidentPayload? {
            val kind = IncidentPushKind.entries.firstOrNull { it.wireValue == data["kind"] }
                ?: return null
            val incidentId = data["incident_id"]?.takeIf(String::isNotEmpty)
            if (incidentId == null && !kind.isForward) return null
            val server = runCatching { URI(data["server"] ?: return null) }.getOrNull()
                ?.takeIf { (it.scheme == "http" || it.scheme == "https") && !it.host.isNullOrBlank() }
                ?: return null
            val priority = data["priority"]?.toIntOrNull()?.takeIf { it in 1..5 } ?: return null
            return FcmIncidentPayload(
                incidentId = incidentId,
                server = server,
                kind = kind,
                priority = priority,
                title = data["title"]?.takeIf(String::isNotEmpty),
                body = data["body"]?.takeIf(String::isNotEmpty),
            )
        }
    }
}
