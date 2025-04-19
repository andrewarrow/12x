import Foundation
import CoreBluetooth
import SwiftUI

class DeviceStore: ObservableObject {
    static let shared = DeviceStore()
    
    private init() {}
    
    // In-memory store for devices
    private var devices: [String: BluetoothDeviceInfo] = [:]
    private let queue = DispatchQueue(label: "com.12x.DeviceStoreQueue", attributes: .concurrent)
    
    @Published private var deviceListVersion = 0
    
    struct BluetoothDeviceInfo {
        let identifier: String
        var name: String
        var rssi: Int
        var lastSeen: Date
        
        // Human-friendly name without signal strength indicators
        var displayName: String {
            // Extract just the name part before any signal strength indicators
            if let range = name.range(of: " (📶") {
                return String(name[..<range.lowerBound])
            }
            return name
        }
        
        // Signal strength as a raw RSSI value
        var signalStrength: String {
            return "\(rssi) dBm"
        }
    }
    
    // Add or update a device with RSSI
    func addDevice(identifier: String, name: String, rssi: Int = -100) {
        print("DEBUG: DeviceStore.addDevice called with id=\(identifier), name=\(name), rssi=\(rssi)")
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let device = BluetoothDeviceInfo(
                identifier: identifier,
                name: name,
                rssi: rssi,
                lastSeen: Date()
            )
            print("DEBUG: DeviceStore created BluetoothDeviceInfo with name=\(name)")
            print("DEBUG: DeviceStore device displayName=\(device.displayName)")
            self.devices[identifier] = device
            
            // Print all devices after adding
            print("DEBUG: DeviceStore now contains \(self.devices.count) devices:")
            for (id, dev) in self.devices {
                print("DEBUG: - ID: \(id.prefix(8))... Name: \(dev.displayName), Signal: \(dev.signalStrength)")
            }
            
            // Notify observers that the device list has changed
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.deviceListVersion += 1
            }
        }
    }
    
    // Update a device with new information
    func updateDevice(identifier: String, name: String, rssi: Int) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if var device = self.devices[identifier] {
                device.name = name
                device.rssi = rssi
                device.lastSeen = Date()
                self.devices[identifier] = device
                
                // Notify observers that the device list has changed
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.deviceListVersion += 1
                }
            } else {
                // If device doesn't exist, add it
                self.addDevice(identifier: identifier, name: name, rssi: rssi)
            }
        }
    }
    
    // Get all devices
    func getAllDevices() -> [BluetoothDeviceInfo] {
        var result: [BluetoothDeviceInfo] = []
        queue.sync {
            result = Array(devices.values)
        }
        return result
    }
    
    // Get a specific device
    func getDevice(identifier: String) -> BluetoothDeviceInfo? {
        var result: BluetoothDeviceInfo?
        queue.sync {
            result = devices[identifier]
        }
        return result
    }
    
    // Update a device's last seen time
    func updateLastSeen(identifier: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if var device = self.devices[identifier] {
                device.lastSeen = Date()
                self.devices[identifier] = device
            }
        }
    }
    
    // Get devices sorted by signal strength (best first)
    func getDevicesSortedBySignalStrength() -> [BluetoothDeviceInfo] {
        var result: [BluetoothDeviceInfo] = []
        queue.sync {
            result = Array(devices.values).sorted { $0.rssi > $1.rssi }
        }
        return result
    }
}