package app.critalarm.localreminders

import android.app.Notification
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import app.critalarm.R
import java.io.IOException

/** Builds a reminder notification: Crit's face, the words, the buttons. */
object LocalReminderNotificationFactory {
    private const val APP_NAME = "Crit Alarm"
    private const val FACE_SIZE_PX = 192

    fun build(context: Context, spec: LocalReminderSpec): Notification {
        // What a locked phone shows: no topic names.
        val publicVersion = Notification.Builder(context, spec.channelId)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setContentTitle(APP_NAME)
            .setContentText(spec.hiddenPreview)
            .build()

        val builder = Notification.Builder(context, spec.channelId)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setContentTitle(spec.title)
            .setContentText(spec.body)
            .setStyle(Notification.BigTextStyle().bigText(spec.body))
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .setAutoCancel(true)
            .setContentIntent(
                LocalReminderTapIntent.open(context, spec, LocalReminderTapIntent.OPEN, requestCode(spec.id, 0)),
            )
        loadFace(context, spec.faceAsset)?.let { builder.setLargeIcon(it) }

        spec.actions.forEachIndexed { index, action ->
            val code = requestCode(spec.id, index + 1)
            // Buttons on a watch do nothing useful here, so none are bridged.
            val pending = if (action.opensApp) {
                LocalReminderTapIntent.open(context, spec, action.id, code)
            } else {
                LocalReminderTapIntent.inBackground(context, spec, action.id, code)
            }
            builder.addAction(
                Notification.Action.Builder(null as Icon?, action.title, pending)
                    .setAllowGeneratedReplies(false)
                    .build(),
            )
        }
        builder.setLocalOnly(true)
        return builder.build()
    }

    private fun requestCode(id: Int, slot: Int): Int = id * 8 + slot

    /** Flutter bundles its assets under flutter_assets/ in the APK. */
    private fun loadFace(context: Context, asset: String): Bitmap? = try {
        context.assets.open("flutter_assets/$asset").use { stream ->
            BitmapFactory.decodeStream(stream)?.let {
                Bitmap.createScaledBitmap(it, FACE_SIZE_PX, FACE_SIZE_PX, true)
            }
        }
    } catch (e: IOException) {
        null
    }
}
