# ── Flutter Framework Baseline Rules ──────────────────────────────────────────
# Prevent R8 from optimizing out or breaking standard Flutter core classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep attributes required for clear crash logging and recognizable stack traces
-keepattributes SourceFile,LineNumberTable,Signature,InnerClasses,EnclosingMethod

# ── Project Custom Rules ──────────────────────────────────────────────────────
# Shizuku loads the advanced scanner user service and AIDL stubs by reflection.
-keep class com.shaheer.mediarescue.mediarescue.AdvancedScannerUserService { public *; }
-keep class com.shaheer.mediarescue.shizuku.** { *; }
-keep class rikka.shizuku.** { *; }

# Android media controls discover the foreground service and media session callbacks.
-keep class com.shaheer.mediarescue.mediarescue.MediaPlaybackService { public *; }

# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task