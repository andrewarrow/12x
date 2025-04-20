import Foundation
import CoreBluetooth
import SwiftUI

class BluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var nearbyDevices: [CBPeripheral] = []
    @Published var connectedPeripherals: [CBPeripheral] = []
    @Published var isScanning: Bool = false
    @Published var isAdvertising: Bool = false
    @Published var scanningMessage: String = "Scanning for devices..."
    @Published var connectionResults: [String: ConnectionResult] = [:]
    
    // MARK: - Core Bluetooth Managers
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    
    // MARK: - UUIDs
    private let serviceUUID = CBUUID(string: "4514d666-d6c9-49cb-bc31-dc6dfa28bd58")
    private let messageCharacteristicUUID = CBUUID(string: "462d10ad-e297-4620-a3af-d964f92fd1a5")
    private let responseCharacteristicUUID = CBUUID(string: "f3c6df3c-334a-4274-a4e9-2c9b1e9decb0")
    private let syncDataCharacteristicUUID = CBUUID(string: "97d52a22-9292-48c6-a89f-8a71d89c5e9b")
    
    // Keep track of characteristics
    private var messageCharacteristic: CBMutableCharacteristic?
    private var responseCharacteristic: CBMutableCharacteristic?
    private var syncDataCharacteristic: CBMutableCharacteristic?
    
    // Track characteristics discovered for peripherals
    private var discoveredCharacteristics: [UUID: [CBUUID: CBCharacteristic]] = [:]
    
    // MARK: - Message Exchange
    enum MessageType: String {
        case hello = "HELLO"
        case hi = "HI"
    }
    
    struct ConnectionResult {
        enum Status {
            case inProgress
            case success
            case failure(String)
        }
        
        var status: Status
        var timestamp: Date
        
        init(status: Status) {
            self.status = status
            self.timestamp = Date()
        }
    }
    
    // MARK: - Device Store
    private let deviceStore = DeviceStore.shared
    
    // Use a dedicated serial queue for Bluetooth operations
    private let bluetoothQueue = DispatchQueue(label: "com.12x.BluetoothQueue", qos: .userInitiated)
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        print("Starting BluetoothManager initialization with service: \(serviceUUID.uuidString)")
        
        // Force-set Bluetooth permission descriptions to ensure they're available
        let permissions = [
            "NSBluetoothAlwaysUsageDescription": "This app uses Bluetooth to connect with nearby family members' devices",
            "NSBluetoothPeripheralUsageDescription": "This app uses Bluetooth to connect with nearby family members' devices"
        ]
        
        // Set using UserDefaults
        for (key, value) in permissions {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        // Add additional check to warn if Info.plist is missing required permissions
        if Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") == nil {
            print("⚠️ WARNING: NSBluetoothAlwaysUsageDescription not found in Info.plist")
            scanningMessage = "Using runtime Bluetooth permissions"
        } else {
            print("✅ NSBluetoothAlwaysUsageDescription found in Info.plist")
        }
        
        // Initialize with options that explicitly request authorization
        let centralOptions: [String: Any] = [
            CBCentralManagerOptionShowPowerAlertKey: true
        ]
        
        print("Creating Bluetooth managers with dedicated queue")
        DispatchQueue.main.async { [weak self] in
            self?.scanningMessage = "Initializing Bluetooth..."
        }
        
        // Create the managers with our dedicated queue
        centralManager = CBCentralManager(delegate: self, queue: bluetoothQueue, options: centralOptions)
        peripheralManager = CBPeripheralManager(delegate: self, queue: bluetoothQueue)
        
        print("BluetoothManager initialization complete")
    }
    
    // MARK: - Central Methods
    func startScanning() {
        // Check for Bluetooth permission and power state
        switch centralManager.state {
        case .poweredOn:
            // Bluetooth is on and ready
            break
        case .poweredOff:
            DispatchQueue.main.async { [weak self] in
                self?.scanningMessage = "Bluetooth is powered off. Please turn on Bluetooth."
            }
            return
        case .unauthorized:
            DispatchQueue.main.async { [weak self] in
                self?.scanningMessage = "Bluetooth permission denied. Please enable in Settings."
            }
            print("IMPORTANT: Bluetooth permission is required. Add NSBluetoothAlwaysUsageDescription to Info.plist")
            return
        case .unsupported:
            DispatchQueue.main.async { [weak self] in
                self?.scanningMessage = "Bluetooth is not supported on this device"
            }
            return
        default:
            DispatchQueue.main.async { [weak self] in
                self?.scanningMessage = "Bluetooth is not ready. Please wait..."
            }
            return
        }
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Clear the nearbyDevices array when we start a new scan
            self.nearbyDevices.removeAll()
            self.isScanning = true
            self.scanningMessage = "Scanning for devices..."
        }
        
        // Start scanning for devices with our service UUID
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        print("Started scanning for devices with UUID: \(serviceUUID.uuidString)")
    }
    
    func stopScanning() {
        centralManager.stopScan()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isScanning = false
            self.scanningMessage = "Scanning stopped"
        }
        
        print("Stopped scanning for devices")
    }
    
    func connectToDevice(_ device: CBPeripheral) {
        centralManager.connect(device, options: nil)
        print("Connecting to device: \(device.name ?? device.identifier.uuidString)")
    }
    
    // MARK: - Connection Testing
    
    func testConnection(with deviceIdentifier: String) {
        print("Testing connection with device: \(deviceIdentifier)")
        
        // First update the UI to show in progress
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connectionResults[deviceIdentifier] = ConnectionResult(status: .inProgress)
            
            // Update device store status to indicate connection attempt
            self.deviceStore.updateConnectionStatus(
                identifier: deviceIdentifier,
                status: .new
            )
        }
        
        // Find the peripheral with this identifier
        guard let uuid = UUID(uuidString: deviceIdentifier),
              let peripheral = nearbyDevices.first(where: { $0.identifier == uuid }) else {
            print("Device not found in nearby devices list")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.connectionResults[deviceIdentifier] = ConnectionResult(
                    status: .failure("Device not found")
                )
                
                // Update device store status
                self.deviceStore.updateConnectionStatus(
                    identifier: deviceIdentifier,
                    status: .error
                )
            }
            return
        }
        
        // If device is already connected, try to send a message
        if connectedPeripherals.contains(where: { $0.identifier == uuid }) {
            if let characteristics = discoveredCharacteristics[uuid],
               let messageChar = characteristics[messageCharacteristicUUID] {
                sendMessage(.hello, to: peripheral, characteristic: messageChar)
            } else {
                // Disconnect and reconnect to discover characteristics
                centralManager.cancelPeripheralConnection(peripheral)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.centralManager.connect(peripheral, options: nil)
                }
            }
        } else {
            // Connect to the device first
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    // MARK: - Message Exchange
    
    private func sendMessage(_ message: MessageType, to peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        print("Sending '\(message.rawValue)' to \(peripheral.name ?? peripheral.identifier.uuidString)")
        
        guard let data = message.rawValue.data(using: .utf8) else {
            print("Failed to convert message to data")
            return
        }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    // Handle incoming message, returning true if proper handshake completes
    private func handleReceivedMessage(_ data: Data, from peripheral: CBPeripheral) -> Bool {
        guard let message = String(data: data, encoding: .utf8),
              let messageType = MessageType(rawValue: message) else {
            print("Received invalid message data from \(peripheral.name ?? peripheral.identifier.uuidString)")
            return false
        }
        
        print("Received '\(messageType.rawValue)' from \(peripheral.name ?? peripheral.identifier.uuidString)")
        
        // Device identifier
        let deviceId = peripheral.identifier.uuidString
        
        if messageType == .hello {
            // Respond with "HI" to a "HELLO"
            if let characteristics = discoveredCharacteristics[peripheral.identifier],
               let responseChar = characteristics[responseCharacteristicUUID] {
                sendMessage(.hi, to: peripheral, characteristic: responseChar)
                
                // Only mark as connected if we had our characteristics and responded
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // Update connection result
                    self.connectionResults[deviceId] = ConnectionResult(status: .success)
                    
                    // Update device store status
                    self.deviceStore.updateConnectionStatus(
                        identifier: deviceId,
                        status: .connected
                    )
                }
                return true
            }
        } else if messageType == .hi {
            // When we receive "HI" in response to our "HELLO", the handshake is complete
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Update connection result
                self.connectionResults[deviceId] = ConnectionResult(status: .success)
                
                // Update device store status
                self.deviceStore.updateConnectionStatus(
                    identifier: deviceId,
                    status: .connected
                )
            }
            return true
        }
        
        return false
    }
    
    // MARK: - Peripheral Methods
    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else {
            print("Peripheral manager not powered on")
            return
        }
        
        // Create the service
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        // Create the characteristics
        let messageChar = CBMutableCharacteristic(
            type: messageCharacteristicUUID,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        
        let responseChar = CBMutableCharacteristic(
            type: responseCharacteristicUUID,
            properties: [.write, .writeWithoutResponse, .notify],
            value: nil,
            permissions: [.writeable]
        )
        
        let syncDataChar = CBMutableCharacteristic(
            type: syncDataCharacteristicUUID,
            properties: [.write, .writeWithoutResponse, .notify, .read],
            value: nil,
            permissions: [.writeable, .readable]
        )
        
        // Add characteristics to the service
        service.characteristics = [messageChar, responseChar, syncDataChar]
        
        // Store references to characteristics
        self.messageCharacteristic = messageChar
        self.responseCharacteristic = responseChar
        self.syncDataCharacteristic = syncDataChar
        
        // Add the service to the peripheral manager
        peripheralManager.add(service)
        
        // Start advertising
        // Get the device name using the improved method
        var deviceName = UIDevice.current.name
        
        // Try to get the personalized name from UserDefaults
        if let customName = UserDefaults.standard.string(forKey: "DeviceCustomName") {
            deviceName = customName
            print("DEBUG: Found custom name in UserDefaults: \(customName)")
        } else {
            // Use host name which often includes personalized name ("Bob's-iPhone.local" format)
            let hostName = ProcessInfo.processInfo.hostName
            print("DEBUG: ProcessInfo.hostName = \(hostName)")
            
            let cleanedName = hostName.replacingOccurrences(of: ".local", with: "")
                                      .replacingOccurrences(of: "-", with: " ")
            print("DEBUG: Cleaned host name = \(cleanedName)")
            deviceName = cleanedName
        }
        
        print("DEBUG: MainMenuView advertising with name: \(deviceName)")
        
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: deviceName
        ])
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAdvertising = true
        }
        
        print("Started advertising as: \(deviceName)")
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAdvertising = false
        }
        
        print("Stopped advertising")
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    // This method is required if you use CBCentralManagerOptionRestoreIdentifierKey
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        print("Bluetooth central manager restoring state")
        
        // Retrieve any peripherals that were connected
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            print("Restored \(peripherals.count) peripherals")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                for peripheral in peripherals {
                    if !self.nearbyDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                        self.nearbyDevices.append(peripheral)
                    }
                }
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // This runs on the bluetoothQueue, update UI properties on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch central.state {
            case .poweredOn:
                print("Central manager powered on")
                self.startScanning()
                self.startAdvertising()
            case .poweredOff:
                print("Central manager powered off")
                self.scanningMessage = "Bluetooth is powered off"
            case .resetting:
                print("Central manager resetting")
            case .unauthorized:
                print("Central manager unauthorized")
                self.scanningMessage = "Bluetooth permission denied"
            case .unsupported:
                print("Central manager unsupported")
                self.scanningMessage = "Bluetooth not supported"
            case .unknown:
                print("Central manager unknown state")
            @unknown default:
                print("Central manager unknown default")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Check if the device has a name
        let deviceName = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown Device"
        
        // Don't filter by name prefix - we're already filtering by service UUID
        // Accept all devices that match our service UUID
        
        // Save to our device store (thread-safe operation) - will update if device already exists
        print("DEBUG: MainMenuView discovered device with name: \(deviceName)")
        print("DEBUG: MainMenuView adding device to store with ID: \(peripheral.identifier.uuidString)")
        deviceStore.addDevice(identifier: peripheral.identifier.uuidString, name: deviceName, rssi: RSSI.intValue)
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // See if we already found this device - if not, add it to nearbyDevices
            if !self.nearbyDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                print("Discovered device: \(deviceName) (RSSI: \(RSSI))")
                self.nearbyDevices.append(peripheral)
            } else {
                // If we found it before, update the existing entry instead of adding a duplicate
                print("Updated existing device: \(deviceName) (RSSI: \(RSSI))")
                // No need to update nearbyDevices directly - we already have a reference to the CBPeripheral
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to device: \(peripheral.name ?? peripheral.identifier.uuidString)")
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !self.connectedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                self.connectedPeripherals.append(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to device: \(peripheral.name ?? peripheral.identifier.uuidString), error: \(error?.localizedDescription ?? "unknown error")")
        
        // Update UI to show connection failure
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let deviceId = peripheral.identifier.uuidString
            
            self.connectionResults[deviceId] = ConnectionResult(
                status: .failure(error?.localizedDescription ?? "Connection failed")
            )
            
            // Update device store status
            self.deviceStore.updateConnectionStatus(
                identifier: deviceId,
                status: .error
            )
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from device: \(peripheral.name ?? peripheral.identifier.uuidString)")
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connectedPeripherals.removeAll(where: { $0.identifier == peripheral.identifier })
            
            // Clear discovered characteristics
            self.discoveredCharacteristics[peripheral.identifier] = nil
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("Discovered service: \(service.uuid)")
            if service.uuid == serviceUUID {
                print("Discovered our service, looking for message characteristics")
                peripheral.discoverCharacteristics(
                    [messageCharacteristicUUID, responseCharacteristicUUID, syncDataCharacteristicUUID],
                    for: service
                )
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("No characteristics found")
            return
        }
        
        // Store discovered characteristics for this peripheral
        var discoveredChars: [CBUUID: CBCharacteristic] = [:]
        
        for characteristic in characteristics {
            print("Discovered characteristic: \(characteristic.uuid)")
            discoveredChars[characteristic.uuid] = characteristic
            
            // Subscribe to notifications
            if characteristic.uuid == responseCharacteristicUUID || 
               characteristic.uuid == syncDataCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
            // Post notification about discovered characteristic
            NotificationCenter.default.post(
                name: NSNotification.Name("BluetoothCharacteristicDiscovered"),
                object: self,
                userInfo: ["characteristic": characteristic, "peripheral": peripheral]
            )
        }
        
        self.discoveredCharacteristics[peripheral.identifier] = discoveredChars
        
        // If we found our message characteristic, try to send a HELLO message
        if let messageChar = discoveredChars[messageCharacteristicUUID] {
            // Wait a brief moment to allow peripheral to set up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.sendMessage(.hello, to: peripheral, characteristic: messageChar)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error reading characteristic value: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            print("No data received from characteristic")
            return
        }
        
        // Handle message based on which characteristic it came from
        if characteristic.uuid == messageCharacteristicUUID || 
           characteristic.uuid == responseCharacteristicUUID {
            _ = handleReceivedMessage(data, from: peripheral)
        }
        
        // Post notification about characteristic value update
        NotificationCenter.default.post(
            name: NSNotification.Name("BluetoothCharacteristicValueUpdated"),
            object: self,
            userInfo: ["characteristic": characteristic, "peripheral": peripheral]
        )
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing to characteristic: \(error.localizedDescription)")
            
            // Update UI to show connection failure
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let deviceId = peripheral.identifier.uuidString
                
                self.connectionResults[deviceId] = ConnectionResult(
                    status: .failure("Failed to send message: \(error.localizedDescription)")
                )
                
                // Update device store status
                self.deviceStore.updateConnectionStatus(
                    identifier: deviceId,
                    status: .error
                )
            }
            
            return
        }
        
        print("Successfully wrote to characteristic: \(characteristic.uuid)")
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BluetoothManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // This runs on the bluetoothQueue, update UI properties on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch peripheral.state {
            case .poweredOn:
                print("Peripheral manager powered on")
                self.startAdvertising()
            case .poweredOff:
                print("Peripheral manager powered off")
            case .resetting:
                print("Peripheral manager resetting")
            case .unauthorized:
                print("Peripheral manager unauthorized")
            case .unsupported:
                print("Peripheral manager unsupported")
            case .unknown:
                print("Peripheral manager unknown state")
            @unknown default:
                print("Peripheral manager unknown default")
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("Error adding service: \(error.localizedDescription)")
        } else {
            print("Service added successfully")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let error = error {
                print("Error starting advertising: \(error.localizedDescription)")
                self.isAdvertising = false
            } else {
                print("Advertising started successfully")
                self.isAdvertising = true
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard let data = request.value else {
                // Respond to invalid requests
                peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
                continue
            }
            
            // Handle based on characteristic
            if request.characteristic.uuid == messageCharacteristicUUID || 
               request.characteristic.uuid == responseCharacteristicUUID {
                // Try to process the message
                if handleReceivedMessage(data, from: request.central) {
                    peripheral.respond(to: request, withResult: .success)
                } else {
                    peripheral.respond(to: request, withResult: .unlikelyError)
                }
            } else if request.characteristic.uuid == syncDataCharacteristicUUID {
                // This is a sync data transfer - just accept it and post a notification
                print("[BTTransfer] Received write to sync data characteristic")
                
                // Create a dummy CBCharacteristic to use in the notification
                let dummyChar = CBMutableCharacteristic(
                    type: syncDataCharacteristicUUID,
                    properties: [.write, .notify],
                    value: data,
                    permissions: [.writeable]
                )
                
                // Post notification about the write
                NotificationCenter.default.post(
                    name: NSNotification.Name("BluetoothCharacteristicValueUpdated"),
                    object: self,
                    userInfo: [
                        "characteristic": dummyChar,
                        "peripheral": request.central
                    ]
                )
                
                peripheral.respond(to: request, withResult: .success)
            } else {
                // Unknown characteristic
                peripheral.respond(to: request, withResult: .requestNotSupported)
            }
        }
    }
    
    private func handleReceivedMessage(_ data: Data, from central: CBCentral) -> Bool {
        guard let message = String(data: data, encoding: .utf8),
              let messageType = MessageType(rawValue: message) else {
            print("Received invalid message data from central")
            return false
        }
        
        print("Received '\(messageType.rawValue)' from central")
        
        if messageType == .hello {
            // Respond with "HI" to a "HELLO"
            guard let responseChar = responseCharacteristic else {
                print("Response characteristic not found")
                return false
            }
            
            guard let data = MessageType.hi.rawValue.data(using: .utf8) else {
                print("Failed to convert HI message to data")
                return false
            }
            
            // Send response
            peripheralManager.updateValue(data, for: responseChar, onSubscribedCentrals: [central])
            return true
        }
        
        return true
    }
}