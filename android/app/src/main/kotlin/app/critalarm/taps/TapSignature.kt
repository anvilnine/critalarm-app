package app.critalarm.taps

import app.critalarm.MainActivity
import app.critalarm.localreminders.LocalReminderAlarms
import app.critalarm.localreminders.LocalReminderTapIntent
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.security.MessageDigest
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * The mark an intent the app built for MainActivity carries.
 *
 * MainActivity is exported, so an extra on its intent does not say who put
 * it there. Every intent the app builds for it (a notification, a widget, a
 * reminder) carries [EXTRA] as well: an HMAC-SHA256, under a key only this
 * install holds, of the extras MainActivity routes on. MainActivity acts on
 * those extras only when the mark matches them.
 *
 * Each extra goes in under its name with a length, in the fixed order of
 * [FIELDS], and a missing extra is told apart from an empty one. A value
 * cannot be moved to another extra, or split across two, and still match.
 *
 * Nothing here logs: the key, a mark and an extra's value stay out of logs.
 *
 * Not covered: the home screen shortcuts. The quick_actions plugin reads its
 * own extra off MainActivity's intent, and the launcher that sends it cannot
 * carry a mark, so a shortcut's screen opens for any app that names it.
 *
 * Pure, so a JVM test can reach it. The key comes in as a parameter.
 */
object TapSignature {
    /** The extra holding the mark. */
    const val EXTRA = "tap_mark"

    /**
     * Flutter's own start route. Never one of ours and never read: every
     * intent loses it at the gate.
     */
    const val FLUTTER_ROUTE = "route"

    /** The extras MainActivity routes on, in the order they are signed. */
    val FIELDS: List<String> = listOf(
        MainActivity.EXTRA_ALARM_INCIDENT_ID,
        MainActivity.EXTRA_INCIDENT_ID,
        MainActivity.EXTRA_TOPIC,
        MainActivity.EXTRA_OPEN,
        MainActivity.EXTRA_FROM,
        LocalReminderAlarms.EXTRA_ID,
        LocalReminderTapIntent.EXTRA_KIND,
        LocalReminderTapIntent.EXTRA_ACTION,
        LocalReminderTapIntent.EXTRA_PAYLOAD,
    )

    private const val ALGORITHM = "HmacSHA256"

    /** Changes when the layout below does, so an old mark never matches it. */
    private const val LAYOUT = "critalarm.tap.1"

    /** The mark for [values], keyed by extra name. Names not in [FIELDS] are not signed. */
    fun sign(key: ByteArray, values: Map<String, String?>): String {
        val mac = Mac.getInstance(ALGORITHM)
        mac.init(SecretKeySpec(key, ALGORITHM))
        return hex(mac.doFinal(message(values)))
    }

    /** True only when [mark] is the mark for [values] under [key]. */
    fun matches(key: ByteArray, values: Map<String, String?>, mark: String?): Boolean {
        if (mark == null) return false
        val expected = sign(key, values)
        // Constant time, so a wrong mark gives nothing away by how fast it fails.
        return MessageDigest.isEqual(
            expected.toByteArray(Charsets.US_ASCII),
            mark.toByteArray(Charsets.US_ASCII),
        )
    }

    /**
     * What the gate makes of one intent's routing extras and mark. [key] is
     * only asked for when there is something to check, so a plain launch
     * never touches the key file.
     */
    fun verdict(values: Map<String, String?>, mark: String?, key: () -> ByteArray?): TapVerdict {
        if (FIELDS.all { values[it] == null }) return TapVerdict.NONE
        val held = key() ?: return TapVerdict.REFUSED
        return if (matches(held, values, mark)) TapVerdict.SIGNED else TapVerdict.REFUSED
    }

    internal fun message(values: Map<String, String?>): ByteArray {
        val bytes = ByteArrayOutputStream()
        val out = DataOutputStream(bytes)
        writeField(out, LAYOUT)
        for (name in FIELDS) {
            writeField(out, name)
            val value = values[name]
            if (value == null) {
                out.writeInt(-1)
            } else {
                writeField(out, value)
            }
        }
        out.flush()
        return bytes.toByteArray()
    }

    private fun writeField(out: DataOutputStream, text: String) {
        val raw = text.toByteArray(Charsets.UTF_8)
        out.writeInt(raw.size)
        out.write(raw)
    }

    private fun hex(raw: ByteArray): String {
        val digits = "0123456789abcdef"
        val text = StringBuilder(raw.size * 2)
        for (byte in raw) {
            val value = byte.toInt() and 0xff
            text.append(digits[value ushr 4])
            text.append(digits[value and 0x0f])
        }
        return text.toString()
    }
}

/** What the gate found on an intent. */
enum class TapVerdict {
    /** No routing extra at all: a plain launch, a link, a shared sound. */
    NONE,

    /** Routing extras with a good mark: an intent the app built. */
    SIGNED,

    /** Routing extras with a wrong or missing mark. The launch goes on as a plain one. */
    REFUSED,
}
