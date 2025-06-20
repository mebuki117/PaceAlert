package com.example.pace_alert

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
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
import androidx.core.app.NotificationCompat
import android.os.Handler
import android.media.Ringtone
import android.media.RingtoneManager
import android.media.AudioManager
import android.media.AudioAttributes

class ForegroundService : Service() {
    private val foregroundChannelId = "ForegroundServiceChannel"
    private val notificationChannelId = "NotificationChannel"
    private val notificationId = 1
    private val sentNotificationIds = mutableSetOf<Int>()
    private val handler = Handler()
    private var ringtone: Ringtone? = null
    private val stopDelay: Long = 600000
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
        "rsg.enter_stronghold" to 320000,
        "rsg.enter_end" to 355000,
        "rsg.credits" to 410359
    )

    private val notifiedEventIds = mutableMapOf<String, MutableSet<String>>()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        startForeground(notificationId, getOngoingNotification())
        startDataFetching()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "STOP_SOUND" -> {
                stopAlertSound()
            }
            else -> {
                startForeground(notificationId, getOngoingNotification())
            }
        }
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

    private fun getOngoingNotification(): Notification {
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
    
        return NotificationCompat.Builder(this, foregroundChannelId)
            .setContentTitle("PaceAlert Running in Background")
            .setContentText("waiting wr pace...")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun showNotification(message: String, liveAccount: String?) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    
        val stopIntent = Intent(this, ForegroundService::class.java).apply {
            action = "STOP_SOUND"
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    
        val notification = NotificationCompat.Builder(this, notificationChannelId)
            .setContentTitle("Pace Alert!")
            .setContentText(message)
            .setSmallIcon(R.mipmap.paceman)
            .addAction(0, "Stop Alert", stopPendingIntent)
            .setDeleteIntent(stopPendingIntent)
            .setAutoCancel(true)
            .build()
    
        val uniqueNotificationId = message.hashCode()
    
        if (!sentNotificationIds.contains(uniqueNotificationId)) {
            notificationManager.notify(uniqueNotificationId, notification)
            sentNotificationIds.add(uniqueNotificationId)
            startAlertSound()
        }
    }

    private fun getNotification(title: String, message: String): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent: PendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, notificationChannelId)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(R.mipmap.paceman)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val foregroundServiceChannel = NotificationChannel(
                foregroundChannelId,
                "Foreground Service Channel",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setSound(null, null)
            }
    
            val notificationChannel = NotificationChannel(
                notificationChannelId,
                "Notification Channel",
                NotificationManager.IMPORTANCE_HIGH
                ).apply {
                     setSound(null, null)
                }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(foregroundServiceChannel)
            manager.createNotificationChannel(notificationChannel)
        }
    }     

    private fun startAlertSound() {
        if (ringtone == null) {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (audioManager.ringerMode != AudioManager.RINGER_MODE_SILENT) {
                val notificationUri = Uri.parse("android.resource://${packageName}/raw/notification")
                ringtone = RingtoneManager.getRingtone(applicationContext, notificationUri)
                ringtone?.apply {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        isLooping = true
                    }
                    audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                    play()
                }
    
                handler.postDelayed({
                    stopAlertSound()
                }, stopDelay)
            }
        }
    }
    
    private fun stopAlertSound() {
        ringtone?.stop()
        ringtone = null
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        stopDataFetching()
        stopAlertSound()
        Log.d("ForegroundService", "Service Destroyed")
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        val restartServiceIntent = Intent(applicationContext, ForegroundService::class.java).also {
            it.setPackage(packageName)
        }
        val restartServicePendingIntent: PendingIntent =
            PendingIntent.getService(this, 1, restartServiceIntent, PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE)
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.set(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + 1000,
            restartServicePendingIntent
        )
        super.onTaskRemoved(rootIntent)
    }
}
