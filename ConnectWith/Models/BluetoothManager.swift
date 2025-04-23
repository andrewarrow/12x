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
            // Use host name which often includes personalized name
            let hostName = ProcessInfo.processInfo.hostName
            let cleanedName = hostName.replacingOccurrences(of: ".local", with: "")
                                      .replacingOccurrences(of: "-", with: " ")
            deviceCustomName = cleanedName
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
        
        // Update the published array all at once to avoid flickering
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Only update if we're in refreshing state (not if the user cancelled)
            if self.scanningState == .refreshing {
                self.discoveredDevices = self.tempDiscoveredDevices
                self.scanningState = .notScanning
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
            
            // Always update the name if we have a better one than "Unknown Device"
            if deviceName != "Unknown Device" || tempDiscoveredDevices[index].name == "Unknown Device" {
                tempDiscoveredDevices[index].name = deviceName
            }
        } else {
            // Add new device
            let newDevice = BluetoothDevice(
                peripheral: peripheral,
                name: deviceName,
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
            
            // Always update the name if we have a better one than "Unknown Device"
            if deviceName != "Unknown Device" || discoveredDevices[index].name == "Unknown Device" {
                discoveredDevices[index].name = deviceName
            }
        } else {
            // Add new device
            let newDevice = BluetoothDevice(
                peripheral: peripheral,
                name: deviceName,
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
        
        // Extract device name from advertisement data for devices running our app
        var deviceName = peripheral.name ?? "Unknown Device"
        if isSameApp && advertisementData[CBAdvertisementDataLocalNameKey] != nil {
            if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String, !localName.isEmpty {
                deviceName = localName
            }
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
