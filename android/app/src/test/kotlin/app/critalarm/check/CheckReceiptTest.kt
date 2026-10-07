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
}
