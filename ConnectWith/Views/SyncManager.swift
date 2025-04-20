import Foundation
import CoreBluetooth
import SwiftUI
import Combine

/// SyncManager - Handles calendar data synchronization between devices
class SyncManager: ObservableObject {
    // Singleton instance
    static let shared = SyncManager()
    
    // Published properties to track sync state
    @Published var isSyncing: Bool = false
    @Published var syncProgress: Double = 0.0
    @Published var bytesTransferred: Int = 0
    @Published var bytesTotal: Int = 0
    @Published var syncLog: [String] = []
    @Published var currentSyncDevice: String? = nil
    
    // Pending updates from sync operations
    @Published var pendingUpdates: [PendingUpdateInfo] = []
    
    // Private initialization
    private init() {
        print("[SyncManager] Initializing SyncManager")
    }
    
    // MARK: - Public Methods
    
    /// Start synchronization with the specified device
    /// - Parameters:
    ///   - deviceId: The identifier of the device to sync with
    ///   - displayName: The display name of the device
    func startSync(with deviceId: String, displayName: String) {
        print("[SyncData] Starting sync with device \(displayName) (\(deviceId))")
        
        // Clear previous sync state
        isSyncing = true
        syncProgress = 0.0
        bytesTransferred = 0
        bytesTotal = 0
        syncLog = []
        currentSyncDevice = deviceId
        
        // Log initial sync state
        addLogEntry("Initializing sync with \(displayName)...")
        
        // Generate sync package from local calendar data
        guard let syncPackage = generateSyncPackage() else {
            addLogEntry("Failed to generate sync package")
            cancelSync()
            return
        }
        
        // Simulated: Encode the package to estimate size
        guard let jsonData = syncPackage.toJSON() else {
            addLogEntry("Failed to encode sync package to JSON")
            cancelSync()
            return
        }
        
        // Set total bytes for progress tracking
        bytesTotal = jsonData.count
        addLogEntry("Prepared sync package (\(formatBytes(bytesTotal)))")
        
        // Placeholder for actual transfer - in a real implementation, 
        // we would send this package via Bluetooth
        simulateSyncTransfer(jsonData, to: deviceId, name: displayName)
    }
    
    /// Cancel ongoing synchronization
    func cancelSync() {
        guard isSyncing else { return }
        
        print("[SyncData] Cancelling sync with device \(currentSyncDevice ?? "unknown")")
        
        // Log cancellation
        addLogEntry("Sync cancelled by user")
        
        // Reset sync state
        resetSyncState()
    }
    
    /// Check if there is an active sync with the specified device
    /// - Parameter deviceId: The identifier of the device to check
    /// - Returns: True if syncing with the specified device
    func isSyncingWith(deviceId: String) -> Bool {
        return isSyncing && currentSyncDevice == deviceId
    }
    
    /// Accept a specific pending update
    /// - Parameter update: The update to accept
    func acceptUpdate(_ update: PendingUpdateInfo) {
        print("[SyncData] Accepting update: \(update.description)")
        
        // Apply the update to local calendar
        SyncUtility.applyUpdate(update)
        
        // Remove from pending updates
        if let index = pendingUpdates.firstIndex(where: { $0.id == update.id }) {
            pendingUpdates.remove(at: index)
        }
        
        // Log acceptance
        addLogEntry("Accepted update from \(update.sourceDevice): \(update.description)")
    }
    
    /// Reject a specific pending update
    /// - Parameter update: The update to reject
    func rejectUpdate(_ update: PendingUpdateInfo) {
        print("[SyncData] Rejecting update: \(update.description)")
        
        // Remove from pending updates
        if let index = pendingUpdates.firstIndex(where: { $0.id == update.id }) {
            pendingUpdates.remove(at: index)
        }
        
        // Log rejection
        addLogEntry("Rejected update from \(update.sourceDevice): \(update.description)")
    }
    
    // MARK: - Helper Methods
    
    /// Add a log entry with timestamp
    /// - Parameter message: The message to log
    func addLogEntry(_ message: String) {
        let timestamp = currentTimeString()
        let logEntry = "[\(timestamp)] \(message)"
        
        print("[SyncData] \(logEntry)")
        
        DispatchQueue.main.async {
            self.syncLog.append(logEntry)
        }
    }
    
    /// Update sync progress
    /// - Parameters:
    ///   - progress: The sync progress (0.0 to 1.0)
    ///   - bytes: The number of bytes transferred
    ///   - total: The total number of bytes to transfer
    func updateProgress(progress: Double, bytes: Int, total: Int) {
        DispatchQueue.main.async {
            self.syncProgress = min(max(progress, 0.0), 1.0)
            self.bytesTransferred = bytes
            self.bytesTotal = total
        }
    }
    
    /// Reset the sync state
    private func resetSyncState() {
        DispatchQueue.main.async {
            self.isSyncing = false
            self.currentSyncDevice = nil
        }
    }
    
    /// Get current time string for logs
    private func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
    
    /// Format bytes to a human-readable string
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - Calendar Data Sync
    
    /// Generate a sync package from local calendar data
    /// - Returns: A SyncPackage or nil if generation fails
    private func generateSyncPackage() -> SyncPackage? {
        addLogEntry("Generating sync package from calendar data")
        
        // Use the utility to create the package
        let syncPackage = SyncUtility.generateSyncPackage()
        
        // Validate the generated package
        guard syncPackage.isValid() else {
            addLogEntry("Generated an invalid sync package - aborting")
            return nil
        }
        
        addLogEntry("Successfully created sync package with \(syncPackage.events.count) events")
        return syncPackage
    }
    
    /// Process a received sync package
    /// - Parameters:
    ///   - jsonData: The JSON data containing the sync package
    ///   - sourceDevice: The name of the source device
    private func processReceivedPackage(_ jsonData: Data, from sourceDevice: String) {
        addLogEntry("Processing sync package from \(sourceDevice)")
        
        // Decode the package
        guard let syncPackage = SyncPackage.fromJSON(jsonData) else {
            addLogEntry("Failed to decode sync package - invalid format")
            return
        }
        
        // Validate the package
        guard syncPackage.isValid() else {
            addLogEntry("Received invalid sync package - rejecting")
            return
        }
        
        // Process the package to identify changes
        let updates = SyncUtility.processSyncPackage(syncPackage)
        
        if updates.isEmpty {
            addLogEntry("No changes detected in sync package")
        } else {
            addLogEntry("Identified \(updates.count) potential updates")
            
            // Add the updates to the pending list
            DispatchQueue.main.async {
                self.pendingUpdates.append(contentsOf: updates)
            }
        }
        
        addLogEntry("Sync completed successfully")
    }
    
    /// Simulate a sync transfer (for development/testing)
    /// - Parameters:
    ///   - data: The data to transfer
    ///   - deviceId: The target device ID
    ///   - name: The display name of the device
    private func simulateSyncTransfer(_ data: Data, to deviceId: String, name: String) {
        let totalBytes = data.count
        addLogEntry("Starting data transfer to \(name) (\(formatBytes(totalBytes)))")
        
        // Simulate transfer progress updates
        var transferredBytes = 0
        let chunkSize = max(totalBytes / 10, 1)
        
        // Create a timer to simulate transfer progress
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self, self.isSyncing else {
                timer.invalidate()
                return
            }
            
            // Simulate bytes transferred
            transferredBytes += chunkSize
            if transferredBytes > totalBytes {
                transferredBytes = totalBytes
            }
            
            // Calculate progress
            let progress = Double(transferredBytes) / Double(totalBytes)
            
            // Update progress
            self.updateProgress(progress: progress, bytes: transferredBytes, total: totalBytes)
            
            // Log progress periodically
            if transferredBytes % (chunkSize * 2) == 0 || transferredBytes == totalBytes {
                self.addLogEntry("Transferred \(self.formatBytes(transferredBytes)) of \(self.formatBytes(totalBytes))")
            }
            
            // Check if transfer is complete
            if transferredBytes >= totalBytes {
                timer.invalidate()
                
                // Simulate receiving the data back (in a real implementation, this would be a separate flow)
                self.addLogEntry("Transfer complete, processing response")
                
                // Simulate a small delay for processing
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Simulate that we received the same package back from the other device
                    self.processReceivedPackage(data, from: name)
                    
                    // Reset sync state after processing
                    self.resetSyncState()
                }
            }
        }
        
        // Start the timer
        timer.fire()
    }
}

// MARK: - Updates Storage
/// Handles storing pending updates from sync operations
class PendingUpdatesStore {
    static let shared = PendingUpdatesStore()
    
    // Published property for pending updates
    @Published var pendingUpdates: [PendingUpdateInfo] = []
    
    private init() {
        print("[SyncData] Initializing PendingUpdatesStore")
    }
    
    /// Add a new pending update
    /// - Parameter update: The update to add
    func addPendingUpdate(_ update: PendingUpdateInfo) {
        pendingUpdates.append(update)
        print("[SyncData] Added pending update: \(update.description)")
    }
    
    /// Remove a pending update
    /// - Parameter id: The ID of the update to remove
    func removePendingUpdate(id: UUID) {
        if let index = pendingUpdates.firstIndex(where: { $0.id == id }) {
            let update = pendingUpdates[index]
            pendingUpdates.remove(at: index)
            print("[SyncData] Removed pending update: \(update.description)")
        }
    }
    
    /// Get all pending updates
    /// - Returns: Array of pending updates
    func getAllPendingUpdates() -> [PendingUpdateInfo] {
        return pendingUpdates
    }
    
    /// Clear all pending updates
    func clearAllPendingUpdates() {
        pendingUpdates.removeAll()
        print("[SyncData] Cleared all pending updates")
    }
}

// MARK: - Bluetooth Transfer Manager
/// This class will be expanded in future tasks to handle actual Bluetooth transfers
class BluetoothTransferManager {
    static let shared = BluetoothTransferManager()
    
    private init() {
        print("[SyncData] Initializing BluetoothTransferManager")
    }
    
    /// Prepare a sync package for transfer
    /// - Returns: Data ready for transfer
    func prepareSyncPackage() -> Data? {
        // Generate a sync package
        let syncPackage = SyncUtility.generateSyncPackage()
        
        // Convert to JSON
        guard let jsonData = syncPackage.toJSON() else {
            print("[SyncData] Failed to encode sync package to JSON")
            return nil
        }
        
        print("[SyncData] Prepared sync package of \(jsonData.count) bytes for transfer")
        return jsonData
    }
    
    /// Send calendar data to a device (placeholder)
    /// - Parameter deviceId: The target device ID
    func sendCalendarData(to deviceId: String) {
        print("[SyncData] Would send calendar data to device \(deviceId)")
        
        // In future implementation, this will use CoreBluetooth to send data
        guard let packageData = prepareSyncPackage() else {
            print("[SyncData] Failed to prepare sync package")
            return
        }
        
        print("[SyncData] Ready to send \(packageData.count) bytes to \(deviceId)")
        // Actual transfer would happen here
    }
}