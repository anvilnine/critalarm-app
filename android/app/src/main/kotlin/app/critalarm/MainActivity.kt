package app.critalarm

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import app.critalarm.alarm.AlarmChannel
import app.critalarm.notifications.NotificationChannels
import app.critalarm.sound.SoundChannel
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not FlutterActivity: flutter_local_notifications
// needs a FragmentActivity to show its permission and exact-alarm dialogs, and
// A2's full-screen alarm intent lands on this class.
class MainActivity : FlutterFragmentActivity() {
    private val SETTINGS_CHANNEL = "app.critalarm/settings"
    private var soundChannel: SoundChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val sounds = SoundChannel(applicationContext)
        soundChannel = sounds
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SoundChannel.NAME)
            .setMethodCallHandler(sounds::handle)
        val alarms = AlarmChannel(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AlarmChannel.NAME)
            .setMethodCallHandler(alarms::handle)
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
                "checkPromotedNotifications" -> result.success(
                    Build.VERSION.SDK_INT < 36 ||
                        getSystemService(NotificationManager::class.java).canPostPromotedNotifications(),
                )
                "checkDndAccess" -> result.success(
                    getSystemService(NotificationManager::class.java).isNotificationPolicyAccessGranted,
                )
                "openExactAlarmsSettings" -> {
                    startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply { data = Uri.parse("package:$packageName") })
                    result.success(true)
                }
                "openPromotedNotificationsSettings" -> {
                    startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_PROMOTION_SETTINGS).apply { data = Uri.parse("package:$packageName") })
                    result.success(true)
                }
                "openDndSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onStop() {
        // Leaving the picker on screen must not leave a preview ringing.
        soundChannel?.stopPreview()
        super.onStop()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // First launch is where the four channels come from. Creating one that
        // already exists changes nothing, so this is safe to run every time.
        NotificationChannels.ensureCreated(this)
        val alarmLaunch = intent.getStringExtra(EXTRA_ALARM_INCIDENT_ID) != null
        if (alarmLaunch && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        super.onCreate(savedInstanceState)
    }

    /**
     * A tapped notification opens the incident it belongs to. A priority 1-3
     * message has no incident (api.md §1.7), so its notification carries the
     * topic and opens that instead.
     */
    override fun getInitialRoute(): String? {
        val incidentId = intent.getStringExtra(EXTRA_ALARM_INCIDENT_ID)
            ?: intent.getStringExtra(EXTRA_INCIDENT_ID)
        if (incidentId != null) return "/incidents/${Uri.encode(incidentId)}"
        val topic = intent.getStringExtra(EXTRA_TOPIC)
        if (topic != null) return "/topics/${Uri.encode(topic)}"
        return super.getInitialRoute()
    }

    companion object {
        const val EXTRA_ALARM_INCIDENT_ID = "alarm_incident_id"
        const val EXTRA_INCIDENT_ID = "incident_id"
        const val EXTRA_TOPIC = "topic"
    }
}
