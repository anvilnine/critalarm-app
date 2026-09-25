package app.critalarm.widgets

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dart's side of the widget snapshot (`lib/core/widgets/widget_host.dart`).
 * `write` stores a snapshot Dart built, `clear` stores the signed-out one.
 */
class WidgetChannel(context: Context) {
    private val store = WidgetSnapshotStore(context)

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "write" -> {
                val json = call.argument<String>("json")
                if (json == null || !store.writeJson(json)) {
                    result.error("bad_args", "json must be a version 1 snapshot", null)
                } else {
                    result.success(null)
                }
            }
            "clear" -> {
                store.clear()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val NAME = "app.critalarm/widgets"
    }
}
