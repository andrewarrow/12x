import Foundation
import CoreBluetooth
import Combine

// The state of the scanning process
enum ScanningState {
    case notScanning
    case scanning
    case refreshing // Special state where we're scanning but data shouldn't be displayed yet
}

class BluetoothManager: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    
    // Published properties that trigger UI updates
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var scanningState: ScanningState = .notScanning
    @Published var connectedDevice: BluetoothDevice?
    @Published var characteristics: [CBCharacteristic] = []
    @Published var services: [CBService] = []
    @Published var isConnecting = false
    @Published var error: String?
    
    // Private properties - used internally but don't trigger UI updates
    private var tempDiscoveredDevices: [BluetoothDevice] = []
    private var lastScanDate: Date = Date()
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        // Scanning will automatically start once Bluetooth is powered on
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
    
    func connect(to device: BluetoothDevice) {
        isConnecting = true
        if let peripheral = device.peripheral {
            centralManager.connect(peripheral, options: nil)
        } else {
            isConnecting = false
            error = "Cannot connect to this device"
        }
    }
    
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
    
    // Temp holder for scan results - doesn't trigger UI updates
    private func addDiscoveredDevice(peripheral: CBPeripheral, rssi: NSNumber) {
        let currentRssi = rssi.intValue
        
        if let index = tempDiscoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            // Update existing device
            tempDiscoveredDevices[index].updateRssi(currentRssi)
        } else {
            // Add new device
            let newDevice = BluetoothDevice(
                peripheral: peripheral,
                name: peripheral.name ?? "Unknown Device",
                rssi: currentRssi
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
    private func updateDeviceList(peripheral: CBPeripheral, rssi: NSNumber) {
        let currentRssi = rssi.intValue
        
        if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            // Update existing device
            discoveredDevices[index].updateRssi(currentRssi)
        } else {
            // Add new device
            let newDevice = BluetoothDevice(
                peripheral: peripheral,
                name: peripheral.name ?? "Unknown Device",
                rssi: currentRssi
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
        // Update the appropriate list based on scanning state
        DispatchQueue.main.async {
            switch self.scanningState {
            case .refreshing:
                // During refresh, update the temporary list
                self.addDiscoveredDevice(peripheral: peripheral, rssi: RSSI)
                
            case .scanning:
                // During normal scanning, update the visible list
                self.updateDeviceList(peripheral: peripheral, rssi: RSSI)
                
            case .notScanning:
                // Shouldn't happen, but just in case
                break
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        
        if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[index].isConnected = true
            connectedDevice = discoveredDevices[index]
        }
        
        isConnecting = false
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnecting = false
        self.error = error?.localizedDescription ?? "Failed to connect"
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

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            self.error = "Error discovering services: \(error.localizedDescription)"
            return
        }
        
        if let services = peripheral.services {
            self.services = services
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            self.error = "Error discovering characteristics: \(error.localizedDescription)"
            return
        }
        
        if let characteristics = service.characteristics {
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
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            self.error = "Error reading characteristic value: \(error.localizedDescription)"
            return
        }
        
        // Just refresh the list to show updated values
        objectWillChange.send()
    }
}