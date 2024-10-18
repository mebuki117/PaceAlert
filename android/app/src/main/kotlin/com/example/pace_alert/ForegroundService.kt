package com.example.pace_alert

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import android.app.AlarmManager
import kotlinx.coroutines.*
import okhttp3.*
import org.json.JSONArray
import java.io.IOException

class ForegroundService : Service() {
    private val channelId = "ForegroundServiceChannel"
    private val notificationId = 1
    private val client = OkHttpClient()
    private var job: Job? = null

    private val eventIdsToNotify = setOf(
        "rsg.enter_nether",
        "rsg.enter_bastion",
        "rsg.enter_fortress",
        "rsg.first_portal",
        "rsg.enter_stronghold",
        "rsg.enter_end",
        "rsg.credits"
    )

    private val eventIdThresholds = mapOf(
        "rsg.enter_nether" to 0,
        "rsg.enter_bastion" to 0,
        "rsg.enter_fortress" to 0,
        "rsg.first_portal" to 0,
        "rsg.enter_stronghold" to 300000,
        "rsg.enter_end" to 371000,
        "rsg.credits" to 421494
    )

    private val notifiedEventIds = mutableMapOf<String, MutableSet<String>>()
    private var sentNotificationIds = mutableSetOf<Int>()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(notificationId, getNotification("Pace Alert Running", "Waiting for pace..."))
        startDataFetching()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startDataFetching()
        return START_STICKY
    }

    private fun startDataFetching() {
        job = CoroutineScope(Dispatchers.IO).launch {
            while (isActive) {
                fetchData()
                delay(20000)
            }
        }
    }

    private fun stopDataFetching() {
        job?.cancel()
    }

    private fun fetchData() {
        val request = Request.Builder()
            .url("https://paceman.gg/api/ars/liveruns")
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("ForegroundService", "Data fetch failed: ${e.message}")
            }

            override fun onResponse(call: Call, response: Response) {
                response.body?.string()?.let { responseBody ->
                    val dataArray = JSONArray(responseBody)
                    checkForNewEvents(dataArray)
                }
            }
        })
    }

    private fun checkForNewEvents(dataArray: JSONArray) {
        val currentNicknames = mutableSetOf<String>()

        for (i in 0 until dataArray.length()) {
            val item = dataArray.getJSONObject(i)
            val eventList = item.optJSONArray("eventList")
            val nickname = item.getString("nickname")
            currentNicknames.add(nickname)

            if (eventList != null) {
                for (j in 0 until eventList.length()) {
                    val eventId = eventList.getJSONObject(j).getString("eventId")
                    val igt = eventList.getJSONObject(j).getInt("igt")

                    val threshold = eventIdThresholds[eventId]

                    if (eventIdsToNotify.contains(eventId) && threshold != null && igt < threshold) {
                        if (!notifiedEventIds.containsKey(nickname)) {
                            notifiedEventIds[nickname] = mutableSetOf()
                        }

                        if (!notifiedEventIds[nickname]!!.contains(eventId)) {
                            val formattedTime = formatTime(igt)
                            val eventMessage = when (eventId) {
                                "rsg.enter_nether" -> "Enter Nether"
                                "rsg.enter_bastion" -> "Enter Bastion"
                                "rsg.enter_fortress" -> "Enter Fortress"
                                "rsg.first_portal" -> "First Portal"
                                "rsg.enter_stronghold" -> "Enter Stronghold"
                                "rsg.enter_end" -> "Enter End"
                                "rsg.credits" -> "Finish"
                                else -> eventId
                            }

                            showNotification("$nickname: $eventMessage ($formattedTime)", item.optJSONObject("user")?.optString("liveAccount"))
                            notifiedEventIds[nickname]!!.add(eventId)
                            Log.d("ForegroundService", "Notification sent: $nickname with eventId: $eventId ($formattedTime)")
                        }
                    }
                }
            }
        }

        notifiedEventIds.keys.removeAll { !currentNicknames.contains(it) }
    }

    private fun formatTime(time: Int): String {
        val seconds = time / 1000
        val minutes = seconds / 60
        val remainingSeconds = seconds % 60
        return String.format("%02d:%02d", minutes, remainingSeconds)
    }

    private fun showNotification(message: String, liveAccount: String?) {
        val notification = getNotification("Pace Alert!", message)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notificationId = System.currentTimeMillis().toInt()

        if (!sentNotificationIds.contains(notificationId)) {
            notificationManager.notify(notificationId, notification)
            sentNotificationIds.add(notificationId)
        }
    }

    private fun getNotification(title: String, message: String): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            pendingIntentFlags
        )

        val soundUri = Uri.parse("android.resource://${packageName}/${R.raw.notification}")

        val notificationBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this)
                .setSound(soundUri)
        }

        return notificationBuilder
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(R.mipmap.paceman)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val soundUri = Uri.parse("android.resource://${packageName}/${R.raw.notification}")
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            val serviceChannel = NotificationChannel(
                channelId,
                "Foreground Service Channel",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(soundUri, audioAttributes)
                enableLights(true)
                enableVibration(true)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        stopDataFetching()
        Log.d("ForegroundService", "Service Destroyed")
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        val restartServiceIntent = Intent(applicationContext, ForegroundService::class.java).also {
            it.setPackage(packageName)
        }
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_ONE_SHOT
        }
        val restartServicePendingIntent = PendingIntent.getService(
            applicationContext, 1, restartServiceIntent, pendingIntentFlags
        )
        val alarmService = getSystemService(ALARM_SERVICE) as AlarmManager
        alarmService.set(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + 1000,
            restartServicePendingIntent
        )
        super.onTaskRemoved(rootIntent)
    }
}