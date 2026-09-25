package app.critalarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TapRouteTest {
    @Test
    fun `an incident opens that incident`() {
        assertEquals("/incidents/inc_1", TapRoute.routeFor(mapOf("incident_id" to "inc_1", "topic" to "prod")))
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
