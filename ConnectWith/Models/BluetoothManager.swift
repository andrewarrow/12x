import Foundation
import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var connectedDevice: BluetoothDevice?
    @Published var isScanning = false
    @Published var characteristics: [CBCharacteristic] = []
    @Published var services: [CBService] = []
    @Published var isConnecting = false
    @Published var error: String?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        
        isScanning = true
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }
    
    func connect(to device: BluetoothDevice) {
        isConnecting = true
        if let peripheral = device.peripheral {
            centralManager.connect(peripheral, options: nil)
        } else {
            // Handle preview or error case
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
    
    private func updateDeviceList(with peripheral: CBPeripheral, rssi: NSNumber) {
        if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[index].rssi = rssi.intValue
            discoveredDevices[index].lastUpdated = Date()
        } else {
            let newDevice = BluetoothDevice(
                peripheral: peripheral,
                name: peripheral.name ?? "Unknown Device",
                rssi: rssi.intValue
            )
            discoveredDevices.append(newDevice)
        }
        
        // Sort devices by signal strength
        discoveredDevices.sort { $0.rssi > $1.rssi }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            startScanning()
        case .poweredOff:
            print("Bluetooth is powered off")
            error = "Bluetooth is powered off"
            isScanning = false
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
        DispatchQueue.main.async {
            self.updateDeviceList(with: peripheral, rssi: RSSI)
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