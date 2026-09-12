package app.critalarm.push

import java.net.URI

enum class IncidentPushKind(val wireValue: String) {
    OPEN("open"),
    REPEAT("repeat"),
    REOPEN("reopen"),
    P4("p4"),
}

data class FcmIncidentPayload(
    val incidentId: String,
    val server: URI,
    val kind: IncidentPushKind,
    val priority: Int,
    val title: String?,
    val body: String?,
) {
    companion object {
        fun fromData(data: Map<String, String>): FcmIncidentPayload? {
            val incidentId = data["incident_id"]?.takeIf(String::isNotEmpty) ?: return null
            val server = runCatching { URI(data["server"] ?: return null) }.getOrNull()
                ?.takeIf { (it.scheme == "http" || it.scheme == "https") && !it.host.isNullOrBlank() }
                ?: return null
            val kind = IncidentPushKind.entries.firstOrNull { it.wireValue == data["kind"] }
                ?: return null
            val priority = data["priority"]?.toIntOrNull()?.takeIf { it in 1..5 } ?: return null
            return FcmIncidentPayload(
                incidentId = incidentId,
                server = server,
                kind = kind,
                priority = priority,
                title = data["title"],
                body = data["body"],
            )
        }
    }
}
