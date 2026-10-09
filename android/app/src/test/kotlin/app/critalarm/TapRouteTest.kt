package app.critalarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TapRouteTest {
    @Test
    fun `an incident opens that incident`() {
        assertEquals("/incidents/inc_1", TapRoute.routeFor(mapOf("incident_id" to "inc_1", "topic" to "prod")))
    }

    // The marker a Done button puts on its tap, and Dart reads back.

    @Test
    fun `a Done tap carries the marker to Dart and into the route`() {
        val tap = TapRoute.tapFor(7, "inc_1", null, null, null, "done")
        assertEquals("done", tap["from"])
        assertEquals("inc_1", tap["incident_id"])
        assertEquals("/incidents/inc_1?from=done", TapRoute.routeFor(tap))
    }

    @Test
    fun `a plain tap on a card carries no marker`() {
        val tap = TapRoute.tapFor(7, "inc_1", null, null, null)
        assertNull(tap["from"])
        assertEquals("/incidents/inc_1", TapRoute.routeFor(tap))
    }

    @Test
    fun `the marker means nothing without an incident, and no other word is one`() {
        assertNull(TapRoute.tapFor(7, null, "prod", null, null, "done")["from"])
        assertNull(TapRoute.tapFor(7, "inc_1", null, null, null, "card")["from"])
        assertEquals("/topics/prod", TapRoute.routeFor(mapOf("topic" to "prod", "from" to "done")))
        assertEquals("/incidents/inc_1", TapRoute.routeFor(mapOf("incident_id" to "inc_1", "from" to "card")))
    }

    @Test
    fun `the link a Done button opens names the incident and the marker`() {
        assertEquals("critalarm://incidents/inc_1?from=done", TapRoute.doneLink("inc_1"))
    }

    @Test
    fun `a topic opens that topic`() {
        assertEquals("/topics/prod", TapRoute.routeFor(mapOf("topic" to "prod")))
    }

    @Test
    fun `open home opens Home`() {
        assertEquals("/", TapRoute.routeFor(mapOf("open" to "home", "tap_id" to "1")))
    }

    @Test
    fun `a topic wins over open home`() {
        assertEquals("/topics/prod", TapRoute.routeFor(mapOf("open" to "home", "topic" to "prod")))
    }

    @Test
    fun `nothing opens nothing`() {
        assertNull(TapRoute.routeFor(null))
        assertNull(TapRoute.routeFor(mapOf("tap_id" to "1")))
        assertNull(TapRoute.routeFor(mapOf("open" to "settings")))
    }

    @Test
    fun `names are escaped the way Dart escapes them`() {
        assertEquals("/topics/my%20topic%2Fx", TapRoute.routeFor(mapOf("topic" to "my topic/x")))
        assertEquals("/topics/a!b'c(d)e~f*g-h_i.j", TapRoute.routeFor(mapOf("topic" to "a!b'c(d)e~f*g-h_i.j")))
    }

    @Test
    fun `open paywall opens the paywall`() {
        assertEquals("/paywall", TapRoute.routeFor(mapOf("open" to "paywall")))
    }
}
