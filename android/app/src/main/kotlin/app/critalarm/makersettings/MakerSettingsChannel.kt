package app.critalarm.makersettings

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The Android half of Dart's `PlatformMakerSettingsOpener`.
 *
 * `open` takes the candidates in order and answers the index of the one that
 * opened, or -1. The page is started from the application context with
 * NEW_TASK, so a settings page of another app opens as its own task.
 */
class MakerSettingsChannel(context: Context) {

    private val launcher = MakerSettingsLauncher(AndroidMakerSettingsGateway(context.applicationContext))

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> {
                val candidates = MakerSettingsCandidate.parseAll(call.argument<Any>("candidates"))
                result.success(launcher.open(candidates))
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        /** Matches PlatformMakerSettingsOpener.channelName in Dart. */
        const val NAME = "app.critalarm/maker_settings"
    }
}

/**
 * Builds each candidate's intent and asks the package manager whether it
 * resolves. The packages Dart names are listed under `<queries>` in the
 * manifest, because from Android 11 the package manager hides apps that
 * are not.
 */
internal class AndroidMakerSettingsGateway(private val context: Context) : MakerSettingsGateway {

    override fun resolves(candidate: MakerSettingsCandidate): Boolean {
        val intent = intentFor(candidate) ?: return false
        return intent.resolveActivity(context.packageManager) != null
    }

    override fun start(candidate: MakerSettingsCandidate) {
        val intent = intentFor(candidate) ?: return
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun intentFor(candidate: MakerSettingsCandidate): Intent? = when (candidate.kind) {
        "component" -> {
            val pkg = candidate.pkg
            val component = candidate.component
            if (pkg == null || component == null) null
            else Intent().setComponent(ComponentName(pkg, component))
        }
        "action" -> candidate.action?.let { Intent(it) }
        "appDetails" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:${context.packageName}")
        }
        else -> null
    }
}
