package app.critalarm.l10n

import android.app.LocaleManager
import android.content.Context
import android.content.res.Configuration
import android.content.res.Resources
import android.os.Build
import android.os.LocaleList

/**
 * The language picked inside the app, for code that runs with no Flutter
 * engine: the alarm card, the status card, the widgets and the channels.
 *
 * Dart sends the pick through `app.critalarm/locale` (`setAppLocale` in
 * lib/core/l10n/native_locale_bridge.dart).
 *
 * - Android 13 and later: the pick goes to the system with
 *   [LocaleManager.setApplicationLocales], so the system's per-app language
 *   screen shows it and every resource in the app follows. The system is
 *   then the truth, also when the person changes it there.
 * - Below 13: the pick is kept in this app's own preferences and put on the
 *   [Context] each lookup uses ([localizedContext]).
 *
 * No pick means System default: the phone's own languages.
 */
object NativeLocale {
    private const val PREFS = "critalarm_locale"
    private const val KEY = "app_locale"

    /** The tag last picked in the app, or null for System default. */
    fun savedTag(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }

    /** Stores [tag] (null or empty for System default) and hands it to the system on 13+. */
    fun apply(context: Context, tag: String?) {
        val clean = tag?.trim()?.takeIf { it.isNotEmpty() }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
            if (clean == null) remove(KEY) else putString(KEY, clean)
        }.apply()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.getSystemService(LocaleManager::class.java)
                ?.applicationLocales = LocaleList.forLanguageTags(clean ?: "")
        }
    }

    /**
     * The locales native text is looked up in: the app's own pick, else the
     * phone's languages. Read fresh every time, so a pick made a moment ago
     * counts even before the system has pushed the new configuration.
     */
    fun locales(context: Context): LocaleList {
        val picked = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.getSystemService(LocaleManager::class.java)?.applicationLocales
        } else {
            savedTag(context)?.let { LocaleList.forLanguageTags(it) }
        }
        return picked?.takeIf { !it.isEmpty } ?: Resources.getSystem().configuration.locales
    }

    /** [context] with its resources in [locales]. [context] itself if that fails. */
    fun localizedContext(context: Context): Context = runCatching {
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocales(locales(context))
        context.createConfigurationContext(configuration)
    }.getOrDefault(context)
}
