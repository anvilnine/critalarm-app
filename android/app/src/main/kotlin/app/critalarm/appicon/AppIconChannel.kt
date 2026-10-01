package app.critalarm.appicon

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dart's side of the app icon (`lib/core/app_icon/app_icon_host.dart`).
 *
 * Each icon is an `activity-alias` of MainActivity in the manifest, and the
 * launcher shows whichever alias is enabled. `current` answers which one that
 * is, `set` enables one and disables the rest. Only `LauncherDefault` is
 * enabled in the manifest, so a fresh install shows the default icon.
 */
class AppIconChannel(private val context: Context) {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "current" -> result.success(current())
            "set" -> {
                val icon = call.argument<String>("icon")
                if (icon == null || icon !in ALIASES) {
                    result.error("bad_args", "icon must be one of ${ALIASES.keys}", null)
                    return
                }
                try {
                    apply(icon)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("unavailable", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun current(): String {
        val packages = context.packageManager
        for ((icon, alias) in ALIASES) {
            if (icon == DEFAULT) continue
            val state = packages.getComponentEnabledSetting(ComponentName(context, alias))
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) return icon
        }
        return DEFAULT
    }

    private fun apply(icon: String) {
        val packages = context.packageManager
        // Turn the new one on before the old one off, so there is never a
        // moment with no launcher entry at all.
        packages.setComponentEnabledSetting(
            ComponentName(context, ALIASES.getValue(icon)),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for ((other, alias) in ALIASES) {
            if (other == icon) continue
            packages.setComponentEnabledSetting(
                ComponentName(context, alias),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }

    companion object {
        const val NAME = "app.critalarm/app_icon"
        private const val DEFAULT = "default"

        /** Dart's name for each icon, and the alias in the manifest that shows it. */
        private val ALIASES = linkedMapOf(
            DEFAULT to "app.critalarm.LauncherDefault",
            "pro_crowned" to "app.critalarm.LauncherProCrowned",
            "pro_shades" to "app.critalarm.LauncherProShades",
            "pro_shades_crown" to "app.critalarm.LauncherProShadesCrown",
        )
    }
}
