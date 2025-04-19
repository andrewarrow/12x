import Foundation
import CoreBluetooth
import Combine
import os.log

class BluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var nearbyDevices: [CBPeripheral] = []
    @Published var connectedPeripherals: [CBPeripheral] = []
    @Published var isScanning: Bool = false
    @Published var isAdvertising: Bool = false
    @Published var scanningMessage: String = "Not scanning"
    
    // MARK: - Core Bluetooth Managers
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    
    // MARK: - UUIDs
    private let serviceUUID = CBUUID(string: "4514d666-d6c9-49cb-bc31-dc6dfa28bd58")
    
    // MARK: - Device Store
    private let deviceStore = DeviceStore.shared
    
    // MARK: - Initialization
    
    // Use a dedicated serial queue for Bluetooth operations
    private let bluetoothQueue = DispatchQueue(label: "com.12x.BluetoothQueue", qos: .userInitiated)
    
    override init() {
        super.init()
        
        // Use our dedicated queue for Bluetooth operations instead of the main queue
        centralManager = CBCentralManager(delegate: self, queue: bluetoothQueue)
        peripheralManager = CBPeripheralManager(delegate: self, queue: bluetoothQueue)
        
        print("BluetoothManager initialized with dedicated queue")
        os_log("BluetoothManager initialized with dedicated queue", log: OSLog.default, type: .info)
    }
    
    // MARK: - Central Methods
    func startScanning() {
        // First check if Bluetooth is ready
        guard centralManager.state == .poweredOn else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.scanningMessage = "Bluetooth is not powered on"
            }
            return
        }
        
        // Update UI values on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.nearbyDevices.removeAll()
            self.isScanning = true
            self.scanningMessage = "Scanning for devices..."
        }
        
        // Start scanning for devices with our service UUID
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        print("Started scanning for devices")
        os_log("Started scanning for BLE devices", log: OSLog.default, type: .info)
    }
    
    func stopScanning() {
        centralManager.stopScan()
        
        // Update UI values on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isScanning = false
            self.scanningMessage = "Scanning stopped"
        }
        
        print("Stopped scanning for devices")
    }
    
    func connectToDevice(_ peripheral: CBPeripheral) {
        centralManager.connect(peripheral, options: nil)
        print("Connecting to device: \(peripheral.name ?? peripheral.identifier.uuidString)")
    }
    
    // MARK: - Peripheral Methods
    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else {
            print("Peripheral manager not powered on")
            return
        }
        
        // Create the service
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        // Add the service to the peripheral manager
        peripheralManager.add(service)
        
        // Get the device name - using better personalization
        var deviceName = UIDevice.current.name
        print("DEBUG: UIDevice.current.name = \(deviceName)")
        
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
        
        print("DEBUG: Final device name for advertising = \(deviceName)")
        
        // Start advertising with a format that will be easy to parse on other devices
        // We include just the device name to make identification easier
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: deviceName
        ])
        
        // Update UI values on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAdvertising = true
        }
        
        print("Started advertising as: \(deviceName)")
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        
        // Update UI values on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAdvertising = false
        }
        
        print("Stopped advertising")
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // This callback runs on the bluetoothQueue, so update UI properties on main thread
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
        let fullDeviceName = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown Device"
        
        // Don't filter by name prefix anymore - accept all devices with our service UUID
        // The service UUID is already used as the filter in scanForPeripherals
        
        // Extract the human-readable portion of the name (similar to AirDrop)
        // For example, from "12x App Bob's iPhone" extract "Bob"
        let cleanedName = extractHumanName(from: fullDeviceName)
        print("DEBUG: Discovered device with full name = \(fullDeviceName)")
        print("DEBUG: Extracted human name = \(cleanedName)")
        
        // Format the device name to include RSSI signal strength for better identification
        // RSSI ranges typically from -30 (very close) to -100 (far away)
        let signalStrength = formatSignalStrength(RSSI.intValue)
        let deviceName = "\(cleanedName) \(signalStrength)"
        print("DEBUG: Final formatted device name = \(deviceName)")
        
        // Update collection on main thread since it affects UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Check if we already have this peripheral in the array
            if !self.nearbyDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                print("Discovered device: \(deviceName) (\(peripheral.identifier)) with RSSI: \(RSSI)")
                self.nearbyDevices.append(peripheral)
            }
            
            // Always update device in the store (which handles duplicates by ID)
            print("DEBUG: Updating device store with identifier: \(peripheral.identifier.uuidString)")
            print("DEBUG: Adding/updating device with name: \(deviceName)")
            print("DEBUG: Adding/updating device with RSSI: \(RSSI.intValue)")
            self.deviceStore.updateDevice(identifier: peripheral.identifier.uuidString, name: deviceName, rssi: RSSI.intValue)
        }
    }
    
    // Extracts human name from device name, similar to AirDrop
    private func extractHumanName(from deviceName: String) -> String {
        // Don't remove any prefix, just use the device name directly
        var name = deviceName
        print("DEBUG: extractHumanName from original: \(name)")
        
        // Common patterns to extract human names
        let patterns = [
            "^(.*?)'s iPhone", // Bob's iPhone
            "^(.*?)'s iPad",   // Bob's iPad
            "^(.*?)'s Mac",    // Bob's Mac
            "^(.*?)'s .*",     // Bob's Device
            "^(.*?) iPhone",   // Bob iPhone
            "^(.*?) iPad",     // Bob iPad
            "iPhone \\((.*)\\)",  // iPhone (Bob)
        ]
        
        // Try to match against known patterns
        for pattern in patterns {
            print("DEBUG: Trying pattern: \(pattern)")
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: name, options: [], range: NSRange(name.startIndex..., in: name)) {
                
                print("DEBUG: Pattern matched: \(pattern)")
                // If the pattern has a capture group, extract it
                if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: name) {
                    let extractedName = String(name[range])
                    print("DEBUG: Extracted name from pattern: \(extractedName)")
                    if !extractedName.isEmpty {
                        return extractedName
                    }
                }
            }
        }
        print("DEBUG: No patterns matched")
        
        // Get the device name directly from UIDevice for this device, or try to extract owner name
        if name == "iPhone" || name == "iPad" || name == "Mac" {
            // For generic device names like "iPhone", use the full device name with a uuid
            let result = "\(name) \(abs(deviceName.hashValue % 1000))"
            print("DEBUG: Generic device, returning with hash: \(result)")
            return result
        } else if name.lowercased().contains("iphone") || name.lowercased().contains("ipad") || name.lowercased().contains("mac") {
            // For device names that include model but no person name, add identifier
            let result = "User \(abs(deviceName.hashValue % 100))'s \(name)"
            print("DEBUG: Model name without person name, returning: \(result)")
            return result
        }
        
        print("DEBUG: Returning unmodified name: \(name)")
        return name
    }
    
    // Format signal strength as just the RSSI value
    private func formatSignalStrength(_ rssi: Int) -> String {
        return "(📶 \(rssi) dBm)"
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to device: \(peripheral.name ?? peripheral.identifier.uuidString)")
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
        
        // Update UI collection on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !self.connectedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                self.connectedPeripherals.append(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to device: \(peripheral.name ?? peripheral.identifier.uuidString), error: \(error?.localizedDescription ?? "unknown error")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from device: \(peripheral.name ?? peripheral.identifier.uuidString)")
        
        // Update UI collection on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connectedPeripherals.removeAll(where: { $0.identifier == peripheral.identifier })
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
        }
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
}