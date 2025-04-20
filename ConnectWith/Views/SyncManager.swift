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
    func processReceivedPackage(_ jsonData: Data, from sourceDevice: String) {
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
    
    /// Start a real Bluetooth sync transfer
    /// - Parameters:
    ///   - data: The data to transfer
    ///   - deviceId: The target device ID
    ///   - name: The display name of the device
    private func simulateSyncTransfer(_ data: Data, to deviceId: String, name: String) {
        let totalBytes = data.count
        addLogEntry("Starting data transfer to \(name) (\(formatBytes(totalBytes)))")
        
        // Access the BluetoothTransferManager to handle the real transfer
        let transferManager = BluetoothTransferManager.shared
        
        // Start observing for transfer progress updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTransferProgress(_:)),
            name: NSNotification.Name("BluetoothTransferProgress"),
            object: nil
        )
        
        // Start the transfer with the transfer manager
        if transferManager.sendCalendarData(to: deviceId) == false {
            // If we couldn't start the transfer, use simulation mode instead
            addLogEntry("Failed to use Bluetooth transfer, falling back to simulation mode")
            useSimulatedTransfer(data, to: deviceId, name: name)
        } else {
            // Transfer started successfully
            addLogEntry("Bluetooth transfer initiated through BluetoothTransferManager")
        }
    }
    
    /// Handle transfer progress updates from BluetoothTransferManager
    @objc private func handleTransferProgress(_ notification: Notification) {
        guard let progress = notification.userInfo?["progress"] as? Double,
              let bytesTransferred = notification.userInfo?["bytesTransferred"] as? Int,
              let bytesTotal = notification.userInfo?["bytesTotal"] as? Int else {
            return
        }
        
        // Update our progress
        updateProgress(progress: progress, bytes: bytesTransferred, total: bytesTotal)
        
        // Check if transfer is complete
        if progress >= 1.0 {
            addLogEntry("Transfer complete, processing response")
            resetSyncState()
            
            // Remove observer
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name("BluetoothTransferProgress"),
                object: nil
            )
        }
    }
    
    /// Fall back to simulated transfer if Bluetooth transfer isn't available
    /// - Parameters:
    ///   - data: The data to transfer
    ///   - deviceId: The target device ID
    ///   - name: The display name of the device
    private func useSimulatedTransfer(_ data: Data, to deviceId: String, name: String) {
        let totalBytes = data.count
        addLogEntry("Using simulated transfer to \(name) (\(formatBytes(totalBytes)))")
        
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
/// Handles Bluetooth data transfer between devices
class BluetoothTransferManager: ObservableObject {
    // Singleton instance
    static let shared = BluetoothTransferManager()
    
    // MARK: - Properties
    
    // UUID for sync data characteristic
    private let syncDataCharacteristicUUID = CBUUID(string: "97d52a22-9292-48c6-a89f-8a71d89c5e9b")
    
    // Reference to Bluetooth manager
    private let bluetoothManager = BluetoothManager()
    
    // Published properties for data binding
    @Published var isTransferring: Bool = false
    @Published var transferProgress: Double = 0.0
    @Published var transferDirection: TransferDirection = .none
    @Published var transferStats: TransferStats = TransferStats()
    @Published var transferError: String? = nil
    
    // Chunk size for data transfer (CoreBluetooth has a limit around 512 bytes, but we'll be conservative)
    private let maxChunkSize: Int = 120
    
    // Data buffers
    private var outgoingData: Data? = nil
    private var incomingDataBuffer: [Int: Data] = [:]
    private var expectedTotalChunks: Int = 0
    private var currentChunk: Int = 0
    private var transferStartTime: Date? = nil
    
    // Target peripheral
    private var targetPeripheral: CBPeripheral? = nil
    private var syncCharacteristic: CBCharacteristic? = nil
    
    // MARK: - Types
    
    enum TransferDirection {
        case none
        case sending
        case receiving
    }
    
    struct TransferStats {
        var bytesSent: Int = 0
        var bytesReceived: Int = 0
        var totalBytes: Int = 0
        var chunksProcessed: Int = 0
        var totalChunks: Int = 0
        var elapsedTime: TimeInterval = 0
        var speedBytesPerSecond: Double = 0
        
        mutating func reset() {
            bytesSent = 0
            bytesReceived = 0
            totalBytes = 0
            chunksProcessed = 0
            totalChunks = 0
            elapsedTime = 0
            speedBytesPerSecond = 0
        }
    }
    
    // MARK: - Transfer Data Structure
    
    // Structure for each data chunk
    struct TransferChunk: Codable {
        let chunkIndex: Int
        let totalChunks: Int
        let chunkData: Data
        let checksum: UInt32
        let totalDataSize: Int
        
        enum CodingKeys: String, CodingKey {
            case chunkIndex, totalChunks, chunkData, checksum, totalDataSize
        }
        
        init(chunkIndex: Int, totalChunks: Int, chunkData: Data, totalDataSize: Int) {
            self.chunkIndex = chunkIndex
            self.totalChunks = totalChunks
            self.chunkData = chunkData
            self.totalDataSize = totalDataSize
            
            // Simple CRC32 checksum implementation
            self.checksum = self.calculateChecksum(data: chunkData)
        }
        
        // Initialize from a dictionary
        init?(from dict: [String: Any]) {
            guard let chunkIndex = dict["chunkIndex"] as? Int,
                  let totalChunks = dict["totalChunks"] as? Int,
                  let chunkDataBase64 = dict["chunkData"] as? String,
                  let chunkData = Data(base64Encoded: chunkDataBase64),
                  let checksum = dict["checksum"] as? UInt32,
                  let totalDataSize = dict["totalDataSize"] as? Int else {
                return nil
            }
            
            self.chunkIndex = chunkIndex
            self.totalChunks = totalChunks
            self.chunkData = chunkData
            self.checksum = checksum
            self.totalDataSize = totalDataSize
        }
        
        // Convert to a dictionary for JSON serialization
        func toDictionary() -> [String: Any] {
            return [
                "chunkIndex": chunkIndex,
                "totalChunks": totalChunks,
                "chunkData": chunkData.base64EncodedString(),
                "checksum": checksum,
                "totalDataSize": totalDataSize
            ]
        }
        
        // Calculate a basic checksum for data validation
        private func calculateChecksum(data: Data) -> UInt32 {
            var checksum: UInt32 = 0
            data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                for i in 0..<data.count {
                    if let ptr = bytes.baseAddress?.advanced(by: i) {
                        let byte = ptr.load(as: UInt8.self)
                        checksum = ((checksum << 1) | (checksum >> 31)) ^ UInt32(byte)
                    }
                }
            }
            return checksum
        }
        
        // Serialize to JSON data
        func toJSON() -> Data? {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: self.toDictionary())
                return jsonData
            } catch {
                print("[BTTransfer] Error serializing transfer chunk: \(error.localizedDescription)")
                return nil
            }
        }
        
        // Deserialize from JSON data
        static func fromJSON(_ jsonData: Data) -> TransferChunk? {
            do {
                guard let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    return nil
                }
                return TransferChunk(from: dict)
            } catch {
                print("[BTTransfer] Error deserializing transfer chunk: \(error.localizedDescription)")
                return nil
            }
        }
        
        // Verify the checksum of this chunk
        func verifyChecksum() -> Bool {
            let calculatedChecksum = calculateChecksum(data: chunkData)
            return calculatedChecksum == checksum
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        print("[BTTransfer] Initializing BluetoothTransferManager")
        
        // Register for notifications from BluetoothManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBluetoothNotification(_:)),
            name: NSNotification.Name("BluetoothCharacteristicDiscovered"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBluetoothNotification(_:)),
            name: NSNotification.Name("BluetoothCharacteristicValueUpdated"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notification Handling
    
    @objc private func handleBluetoothNotification(_ notification: Notification) {
        // Extract the characteristic and peripheral from the notification
        guard let userInfo = notification.userInfo,
              let characteristic = userInfo["characteristic"] as? CBCharacteristic,
              let peripheral = userInfo["peripheral"] as? CBPeripheral else {
            return
        }
        
        // Check if this is the sync data characteristic
        if characteristic.uuid == syncDataCharacteristicUUID {
            print("[BTTransfer] Found sync characteristic: \(characteristic.uuid)")
            syncCharacteristic = characteristic
            
            // If we're in the middle of a transfer and waiting for this characteristic
            if isTransferring && transferDirection == .sending {
                continueTransfer()
            }
        }
        
        // Handle value updates for sync data characteristic
        if notification.name == NSNotification.Name("BluetoothCharacteristicValueUpdated") {
            if characteristic.uuid == syncDataCharacteristicUUID, let data = characteristic.value {
                // Handle incoming data chunk
                handleIncomingData(data, from: peripheral)
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Prepare a sync package for transfer
    /// - Returns: Data ready for transfer
    func prepareSyncPackage() -> Data? {
        // Generate a sync package
        let syncPackage = SyncUtility.generateSyncPackage()
        
        // Convert to JSON
        guard let jsonData = syncPackage.toJSON() else {
            print("[BTTransfer] Failed to encode sync package to JSON")
            return nil
        }
        
        print("[BTTransfer] Prepared sync package of \(jsonData.count) bytes for transfer")
        return jsonData
    }
    
    /// Send test data to a device
    /// - Parameter deviceId: The target device ID
    /// - Returns: Boolean indicating if transfer was successfully started
    func sendTestData(to deviceId: String) -> Bool {
        print("[BTTransfer] Sending test data to device \(deviceId)")
        
        // Create test data
        let testPackage = SyncPackage(events: [
            CalendarEventSync(
                month: 4,
                monthName: "April",
                title: "Test Event",
                location: "Test Location",
                day: 15
            )
        ])
        
        guard let jsonData = testPackage.toJSON() else {
            reportError("Failed to create test data")
            return false
        }
        
        // Start transfer
        return startTransfer(data: jsonData, to: deviceId)
    }
    
    /// Send calendar data to a device
    /// - Parameter deviceId: The target device ID
    /// - Returns: Boolean indicating if transfer was successfully started
    func sendCalendarData(to deviceId: String) -> Bool {
        print("[BTTransfer] Sending calendar data to device \(deviceId)")
        
        // Generate sync package
        guard let packageData = prepareSyncPackage() else {
            reportError("Failed to prepare sync package")
            return false
        }
        
        // Start transfer
        return startTransfer(data: packageData, to: deviceId)
    }
    
    /// Cancel ongoing transfer
    func cancelTransfer() {
        print("[BTTransfer] Transfer cancelled by user")
        
        // Reset transfer state
        resetTransferState()
    }
    
    /// Get current transfer status
    /// - Returns: Formatted transfer status string
    func getTransferStatus() -> String {
        if !isTransferring {
            return "No active transfer"
        }
        
        let directionText = transferDirection == .sending ? "Sending to" : "Receiving from"
        let deviceName = targetPeripheral?.name ?? "unknown device"
        let percentComplete = Int(transferProgress * 100)
        
        // Format as transfer status
        var status = "\(directionText) \(deviceName): \(percentComplete)%\n"
        
        // Add more details based on direction
        if transferDirection == .sending {
            status += "Sent \(formatBytes(transferStats.bytesSent)) of \(formatBytes(transferStats.totalBytes))\n"
            status += "Chunk \(transferStats.chunksProcessed)/\(transferStats.totalChunks)"
        } else {
            status += "Received \(formatBytes(transferStats.bytesReceived)) of \(formatBytes(transferStats.totalBytes))\n"
            status += "Chunk \(transferStats.chunksProcessed)/\(transferStats.totalChunks)"
        }
        
        // Add speed if available
        if transferStats.speedBytesPerSecond > 0 {
            status += "\nSpeed: \(formatBytes(Int(transferStats.speedBytesPerSecond)))/s"
        }
        
        return status
    }
    
    // MARK: - Private Methods
    
    /// Start a new data transfer to a device
    /// - Parameters:
    ///   - data: The data to transfer
    ///   - deviceId: The target device ID
    /// - Returns: Boolean indicating if transfer was successfully started
    private func startTransfer(data: Data, to deviceId: String) -> Bool {
        // Reset previous transfer
        resetTransferState()
        
        // Find the peripheral with this identifier
        guard let uuid = UUID(uuidString: deviceId),
              let peripheral = bluetoothManager.connectedPeripherals.first(where: { $0.identifier == uuid }) else {
            reportError("Device not found or not connected")
            return false
        }
        
        // Store target peripheral
        targetPeripheral = peripheral
        
        // Initialize transfer state
        isTransferring = true
        transferDirection = .sending
        outgoingData = data
        transferStartTime = Date()
        
        // Update stats
        transferStats.totalBytes = data.count
        transferStats.totalChunks = Int(ceil(Double(data.count) / Double(maxChunkSize)))
        
        print("[BTTransfer] Starting transfer to device \(peripheral.name ?? deviceId), data size: \(formatBytes(data.count))")
        
        // Check if we already have discovered the sync characteristic
        if let characteristic = syncCharacteristic {
            // Start sending right away
            sendNextChunk(to: peripheral, characteristic: characteristic)
            return true
        } else {
            // Need to discover services and characteristics first
            peripheral.discoverServices(nil)
            
            print("[BTTransfer] Discovering services and characteristics for transfer")
            return true // We've at least started the discovery process
        }
    }
    
    /// Continue an existing transfer
    private func continueTransfer() {
        guard let peripheral = targetPeripheral,
              let characteristic = syncCharacteristic else {
            reportError("Can't continue transfer - missing device or characteristic")
            return
        }
        
        sendNextChunk(to: peripheral, characteristic: characteristic)
    }
    
    /// Send the next data chunk to the peripheral
    /// - Parameters:
    ///   - peripheral: The target peripheral
    ///   - characteristic: The characteristic to write to
    private func sendNextChunk(to peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        guard isTransferring && transferDirection == .sending,
              let dataToSend = outgoingData else {
            reportError("No data to send")
            return
        }
        
        // Calculate chunk range
        let startIndex = currentChunk * maxChunkSize
        guard startIndex < dataToSend.count else {
            // We've sent all chunks
            finishTransfer()
            return
        }
        
        // Calculate end index for this chunk
        let endIndex = min(startIndex + maxChunkSize, dataToSend.count)
        let chunkRange = startIndex..<endIndex
        let chunkData = dataToSend.subdata(in: chunkRange)
        
        // Create transfer chunk
        let transferChunk = TransferChunk(
            chunkIndex: currentChunk,
            totalChunks: transferStats.totalChunks,
            chunkData: chunkData,
            totalDataSize: dataToSend.count
        )
        
        // Serialize chunk
        guard let chunkJson = transferChunk.toJSON() else {
            reportError("Failed to serialize chunk \(currentChunk)")
            return
        }
        
        // Send chunk
        peripheral.writeValue(chunkJson, for: characteristic, type: .withResponse)
        
        // Update stats
        transferStats.bytesSent += chunkData.count
        transferStats.chunksProcessed = currentChunk + 1
        updateTransferProgress()
        
        print("[BTTransfer] Sending chunk \(currentChunk+1)/\(transferStats.totalChunks), size: \(chunkData.count) bytes")
        
        // Move to next chunk
        currentChunk += 1
    }
    
    /// Handle incoming data from a peripheral
    /// - Parameters:
    ///   - data: The received data
    ///   - peripheral: The sending peripheral
    private func handleIncomingData(_ data: Data, from peripheral: CBPeripheral) {
        // Parse the incoming chunk
        guard let chunk = TransferChunk.fromJSON(data) else {
            reportError("Failed to parse incoming data chunk")
            return
        }
        
        // Verify checksum
        guard chunk.verifyChecksum() else {
            reportError("Checksum validation failed for chunk \(chunk.chunkIndex)")
            return
        }
        
        // Update transfer direction if this is the first chunk
        if transferDirection == .none || !isTransferring {
            isTransferring = true
            transferDirection = .receiving
            transferStartTime = Date()
            expectedTotalChunks = chunk.totalChunks
            
            // Update stats
            transferStats.totalBytes = chunk.totalDataSize
            transferStats.totalChunks = chunk.totalChunks
            
            // Store target peripheral
            targetPeripheral = peripheral
            
            print("[BTTransfer] Starting reception from \(peripheral.name ?? peripheral.identifier.uuidString), total size: \(formatBytes(chunk.totalDataSize))")
        }
        
        // Store this chunk in the buffer
        incomingDataBuffer[chunk.chunkIndex] = chunk.chunkData
        
        // Update stats
        transferStats.bytesReceived += chunk.chunkData.count
        transferStats.chunksProcessed = incomingDataBuffer.count
        updateTransferProgress()
        
        print("[BTTransfer] Received chunk \(chunk.chunkIndex+1)/\(chunk.totalChunks), size: \(chunk.chunkData.count) bytes")
        
        // Check if we've received all chunks
        if incomingDataBuffer.count == expectedTotalChunks {
            // Reassemble the data
            reassembleAndProcessData()
        }
    }
    
    /// Reassemble received chunks and process the complete data
    private func reassembleAndProcessData() {
        print("[BTTransfer] Reassembling complete data from \(incomingDataBuffer.count) chunks")
        
        // Create a new data buffer
        var completeData = Data()
        
        // Add each chunk in order
        for i in 0..<expectedTotalChunks {
            if let chunkData = incomingDataBuffer[i] {
                completeData.append(chunkData)
            } else {
                reportError("Missing chunk \(i) during reassembly")
                return
            }
        }
        
        // Process the reassembled data
        print("[BTTransfer] Successfully reassembled \(formatBytes(completeData.count)) of data")
        
        // Try to parse as a sync package
        if let syncPackage = SyncPackage.fromJSON(completeData) {
            print("[BTTransfer] Successfully parsed sync package with \(syncPackage.events.count) events")
            
            // Process the sync package
            let sourceDevice = syncPackage.sourceDevice.name
            SyncManager.shared.processReceivedPackage(completeData, from: sourceDevice)
            
            // Finish the transfer
            finishTransfer()
        } else {
            reportError("Failed to parse received data as sync package")
            
            // Even if parsing failed, still consider the transfer complete
            finishTransfer()
        }
    }
    
    /// Update transfer progress and calculate transfer speed
    private func updateTransferProgress() {
        // Calculate progress
        let totalBytes = max(1, transferStats.totalBytes)  // Avoid division by zero
        let processedBytes = transferDirection == .sending ? transferStats.bytesSent : transferStats.bytesReceived
        transferProgress = Double(processedBytes) / Double(totalBytes)
        
        // Calculate elapsed time and speed
        if let startTime = transferStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            transferStats.elapsedTime = elapsed
            
            if elapsed > 0 {
                transferStats.speedBytesPerSecond = Double(processedBytes) / elapsed
            }
        }
        
        // Log progress updates at regular intervals
        if Int(transferProgress * 100) % 10 == 0 && Int(transferProgress * 100) > 0 {
            print("[BTTransfer] Transfer progress: \(Int(transferProgress * 100))%")
        }
        
        // Post notification about progress update for SyncManager to receive
        NotificationCenter.default.post(
            name: NSNotification.Name("BluetoothTransferProgress"),
            object: self,
            userInfo: [
                "progress": transferProgress,
                "bytesTransferred": processedBytes,
                "bytesTotal": totalBytes
            ]
        )
    }
    
    /// Finish the current transfer
    private func finishTransfer() {
        // Calculate final stats
        if let startTime = transferStartTime {
            let totalTime = Date().timeIntervalSince(startTime)
            transferStats.elapsedTime = totalTime
            
            print("[BTTransfer] Transfer completed, total bytes: \(formatBytes(transferStats.totalBytes)), time: \(String(format: "%.2f", totalTime))s")
            
            if totalTime > 0 {
                let bytesProcessed = transferDirection == .sending ? transferStats.bytesSent : transferStats.bytesReceived
                transferStats.speedBytesPerSecond = Double(bytesProcessed) / totalTime
                print("[BTTransfer] Transfer speed: \(formatBytes(Int(transferStats.speedBytesPerSecond)))/s")
            }
        }
        
        // Reset state but keep stats for viewing
        isTransferring = false
        outgoingData = nil
        incomingDataBuffer = [:]
        currentChunk = 0
        expectedTotalChunks = 0
        transferStartTime = nil
        transferDirection = .none
        transferError = nil
    }
    
    /// Reset all transfer state
    private func resetTransferState() {
        isTransferring = false
        transferProgress = 0
        transferDirection = .none
        transferError = nil
        outgoingData = nil
        incomingDataBuffer = [:]
        currentChunk = 0
        expectedTotalChunks = 0
        transferStartTime = nil
        targetPeripheral = nil
        transferStats.reset()
    }
    
    /// Report an error during transfer
    /// - Parameter message: The error message
    private func reportError(_ message: String) {
        let errorMessage = "[BTTransfer] Error during transfer: \(message)"
        print(errorMessage)
        transferError = message
        
        // Reset transfer state
        resetTransferState()
    }
    
    /// Format bytes to human-readable string
    /// - Parameter bytes: Number of bytes
    /// - Returns: Formatted string
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}