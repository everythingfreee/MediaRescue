// IAdvancedScanner.aidl
//
// The deliberately narrow interface exposed by the MediaRescue User Service.
// The user service runs inside the Shizuku execution context and is therefore
// treated as privileged code.
//
// SECURITY RULES:
//  - The scan roots are fixed and hard-coded inside the user service:
//        rootIndex 0 -> /storage/emulated/0/Android/data
//        rootIndex 1 -> /storage/emulated/0/Android/obb
//    No path strings are ever accepted from the caller, so nothing outside
//    those two roots can be requested.
//  - File copying is limited to an approved source and a shared-storage
//    destination. There is no delete / rename / execute / install API.
//  - There is no "executeCommand" or "readArbitraryPath".
package com.shaheer.mediarescue.shizuku;

import com.shaheer.mediarescue.shizuku.IAdvancedScannerCallback;

interface IAdvancedScanner {

    // Reserved Shizuku destroy method. Shizuku calls this when the user
    // service must be torn down (version change, unbind, Shizuku restart).
    void destroy() = 16777114;

    // Cancels the currently running scan (non-blocking). Traversal stops at
    // the next safe check point and the callback reports onCancelled().
    void requestCancel() = 1;

    // Checks whether an approved scan root exists and is readable.
    // Returns one of the ROOT_* status codes (see IAdvancedScannerCallback).
    int checkRoot(int rootIndex) = 2;

    // Starts a read-only recursive scan of the two approved roots
    // (Android/data first, then Android/obb). Returns a START_* code:
    //   0 = STARTED, 1 = ALREADY_RUNNING, 2 = INVALID_CALLBACK, 3 = INTERNAL_ERROR
    // Progress/status are delivered through the callback.
    int startScan(IAdvancedScannerCallback callback) = 3;

    // Copies one approved source file to an exact shared-storage destination.
    // The service validates both paths and verifies the copied byte length.
    boolean copyFile(String sourcePath, String destinationPath, boolean overwrite) = 5;

    // Terminates the user-service process.
    void exit() = 4;
}