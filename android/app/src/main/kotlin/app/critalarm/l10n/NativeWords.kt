package app.critalarm.l10n

import android.content.Context
import android.content.res.Resources

/**
 * Where native text comes from. [English] is the words compiled into
 * [NativeText], which the JVM tests use. [of] reads the generated string
 * resources in the language picked in the app (see [NativeLocale]).
 */
fun interface NativeWords {
    /** The text for [text], with its `{name}` placeholders still in it. */
    fun template(text: NativeText): String

    /** [text] with each `{name}` replaced by its value from [args]. */
    fun text(text: NativeText, vararg args: Pair<String, Any>): String = fill(template(text), *args)

    companion object {
        val English = NativeWords { it.english }

        /** Resources in the picked language. Falls back to [English] for any lookup that fails. */
        fun of(context: Context): NativeWords {
            val resources = NativeLocale.localizedContext(context).resources
            return ResourceWords(resources)
        }

        fun fill(template: String, vararg args: Pair<String, Any>): String =
            args.fold(template) { out, (name, value) -> out.replace("{$name}", value.toString()) }
    }
}

private class ResourceWords(private val resources: Resources) : NativeWords {
    override fun template(text: NativeText): String =
        runCatching { resources.getString(text.resId) }
            .getOrNull()
            ?.takeIf { it.isNotEmpty() }
            ?: text.english
}
