package app.critalarm.storage

import android.content.Context

class IncidentDeliveryStore(context: Context) {
    private val preferences = context.getSharedPreferences("incident_delivery", Context.MODE_PRIVATE)

    fun isActive(incidentId: String) = preferences.getBoolean("active:$incidentId", false)
    fun isAcknowledged(incidentId: String) = preferences.getBoolean("acknowledged:$incidentId", false)

    fun activate(incidentId: String, reopen: Boolean = false) {
        preferences.edit().putBoolean("active:$incidentId", true).apply {
            if (reopen) remove("acknowledged:$incidentId")
        }.apply()
    }

    fun markAcknowledged(incidentId: String) {
        preferences.edit()
            .putBoolean("acknowledged:$incidentId", true)
            .remove("active:$incidentId")
            .apply()
    }
}
