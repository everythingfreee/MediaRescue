package com.shaheer.mediarescue.mediarescue

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat

class MediaPlaybackService : Service() {
    companion object {
        const val ACTION_START = "com.shaheer.mediarescue.media.START"
        const val ACTION_PLAY_PAUSE = "com.shaheer.mediarescue.media.PLAY_PAUSE"
        const val ACTION_NEXT = "com.shaheer.mediarescue.media.NEXT"
        const val ACTION_PREVIOUS = "com.shaheer.mediarescue.media.PREVIOUS"
        const val ACTION_STOP = "com.shaheer.mediarescue.media.STOP"
        const val EXTRA_PATH = "path"
        const val EXTRA_TITLE = "title"
        const val EXTRA_POSITION_MS = "positionMs"
        const val EXTRA_PLAYING = "playing"
        const val EXTRA_PATHS = "paths"
        const val EXTRA_TITLES = "titles"
        const val EXTRA_INDEX = "index"
        const val EXTRA_NOTIFICATION_ENABLED = "notificationEnabled"
        const val NOTIFICATION_ID = 2301
        const val CHANNEL_ID = "mediarescue_playback"

        @Volatile
        private var instance: MediaPlaybackService? = null

        fun snapshot(): Map<String, Any> {
            val service = instance ?: return mapOf(
                "active" to false,
                "playing" to false,
                "positionMs" to 0,
                "index" to 0,
            )
            val player = service.player
            return mapOf(
                "active" to (player != null),
                "playing" to (player?.isPlaying == true),
                "positionMs" to (player?.currentPosition ?: 0),
                "index" to service.currentIndex,
            )
        }
    }

    private var player: MediaPlayer? = null
    private var mediaSession: MediaSessionCompat? = null
    private var title = "MediaRescue"
    private var currentIndex = 0
    private var paths = emptyList<String>()
    private var titles = emptyList<String>()
    private var prepared = false
    private var notificationEnabled = true

    override fun onCreate() {
        super.onCreate()
        instance = this
        createChannel()
        mediaSession = MediaSessionCompat(this, "MediaRescuePlayback").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() = startCurrent()
                override fun onPause() = pauseCurrent()
                override fun onStop() = stopPlayback()

                override fun onSeekTo(pos: Long) {
                    try {
                        val duration = player?.duration?.toLong() ?: pos
                        player?.seekTo(pos.coerceAtLeast(0L).coerceAtMost(duration).toInt())
                        updatePlaybackState()
                    } catch (_: IllegalStateException) {
                        // MediaPlayer may still be preparing.
                    }
                }

                override fun onSkipToNext() {
                    if (paths.size > 1) openIndex((currentIndex + 1) % paths.size, true)
                }

                override fun onSkipToPrevious() {
                    if (paths.size > 1) openIndex((currentIndex - 1 + paths.size) % paths.size, true)
                }
            })
            isActive = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startPlayback(intent)
            ACTION_PLAY_PAUSE -> if (player?.isPlaying == true) pauseCurrent() else startCurrent()
            ACTION_NEXT -> if (paths.size > 1) openIndex((currentIndex + 1) % paths.size, true)
            ACTION_PREVIOUS -> if (paths.size > 1) openIndex((currentIndex - 1 + paths.size) % paths.size, true)
            ACTION_STOP -> stopPlayback()
        }
        return START_NOT_STICKY
    }

    private fun startPlayback(intent: Intent) {
        val incomingPaths = intent.getStringArrayListExtra(EXTRA_PATHS).orEmpty()
        val incomingTitles = intent.getStringArrayListExtra(EXTRA_TITLES).orEmpty()
        paths = if (incomingPaths.isEmpty()) listOfNotNull(intent.getStringExtra(EXTRA_PATH)) else incomingPaths
        titles = if (incomingTitles.isEmpty()) listOf(intent.getStringExtra(EXTRA_TITLE) ?: "MediaRescue") else incomingTitles
        currentIndex = intent.getIntExtra(EXTRA_INDEX, 0).coerceIn(0, (paths.size - 1).coerceAtLeast(0))
        notificationEnabled = intent.getBooleanExtra(EXTRA_NOTIFICATION_ENABLED, true)
        openIndex(currentIndex, intent.getBooleanExtra(EXTRA_PLAYING, true), intent.getIntExtra(EXTRA_POSITION_MS, 0))
    }

    private fun openIndex(index: Int, shouldPlay: Boolean, positionMs: Int = 0) {
        if (paths.isEmpty()) return
        currentIndex = index.coerceIn(0, paths.lastIndex)
        title = titles.getOrNull(currentIndex) ?: "MediaRescue"
        prepared = false
        releasePlayer()
        val newPlayer = MediaPlayer()
        player = newPlayer
        newPlayer.setOnCompletionListener {
            if (paths.size > 1) openIndex((currentIndex + 1) % paths.size, true) else stopPlayback()
        }
        try {
            newPlayer.setDataSource(paths[currentIndex])
            newPlayer.setOnPreparedListener {
                prepared = true
                if (positionMs > 0) it.seekTo(positionMs)
                if (shouldPlay) it.start()
                updateMetadata()
                updatePlaybackState()
                updateNotification()
            }
            newPlayer.prepareAsync()
            if (notificationEnabled) startAsForeground()
        } catch (_: Exception) {
            stopPlayback()
        }
    }

    private fun startCurrent() {
        try {
            if (prepared) player?.start()
            updatePlaybackState()
            updateNotification()
        } catch (_: IllegalStateException) {}
    }

    private fun pauseCurrent() {
        try {
            player?.pause()
            updatePlaybackState()
            updateNotification()
        } catch (_: IllegalStateException) {}
    }

    private fun startAsForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopPlayback() {
        releasePlayer()
        mediaSession?.isActive = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun releasePlayer() {
        prepared = false
        try {
            player?.setOnCompletionListener(null)
            player?.release()
        } catch (_: IllegalStateException) {}
        player = null
    }

    private fun updateMetadata() {
        val artwork = artworkForCurrentMedia()
        mediaSession?.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_TITLE, title)
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, try { player?.duration?.toLong() ?: 0L } catch (_: IllegalStateException) { 0L })
                .apply { if (artwork != null) putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, artwork) }
                .build(),
        )
    }

    private fun updatePlaybackState() {
        val current = player ?: return
        val state = if (current.isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        var actions = PlaybackStateCompat.ACTION_PLAY or PlaybackStateCompat.ACTION_PAUSE or PlaybackStateCompat.ACTION_PLAY_PAUSE or PlaybackStateCompat.ACTION_SEEK_TO or PlaybackStateCompat.ACTION_STOP
        if (paths.size > 1) actions = actions or PlaybackStateCompat.ACTION_SKIP_TO_NEXT or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
        val position = try { current.currentPosition.toLong() } catch (_: IllegalStateException) { 0L }
        mediaSession?.setPlaybackState(
            PlaybackStateCompat.Builder().setActions(actions).setState(state, position, 1f, SystemClock.elapsedRealtime()).build(),
        )
    }

    private fun updateNotification() {
        if (notificationEnabled && player != null) {
            getSystemService(NotificationManager::class.java)?.notify(NOTIFICATION_ID, buildNotification())
        }
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = PendingIntent.getActivity(this, 2302, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val mediaStyle = MediaStyle().setMediaSession(mediaSession?.sessionToken).setShowActionsInCompactView(0, 1, 2)
        val artwork = artworkForCurrentMedia()
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText(if (player?.isPlaying == true) "Playing" else "Paused")
            .setContentIntent(contentIntent)
            .setLargeIcon(artwork)
            .setStyle(mediaStyle)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        if (paths.size > 1) builder.addAction(android.R.drawable.ic_media_previous, "Previous", serviceIntent(ACTION_PREVIOUS, 2305))
        builder.addAction(if (player?.isPlaying == true) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play, if (player?.isPlaying == true) "Pause" else "Play", serviceIntent(ACTION_PLAY_PAUSE, 2303))
        if (paths.size > 1) builder.addAction(android.R.drawable.ic_media_next, "Next", serviceIntent(ACTION_NEXT, 2306))
        builder.addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", serviceIntent(ACTION_STOP, 2304))
        return builder.build()
    }

    private fun artworkForCurrentMedia() = paths.getOrNull(currentIndex)?.let { path ->
        try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(path)
            val frame = retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            retriever.release()
            frame
        } catch (_: RuntimeException) {
            BitmapFactory.decodeFile(path)
        }
    }

    private fun serviceIntent(action: String, requestCode: Int): PendingIntent = PendingIntent.getService(this, requestCode, Intent(this, MediaPlaybackService::class.java).setAction(action), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(CHANNEL_ID, "Media playback", NotificationManager.IMPORTANCE_LOW).apply { description = "Background video and audio playback" }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    override fun onDestroy() {
        releasePlayer()
        mediaSession?.release()
        instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
