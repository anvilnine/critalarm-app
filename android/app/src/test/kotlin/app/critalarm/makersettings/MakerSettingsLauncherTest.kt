package app.critalarm.makersettings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MakerSettingsLauncherTest {

    private fun component(pkg: String) =
        MakerSettingsCandidate("component", pkg = pkg, component = "$pkg.Page")

    private val appDetails = MakerSettingsCandidate("appDetails")

    /** Which candidates resolve, which throw when started, and what was started. */
    private class FakeGateway(
        private val resolving: Set<String> = emptySet(),
        private val throwing: Set<String> = emptySet(),
        private val throwOnResolve: Set<String> = emptySet(),
    ) : MakerSettingsGateway {
        val started = mutableListOf<String>()

        private fun name(c: MakerSettingsCandidate) = c.pkg ?: c.kind

        override fun resolves(candidate: MakerSettingsCandidate): Boolean {
            if (name(candidate) in throwOnResolve) throw IllegalStateException("resolve failed")
            return name(candidate) in resolving
        }

        override fun start(candidate: MakerSettingsCandidate) {
            if (name(candidate) in throwing) throw SecurityException("not exported")
            started += name(candidate)
        }
    }

    @Test
    fun opensTheFirstCandidateThatResolves() {
        val gateway = FakeGateway(resolving = setOf("a.maker", "appDetails"))
        val index = MakerSettingsLauncher(gateway).open(listOf(component("a.maker"), appDetails))
        assertEquals(0, index)
        assertEquals(listOf("a.maker"), gateway.started)
    }

    @Test
    fun anUnresolvedComponentFallsBackToTheNextAndDoesNotThrow() {
        val gateway = FakeGateway(resolving = setOf("appDetails"))
        val index = MakerSettingsLauncher(gateway).open(listOf(component("missing.maker"), appDetails))
        assertEquals(1, index)
        // The missing component was never started.
        assertEquals(listOf("appDetails"), gateway.started)
    }

    @Test
    fun aComponentThatRefusesToStartFallsBack() {
        val gateway = FakeGateway(
            resolving = setOf("locked.maker", "appDetails"),
            throwing = setOf("locked.maker"),
        )
        val index = MakerSettingsLauncher(gateway).open(listOf(component("locked.maker"), appDetails))
        assertEquals(1, index)
        assertEquals(listOf("appDetails"), gateway.started)
    }

    @Test
    fun aResolveThatThrowsFallsBack() {
        val gateway = FakeGateway(
            resolving = setOf("appDetails"),
            throwOnResolve = setOf("odd.maker"),
        )
        val index = MakerSettingsLauncher(gateway).open(listOf(component("odd.maker"), appDetails))
        assertEquals(1, index)
    }

    @Test
    fun triesTheCandidatesInOrder() {
        val gateway = FakeGateway(resolving = setOf("one", "two", "appDetails"), throwing = setOf("one"))
        val index = MakerSettingsLauncher(gateway).open(
            listOf(component("one"), component("two"), appDetails),
        )
        assertEquals(1, index)
        assertEquals(listOf("two"), gateway.started)
    }

    @Test
    fun answersMinusOneWhenNothingOpensAndStillDoesNotThrow() {
        val gateway = FakeGateway(
            resolving = setOf("locked.maker", "appDetails"),
            throwing = setOf("locked.maker", "appDetails"),
        )
        val index = MakerSettingsLauncher(gateway).open(listOf(component("locked.maker"), appDetails))
        assertEquals(-1, index)
        assertTrue(gateway.started.isEmpty())
    }

    @Test
    fun anEmptyListOpensNothing() {
        assertEquals(-1, MakerSettingsLauncher(FakeGateway()).open(emptyList()))
    }

    @Test
    fun parsesTheListDartSendsAndDropsWhatIsMalformed() {
        val parsed = MakerSettingsCandidate.parseAll(
            listOf(
                mapOf("kind" to "component", "package" to "p", "component" to "p.C"),
                mapOf("kind" to "component", "package" to "p"),
                mapOf("kind" to "action", "action" to "a.B"),
                mapOf("kind" to "action"),
                mapOf("kind" to "appDetails"),
                mapOf("kind" to "mystery"),
                "not a map",
                null,
            ),
        )
        assertEquals(
            listOf(
                MakerSettingsCandidate("component", pkg = "p", component = "p.C"),
                MakerSettingsCandidate("action", action = "a.B"),
                MakerSettingsCandidate("appDetails"),
            ),
            parsed,
        )
    }

    @Test
    fun anythingThatIsNotAListParsesToNothing() {
        assertEquals(emptyList<MakerSettingsCandidate>(), MakerSettingsCandidate.parseAll(null))
        assertEquals(emptyList<MakerSettingsCandidate>(), MakerSettingsCandidate.parseAll("x"))
    }
}
