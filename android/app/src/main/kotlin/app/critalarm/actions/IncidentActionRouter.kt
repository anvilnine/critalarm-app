package app.critalarm.actions

import java.net.URLEncoder

data class IncidentActionRoute(val action: IncidentAction, val path: String)

object IncidentActionRouter {
    fun fromTrigger(trigger: String, incidentId: String): IncidentActionRoute? {
        if (incidentId.isEmpty()) return null
        val action = when (trigger) {
            "stop" -> IncidentAction.ACK
            "acknowledge" -> IncidentAction.CLOSE
            else -> return null
        }
        // The Charset overload is API 33 and minSdk is 28, so on Android 9 to
        // 12L it throws NoSuchMethodError and the Stop button does nothing
        // while the alarm keeps ringing. The String overload is API 1.
        val encodedId = URLEncoder.encode(incidentId, "UTF-8")
            .replace("+", "%20")
        return IncidentActionRoute(action, "/v1/incidents/$encodedId/${action.wireValue}")
    }
}
