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

// Custom UUIDs for app identification and chat
let connectWithAppServiceUUID = CBUUID(string: "6F7A99FE-2F4A-41C0-ADB0-9D8CB68BEBA0")
let chatServiceUUID = CBUUID(string: "6F7A99FE-2F4A-41C0-ADB0-9D8CB68BEBA1")
let chatCharacteristicUUID = CBUUID(string: "6F7A99FE-2F4A-41C0-ADB0-9D8CB68BEBA2")

class BluetoothManager: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var peripheralManager: CBPeripheralManager!
    private var chatCharacteristic: CBMutableCharacteristic?
    
    // Published properties that trigger UI updates
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var scanningState: ScanningState = .notScanning
    @Published var connectedDevice: BluetoothDevice?
    @Published var characteristics: [CBCharacteristic] = []
    @Published var services: [CBService] = []
    @Published var isConnecting = false
    @Published var error: String?
    
    // Chat-related properties
    @Published var sendingMessage = false
    @Published var debugMessages: [String] = []
    @Published var sentMessages: [ChatMessage] = []
    @Published var receivedMessages: [ChatMessage] = []
    
    // Alert system for incoming messages
    @Published var showMessageAlert = false
    @Published var alertMessage: ChatMessage?
    
    // Private properties - used internally but don't trigger UI updates
    private var tempDiscoveredDevices: [BluetoothDevice] = []
    private var lastScanDate: Date = Date()
    private var deviceCustomName: String = UIDevice.current.name
    
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
        
        addDebugMessage("Initialized BluetoothManager with device name: \(deviceCustomName)")
        
        // Scanning will automatically start once Bluetooth is powered on
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
    
    // Send a message to a specific device
    func sendMessage(text: String, to device: BluetoothDevice) {
        guard !text.isEmpty else {
            addDebugMessage("Cannot send empty message")
            return
        }
        
        addDebugMessage("Preparing to send message to \(device.name): \"\(text)\"")
        
        guard let peripheral = device.peripheral else {
            addDebugMessage("Error: Cannot send message - no peripheral")
            return
        }
        
        // Create a new message
        let message = ChatMessage(text: text, senderName: deviceCustomName)
        
        // Update UI to show we're sending
        DispatchQueue.main.async {
            self.sendingMessage = true
            // Add to our sent messages
            self.sentMessages.append(message)
        }
        
        addDebugMessage("Connecting to \(device.name) to send message...")
        
        // Connect to the device if not already connected
        if !device.isConnected {
            self.connect(to: device, completionHandler: { success in
                if success {
                    self.addDebugMessage("Connected successfully to \(device.name)")
                    self.discoverServices(peripheral: peripheral, message: message)
                } else {
                    self.addDebugMessage("Failed to connect to \(device.name)")
                    DispatchQueue.main.async {
                        self.sendingMessage = false
                        self.error = "Failed to connect for sending message"
                    }
                }
            })
        } else {
            // Already connected, proceed to discover services
            self.addDebugMessage("Already connected to \(device.name)")
            self.discoverServices(peripheral: peripheral, message: message)
        }
    }
    
    // Discover services after connection for message sending
    private func discoverServices(peripheral: CBPeripheral, message: ChatMessage) {
        peripheral.delegate = self
        
        addDebugMessage("Discovering services for \(peripheral.name ?? "Unknown")")
        peripheral.discoverServices([chatServiceUUID])
    }
    
    // Write message to characteristic
    private func writeMessageToCharacteristic(message: ChatMessage, characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        guard let data = message.toData() else {
            addDebugMessage("Error: Failed to convert message to data")
            DispatchQueue.main.async {
                self.sendingMessage = false
                self.error = "Failed to convert message to data"
            }
            return
        }
        
        addDebugMessage("Writing message data (\(data.count) bytes) to characteristic")
        
        // Write data to characteristic
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        
        // We'll get completion in the didWriteValueFor delegate method
    }
    
    // Called when we want to actively disconnect after sending
    private func finishMessageSending(success: Bool, errorMessage: String? = nil) {
        if success {
            addDebugMessage("Message sent successfully!")
        } else {
            addDebugMessage("Failed to send message: \(errorMessage ?? "Unknown error")")
            DispatchQueue.main.async {
                self.error = errorMessage
            }
        }
        
        // Disconnect after sending
        if let peripheral = self.peripheral, peripheral.state == .connected {
            addDebugMessage("Disconnecting after message operation")
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
        // Reset state
        DispatchQueue.main.async {
            self.sendingMessage = false
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
            setupChatService()
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
    
    // Setup the chat service to receive messages
    private func setupChatService() {
        // Only proceed if Bluetooth is powered on
        guard peripheralManager.state == .poweredOn else {
            addDebugMessage("Cannot setup chat service - Bluetooth peripheral is not powered on")
            return
        }
        
        addDebugMessage("Setting up chat service for receiving messages")
        
        // Create the characteristic for chat messages
        chatCharacteristic = CBMutableCharacteristic(
            type: chatCharacteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        // Create the chat service
        let chatService = CBMutableService(type: chatServiceUUID, primary: true)
        
        // Add the characteristic to the service
        chatService.characteristics = [chatCharacteristic!]
        
        // Add the service to the peripheral manager
        peripheralManager.add(chatService)
        
        addDebugMessage("Chat service setup complete")
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
            CBAdvertisementDataServiceUUIDsKey: [connectWithAppServiceUUID, chatServiceUUID],
            CBAdvertisementDataLocalNameKey: deviceCustomName
        ])
        
        addDebugMessage("Bluetooth advertising started")
    }
    
    // Called when a central device writes to one of our characteristics
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            addDebugMessage("Received write request to characteristic: \(request.characteristic.uuid.uuidString)")
            
            // Check if this is a write to our chat characteristic
            if request.characteristic.uuid == chatCharacteristicUUID, let data = request.value {
                addDebugMessage("Received chat data: \(data.count) bytes")
                
                // Try to parse the message
                if let message = ChatMessage.fromData(data) {
                    addDebugMessage("Received message from \(message.senderName): \"\(message.text)\"")
                    
                    // Set as incoming message
                    var incomingMessage = message
                    incomingMessage.isIncoming = true
                    
                    // Add to received messages list
                    DispatchQueue.main.async {
                        self.receivedMessages.append(incomingMessage)
                        
                        // Show in-app alert
                        self.showMessageInAppAlert(message: incomingMessage)
                    }
                } else {
                    addDebugMessage("Failed to parse received message data")
                }
            }
            
            // Respond to the request
            peripheralManager.respond(to: request, withResult: .success)
        }
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
            finishMessageSending(success: false, errorMessage: "Error discovering services")
            return
        }
        
        if let services = peripheral.services {
            addDebugMessage("Discovered \(services.count) services")
            self.services = services
            
            // Check if there's a chat service among the discovered services
            var foundChatService = false
            
            for service in services {
                addDebugMessage("Service: \(service.uuid.uuidString)")
                
                if service.uuid == chatServiceUUID {
                    foundChatService = true
                    addDebugMessage("Found chat service")
                    // Discover characteristics for chat service
                    peripheral.discoverCharacteristics([chatCharacteristicUUID], for: service)
                } else {
                    // Discover all characteristics for other services
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
            
            if !foundChatService && sendingMessage {
                addDebugMessage("Error: Chat service not found on device")
                finishMessageSending(success: false, errorMessage: "Chat service not available on this device")
            }
        } else {
            if sendingMessage {
                addDebugMessage("Error: No services found")
                finishMessageSending(success: false, errorMessage: "No services found on device")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            addDebugMessage("Error discovering characteristics: \(error.localizedDescription)")
            self.error = "Error discovering characteristics: \(error.localizedDescription)"
            
            if service.uuid == chatServiceUUID && sendingMessage {
                finishMessageSending(success: false, errorMessage: "Error discovering characteristics")
            }
            return
        }
        
        if let characteristics = service.characteristics {
            addDebugMessage("Discovered \(characteristics.count) characteristics for service \(service.uuid.uuidString)")
            
            // Check if this is the chat service
            if service.uuid == chatServiceUUID {
                // Find the chat characteristic
                var foundChatCharacteristic = false
                
                for characteristic in characteristics {
                    addDebugMessage("Characteristic: \(characteristic.uuid.uuidString), properties: \(characteristic.properties.rawValue)")
                    
                    if characteristic.uuid == chatCharacteristicUUID {
                        foundChatCharacteristic = true
                        addDebugMessage("Found chat characteristic")
                        
                        // If we're trying to send a message, proceed
                        if sendingMessage && !sentMessages.isEmpty {
                            let message = sentMessages.last!
                            writeMessageToCharacteristic(message: message, characteristic: characteristic, peripheral: peripheral)
                        }
                        
                        // Setup notifications for incoming messages
                        if characteristic.properties.contains(.notify) {
                            addDebugMessage("Setting up notifications for chat characteristic")
                            peripheral.setNotifyValue(true, for: characteristic)
                        }
                    }
                }
                
                if !foundChatCharacteristic && sendingMessage {
                    addDebugMessage("Error: Chat characteristic not found")
                    finishMessageSending(success: false, errorMessage: "Chat characteristic not available")
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
        
        // Handle chat characteristic value updates (incoming messages)
        if characteristic.uuid == chatCharacteristicUUID, let data = characteristic.value {
            addDebugMessage("Received data on chat characteristic: \(data.count) bytes")
            
            if let message = ChatMessage.fromData(data) {
                addDebugMessage("Received message from \(message.senderName): \"\(message.text)\"")
                
                // Set as incoming message
                var incomingMessage = message
                incomingMessage.isIncoming = true
                
                // Add to received messages list
                DispatchQueue.main.async {
                    self.receivedMessages.append(incomingMessage)
                    
                    // Also update the device's message list if we can find it
                    if let index = self.discoveredDevices.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
                        var device = self.discoveredDevices[index]
                        device.receivedMessages.append(incomingMessage)
                        self.discoveredDevices[index] = device
                    }
                    
                    // Show in-app alert
                    self.showMessageInAppAlert(message: incomingMessage)
                }
            } else {
                addDebugMessage("Failed to parse received message data")
            }
        }
        
        // Standard update for UI
        objectWillChange.send()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == chatCharacteristicUUID {
            if let error = error {
                addDebugMessage("Error writing to chat characteristic: \(error.localizedDescription)")
                finishMessageSending(success: false, errorMessage: "Failed to send message: \(error.localizedDescription)")
            } else {
                addDebugMessage("Successfully wrote message to chat characteristic")
                finishMessageSending(success: true)
            }
        }
    }
    
    // Display an in-app alert for incoming messages
    private func showMessageInAppAlert(message: ChatMessage) {
        addDebugMessage("Showing in-app alert: Message from \(message.senderName)")
        
        DispatchQueue.main.async {
            self.alertMessage = message
            self.showMessageAlert = true
        }
    }
}
