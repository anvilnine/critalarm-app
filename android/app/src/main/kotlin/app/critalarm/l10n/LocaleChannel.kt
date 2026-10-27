package app.critalarm.l10n

import android.content.Context
import android.util.Log
import app.critalarm.notifications.NotificationChannels
import app.critalarm.widgets.WidgetRedraw
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dart's side of the language pick (`lib/core/l10n/native_locale_bridge.dart`).
 *
 * `setAppLocale` with a tag, or with none for System default, stores it
 * ([NativeLocale.apply]), then renames the six notification channels in it
 * and redraws every widget. The channel ids stay, so their sound, importance
 * and the person's own settings stay too. A card already on screen keeps its
 * words until it is next posted.
 */
class LocaleChannel(private val context: Context) {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setAppLocale" -> {
                val tag = call.argument<String>("tag")
                NativeLocale.apply(context, tag)
                Log.i(TAG, "app_locale_set tag=${tag ?: "system"}")
                runCatching { NotificationChannels.ensureCreated(context, NativeWords.of(context)) }
                    .onFailure { Log.w(TAG, "channel_rename_failed", it) }
                runCatching { WidgetRedraw.drawAll(context) }
                    .onFailure { Log.w(TAG, "widget_redraw_failed", it) }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val NAME = "app.critalarm/locale"
        private const val TAG = "CritAlarmLocale"
    }
}
