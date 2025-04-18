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
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        print("BluetoothManager initialized")
        os_log("BluetoothManager initialized", log: OSLog.default, type: .info)
    }
    
    // MARK: - Central Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            scanningMessage = "Bluetooth is not powered on"
            return
        }
        
        nearbyDevices.removeAll()
        
        // Start scanning for devices with our service UUID
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        isScanning = true
        scanningMessage = "Scanning for devices..."
        print("Started scanning for devices")
        os_log("Started scanning for BLE devices", log: OSLog.default, type: .info)
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        scanningMessage = "Scanning stopped"
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
        
        isAdvertising = true
        print("Started advertising")
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        isAdvertising = false
        print("Stopped advertising")
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Central manager powered on")
            startScanning()
            startAdvertising()
        case .poweredOff:
            print("Central manager powered off")
            scanningMessage = "Bluetooth is powered off"
        case .resetting:
            print("Central manager resetting")
        case .unauthorized:
            print("Central manager unauthorized")
            scanningMessage = "Bluetooth permission denied"
        case .unsupported:
            print("Central manager unsupported")
            scanningMessage = "Bluetooth not supported"
        case .unknown:
            print("Central manager unknown state")
        @unknown default:
            print("Central manager unknown default")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Check if the device has a name
        let deviceName = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown Device"
        
        // Only add devices that have "12x App" in their name
        guard deviceName.contains("12x App") else {
            return
        }
        
        // See if we already found this device
        if !nearbyDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            print("Discovered device: \(deviceName) (\(peripheral.identifier))")
            nearbyDevices.append(peripheral)
            
            // Save to our device store
            deviceStore.addDevice(identifier: peripheral.identifier.uuidString, name: deviceName)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to device: \(peripheral.name ?? peripheral.identifier.uuidString)")
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
        
        if !connectedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            connectedPeripherals.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to device: \(peripheral.name ?? peripheral.identifier.uuidString), error: \(error?.localizedDescription ?? "unknown error")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from device: \(peripheral.name ?? peripheral.identifier.uuidString)")
        connectedPeripherals.removeAll(where: { $0.identifier == peripheral.identifier })
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
        switch peripheral.state {
        case .poweredOn:
            print("Peripheral manager powered on")
            startAdvertising()
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
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("Error adding service: \(error.localizedDescription)")
        } else {
            print("Service added successfully")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Error starting advertising: \(error.localizedDescription)")
        } else {
            print("Advertising started successfully")
        }
    }
}