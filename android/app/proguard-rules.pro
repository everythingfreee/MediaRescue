# Shizuku loads the advanced scanner user service and AIDL stubs by reflection.
-keep class com.shaheer.mediarescue.mediarescue.AdvancedScannerUserService { public *; }
-keep class com.shaheer.mediarescue.shizuku.** { *; }
-keep class rikka.shizuku.** { *; }

# Android media controls discover the foreground service and media session callbacks.
-keep class com.shaheer.mediarescue.mediarescue.MediaPlaybackService { public *; }
