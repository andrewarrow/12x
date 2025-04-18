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
        
        // Start advertising
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "12x App \(UIDevice.current.name)"
        ])
        
        // Update UI values on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAdvertising = true
        }
        
        print("Started advertising")
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
        let deviceName = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown Device"
        
        // Only add devices that have "12x App" in their name
        guard deviceName.contains("12x App") else {
            return
        }
        
        // Update collection on main thread since it affects UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // See if we already found this device
            if !self.nearbyDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                print("Discovered device: \(deviceName) (\(peripheral.identifier))")
                self.nearbyDevices.append(peripheral)
                
                // Save to our device store
                self.deviceStore.addDevice(identifier: peripheral.identifier.uuidString, name: deviceName)
            }
        }
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