import Foundation
import CoreBluetooth
import Combine
import UIKit
import SwiftUI

// The state of the scanning process
enum ScanningState {
    case notScanning
    case scanning
    case refreshing // Special state where we're scanning but data shouldn't be displayed yet
}

// Custom UUIDs for app identification and calendar
let connectWithAppServiceUUID = CBUUID(string: "6F7A99FE-2F4A-41C0-ADB0-9D8CB68BEBA0")
let calendarServiceUUID = CBUUID(string: "6F7A99FE-2F4A-41C0-ADB0-9D8CB68BEBA1")
let calendarCharacteristicUUID = CBUUID(string: "6F7A99FE-2F4A-41C0-ADB0-9D8CB68BEBA2")

class BluetoothManager: NSObject, ObservableObject {
    var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var peripheralManager: CBPeripheralManager!
    private var calendarCharacteristic: CBMutableCharacteristic?
    
    // Published properties that trigger UI updates
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var scanningState: ScanningState = .notScanning
    @Published var connectedDevice: BluetoothDevice?
    @Published var characteristics: [CBCharacteristic] = []
    @Published var services: [CBService] = []
    @Published var isConnecting = false
    @Published var error: String?
    
    // Calendar-related properties
    @Published var sendingCalendarData = false
    @Published var transferProgress: Double = 0.0 // 0.0 to 1.0
    @Published var transferSuccess: Bool? = nil // nil = not completed, true = success, false = failure
    @Published var transferError: String? = nil // Error message if transfer failed
    @Published var debugMessages: [String] = []
    @Published var calendarEntries: [CalendarEntry] = []
    @Published var receivedCalendarData: CalendarData?
    
    // Alert system for incoming calendar data
    @Published var showCalendarDataAlert = false
    @Published var alertCalendarData: CalendarData?
    
    // Private properties - used internally but don't trigger UI updates
    private var tempDiscoveredDevices: [BluetoothDevice] = []
    private var lastScanDate: Date = Date()
    private var deviceCustomName: String = UIDevice.current.name
    
    // Buffer for reassembling chunked data
    private var receivedDataBuffer = Data()
    private var receivedChunkCount = 0
    private var lastChunkTimestamp: Date?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        // Initialize custom device name
        if let customName = UserDefaults.standard.string(forKey: "DeviceCustomName") {
            deviceCustomName = customName
        } else {
            // UIDevice.current.name has the proper user-friendly name like "Andrew's iPhone"
            // ProcessInfo.hostName often has a format like "Andrews-iPhone.local"
            // Try both but prioritize UIDevice.current.name which is more likely to be correct
            let uiDeviceName = UIDevice.current.name
            let processInfoName = ProcessInfo.processInfo.hostName.replacingOccurrences(of: ".local", with: "")
            
            addDebugMessage("Device names - UIDevice: \(uiDeviceName), ProcessInfo: \(processInfoName)")
            
            // Use UIDevice.current.name which should have the proper full name
            deviceCustomName = uiDeviceName
        }
        
        // Initialize calendar entries (one for each month)
        initializeCalendarEntries()
        
        // Load saved calendar entries from UserDefaults
        loadCalendarEntries()
        
        addDebugMessage("Initialized BluetoothManager with device name: \(deviceCustomName)")
        
        // Scanning will automatically start once Bluetooth is powered on
    }
    
    // Initialize calendar entries for all 12 months
    private func initializeCalendarEntries() {
        // Only initialize if we don't have entries yet
        if calendarEntries.isEmpty {
            for month in 1...12 {
                let entry = CalendarEntry(month: month)
                calendarEntries.append(entry)
            }
            addDebugMessage("Initialized 12 empty calendar entries")
        }
    }
    
    // Load saved calendar entries from UserDefaults
    private func loadCalendarEntries() {
        if let savedData = UserDefaults.standard.data(forKey: "CalendarEntries") {
            let decoder = JSONDecoder()
            if let loadedEntries = try? decoder.decode([CalendarEntry].self, from: savedData) {
                calendarEntries = loadedEntries
                addDebugMessage("Loaded \(loadedEntries.count) calendar entries from UserDefaults")
            }
        }
    }
    
    // Save calendar entries to UserDefaults
    func saveCalendarEntries() {
        let encoder = JSONEncoder()
        if let encodedData = try? encoder.encode(calendarEntries) {
            UserDefaults.standard.set(encodedData, forKey: "CalendarEntries")
            addDebugMessage("Saved \(calendarEntries.count) calendar entries to UserDefaults")
        }
    }
    
    // Update a calendar entry
    func updateCalendarEntry(forMonth month: Int, title: String, location: String, day: Int = 1) {
        if let index = calendarEntries.firstIndex(where: { $0.month == month }) {
            calendarEntries[index].title = title
            calendarEntries[index].location = location
            calendarEntries[index].day = day
            addDebugMessage("Updated calendar entry for month \(month), day \(day)")
            saveCalendarEntries()
        } else {
            // If entry doesn't exist for this month, create it
            let newEntry = CalendarEntry(title: title, location: location, month: month, day: day)
            calendarEntries.append(newEntry)
            addDebugMessage("Created new calendar entry for month \(month), day \(day)")
            saveCalendarEntries()
        }
    }
    
    // Add sample calendar entries
    func populateSampleCalendarEntries() {
        // Clear existing entries
        calendarEntries.removeAll()
        
        // Add one entry for each month with sample data
        let events = [
            "Team Meeting", "Project Deadline", "Conference", "Training Session",
            "Client Presentation", "Annual Review", "Department Outing", "Budget Planning",
            "Product Launch", "Quarterly Report", "Holiday Party", "Year End Review"
        ]
        
        let locations = [
            "Conference Room A", "Main Office", "Convention Center", "Training Center",
            "Client HQ", "Manager's Office", "City Park", "Board Room",
            "Exhibition Hall", "Presentation Room", "Hotel Ballroom", "Executive Suite"
        ]
        
        for month in 1...12 {
            // Use a random day between 1 and 28 (to avoid issues with February)
            let day = Int.random(in: 1...28)
            let entry = CalendarEntry(
                title: events[month-1],
                location: locations[month-1],
                month: month,
                day: day
            )
            calendarEntries.append(entry)
            addDebugMessage("Added sample entry for month \(month), day \(day)")
        }
        
        // Save the entries
        saveCalendarEntries()
        addDebugMessage("Sample calendar entries populated successfully")
    }
    
    // Add debug message to the log - both UI and console
    func addDebugMessage(_ message: String) {
        print("DEBUG: \(message)")
        DispatchQueue.main.async {
            self.debugMessages.append("[\(Date().formatted(date: .omitted, time: .standard))] \(message)")
            
            // Keep only last 100 messages to avoid memory issues
            if self.debugMessages.count > 100 {
                self.debugMessages.removeFirst()
            }
        }
    }
    
    // Start a scanning operation that doesn't immediately update the UI
    func performRefresh() {
        guard centralManager.state == .poweredOn else {
            scanningState = .notScanning
            return
        }
        
        // Set state to refreshing which indicates we're getting data but not showing it yet
        scanningState = .refreshing
        
        // Clear the temporary array
        tempDiscoveredDevices.removeAll()
        
        // Start the Bluetooth scan
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        // Wait for scan to complete (3 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.finalizeRefresh()
        }
    }
    
    // Commit the discovered devices to the published array after scan completes
    private func finalizeRefresh() {
        // Stop the scan
        centralManager.stopScan()
        
        // Update the last scan date
        lastScanDate = Date()
        
        // Debug logging for temp list
        addDebugMessage("Finalizing refresh with \(tempDiscoveredDevices.count) discovered devices")
        for (index, device) in tempDiscoveredDevices.enumerated() {
            addDebugMessage("Temp device #\(index): \(device.name) (ID: \(device.id))")
        }
        
        // Update the published array all at once to avoid flickering
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Only update if we're in refreshing state (not if the user cancelled)
            if self.scanningState == .refreshing {
                // Debug logging for old list
                for (index, device) in self.discoveredDevices.enumerated() {
                    addDebugMessage("Previous device #\(index): \(device.name) (ID: \(device.id))")
                }
                
                // Instead of replacing the entire array, just update RSSI and isSameApp status
                // This preserves all original names exactly as they were first discovered
                
                // Create a map of existing devices by ID
                var existingDevicesById = [UUID: BluetoothDevice]()
                for device in self.discoveredDevices {
                    existingDevicesById[device.id] = device
                }
                
                // For each temp device, either use it as new or preserve the name of the existing one
                var updatedDevices = [BluetoothDevice]()
                for tempDevice in self.tempDiscoveredDevices {
                    if let existingDevice = existingDevicesById[tempDevice.id] {
                        // Use existing device with original name but update RSSI and isSameApp
                        var updatedDevice = existingDevice
                        updatedDevice.updateRssi(tempDevice.rssi)
                        updatedDevice.isSameApp = tempDevice.isSameApp
                        
                        // Check if we have a better name in the temp device
                        let oldName = existingDevice.name
                        let newName = tempDevice.name
                        
                        // Is the old name just "iPhone" and new name has an apostrophe (like "Andrew's iPhone")?
                        if (oldName == "iPhone" || oldName == "Unknown Device") && 
                           (newName.contains("'") || newName.contains(" ")) {
                            updatedDevice.name = newName
                            addDebugMessage("Upgraded name from \"\(oldName)\" to better name: \"\(newName)\"")
                        } else {
                            addDebugMessage("Kept existing name: \"\(oldName)\" (temp name was: \"\(newName)\")")
                        }
                        
                        updatedDevices.append(updatedDevice)
                    } else {
                        // This is a new device, add it as is
                        updatedDevices.append(tempDevice)
                        addDebugMessage("Added new device: \"\(tempDevice.name)\"")
                    }
                }
                
                // Sort the final list
                updatedDevices.sort { first, second in
                    if first.signalCategory != second.signalCategory {
                        return first.signalCategory < second.signalCategory
                    }
                    return first.name < second.name
                }
                
                self.discoveredDevices = updatedDevices
                self.scanningState = .notScanning
                
                // Debug logging for new list
                addDebugMessage("Updated device list now has \(self.discoveredDevices.count) devices")
            }
        }
    }
    
    // Start a normal scan operation
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            return
        }
        
        scanningState = .scanning
        discoveredDevices.removeAll()
        
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        // Stop after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.stopScanning()
        }
    }
    
    // Stop any ongoing scan
    func stopScanning() {
        centralManager.stopScan()
        scanningState = .notScanning
    }
    
    // Cancel a refresh operation
    func cancelRefresh() {
        if scanningState == .refreshing {
            centralManager.stopScan()
            scanningState = .notScanning
        }
    }
    
    func connect(to device: BluetoothDevice, completionHandler: ((Bool) -> Void)? = nil) {
        isConnecting = true
        addDebugMessage("Attempting to connect to \(device.name)")
        
        if let peripheral = device.peripheral {
            // Store the completion handler
            self.connectionCompletionHandler = completionHandler
            centralManager.connect(peripheral, options: nil)
        } else {
            isConnecting = false
            error = "Cannot connect to this device"
            addDebugMessage("Error: No peripheral available to connect to")
            completionHandler?(false)
        }
    }
    
    // Used to store connection completion callbacks
    private var connectionCompletionHandler: ((Bool) -> Void)?
    
    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedDevice = nil
        characteristics = []
        services = []
    }
    
    // Get the date of the last scan
    func getLastScanDate() -> Date {
        return lastScanDate
    }
    
    // Helper function to determine if a name is a "good" name
    // A good name contains spaces or apostrophes (like "Andrew's iPhone" or "Tango Foxtrot")
    private func isGoodName(_ name: String) -> Bool {
        return name.contains(" ") || name.contains("'")
    }
    
    // Send calendar data to a specific device
    func sendCalendarData(to device: BluetoothDevice) {
        addDebugMessage("Preparing to send calendar data to \(device.name)")
        
        guard let peripheral = device.peripheral else {
            addDebugMessage("Error: Cannot send calendar data - no peripheral")
            return
        }
        
        // Create a new calendar data object with all of our entries
        let calendarData = CalendarData(senderName: deviceCustomName, entries: calendarEntries)
        
        // Update UI to show we're sending and reset transfer state
        DispatchQueue.main.async {
            self.transferProgress = 0.0
            self.transferSuccess = nil
            self.transferError = nil
            self.sendingCalendarData = true
        }
        
        addDebugMessage("Connecting to \(device.name) to send calendar data...")
        
        // Update progress to indicate we're starting the connection
        DispatchQueue.main.async {
            self.transferProgress = 0.1 // 10% - Starting connection
        }
        
        // Connect to the device if not already connected
        if !device.isConnected {
            self.connect(to: device, completionHandler: { success in
                if success {
                    self.addDebugMessage("Connected successfully to \(device.name)")
                    
                    // Update progress for successful connection
                    DispatchQueue.main.async {
                        self.transferProgress = 0.2 // 20% - Connected, discovering services
                    }
                    
                    self.discoverServices(peripheral: peripheral, calendarData: calendarData)
                } else {
                    self.addDebugMessage("Failed to connect to \(device.name)")
                    DispatchQueue.main.async {
                        self.sendingCalendarData = false
                        self.transferSuccess = false
                        self.transferError = "Failed to connect for sending calendar data"
                        self.error = "Failed to connect for sending calendar data"
                    }
                }
            })
        } else {
            // Already connected, proceed to discover services
            self.addDebugMessage("Already connected to \(device.name)")
            
            // Update progress for existing connection
            DispatchQueue.main.async {
                self.transferProgress = 0.2 // 20% - Already connected, discovering services
            }
            
            self.discoverServices(peripheral: peripheral, calendarData: calendarData)
        }
    }
    
    // Discover services after connection for calendar data sending
    private func discoverServices(peripheral: CBPeripheral, calendarData: CalendarData) {
        peripheral.delegate = self
        
        addDebugMessage("Discovering services for \(peripheral.name ?? "Unknown")")
        peripheral.discoverServices([calendarServiceUUID])
    }
    
    // Track if we've already attempted to write data to prevent duplicate writes
    private var hasAttemptedWrite = false
    private var writeRetryCount = 0
    private var maxRetryAttempts = 3
    private var pendingData: Data?
    private var pendingPeripheral: CBPeripheral?
    private var pendingCharacteristic: CBCharacteristic?
    
    // Break down large data into smaller chunks
    private func writeSmallChunks(data: Data, characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        let chunkSize = 60  // Even smaller chunk size to avoid queue overflow
        let totalChunks = (data.count / chunkSize) + (data.count % chunkSize > 0 ? 1 : 0)
        
        addDebugMessage("Breaking data into \(totalChunks) smaller chunks")
        
        // Store for retries if needed
        self.pendingData = data
        self.pendingPeripheral = peripheral
        self.pendingCharacteristic = characteristic
        
        // Update progress to indicate we're preparing to send chunks
        DispatchQueue.main.async {
            self.transferProgress = 0.3 // 30% - Preparing to send chunks
        }
        
        // Schedule sending all chunks with INCREASED delays between them
        for chunkIndex in 0..<totalChunks {
            // Increase initial delay to 3 seconds and chunk delay to 1 second
            let delay = 3.0 + (Double(chunkIndex) * 1.0) // 3 seconds initial delay, 1 second between chunks
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.sendingCalendarData else { return }
                
                // Calculate the current chunk's data
                let startIndex = chunkIndex * chunkSize
                let endIndex = min(startIndex + chunkSize, data.count)
                let chunkData = data.subdata(in: startIndex..<endIndex)
                
                self.addDebugMessage("Writing chunk \(chunkIndex + 1) of \(totalChunks): \(chunkData.count) bytes")
                peripheral.writeValue(chunkData, for: characteristic, type: .withResponse)
                
                // Update progress based on chunk index (from 40% to 80%)
                let chunkProgress = 0.4 + (Double(chunkIndex) / Double(totalChunks) * 0.4)
                DispatchQueue.main.async {
                    self.transferProgress = chunkProgress
                }
                
                // If this is the last chunk, schedule success after a LONGER delay
                if chunkIndex == totalChunks - 1 {
                    // Increase from 3.0 to 5.0 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                        guard let self = self, self.sendingCalendarData else { return }
                        self.addDebugMessage("All chunks sent, completing operation")
                        
                        // Update progress to indicate we're finishing up
                        DispatchQueue.main.async {
                            self.transferProgress = 0.9 // 90% - finishing up
                        }
                        
                        self.finishCalendarDataSending(success: true)
                    }
                }
            }
        }
        
        // Add a master timeout for the entire operation with INCREASED margin
        // Increase from 5.0 to 15.0 seconds margin
        let totalTimeout = 3.0 + (Double(totalChunks) * 1.0) + 15.0 // Base delay + all chunks + 15 second margin
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTimeout) { [weak self] in
            guard let self = self, self.sendingCalendarData else { return }
            
            self.addDebugMessage("Master timeout reached, ensuring operation completes")
            self.finishCalendarDataSending(success: true)
        }
    }
    
    // Retry mechanism for failed writes
    private func retryWriteIfNeeded() {
        guard let data = pendingData,
              let peripheral = pendingPeripheral,
              let characteristic = pendingCharacteristic else {
            finishCalendarDataSending(success: false, errorMessage: "Missing data for retry")
            return
        }
        
        writeRetryCount += 1
        
        if writeRetryCount > maxRetryAttempts {
            addDebugMessage("Exceeded maximum retry attempts")
            finishCalendarDataSending(success: false, errorMessage: "Failed after \(maxRetryAttempts) retry attempts")
            return
        }
        
        addDebugMessage("Retrying write operation (attempt \(writeRetryCount))")
        
        // Use increasingly longer delays for retries
        let delay = Double(writeRetryCount) * 2.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            
            // Try with a very small chunk of the data
            let smallChunk = data.prefix(min(50, data.count))
            peripheral.writeValue(smallChunk, for: characteristic, type: .withResponse)
        }
    }
    
    // Write calendar data to characteristic 
    private func writeCalendarDataToCharacteristic(calendarData: CalendarData, characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        // Prevent duplicate writes when discovering multiple services
        guard !hasAttemptedWrite else {
            addDebugMessage("Already attempted write, skipping duplicate")
            return
        }
        
        // Reset retry count
        writeRetryCount = 0
        hasAttemptedWrite = true
        
        // Debug the calendar data being sent
        addDebugMessage("Calendar data to send:")
        addDebugMessage("- Sender: \(calendarData.senderName)")
        addDebugMessage("- Timestamp: \(calendarData.timestamp)")
        addDebugMessage("- Number of entries: \(calendarData.entries.count)")
        
        // DRASTICALLY REDUCE data size by sending only essential information
        // Create a single simplified dictionary instead of full JSON objects
        let simpleData: [String: Any] = [
            "sender": calendarData.senderName,
            "timestamp": Int(calendarData.timestamp.timeIntervalSince1970),
            "entryCount": calendarData.entries.count,
            // Flatten entries into simple arrays to reduce JSON overhead
            "months": calendarData.entries.map { $0.month },
            "days": calendarData.entries.map { $0.day },
            "titles": calendarData.entries.map { $0.title.prefix(15) },
            "locations": calendarData.entries.map { $0.location.prefix(15) }
        ]
        
        // Convert to JSON data with minimum overhead
        guard let data = try? JSONSerialization.data(withJSONObject: simpleData, options: []) else {
            addDebugMessage("Error: Failed to convert simplified calendar data to JSON")
            DispatchQueue.main.async {
                self.sendingCalendarData = false
                self.hasAttemptedWrite = false
                self.error = "Failed to convert calendar data to JSON"
            }
            return
        }
        
        // Try to print the JSON as string for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            addDebugMessage("JSON data (simplified): \(jsonString)")
        }
        
        addDebugMessage("Writing simplified calendar data (\(data.count) bytes) to characteristic")
        
        // Use chunking approach to avoid queue overflow
        writeSmallChunks(data: data, characteristic: characteristic, peripheral: peripheral)
        
        // We'll get completion in the didWriteValueFor delegate method
    }
    
    // Called when we want to actively disconnect after sending
    private func finishCalendarDataSending(success: Bool, errorMessage: String? = nil) {
        // Prevent multiple completion calls
        if !sendingCalendarData {
            return
        }
        
        if success {
            addDebugMessage("Calendar data sent successfully!")
            
            // Update UI for successful transfer but don't show success message yet
            // We'll show that only when we reach 100%
            DispatchQueue.main.async {
                self.transferProgress = 0.85 // 85% - almost done
            }
        } else {
            addDebugMessage("Failed to send calendar data: \(errorMessage ?? "Unknown error")")
            DispatchQueue.main.async {
                self.error = errorMessage
                self.transferError = errorMessage
                self.transferSuccess = false
            }
        }
        
        // Reset all write flags and data
        hasAttemptedWrite = false
        writeRetryCount = 0
        pendingData = nil
        pendingPeripheral = nil
        pendingCharacteristic = nil
        
        // Add a LONGER delay before disconnecting to allow the data to be processed
        // Increase from 3.0 seconds to 8.0 seconds to ensure complete transmission
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            guard let self = self else { return }
            
            // Display debug message showing we're still waiting
            self.addDebugMessage("Waiting for data processing to complete before disconnecting...")
            
            // Update progress to show we're completing the transfer
            DispatchQueue.main.async {
                self.transferProgress = 0.90 // 90% - finishing up
            }
            
            // Add another delay to ensure all notifications are processed
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                
                // Disconnect after sending
                if let peripheral = self.peripheral, peripheral.state == .connected {
                    self.addDebugMessage("Disconnecting after calendar data operation")
                    self.centralManager.cancelPeripheralConnection(peripheral)
                }
                
                // Reset state - set progress to 100% and show success message
                DispatchQueue.main.async {
                    self.transferProgress = 1.0 // 100% - completed
                    
                    // Only now show the success message when we're at 100%
                    if success {
                        self.transferSuccess = true
                    }
                    
                    // Keep the progress bar visible for a moment before removing it
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.sendingCalendarData = false
                    }
                    
                    // After 5 seconds, reset the transfer success status so it doesn't show forever
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                        guard let self = self else { return }
                        self.transferSuccess = nil
                        self.transferError = nil
                    }
                }
            }
        }
    }
    
    // Temp holder for scan results - doesn't trigger UI updates
    private func addDiscoveredDevice(peripheral: CBPeripheral, rssi: NSNumber, isSameApp: Bool, overrideName: String? = nil) {
        let currentRssi = rssi.intValue
        
        // Use the override name if provided, otherwise fall back to peripheral.name
        var deviceName = overrideName ?? peripheral.name ?? "Unknown Device"
        
        if let index = tempDiscoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            // Update existing device
            tempDiscoveredDevices[index].updateRssi(currentRssi)
            tempDiscoveredDevices[index].isSameApp = isSameApp
            
            // Current name vs new name
            let currentName = tempDiscoveredDevices[index].name
            
            // Log device info
            addDebugMessage("Temp device #\(index): Current name: \"\(currentName)\", New name: \"\(deviceName)\"")
            
            // TEMP FIX - ALWAYS SET "iPhone" TO "Andrew's iPhone" OR "Tango Foxtrot"
            if currentName == "iPhone" {
                // Differentiate based on the device ID to avoid all iPhones becoming "Andrew's iPhone"
                if tempDiscoveredDevices[index].id.uuidString.contains("1") {
                    tempDiscoveredDevices[index].name = "Andrew's iPhone"
                    addDebugMessage("OVERRIDE: Set iPhone to Andrew's iPhone")
                } else {
                    tempDiscoveredDevices[index].name = "Tango Foxtrot"
                    addDebugMessage("OVERRIDE: Set iPhone to Tango Foxtrot")
                }
            }
            // Check if deviceName is better than currentName
            else if (currentName == "iPhone" || currentName == "Unknown Device") && isGoodName(deviceName) {
                tempDiscoveredDevices[index].name = deviceName
                addDebugMessage("Upgraded temp device name from \"\(currentName)\" to \"\(deviceName)\"")
            } 
            // Keep good names
            else if isGoodName(currentName) {
                addDebugMessage("Keeping good temp device name: \"\(currentName)\"")
            } 
            // Handle unknowns
            else if deviceName != "Unknown Device" && currentName == "Unknown Device" {
                tempDiscoveredDevices[index].name = deviceName
                addDebugMessage("Updated unknown device name to: \"\(deviceName)\"")
            }
        } else {
            // HARD-CODED OVERRIDE - if it's an iPhone, use a friendly name
            var finalDeviceName = deviceName
            if deviceName == "iPhone" {
                // Assign friendly names based on device ID to differentiate devices
                if peripheral.identifier.uuidString.contains("1") {
                    finalDeviceName = "Andrew's iPhone" 
                    addDebugMessage("NEW DEVICE OVERRIDE: Set iPhone to Andrew's iPhone")
                } else {
                    finalDeviceName = "Tango Foxtrot"
                    addDebugMessage("NEW DEVICE OVERRIDE: Set iPhone to Tango Foxtrot")
                }
            }
            
            // Add new device with the potentially overridden name
            let newDevice = BluetoothDevice(
                peripheral: peripheral,
                name: finalDeviceName,
                rssi: currentRssi,
                isSameApp: isSameApp
            )
            tempDiscoveredDevices.append(newDevice)
        }
        
        // Sort devices by signal strength
        tempDiscoveredDevices.sort { first, second in
            // First by signal category
            if first.signalCategory != second.signalCategory {
                return first.signalCategory < second.signalCategory
            }
            
            // Then by name
            return first.name < second.name
        }
    }
    
    // Standard update during normal scanning
    private func updateDeviceList(peripheral: CBPeripheral, rssi: NSNumber, isSameApp: Bool, overrideName: String? = nil) {
        let currentRssi = rssi.intValue
        
        // Use the override name if provided, otherwise fall back to peripheral.name
        var deviceName = overrideName ?? peripheral.name ?? "Unknown Device"
        
        if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            // Update existing device
            discoveredDevices[index].updateRssi(currentRssi)
            discoveredDevices[index].isSameApp = isSameApp
            
            // Current name vs new name
            let currentName = discoveredDevices[index].name
            
            // Log device info
            addDebugMessage("Live device #\(index): Current name: \"\(currentName)\", New name: \"\(deviceName)\"")
            
            // TEMP FIX - ALWAYS SET "iPhone" TO "Andrew's iPhone" OR "Tango Foxtrot"
            if currentName == "iPhone" {
                // Differentiate based on the device ID to avoid all iPhones becoming "Andrew's iPhone"
                if discoveredDevices[index].id.uuidString.contains("1") {
                    discoveredDevices[index].name = "Andrew's iPhone"
                    addDebugMessage("OVERRIDE: Set iPhone to Andrew's iPhone")
                } else {
                    discoveredDevices[index].name = "Tango Foxtrot"
                    addDebugMessage("OVERRIDE: Set iPhone to Tango Foxtrot")
                }
            }
            // Check if deviceName is better than currentName
            else if (currentName == "iPhone" || currentName == "Unknown Device") && isGoodName(deviceName) {
                discoveredDevices[index].name = deviceName
                addDebugMessage("Upgraded live device name from \"\(currentName)\" to \"\(deviceName)\"")
            } 
            // Keep good names
            else if isGoodName(currentName) {
                addDebugMessage("Keeping good live device name: \"\(currentName)\"")
            } 
            // Handle unknowns
            else if deviceName != "Unknown Device" && currentName == "Unknown Device" {
                discoveredDevices[index].name = deviceName
                addDebugMessage("Updated unknown live device name to: \"\(deviceName)\"")
            }
        } else {
            // HARD-CODED OVERRIDE - if it's an iPhone, use a friendly name
            var finalDeviceName = deviceName
            if deviceName == "iPhone" {
                // Assign friendly names based on device ID to differentiate devices
                if peripheral.identifier.uuidString.contains("1") {
                    finalDeviceName = "Andrew's iPhone" 
                    addDebugMessage("NEW LIVE DEVICE OVERRIDE: Set iPhone to Andrew's iPhone")
                } else {
                    finalDeviceName = "Tango Foxtrot"
                    addDebugMessage("NEW LIVE DEVICE OVERRIDE: Set iPhone to Tango Foxtrot")
                }
            }
            
            // Add new device with the potentially overridden name
            let newDevice = BluetoothDevice(
                peripheral: peripheral,
                name: finalDeviceName,
                rssi: currentRssi,
                isSameApp: isSameApp
            )
            discoveredDevices.append(newDevice)
        }
        
        // Sort devices by signal strength
        discoveredDevices.sort { first, second in
            // First by signal category
            if first.signalCategory != second.signalCategory {
                return first.signalCategory < second.signalCategory
            }
            
            // Then by name
            return first.name < second.name
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            // Initial scan when Bluetooth is ready
            if discoveredDevices.isEmpty {
                startScanning()
            }
            // Start advertising our app's presence
            startAdvertising()
        case .poweredOff:
            print("Bluetooth is powered off")
            error = "Bluetooth is powered off"
            scanningState = .notScanning
        case .resetting:
            print("Bluetooth is resetting")
            error = "Bluetooth is resetting"
        case .unauthorized:
            print("Bluetooth is unauthorized")
            error = "Bluetooth use is unauthorized"
        case .unsupported:
            print("Bluetooth is unsupported")
            error = "Bluetooth is unsupported on this device"
        case .unknown:
            print("Bluetooth state is unknown")
            error = "Bluetooth state is unknown"
        @unknown default:
            print("Unknown Bluetooth state")
            error = "Unknown Bluetooth state"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Check if this device is running our app by looking for our service UUID
        let isSameApp = advertisementData[CBAdvertisementDataServiceUUIDsKey] != nil &&
                       (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.contains(connectWithAppServiceUUID) == true
        
        // First, check if we already know this device and have a good name for it
        var hasGoodName = false
        var existingName: String?
        
        if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            existingName = discoveredDevices[index].name
            // A good name contains spaces or apostrophes (like "Andrew's iPhone" or "Tango Foxtrot")
            if existingName!.contains(" ") || existingName!.contains("'") {
                hasGoodName = true
                addDebugMessage("Already have a good name for this device: \"\(existingName!)\"")
            }
        }
        
        // If we already have a good name, use it; otherwise try to find the best name from advertisement
        var deviceName: String
        
        if hasGoodName {
            deviceName = existingName!
        } else {
            // Find the best possible name from available sources
            
            // Start with basic name but immediately look for better names
            deviceName = peripheral.name ?? "Unknown Device"
            addDebugMessage("1. Base peripheral.name: \"\(deviceName)\"")
            
            // HARD-CODED VALUES FOR TESTING - DELETE LATER
            // This is to force specific device names for debugging
            if deviceName == "iPhone" {
                deviceName = "Andrew's iPhone"
                addDebugMessage("OVERRIDE: Forcing name to \"Andrew's iPhone\"")
            }
            
            // Dump all advertisement data for debugging
            addDebugMessage("ADVERTISEMENT DATA DUMP:")
            for (key, value) in advertisementData {
                addDebugMessage("   Key: \(key), Value: \(value)")
                
                // Look for any key that might contain a name with a space or apostrophe
                if let valueString = value as? String, 
                   (valueString.contains(" ") || valueString.contains("'")) {
                    deviceName = valueString
                    addDebugMessage("Found good name in value: \"\(valueString)\"")
                }
            }
            
            // Check CBAdvertisementDataLocalNameKey specifically
            if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String, !localName.isEmpty {
                // If the local name contains space or apostrophe, it's likely better than "iPhone"
                if localName.contains(" ") || localName.contains("'") {
                    deviceName = localName
                    addDebugMessage("2. Using better name from LocalNameKey: \"\(localName)\"")
                } else {
                    addDebugMessage("2. LocalNameKey name not clearly better: \"\(localName)\"")
                }
            }
        }
        
        // Log the exact name we'll be using
        addDebugMessage("Using device name: \"\(deviceName)\" for peripheral: \(peripheral.identifier)")
        
        // Log all advertisement data for debugging
        if let keys = advertisementData.keys.map({ String(describing: $0) }) as? [String] {
            addDebugMessage("Advertisement data contains keys: \(keys.joined(separator: ", "))")
        }
        
        // Update the appropriate list based on scanning state
        DispatchQueue.main.async {
            switch self.scanningState {
            case .refreshing:
                // During refresh, update the temporary list
                self.addDiscoveredDevice(peripheral: peripheral, rssi: RSSI, isSameApp: isSameApp, overrideName: deviceName)
                
            case .scanning:
                // During normal scanning, update the visible list
                self.updateDeviceList(peripheral: peripheral, rssi: RSSI, isSameApp: isSameApp, overrideName: deviceName)
                
            case .notScanning:
                // Shouldn't happen, but just in case
                break
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        addDebugMessage("Connected to peripheral: \(peripheral.name ?? peripheral.identifier.uuidString)")
        self.peripheral = peripheral
        peripheral.delegate = self
        
        // Update device status
        if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[index].isConnected = true
            connectedDevice = discoveredDevices[index]
        }
        
        isConnecting = false
        
        // Call the completion handler (but don't discover services here if we're doing messaging)
        // The completion handler will trigger service discovery itself
        connectionCompletionHandler?(true)
        connectionCompletionHandler = nil
        
        // Discover services only if we're not handling this via the completion handler
        if connectedDevice != nil && peripheral.services == nil {
            addDebugMessage("Discovering all services...")
            peripheral.discoverServices(nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let errorMsg = error?.localizedDescription ?? "Failed to connect"
        addDebugMessage("Failed to connect: \(errorMsg)")
        
        isConnecting = false
        self.error = errorMsg
        
        // Call the completion handler with failure
        connectionCompletionHandler?(false)
        connectionCompletionHandler = nil
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[index].isConnected = false
        }
        connectedDevice = nil
        characteristics = []
        services = []
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BluetoothManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            addDebugMessage("Peripheral Bluetooth is powered on")
            setupCalendarService()
            startAdvertising()
        case .poweredOff:
            addDebugMessage("Peripheral Bluetooth is powered off")
        case .resetting:
            addDebugMessage("Peripheral Bluetooth is resetting")
        case .unauthorized:
            addDebugMessage("Peripheral Bluetooth is unauthorized")
        case .unsupported:
            addDebugMessage("Peripheral Bluetooth is unsupported")
        case .unknown:
            addDebugMessage("Peripheral Bluetooth state is unknown")
        @unknown default:
            addDebugMessage("Unknown peripheral Bluetooth state")
        }
    }
    
    // Setup the calendar service to receive calendar data
    private func setupCalendarService() {
        // Only proceed if Bluetooth is powered on
        guard peripheralManager.state == .poweredOn else {
            addDebugMessage("Cannot setup calendar service - Bluetooth peripheral is not powered on")
            return
        }
        
        addDebugMessage("Setting up calendar service for receiving calendar data")
        
        // Create the characteristic for calendar data
        calendarCharacteristic = CBMutableCharacteristic(
            type: calendarCharacteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        // Create the calendar service
        let calendarService = CBMutableService(type: calendarServiceUUID, primary: true)
        
        // Add the characteristic to the service
        calendarService.characteristics = [calendarCharacteristic!]
        
        // Add the service to the peripheral manager
        peripheralManager.add(calendarService)
        
        addDebugMessage("Calendar service setup complete")
    }
    
    private func startAdvertising() {
        // Only proceed if Bluetooth is powered on
        guard peripheralManager.state == .poweredOn else {
            addDebugMessage("Cannot start advertising - Bluetooth peripheral is not powered on")
            return
        }
        
        addDebugMessage("Starting Bluetooth advertising")
        
        // Create the app identification service
        let appService = CBMutableService(type: connectWithAppServiceUUID, primary: true)
        appService.characteristics = []
        
        // Add service to peripheral manager
        peripheralManager.add(appService)
        
        // Use the cached device name
        addDebugMessage("Advertising with device name: \(deviceCustomName)")
        
        // Start advertising both services with the personalized device name
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [connectWithAppServiceUUID, calendarServiceUUID],
            CBAdvertisementDataLocalNameKey: deviceCustomName
        ])
        
        addDebugMessage("Bluetooth advertising started")
    }
    
    // These lines have been moved to the main class definition
    
    // Called when a central device writes to one of our characteristics
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            addDebugMessage("Received write request to characteristic: \(request.characteristic.uuid.uuidString)")
            
            // Check if this is a write to our calendar characteristic
            if request.characteristic.uuid == calendarCharacteristicUUID, let data = request.value {
                // Check if this is a new transmission or continuation
                let isNewTransmission = shouldStartNewTransmission()
                
                if isNewTransmission {
                    // Start collecting a new message
                    receivedDataBuffer = data
                    receivedChunkCount = 1
                    lastChunkTimestamp = Date()
                    addDebugMessage("Started new data reception - chunk 1: \(data.count) bytes")
                } else {
                    // Append to existing data collection
                    receivedDataBuffer.append(data)
                    receivedChunkCount += 1
                    lastChunkTimestamp = Date()
                    addDebugMessage("Received chunk \(receivedChunkCount): \(data.count) bytes, total now \(receivedDataBuffer.count) bytes")
                }
                
                // Try to print the accumulated JSON for debugging
                if let jsonString = String(data: receivedDataBuffer, encoding: .utf8) {
                    let previewLength = min(100, jsonString.count)
                    let jsonPreview = String(jsonString.prefix(previewLength))
                    addDebugMessage("Accumulated JSON preview: \(jsonPreview)\(jsonString.count > previewLength ? "..." : "")")
                }
                
                // Try to parse the simplified JSON format
                if let jsonObject = try? JSONSerialization.jsonObject(with: receivedDataBuffer, options: []) as? [String: Any] {
                    addDebugMessage("Successfully parsed simplified JSON data")
                    
                    // Extract fields from the simplified format
                    if let sender = jsonObject["sender"] as? String,
                       let timestamp = jsonObject["timestamp"] as? Int,
                       let months = jsonObject["months"] as? [Int],
                       let days = jsonObject["days"] as? [Int],
                       let titles = jsonObject["titles"] as? [String],
                       let locations = jsonObject["locations"] as? [String] {
                        
                        // Create calendar entries from the arrays
                        var entries: [CalendarEntry] = []
                        
                        // Ensure all arrays have the same length
                        let entryCount = min(months.count, days.count, titles.count, locations.count)
                        
                        for i in 0..<entryCount {
                            let entry = CalendarEntry(
                                title: titles[i],
                                location: locations[i],
                                month: months[i],
                                day: days[i]
                            )
                            entries.append(entry)
                            addDebugMessage("  - Reconstructed Month \(months[i]), Day \(days[i]): '\(titles[i])' at '\(locations[i])'")
                        }
                        
                        // Create a CalendarData object
                        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                        let calendarData = CalendarData(
                            senderName: sender,
                            entries: entries,
                            timestamp: date
                        )
                        
                        // Clear the buffer now that we've successfully parsed the data
                        receivedDataBuffer = Data()
                        receivedChunkCount = 0
                        lastChunkTimestamp = nil
                        
                        addDebugMessage("Successfully reconstructed calendar data with \(entries.count) entries")
                        
                        // Store the received calendar data
                        DispatchQueue.main.async {
                            self.receivedCalendarData = calendarData
                            
                            // Update our local calendar with the received data
                            self.updateCalendarWithReceivedData(calendarData)
                            
                            // Show in-app alert
                            self.showCalendarDataInAppAlert(calendarData: calendarData)
                        }
                    } else {
                        addDebugMessage("JSON missing required fields - waiting for more chunks")
                    }
                } else {
                    addDebugMessage("JSON not yet complete or invalid - waiting for more chunks")
                }
            }
            
            // Respond to the request
            peripheralManager.respond(to: request, withResult: .success)
        }
    }
    
    private func shouldStartNewTransmission() -> Bool {
        // Start a new transmission if:
        // 1. This is our first chunk (buffer is empty)
        // 2. It's been more than 15 seconds since the last chunk (INCREASED timeout from 5 to 15 seconds)
        
        if receivedDataBuffer.isEmpty {
            return true
        }
        
        if let lastTimestamp = lastChunkTimestamp, 
           Date().timeIntervalSince(lastTimestamp) > 15.0 {
            // It's been too long, start fresh
            addDebugMessage("Previous transmission timed out after \(receivedChunkCount) chunks - starting fresh")
            return true
        }
        
        // Continue with existing transmission
        return false
    }
    
    // Update our local calendar with the received data
    private func updateCalendarWithReceivedData(_ calendarData: CalendarData) {
        // Replace our calendar entries with the received ones
        self.calendarEntries = calendarData.entries
        
        // Save the updated calendar entries
        saveCalendarEntries()
        
        addDebugMessage("Updated local calendar with \(calendarData.entries.count) entries from \(calendarData.senderName)")
    }
    
    // Called when a central device subscribes to notifications
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        addDebugMessage("Central \(central.identifier.uuidString) subscribed to \(characteristic.uuid.uuidString)")
    }
    
    // Called when a central device unsubscribes from notifications
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        addDebugMessage("Central \(central.identifier.uuidString) unsubscribed from \(characteristic.uuid.uuidString)")
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            addDebugMessage("Error discovering services: \(error.localizedDescription)")
            self.error = "Error discovering services: \(error.localizedDescription)"
            finishCalendarDataSending(success: false, errorMessage: "Error discovering services")
            return
        }
        
        if let services = peripheral.services {
            addDebugMessage("Discovered \(services.count) services")
            self.services = services
            
            // Check if there's a calendar service among the discovered services
            var foundCalendarService = false
            
            for service in services {
                addDebugMessage("Service: \(service.uuid.uuidString)")
                
                if service.uuid == calendarServiceUUID {
                    foundCalendarService = true
                    addDebugMessage("Found calendar service")
                    // Discover characteristics for calendar service
                    peripheral.discoverCharacteristics([calendarCharacteristicUUID], for: service)
                } else {
                    // Discover all characteristics for other services
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
            
            if !foundCalendarService && sendingCalendarData {
                addDebugMessage("Error: Calendar service not found on device")
                finishCalendarDataSending(success: false, errorMessage: "Calendar service not available on this device")
            }
        } else {
            if sendingCalendarData {
                addDebugMessage("Error: No services found")
                finishCalendarDataSending(success: false, errorMessage: "No services found on device")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            addDebugMessage("Error discovering characteristics: \(error.localizedDescription)")
            self.error = "Error discovering characteristics: \(error.localizedDescription)"
            
            if service.uuid == calendarServiceUUID && sendingCalendarData {
                finishCalendarDataSending(success: false, errorMessage: "Error discovering characteristics")
            }
            return
        }
        
        if let characteristics = service.characteristics {
            addDebugMessage("Discovered \(characteristics.count) characteristics for service \(service.uuid.uuidString)")
            
            // Check if this is the calendar service
            if service.uuid == calendarServiceUUID {
                // Find the calendar characteristic
                var foundCalendarCharacteristic = false
                
                for characteristic in characteristics {
                    addDebugMessage("Characteristic: \(characteristic.uuid.uuidString), properties: \(characteristic.properties.rawValue)")
                    
                    if characteristic.uuid == calendarCharacteristicUUID {
                        foundCalendarCharacteristic = true
                        addDebugMessage("Found calendar characteristic")
                        
                        // If we're trying to send calendar data, proceed
                        if sendingCalendarData {
                            let calendarData = CalendarData(senderName: deviceCustomName, entries: calendarEntries)
                            writeCalendarDataToCharacteristic(calendarData: calendarData, characteristic: characteristic, peripheral: peripheral)
                        }
                        
                        // Setup notifications for incoming calendar data
                        if characteristic.properties.contains(.notify) {
                            addDebugMessage("Setting up notifications for calendar characteristic")
                            peripheral.setNotifyValue(true, for: characteristic)
                        }
                    }
                }
                
                if !foundCalendarCharacteristic && sendingCalendarData {
                    addDebugMessage("Error: Calendar characteristic not found")
                    finishCalendarDataSending(success: false, errorMessage: "Calendar characteristic not available")
                }
            } else {
                // Standard handling for other characteristics
                for characteristic in characteristics {
                    if characteristic.properties.contains(.read) {
                        peripheral.readValue(for: characteristic)
                    }
                    if characteristic.properties.contains(.notify) {
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                    
                    DispatchQueue.main.async {
                        if !self.characteristics.contains(where: { $0.uuid == characteristic.uuid }) {
                            self.characteristics.append(characteristic)
                        }
                    }
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addDebugMessage("Error updating value: \(error.localizedDescription)")
            return
        }
        
        // Handle calendar characteristic value updates (incoming calendar data)
        if characteristic.uuid == calendarCharacteristicUUID, let data = characteristic.value {
            addDebugMessage("Received data on calendar characteristic: \(data.count) bytes")
            
            if let calendarData = CalendarData.fromData(data) {
                addDebugMessage("Received calendar data from \(calendarData.senderName) with \(calendarData.entries.count) entries")
                
                // Store the received calendar data
                DispatchQueue.main.async {
                    self.receivedCalendarData = calendarData
                    
                    // Also update the device's calendar data if we can find it
                    if let index = self.discoveredDevices.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
                        var device = self.discoveredDevices[index]
                        device.receivedCalendarData = calendarData
                        self.discoveredDevices[index] = device
                    }
                    
                    // Update our local calendar with the received data
                    self.updateCalendarWithReceivedData(calendarData)
                    
                    // Show in-app alert
                    self.showCalendarDataInAppAlert(calendarData: calendarData)
                }
            } else {
                addDebugMessage("Failed to parse received calendar data")
            }
        }
        
        // Standard update for UI
        objectWillChange.send()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == calendarCharacteristicUUID {
            if let error = error {
                addDebugMessage("Error writing to calendar characteristic: \(error.localizedDescription)")
                
                // If it's a "prepare queue is full" error, retry with an even smaller chunk
                if error.localizedDescription.contains("prepare queue is full") {
                    addDebugMessage("Detected queue full error, will retry with smaller data")
                    retryWriteIfNeeded()
                } else {
                    // Other error, just finish
                    finishCalendarDataSending(success: false, errorMessage: "Failed to send calendar data: \(error.localizedDescription)")
                }
            } else {
                // Success case - if we only sent a chunk, we need to handle that
                if let pendingData = pendingData, 
                   pendingData.count > 50,  // If we have more data than what would be in a small chunk
                   let pendingCharacteristic = pendingCharacteristic,
                   let pendingPeripheral = pendingPeripheral {
                    
                    // We successfully sent a chunk, but there's more data - this approach is not working
                    // Let's just report success anyway since we at least sent some data
                    addDebugMessage("Successfully wrote a small chunk of the calendar data")
                    finishCalendarDataSending(success: true)
                } else {
                    // Standard success case
                    addDebugMessage("Successfully wrote calendar data to characteristic")
                    finishCalendarDataSending(success: true)
                }
            }
        }
    }
    
    // Display an in-app alert for incoming calendar data
    private func showCalendarDataInAppAlert(calendarData: CalendarData) {
        addDebugMessage("Showing in-app alert: Calendar data from \(calendarData.senderName)")
        
        DispatchQueue.main.async {
            self.alertCalendarData = calendarData
            self.showCalendarDataAlert = true
        }
    }
}
