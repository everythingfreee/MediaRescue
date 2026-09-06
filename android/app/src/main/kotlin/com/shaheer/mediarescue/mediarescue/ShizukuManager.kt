package com.shaheer.mediarescue.mediarescue

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.RemoteException
import android.util.Log
import com.shaheer.mediarescue.shizuku.IAdvancedScannerCallback
import com.shaheer.mediarescue.shizuku.IAdvancedScanner
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import rikka.shizuku.Shizuku
import rikka.shizuku.Shizuku.UserServiceArgs

/**
 * Dedicated manager for the optional Shizuku-based Advanced Scanner.
 *
 * Everything Shizuku-specific for MediaRescue lives here. The Flutter layer
 * only ever talks to this manager (through MainActivity's MethodChannel) and
 * never handles binders, Parcels or Shizuku internals.
 *
 * Responsibilities:
 *  - detecting Shizuku / Sui availability and judging whether the binder is alive
 *  - requesting Shizuku authorization and tracking its result
 *  - starting / stopping the MediaRescue User Service
 *  - tracking binder death, disconnection and permission revocation
 *  - starting / cancelling advanced scans via the User Service
 *  - emitting scan progress + results to the Flutter layer (EventChannel)
 *
 * This is intentionally isolated from the normal MediaRescue scanner: the
 * normal scanner never touches this class.
 */
class ShizukuManager {

    companion object {
        /** Our own package name (application id). */
        const val PACKAGE_NAME = "com.shaheer.mediarescue.mediarescue"

        /** Package name of the official Shizuku application. */
        const val SHIZUKU_PACKAGE = "moe.shizuku.privileged.api"

        /** Application-specific code passed to Shizuku permission requests. */
        const val REQUEST_CODE_PERMISSION = 1001

        /** Version tag of the Shizuku user service (bump to force a restart). */
        const val USER_SERVICE_VERSION = 1

        // startScan() return codes (see IAdvancedScanner.aidl).
        const val START_STARTED = 0
        const val START_ALREADY_RUNNING = 1
        const val START_INVALID_CALLBACK = 2
        const val START_INTERNAL_ERROR = 3

        val INSTANCE = ShizukuManager()
    }

    private val TAG = "ShizukuManager"

    // ── State (guarded by the state lock) ───────────────────────────────────

    private val stateLock = Object()

    private val binderAlive = AtomicBoolean(false)
    private val binderReceivedEver = AtomicBoolean(false)
    private val binderWasConnected = AtomicBoolean(false)
    private val permissionGrantedEver = AtomicBoolean(false)
    private val waitingForPermission = AtomicBoolean(false)
    private val permissionDeniedEver = AtomicBoolean(false)
    private val userServiceConnected = AtomicBoolean(false)
    private val userServiceStarting = AtomicBoolean(false)

    private var userService: IAdvancedScanner? = null
    private var serviceBinder: IBinder? = null
    private var activeScanCallback: AdvancedScannerCallback? = null
    private var lastError: String? = null
    private var isRegistered = false

    // ── Event delivery to Flutter (set by MainActivity) ─────────────────────

    /** Sends an advanced-scan event map to Flutter over the EventChannel. */
    fun interface EventSink {
        fun send(event: Map<String, Any>)
    }

    private var eventSink: EventSink? = null

    fun setEventSink(sink: EventSink?) {
        eventSink = sink
    }

    // ── Listener registration ───────────────────────────────────────────────

    private val binderReceivedListener = Shizuku.OnBinderReceivedListener {
        Log.i(TAG, "Shizuku binder received")
        synchronized (stateLock) {
            binderReceivedEver.set(true)
            binderAlive.set(true)
            binderWasConnected.set(true)
        }
        emitStateChanged()
    }

    private val binderDeadListener = Shizuku.OnBinderDeadListener {
        Log.w(TAG, "Shizuku binder dead")
        handleBinderLost("The Shizuku connection was lost. Please restart Shizuku and try again.")
    }

    private val permissionResultListener = Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
        handlePermissionResult(requestCode, grantResult)
    }

    /** Registers Shizuku listeners. Safe to call multiple times. */
    fun register() {
        Log.i(TAG, "registering Shizuku lifecycle listeners")
        synchronized (stateLock) {
            if (isRegistered) return
            isRegistered = true
        }
        Shizuku.addBinderReceivedListenerSticky(binderReceivedListener)
        Shizuku.addBinderDeadListener(binderDeadListener)
        Shizuku.addRequestPermissionResultListener(permissionResultListener)
    }

    /** Removes Shizuku listeners and stops the user service. */
    fun unregister() {
        Log.i(TAG, "unregistering Shizuku lifecycle listeners")
        synchronized (stateLock) {
            if (!isRegistered) return
            isRegistered = false
        }
        try {
            Shizuku.removeBinderReceivedListener(binderReceivedListener)
            Shizuku.removeBinderDeadListener(binderDeadListener)
            Shizuku.removeRequestPermissionResultListener(permissionResultListener)
        } catch (e: Exception) {
            Log.w(TAG, "unregister listener removal failed: ${e.message}")
        }
        try {
            Shizuku.unbindUserService(userServiceArgs, serviceConnection, true)
        } catch (e: Exception) {
            Log.w(TAG, "unbindUserService failed: ${e.message}")
        }
        synchronized(stateLock) {
            userService = null
            serviceBinder = null
            userServiceConnected.set(false)
            userServiceStarting.set(false)
            activeScanCallback = null
        }
    }

    // ── State snapshot for Flutter ────────────────────────────────────────────

    /** True when the Shizuku application is installed on this device. */
    fun isShizukuInstalled(context: Context): Boolean = try {
        context.packageManager.getPackageInfo(SHIZUKU_PACKAGE, 0)
        true
    } catch (e: Exception) {
        false
    }

    /** True when the Shizuku binder is alive (the Shizuku service is running). */
    fun isBinderAlive(): Boolean = try {
        if (!binderReceivedEver.get()) {
            Log.d(TAG, "binder availability check deferred: binder not received")
            false
        } else {
            Shizuku.pingBinder().also { alive ->
                binderAlive.set(alive)
                Log.d(TAG, "binder availability check: alive=$alive")
            }
        }
    } catch (t: Throwable) {
        binderAlive.set(false)
        Log.w(TAG, "binder availability check failed: ${t.javaClass.simpleName}: ${t.message}")
        false
    }

    /** True when MediaRescue holds Shizuku authorization. */
    fun isAuthorized(): Boolean = try {
        if (!binderAlive.get()) {
            Log.d(TAG, "permission check skipped: binder unavailable")
            false
        } else {
            (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED).also { granted ->
                Log.i(TAG, "Shizuku permission check: granted=$granted")
            }
        }
    } catch (t: Throwable) {
        Log.w(TAG, "permission check failed: ${t.javaClass.simpleName}: ${t.message}")
        false
    }

    /**
     * Snapshot for Flutter. `state` is one of: unavailable, not_running,
     * waiting_for_permission, permission_denied, authorized, service_connected.
     * Authorization and connectivity are verified — never inferred from the
     * app being installed or the binder merely being alive.
     */
    fun getStateMap(context: Context): Map<String, Any> {
        Log.d(TAG, "Shizuku state check started")
        val installed = isShizukuInstalled(context)
        val running = isBinderAlive()
        val binderReceived = binderReceivedEver.get()
        val authorized = running && isAuthorized()
        val serviceConnected: Boolean
        val state: String
        synchronized(stateLock) {
            serviceConnected = userServiceConnected.get()
            state = when {
                !installed -> "unavailable"
                !binderReceived -> "binder_not_received"
                !running -> if (binderWasConnected.get()) "binder_disconnected" else "not_running"
                waitingForPermission.get() -> "waiting_for_permission"
                !authorized -> if (permissionDeniedEver.get()) "permission_denied" else "waiting_for_permission"
                serviceConnected -> "service_connected"
                else -> "authorized"
            }
        }
        return mapOf(
            "installed" to installed,
            "running" to running,
            "binderReceived" to binderReceived,
            "authorized" to authorized,
            "serviceConnected" to serviceConnected,
            "state" to state,
        )
    }

    // ── Authorization ──────────────────────────────────────────────────────────

    private var pendingPermissionResult: MethodChannel.Result? = null

    /** Asks Shizuku to show its authorization dialog for MediaRescue. */
    fun requestPermission(result: MethodChannel.Result) {
        Log.i(TAG, "Shizuku permission request started")
        if (!isBinderAlive()) {
            result.success(mapOf("status" to "not_running", "message" to "Shizuku is not running. Start Shizuku first, then try again."))
            return
        }
        if (isAuthorized()) {
            synchronized(stateLock) { permissionGrantedEver.set(true) }
            result.success(mapOf("status" to "granted"))
            return
        }
        synchronized(stateLock) {
            waitingForPermission.set(true)
            pendingPermissionResult = result
        }
        emitStateChanged()
        try {
            Shizuku.requestPermission(REQUEST_CODE_PERMISSION)
        } catch (t: Throwable) {
            synchronized(stateLock) {
                waitingForPermission.set(false)
                pendingPermissionResult = null
            }
            Log.w(TAG, "requestPermission failed: ${t.javaClass.simpleName}: ${t.message}")
            result.success(mapOf("status" to "error", "message" to "Could not open the Shizuku authorization dialog. Make sure Shizuku is running."))
        }
    }

    private fun handlePermissionResult(requestCode: Int, grantResult: Int) {
        Log.i(TAG, "Shizuku permission result: requestCode=$requestCode granted=${grantResult == PackageManager.PERMISSION_GRANTED}")
        val pending: MethodChannel.Result?
        synchronized(stateLock) {
            if (requestCode != REQUEST_CODE_PERMISSION) return
            pending = pendingPermissionResult
            pendingPermissionResult = null
            waitingForPermission.set(false)
            if (grantResult == PackageManager.PERMISSION_GRANTED) {
                permissionGrantedEver.set(true)
            } else {
                permissionDeniedEver.set(true)
            }
        }
        // MethodChannel.Result must be completed on the main thread.
        mainHandler.post {
            pending?.success(mapOf("status" to if (grantResult == PackageManager.PERMISSION_GRANTED) "granted" else "denied"))
        }
        emitStateChanged()
    }

    // ── User service lifecycle ────────────────────────────────────────────────

    private val userServiceArgs: UserServiceArgs by lazy {
        UserServiceArgs(
            ComponentName(PACKAGE_NAME, AdvancedScannerUserService::class.java.getName()),
        )
            .processNameSuffix("advanced_scanner")
            .version(USER_SERVICE_VERSION)
    }

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            Log.i(TAG, "user service connected")
            synchronized(stateLock) {
                userServiceStarting.set(false)
                userServiceConnected.set(true)
                serviceBinder = binder
                userService = binder?.let { IAdvancedScanner.Stub.asInterface(it) }
            }
            emitStateChanged()
            tryStartPendingScan()
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            Log.w(TAG, "user service disconnected")
            handleBinderLost("The Advanced Scanning service was disconnected. Make sure Shizuku is running and try again.")
        }
    }

    private fun handleBinderLost(userMessage: String) {
        val wasScanning: Boolean
        synchronized(stateLock) {
            wasScanning = activeScanCallback != null
            binderAlive.set(false)
            userServiceConnected.set(false)
            userServiceStarting.set(false)
            userService = null
            serviceBinder = null
            activeScanCallback = null
        }
        emitStateChanged()
        if (wasScanning) {
            // A lost connection must NEVER be reported as a successful scan;
            // already-collected results are preserved and flagged as partial.
            emitEvent(mapOf("type" to "error", "errorType" to "SHIZUKU_DISCONNECTED", "message" to userMessage))
            emitEvent(
                mapOf(
                    "type" to "completed",
                    "cancelled" to true,
                    "reason" to "shizuku_lost",
                    "totalFiles" to lastFilesFound,
                    "errorCount" to lastErrors,
                ),
            )
        }
    }

    private var pendingStartScan = false
    private var lastFilesFound = 0
    private var lastErrors = 0

    /** Starts the advanced scan, binding the user service first when needed. */
    fun startAdvancedScan() {
        if (!isBinderAlive() || !isAuthorized()) {
            emitEvent(
                mapOf(
                    "type" to "error",
                    "errorType" to "SHIZUKU_NOT_READY",
                    "message" to "Shizuku is not ready. Make sure Shizuku is running and MediaRescue is authorized.",
                ),
            )
            return
        }
        val service = synchronized(stateLock) { userService }
        if (service != null) {
            beginScan(service)
            return
        }
        synchronized(stateLock) {
            pendingStartScan = true
            userServiceStarting.set(true)
        }
        emitStateChanged()
        try {
            Log.i(TAG, "binding Advanced Scanning user service")
            Shizuku.bindUserService(userServiceArgs, serviceConnection)
        } catch (t: Throwable) {
            synchronized(stateLock) {
                pendingStartScan = false
                userServiceStarting.set(false)
            }
            Log.w(TAG, "bindUserService failed: ${t.javaClass.simpleName}: ${t.message}")
            emitEvent(mapOf("type" to "error", "errorType" to "SERVICE_START_FAILED", "message" to "Could not start the Advanced Scanning service. Make sure Shizuku is running."))
            emitStateChanged()
        }
    }

    private fun tryStartPendingScan() {
        val service = synchronized(stateLock) {
            if (!pendingStartScan || !userServiceConnected.get()) return
            pendingStartScan = false
            userService
        } ?: return
        beginScan(service)
    }

    private fun beginScan(service: IAdvancedScanner) {
        val callback = AdvancedScannerCallback(this)
        synchronized(stateLock) {
            activeScanCallback = callback
            lastFilesFound = 0
            lastErrors = 0
        }
        emitEvent(mapOf("type" to "scan", "status" to "started"))
        try {
            val code = service.startScan(callback)
            if (code != START_STARTED) {
                synchronized(stateLock) { activeScanCallback = null }
                emitEvent(
                    mapOf(
                        "type" to "error",
                        "errorType" to "SCAN_START_FAILED",
                        "message" to when (code) {
                            START_ALREADY_RUNNING -> "A scan is already running."
                            else -> "The scan could not be started."
                        },
                    ),
                )
            }
        } catch (e: RemoteException) {
            synchronized(stateLock) { activeScanCallback = null }
            Log.w(TAG, "startScan IPC failed: ${e.message}")
            emitEvent(mapOf("type" to "error", "errorType" to "IPC_ERROR", "message" to "Shizuku connection was lost. Please restart Shizuku and try again."))
        }
    }

    /** Cancels the active scan (safe no-op when nothing is running). */
    fun stopAdvancedScan() {
        val service = synchronized(stateLock) { userService } ?: return
        try {
            service.requestCancel()
        } catch (e: RemoteException) {
            Log.w(TAG, "requestCancel IPC failed: ${e.message}")
        }
    }

    /** Copies an approved scan result through the privileged user service. */
    fun copyAdvancedFile(sourcePath: String, destinationPath: String, overwrite: Boolean): Boolean {
        if (!isBinderAlive() || !isAuthorized()) return false
        val service = synchronized(stateLock) { userService } ?: return false
        return try {
            service.copyFile(sourcePath, destinationPath, overwrite)
        } catch (e: RemoteException) {
            Log.w(TAG, "copyFile IPC failed: ${e.javaClass.simpleName}: ${e.message}")
            false
        }
    }

    // ── Event plumbing (main-thread delivery to the EventSink) ────────────────

    private val mainHandler = Handler(Looper.getMainLooper())

    private fun emitEvent(event: Map<String, Any>) {
        mainHandler.post { eventSink?.send(event) }
    }

    private fun emitStateChanged() {
        mainHandler.post { eventSink?.send(mapOf("type" to "state")) }
    }

    internal fun onCallbackEvent(event: Map<String, Any>) = emitEvent(event)

    internal fun onScanProgress(filesFound: Int, errors: Int) {
        synchronized(stateLock) {
            lastFilesFound = filesFound
            lastErrors = errors
        }
    }

    internal fun snapshotCounts(): IntArray = synchronized(stateLock) {
        intArrayOf(lastFilesFound, lastErrors)
    }

    internal fun onScanFinished() {
        synchronized(stateLock) { activeScanCallback = null }
        emitStateChanged()
    }
}

/**
 * App-side binder stub receiving progress and results from the MediaRescue
 * user service running under Shizuku. Callback methods arrive on binder
 * threads; everything is re-posted to the main thread before it reaches
 * Flutter (the EventSink is main-thread only).
 */
private class AdvancedScannerCallback(private val manager: ShizukuManager) :
    IAdvancedScannerCallback.Stub() {

    override fun onRootStatus(rootIndex: Int, status: Int, message: String?) {
        manager.onCallbackEvent(
            mapOf(
                "type" to "rootStatus",
                "rootIndex" to rootIndex,
                "status" to status,
                "message" to (message ?: ""),
            ),
        )
    }

    override fun onProgress(rootIndex: Int, filesFound: Int, errors: Int, currentPath: String?) {
        manager.onScanProgress(filesFound, errors)
        manager.onCallbackEvent(
            mapOf(
                "type" to "progress",
                "rootIndex" to rootIndex,
                "filesFound" to filesFound,
                "errors" to errors,
                "currentPath" to (currentPath ?: ""),
            ),
        )
    }

    override fun onBatch(rootIndex: Int, entries: Array<out String>?) {
        if (entries == null || entries.isEmpty()) return
        manager.onCallbackEvent(
            mapOf("type" to "batch", "rootIndex" to rootIndex, "entries" to entries.toList()),
        )
    }

    override fun onRootComplete(rootIndex: Int, filesFound: Int, errors: Int, message: String?) {
        manager.onCallbackEvent(
            mapOf(
                "type" to "rootComplete",
                "rootIndex" to rootIndex,
                "filesFound" to filesFound,
                "errors" to errors,
                "message" to (message ?: ""),
            ),
        )
    }

    override fun onScanComplete(totalFiles: Int, totalErrors: Int) {
        manager.onScanProgress(totalFiles, totalErrors)
        manager.onScanFinished()
        manager.onCallbackEvent(
            mapOf(
                "type" to "completed",
                "cancelled" to false,
                "totalFiles" to totalFiles,
                "errorCount" to totalErrors,
            ),
        )
    }

    override fun onCancelled(rootIndex: Int, filesFound: Int, errors: Int) {
        manager.onScanFinished()
        manager.onCallbackEvent(
            mapOf(
                "type" to "completed",
                "cancelled" to true,
                "totalFiles" to filesFound,
                "errorCount" to errors,
            ),
        )
    }

    override fun onScanError(code: Int, message: String?) {
        manager.onScanFinished()
        val counts = manager.snapshotCounts()
        manager.onCallbackEvent(
            mapOf("type" to "error", "errorType" to "SCAN_ERROR", "code" to code, "message" to (message ?: "The scan failed.")),
        )
        manager.onCallbackEvent(
            mapOf(
                "type" to "completed",
                "cancelled" to false,
                "failed" to true,
                "totalFiles" to counts[0],
                "errorCount" to counts[1],
            ),
                )
    }
}