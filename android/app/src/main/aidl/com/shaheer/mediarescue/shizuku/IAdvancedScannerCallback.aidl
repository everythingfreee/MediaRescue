// IAdvancedScannerCallback.aidl
//
// Progress callbacks delivered from the MediaRescueUserService (the process
// running under Shizuku) back to the MediaRescue app process.
//
// All methods are oneway so the privileged user-service process never blocks
// waiting on the app. Keep this interface narrow: it ONLY carries the events
// Advanced Scanning needs.
package com.shaheer.mediarescue.shizuku;

oneway interface IAdvancedScannerCallback {

    // Status of a scan root before/at scan start.
    // status: 0 = ROOT_OK, 1 = ROOT_MISSING, 2 = ROOT_NOT_DIRECTORY,
    //         3 = ROOT_INACCESSIBLE, 4 = ROOT_INVALID
    void onRootStatus(int rootIndex, int status, String message);

    // Periodic progress while a root is traversed (throttled by the service).
    void onProgress(int rootIndex, int filesFound, int errors, String currentPath);

    // Batch of scanned entries serialized as compact JSON strings
    // (bounded size, e.g. 200 entries per batch).
    void onBatch(int rootIndex, in String[] entries);

    // A single root finished (either fully scanned, or immediately because it
    // was missing / inaccessible). An inaccessible root is reported here with
    // 0 files — never silently treated as an empty directory.
    void onRootComplete(int rootIndex, int filesFound, int errors, String message);

    // Both approved roots finished.
    void onScanComplete(int totalFiles, int totalErrors);

    // The active scan was cancelled by the user / client.
    void onCancelled(int rootIndex, int filesFound, int errors);

    // The scan failed at the scan level (code + human-readable message).
    void onScanError(int code, String message);
}