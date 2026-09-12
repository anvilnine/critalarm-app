package app.critalarm.actions

import java.net.URLEncoder
import java.nio.charset.StandardCharsets

data class IncidentActionRoute(val action: IncidentAction, val path: String)

object IncidentActionRouter {
    fun fromTrigger(trigger: String, incidentId: String): IncidentActionRoute? {
        if (incidentId.isEmpty()) return null
        val action = when (trigger) {
            "stop" -> IncidentAction.ACK
            "acknowledge" -> IncidentAction.CLOSE
            else -> return null
        }
        val encodedId = URLEncoder.encode(incidentId, StandardCharsets.UTF_8)
            .replace("+", "%20")
        return IncidentActionRoute(action, "/v1/incidents/$encodedId/${action.wireValue}")
    }
}
