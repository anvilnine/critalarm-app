package app.critalarm.check

import java.net.URI
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The receipt request of api.md §4.5, and what is kept from its answer. */
class CheckReceiptTest {
    private val device = RelayDevice(
        relay = URI("https://relay.example.test"),
        deviceId = "dev_3f2a",
        deviceToken = "dv_test",
    )
    private val push = CheckPush(checkId = "chk_5c1d", attempt = 2)

    @Test
    fun `the request is the one the contract describes`() {
        val request = CheckReceipt.request(device, push, receivedAtSeconds = 1759800004)
        assertEquals("POST", request.method)
        assertEquals(
            "https://relay.example.test/relay/v1/devices/dev_3f2a/checks/chk_5c1d/receipt",
            request.url,
        )
        assertEquals("Bearer dv_test", request.headers["Authorization"])
        assertEquals("application/json", request.headers["Content-Type"])
        val body = JSONObject(request.body)
        assertEquals(2, body.getInt("attempt"))
        assertEquals(1759800004L, body.getLong("received_at"))
        assertEquals(setOf("attempt", "received_at"), body.keys().asSequence().toSet())
    }

    @Test
    fun `a push with no attempt sends none`() {
        val request = CheckReceipt.request(device, CheckPush("chk_1", null), 10)
        assertEquals(setOf("received_at"), JSONObject(request.body).keys().asSequence().toSet())
    }

    @Test
    fun `a relay under a path keeps its path`() {
        val under = device.copy(relay = URI("http://10.0.2.2:8787/base/"))
        assertEquals(
            "http://10.0.2.2:8787/base/relay/v1/devices/dev_3f2a/checks/chk_5c1d/receipt",
            CheckReceipt.request(under, push, 10).url,
        )
    }

    @Test
    fun `ids are escaped as path segments`() {
        val odd = CheckReceipt.request(device.copy(deviceId = "dev a/b"), CheckPush("chk?x", 1), 10)
        assertTrue(odd.url.endsWith("/relay/v1/devices/dev%20a%2Fb/checks/chk%3Fx/receipt"))
    }

    @Test
    fun `the secrets stay out of the text forms`() {
        val request = CheckReceipt.request(device, push, 10)
        assertFalse(request.toString().contains("chk_5c1d"))
        assertFalse(request.toString().contains("dv_test"))
        assertFalse(device.toString().contains("dv_test"))
    }

    @Test
    fun `the relay comes from the saved session and the device from its registration`() {
        val parsed = RelayDevice.parse(
            apiSession = "https://alerts.example.com|https://relay.example.test|selfhosted|ad_secret",
            deviceId = "dev_3f2a",
            deviceToken = "dv_test",
        )
        assertEquals(device, parsed)
        // The fourth part belongs to the user's own server. It is never sent.
        assertFalse(CheckReceipt.request(parsed!!, push, 10).headers.values.any { it.contains("ad_secret") })
    }

    @Test
    fun `with any part missing there is nobody to answer`() {
        val session = "https://a.example|https://relay.example.test|hosted|dv_test"
        assertNull(RelayDevice.parse(null, "dev_1", "dv_test"))
        assertNull(RelayDevice.parse("https://a.example", "dev_1", "dv_test"))
        assertNull(RelayDevice.parse("https://a.example|ftp://relay|hosted|x", "dev_1", "dv_test"))
        assertNull(RelayDevice.parse(session, null, "dv_test"))
        assertNull(RelayDevice.parse(session, "dev_1", null))
        assertNull(RelayDevice.parse(session, "dev_1", " "))
    }

    @Test
    fun `three tries and then it is dropped`() {
        assertEquals(3, CheckReceipt.TRY_DELAYS_MS.size)
        assertEquals(0L, CheckReceipt.TRY_DELAYS_MS.first())
        // Well inside the ten minutes a job may run.
        val worst = CheckReceipt.TRY_DELAYS_MS.sum() +
            3L * (CheckReceipt.CONNECT_TIMEOUT_MS + CheckReceipt.READ_TIMEOUT_MS)
        assertTrue(worst < 120_000)
    }

    @Test
    fun `only no answer and a server error are tried again`() {
        assertTrue(CheckReceipt.shouldRetry(null))
        assertTrue(CheckReceipt.shouldRetry(500))
        assertTrue(CheckReceipt.shouldRetry(503))
        assertTrue(CheckReceipt.shouldRetry(429))
        assertFalse(CheckReceipt.shouldRetry(200))
        assertFalse(CheckReceipt.shouldRetry(401))
        assertFalse(CheckReceipt.shouldRetry(403))
        assertFalse(CheckReceipt.shouldRetry(404))
    }

    @Test
    fun `the answer is read`() {
        val answer = CheckReceipt.parseAnswer(
            """{ "counted":true, "next_due_at":1760404800, "notice_after":1761096000 }""",
        )
        assertEquals(CheckReceiptAnswer(true, 1760404800, 1761096000), answer)
        val late = CheckReceipt.parseAnswer("""{"counted":false,"next_due_at":null,"notice_after":null}""")
        assertEquals(CheckReceiptAnswer(false, null, null), late)
        assertNull(CheckReceipt.parseAnswer("not json"))
        assertNull(CheckReceipt.parseAnswer("""{"error":"not found"}"""))
        assertNull(CheckReceipt.parseAnswer(null))
    }

    @Test
    fun `the arrival is recorded and an older answer stays`() {
        val first = CheckReceipt.withArrival(null, 100)
        assertEquals(100L, JSONObject(first).getLong("received_at"))

        val answered = CheckReceipt.withAnswer(first, CheckReceiptAnswer(true, 700, 900), nowSeconds = 101)
        val next = JSONObject(CheckReceipt.withArrival(answered, 800))
        assertEquals(800L, next.getLong("received_at"))
        assertEquals(900L, next.getLong("notice_after"))
        assertEquals(101L, next.getLong("notice_after_seen_at"))
        assertEquals(700L, next.getLong("next_due_at"))
    }

    @Test
    fun `an answer with nothing to report leaves the record as it was`() {
        val before = CheckReceipt.withAnswer(
            CheckReceipt.withArrival(null, 100),
            CheckReceiptAnswer(true, 700, 900),
            nowSeconds = 101,
        )
        val after = JSONObject(CheckReceipt.withAnswer(before, CheckReceiptAnswer(false, null, null), 500))
        assertEquals(900L, after.getLong("notice_after"))
        assertEquals(101L, after.getLong("notice_after_seen_at"))
    }

    @Test
    fun `the record never holds the id of a check`() {
        val record = CheckReceipt.withAnswer(
            CheckReceipt.withArrival("garbage", 100),
            CheckReceiptAnswer(true, 700, 900),
            101,
        )
        assertEquals(
            setOf("received_at", "notice_after", "notice_after_seen_at", "next_due_at"),
            JSONObject(record).keys().asSequence().toSet(),
        )
    }

    // The token only goes out over https.

    @Test
    fun `a receipt goes to an https relay`() {
        assertTrue(CheckReceipt.maySend(URI("https://relay.example.test"), emptySet()))
        assertTrue(CheckReceipt.maySend(URI("HTTPS://relay.example.test"), emptySet()))
    }

    @Test
    fun `a release build sends nothing over http, not even to this machine`() {
        val none = emptySet<String>()
        for (relay in listOf(
            "http://relay.example.test",
            "http://127.0.0.1:8792",
            "http://localhost:8792",
            "http://10.0.2.2:8792",
            "ftp://relay.example.test",
        )) {
            assertFalse(relay, CheckReceipt.maySend(URI(relay), none))
        }
    }

    @Test
    fun `a debug build may reach a relay on this machine over http, and no other`() {
        val local = setOf("127.0.0.1", "localhost", "10.0.2.2")
        assertTrue(CheckReceipt.maySend(URI("http://10.0.2.2:8792"), local))
        assertTrue(CheckReceipt.maySend(URI("http://127.0.0.1:8792/base"), local))
        assertTrue(CheckReceipt.maySend(URI("http://LOCALHOST:8792"), local))
        assertFalse(CheckReceipt.maySend(URI("http://relay.example.test"), local))
        assertFalse(CheckReceipt.maySend(URI("http://10.0.2.2.example.test"), local))
        assertFalse(CheckReceipt.maySend(URI("http://192.168.1.10:8792"), local))
    }

    @Test
    fun `only the debug source set lists a plain http host`() {
        fun hosts(buildType: String) =
            java.io.File("src/$buildType/kotlin/app/critalarm/check/PlainHttpRelays.kt").readText()
        assertTrue(hosts("release").contains("emptySet()"))
        assertTrue(hosts("profile").contains("emptySet()"))
        assertFalse(hosts("release").contains("10.0.2.2"))
        assertFalse(hosts("profile").contains("10.0.2.2"))
        assertTrue(hosts("debug").contains("10.0.2.2"))
        assertFalse(java.io.File("src/main/kotlin/app/critalarm/check/PlainHttpRelays.kt").exists())
    }

    @Test
    fun `the job asks before it sends and says why not without naming the host`() {
        val service = java.io.File("src/main/kotlin/app/critalarm/check/CheckReceiptJobService.kt").readText()
        val gate = service.indexOf("CheckReceipt.maySend(device.relay, PlainHttpRelays.hosts)")
        assertTrue(gate >= 0)
        assertTrue(gate < service.indexOf("CheckReceipt.send("))
        assertTrue(service.contains("\"check_receipt_skipped reason=relay_not_https\""))
    }

    // One receipt: its tries, and its own cancellation.

    private val request = CheckReceipt.request(device, push, 10)

    private fun send(
        statuses: List<Int?>,
        isCancelled: () -> Boolean = { false },
        answers: MutableList<CheckReceiptAnswer?> = mutableListOf(),
    ): Pair<CheckReceipt.Outcome, Int> {
        var posts = 0
        val outcome = CheckReceipt.send(
            request = request,
            post = {
                val status = statuses[minOf(posts, statuses.size - 1)]
                posts += 1
                status to if (status == 200) """{"counted":true,"notice_after":900}""" else null
            },
            isCancelled = isCancelled,
            sleep = {},
            onAnswer = { answers.add(it) },
        )
        return outcome to posts
    }

    @Test
    fun `a receipt that lands is sent once`() {
        val answers = mutableListOf<CheckReceiptAnswer?>()
        assertEquals(CheckReceipt.Outcome.SENT to 1, send(listOf(200), answers = answers))
        assertEquals(listOf(CheckReceiptAnswer(true, null, 900)), answers)
    }

    @Test
    fun `two failures and then it lands`() {
        assertEquals(CheckReceipt.Outcome.SENT to 3, send(listOf(503, null, 200)))
    }

    @Test
    fun `three failures and it is dropped`() {
        assertEquals(CheckReceipt.Outcome.DROPPED to 3, send(listOf(503)))
        assertEquals(CheckReceipt.Outcome.DROPPED to 3, send(listOf(null)))
    }

    @Test
    fun `a final answer is not asked again`() {
        assertEquals(CheckReceipt.Outcome.REFUSED to 1, send(listOf(404)))
        assertEquals(CheckReceipt.Outcome.REFUSED to 1, send(listOf(401)))
    }

    @Test
    fun `a stopped job posts nothing`() {
        assertEquals(CheckReceipt.Outcome.CANCELLED to 0, send(listOf(200), isCancelled = { true }))
    }

    @Test
    fun `stopping one job does not stop the next one on the same service`() {
        val jobs = CheckReceiptJobs()
        val first = jobs.started(1)
        jobs.stop(1)
        assertTrue(first.isStopped)
        assertEquals(CheckReceipt.Outcome.CANCELLED to 0, send(listOf(200), isCancelled = { first.isStopped }))
        jobs.finished(1, first)

        // The same service object, a later job.
        val second = jobs.started(2)
        assertFalse(second.isStopped)
        assertEquals(CheckReceipt.Outcome.SENT to 1, send(listOf(200), isCancelled = { second.isStopped }))
    }

    @Test
    fun `the same job id run again starts unstopped`() {
        val jobs = CheckReceiptJobs()
        val first = jobs.started(7)
        jobs.stop(7)
        val again = jobs.started(7)
        assertTrue(first.isStopped)
        assertFalse(again.isStopped)
        // The first run ending late does not take the second run's entry.
        jobs.finished(7, first)
        jobs.stop(7)
        assertTrue(again.isStopped)
    }

    @Test
    fun `a stop for a job that is not running is nothing`() {
        val jobs = CheckReceiptJobs()
        jobs.stop(3)
        assertFalse(jobs.started(3).isStopped)
    }

    @Test
    fun `the service keeps nothing about one job on itself`() {
        val service = java.io.File("src/main/kotlin/app/critalarm/check/CheckReceiptJobService.kt").readText()
        assertFalse(service.contains("@Volatile"))
        assertTrue(service.contains("jobs.started(params.jobId)"))
        assertTrue(service.contains("jobs.stop(params.jobId)"))
    }

    // Nothing on the thread a push arrives on.

    @Test
    fun `answering a check only hands it to the responder's own thread`() {
        val responder = java.io.File("src/main/kotlin/app/critalarm/check/WeeklyCheckResponder.kt").readText()
        val answer = responder.substringAfter("fun answer(context: Context, push: CheckPush) {").substringBefore("\n    }")
        assertTrue(answer.contains("worker.execute"))
        for (work in listOf("getSharedPreferences", "JobScheduler", "JobInfo", ".edit()", "Log.")) {
            assertFalse("answer must not call $work itself", answer.contains(work))
        }
        assertTrue(responder.contains("Executors.newSingleThreadExecutor"))
    }

    @Test
    fun `every change to the record goes through the one writer`() {
        val responder = java.io.File("src/main/kotlin/app/critalarm/check/WeeklyCheckResponder.kt").readText()
        assertEquals(1, Regex("putString\\(ARRIVAL_KEY").findAll(responder).count())
        val recordAnswer = responder.substringAfter("fun recordAnswer(").substringBefore("\n    }")
        assertTrue(recordAnswer.contains("worker.execute"))
        val others = java.io.File("src/main/kotlin/app/critalarm/check").walkTopDown()
            .filter { it.extension == "kt" && it.name != "WeeklyCheckResponder.kt" }
            .filter { it.readText().contains("ARRIVAL_KEY") }
            .map { it.name }.toList()
        assertEquals(emptyList<String>(), others)
    }
}
