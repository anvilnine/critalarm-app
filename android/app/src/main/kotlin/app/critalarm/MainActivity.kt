package app.critalarm

import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import app.critalarm.alarm.AlarmChannel
import app.critalarm.notifications.LiveUpdate
import app.critalarm.notifications.NotificationChannels
import app.critalarm.reminders.ReminderChannel
import app.critalarm.reminders.ReminderTapIntent
import app.critalarm.sound.IncomingAudioHolder
import app.critalarm.sound.SoundChannel
import app.critalarm.widgets.WidgetChannel
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not FlutterActivity: flutter_local_notifications
// needs a FragmentActivity to show its permission and exact-alarm dialogs, and
// A2's full-screen alarm intent lands on this class.
class MainActivity : FlutterFragmentActivity() {
    private val SETTINGS_CHANNEL = "app.critalarm/settings"
    private var soundChannel: SoundChannel? = null
    private var soundMethods: MethodChannel? = null

    /**
     * A tap the activity has read off an intent but Dart has not taken yet.
     * Dart asks for it on resume, before it reloads its lists.
     */
    private var pendingTap: Map<String, String>? = null

    private var tapSequence = 0

    /** A reminder tap Dart has not taken yet. Separate from incident taps. */
    private var pendingReminderTap: Map<String, Any>? = null

    private var reminderChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The same channel iOS uses, with the same two calls Dart makes of it:
        // `takePending` for a tap the platform still holds, and the
        // `onNotificationTap` / `onPushReceived` calls sent the other way.
        val push = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PUSH_CHANNEL)
        push.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePending" -> {
                    val tap = pendingTap
                    pendingTap = null
                    result.success(if (tap == null) null else mapOf("tap" to tap))
                }
                // The APNs token and the app-icon badge are iOS only.
                else -> result.notImplemented()
            }
        }
        pushChannel = push
        val soundMethods = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SoundChannel.NAME)
        val sounds = SoundChannel(applicationContext, soundMethods)
        soundChannel = sounds
        this.soundMethods = soundMethods
        soundMethods.setMethodCallHandler(sounds::handle)
        val alarms = AlarmChannel(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AlarmChannel.NAME)
            .setMethodCallHandler(alarms::handle)
        val widgets = WidgetChannel(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WidgetChannel.NAME)
            .setMethodCallHandler(widgets::handle)
        val reminders = ReminderChannel(applicationContext) {
            val tap = pendingReminderTap
            pendingReminderTap = null
            tap
        }
        reminderChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ReminderChannel.NAME)
            .also { it.setMethodCallHandler(reminders::handle) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            }
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("UNAVAILABLE", "Cannot open settings", null)
                        }
                    }
                }
                "openAppSettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Cannot open settings", null)
                    }
                }
                "openFullScreenIntentSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Cannot open settings", null)
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallback = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            } else {
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                            }
                            startActivity(fallback)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("UNAVAILABLE", "Cannot open battery optimization settings", null)
                        }
                    }
                }
                "checkBatteryOptimization" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                            val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)
                            result.success(isIgnoring)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", e.message, null)
                    }
                }
                "checkFullScreenIntent" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            result.success(notificationManager.canUseFullScreenIntent())
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(true)
                    }
                }
                "checkNotificationPermission" -> {
                    try {
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        result.success(notificationManager.areNotificationsEnabled())
                    } catch (e: Exception) {
                        result.success(true)
                    }
                }
                "checkExactAlarms" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                        getSystemService(android.app.AlarmManager::class.java).canScheduleExactAlarms(),
                )
                // LiveUpdate is what the notification code asks before it posts
                // a promoted card, so the answer here and the card on screen
                // cannot drift apart. It says no below Android 16, where there
                // is no promotion and so nothing the user could fix, which is
                // what the version check in front of it covers.
                "checkPromotedNotifications" -> result.success(
                    Build.VERSION.SDK_INT < 36 || LiveUpdate.canPromote(this),
                )
                "checkDndAccess" -> result.success(
                    getSystemService(NotificationManager::class.java).isNotificationPolicyAccessGranted,
                )
                "openExactAlarmsSettings" -> {
                    startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply { data = Uri.parse("package:$packageName") })
                    result.success(true)
                }
                // Settings.ACTION_MANAGE_APP_PROMOTED_NOTIFICATIONS does not
                // exist at compileSdk 36. The screen behind the constant below
                // is the Android 16 one, and it is missing on every older
                // release, so a miss lands on the app's own notification page.
                "openPromotedNotificationsSettings" -> {
                    try {
                        startActivity(
                            // An app-scoped notification screen reads the
                            // package off EXTRA_APP_PACKAGE. The data URI alone
                            // opens Settings on the wrong page and throws
                            // nothing, so the catch below never sees it.
                            Intent(Settings.ACTION_APP_NOTIFICATION_PROMOTION_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            },
                        )
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                },
                            )
                            result.success(true)
                        } catch (e2: ActivityNotFoundException) {
                            result.error("UNAVAILABLE", "Cannot open promoted notification settings", null)
                        }
                    }
                }
                "openDndSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // The push service checks this to decide whether anyone is listening.
        // Leaving it set after the engine goes keeps the activity alive.
        pushChannel = null
        reminderChannel = null
        soundMethods = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onStop() {
        // Leaving the picker on screen must not leave a preview ringing.
        soundChannel?.endPreview()
        super.onStop()
    }

    /**
     * A notification tapped while the app is already running. The tap intents
     * carry SINGLE_TOP, so the tap lands here instead of in onCreate and
     * `getInitialRoute` never sees it. iOS hands a warm tap over the same way.
     */
    override fun onNewIntent(intent: Intent) {
        val reminderTap = ReminderTapIntent.read(this, intent)
        val tap = readTap(intent)
        readIncomingAudio(intent)
        setIntent(intent)
        super.onNewIntent(intent)
        if (reminderTap != null) {
            // Held as well as sent, like an incident tap: Dart asks again on
            // resume, and the tap id makes the second copy a no-op.
            pendingReminderTap = reminderTap
            reminderChannel?.invokeMethod("onReminderTap", reminderTap)
        }
        if (tap == null) return
        // Held as well as sent. Dart asks for a tap on resume, before it
        // reloads its lists, so the same tap can reach it twice; the id on it
        // is what makes the second copy a no-op.
        pendingTap = tap
        pushChannel?.invokeMethod("onNotificationTap", tap)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // First launch is where the six channels come from. Creating one that
        // already exists changes nothing, so this is safe to run every time.
        NotificationChannels.ensureCreated(this)
        pendingReminderTap = ReminderTapIntent.read(this, intent)
        val alarmLaunch = intent.getStringExtra(EXTRA_ALARM_INCIDENT_ID) != null
        if (alarmLaunch && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        super.onCreate(savedInstanceState)
        val shared = readIncomingAudio(intent)
        if (savedInstanceState == null) {
            IncomingAudioHolder.clearLeftovers(cacheDir, keep = shared?.get("path") as String?)
        }
    }

    /**
     * A sound file ShareReceiverActivity copied in. Held for Dart's
     * `takeIncomingAudio` and sent live as well, the same way a tap is.
     */
    private fun readIncomingAudio(intent: Intent?): Map<String, Any>? {
        val file = IncomingAudioHolder.read(intent) ?: return null
        soundMethods?.invokeMethod("incomingAudio", file)
        return file
    }

    /**
     * A tapped notification opens the incident it belongs to. A priority 1-3
     * message has no incident (api.md §1.7), so its notification carries the
     * topic and opens that instead.
     */
    override fun getInitialRoute(): String? =
        routeFor(readTap(intent)) ?: super.getInitialRoute()

    /**
     * The tap a notification put on an intent, read once.
     *
     * The extras come off as they are read and the activity keeps the intent
     * without them, so nothing reopens the same screen later. An intent the
     * system replayed out of the recents list is ignored outright: the user
     * asked for the app, not for a notification they already dealt with.
     */
    private fun readTap(intent: Intent?): Map<String, String>? {
        if (intent == null) return null
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return null
        val incidentId = intent.getStringExtra(EXTRA_ALARM_INCIDENT_ID)
            ?: intent.getStringExtra(EXTRA_INCIDENT_ID)
        val topic = intent.getStringExtra(EXTRA_TOPIC)
        val open = intent.getStringExtra(EXTRA_OPEN)
        if (incidentId == null && topic == null && open == null) return null
        intent.removeExtra(EXTRA_ALARM_INCIDENT_ID)
        intent.removeExtra(EXTRA_INCIDENT_ID)
        intent.removeExtra(EXTRA_TOPIC)
        intent.removeExtra(EXTRA_OPEN)
        tapSequence += 1
        val tap = mutableMapOf(KEY_TAP_ID to tapSequence.toString())
        if (incidentId != null) tap[EXTRA_INCIDENT_ID] = incidentId
        if (topic != null) tap[EXTRA_TOPIC] = topic
        if (open != null) tap[EXTRA_OPEN] = open
        return tap
    }

    /** See [TapRoute]. */
    private fun routeFor(tap: Map<String, String>?): String? = TapRoute.routeFor(tap)

    companion object {
        const val EXTRA_ALARM_INCIDENT_ID = "alarm_incident_id"
        const val EXTRA_INCIDENT_ID = "incident_id"
        const val EXTRA_TOPIC = "topic"

        /** `open=home` comes from the open count widget and opens Home. */
        const val EXTRA_OPEN = "open"
        const val OPEN_HOME = "home"

        /** Matches PushHost.channelName in Dart and the channel in AppDelegate. */
        const val PUSH_CHANNEL = "app.critalarm/push"

        /** Matches PushHost.tapIdKey in Dart. */
        const val KEY_TAP_ID = "tap_id"

        /**
         * The push channel of the running app, or null when no engine is
         * attached. The push service runs in both cases.
         */
        @Volatile
        private var pushChannel: MethodChannel? = null

        /**
         * Tells a running app that a push landed, so the screen the user is
         * looking at can catch up without being left and come back to. Does
         * nothing when the app is not running, and never blocks the caller:
         * the push service is on a background thread and a channel call has
         * to be made on the main one.
         */
        fun notifyPushReceived() {
            if (pushChannel == null) return
            Handler(Looper.getMainLooper()).post {
                pushChannel?.invokeMethod("onPushReceived", null)
            }
        }
    }
}
