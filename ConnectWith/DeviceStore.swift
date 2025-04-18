import Foundation
import CoreBluetooth

class DeviceStore {
    static let shared = DeviceStore()
    
    private init() {}
    
    // In-memory store for devices
    private var devices: [String: BluetoothDeviceInfo] = [:]
    
    struct BluetoothDeviceInfo {
        let identifier: String
        var name: String
        var lastSeen: Date
    }
    
    // Add or update a device
    func addDevice(identifier: String, name: String) {
        let device = BluetoothDeviceInfo(
            identifier: identifier,
            name: name,
            lastSeen: Date()
        )
        devices[identifier] = device
    }
    
    // Get all devices
    func getAllDevices() -> [BluetoothDeviceInfo] {
        return Array(devices.values)
    }
    
    // Get a specific device
    func getDevice(identifier: String) -> BluetoothDeviceInfo? {
        return devices[identifier]
    }
    
    // Update a device's last seen time
    func updateLastSeen(identifier: String) {
        if var device = devices[identifier] {
            device.lastSeen = Date()
            devices[identifier] = device
        }
    }
}