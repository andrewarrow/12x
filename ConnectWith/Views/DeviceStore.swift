import Foundation
import CoreBluetooth
import SwiftUI

// Enhanced DeviceStore that supports both temporary scanning and persistent storage
class DeviceStore: ObservableObject {
    static let shared = DeviceStore()
    
    private init() {
        // Load saved devices from UserDefaults when initialized
        loadSavedDevices()
    }
    
    // MARK: - Device Models
    
    // In-memory store for discovered devices during scanning
    private var devices: [String: BluetoothDeviceInfo] = [:]
    
    // Persistent store for saved family member devices
    @Published private(set) var savedDevices: [String: SavedDeviceInfo] = [:]
    
    // Thread safety
    private let queue = DispatchQueue(label: "com.12x.DeviceStoreQueue", attributes: .concurrent)
    
    // Change tracking
    @Published private var deviceListVersion = 0
    
    // Device info for detected Bluetooth devices
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
    
    // Persistent device info for saved family member devices
    struct SavedDeviceInfo: Codable, Identifiable {
        var id: String { identifier }
        let identifier: String
        var name: String
        var displayName: String
        var lastConnected: Date?
        var connectionStatus: ConnectionStatus
        
        enum ConnectionStatus: String, Codable {
            case new
            case connected
            case error
            
            var icon: String {
                switch self {
                case .new: return "circle.dashed"
                case .connected: return "checkmark.circle.fill"
                case .error: return "exclamationmark.circle.fill" 
                }
            }
            
            var color: Color {
                switch self {
                case .new: return .gray
                case .connected: return .green
                case .error: return .red
                }
            }
        }
    }
    
    // MARK: - Temporary Device Methods (Scanning)
    
    // Add or update a device with RSSI
    func addDevice(identifier: String, name: String, rssi: Int = -100) {
        print("DEBUG: DeviceStore.addDevice called with id=\(identifier), name=\(name), rssi=\(rssi)")
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Check if we already have a device with the same name (potential duplicate with different ID)
            let matchingNameDevices = self.devices.values.filter { $0.displayName == name }
            
            if !matchingNameDevices.isEmpty {
                print("DEBUG: Found \(matchingNameDevices.count) existing devices with name '\(name)'")
                
                // We have devices with the same name, check if this is likely a duplicate
                if var existingDevice = matchingNameDevices.first {
                    // Use the existing device's identifier instead
                    print("DEBUG: Using existing device ID \(existingDevice.identifier) instead of \(identifier)")
                    existingDevice.rssi = rssi
                    existingDevice.lastSeen = Date()
                    self.devices[existingDevice.identifier] = existingDevice
                    
                    // Don't continue - we've already updated the existing device
                    
                    // Notify observers that the device list has changed
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.deviceListVersion += 1
                    }
                    return
                }
            }
            
            // Normal flow - update existing device if it exists
            if var existingDevice = self.devices[identifier] {
                existingDevice.name = name
                existingDevice.rssi = rssi
                existingDevice.lastSeen = Date()
                self.devices[identifier] = existingDevice
                print("DEBUG: DeviceStore updated existing device: \(name)")
            } else {
                // Create new device if it doesn't exist
                let device = BluetoothDeviceInfo(
                    identifier: identifier,
                    name: name,
                    rssi: rssi,
                    lastSeen: Date()
                )
                print("DEBUG: DeviceStore created new BluetoothDeviceInfo with name=\(name)")
                print("DEBUG: DeviceStore device displayName=\(device.displayName)")
                self.devices[identifier] = device
            }
            
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
    
    // Get all discovered devices
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
    
    // MARK: - Persistent Device Methods (Saved Family Members)
    
    // Add a device to the saved list (called when user selects family members)
    func saveDevice(identifier: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self,
                  let deviceInfo = self.devices[identifier] else { return }
            
            let savedDevice = SavedDeviceInfo(
                identifier: identifier,
                name: deviceInfo.name,
                displayName: deviceInfo.displayName,
                lastConnected: nil,
                connectionStatus: .new
            )
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.savedDevices[identifier] = savedDevice
                self.saveToPersistentStorage()
                self.objectWillChange.send()
            }
        }
    }
    
    // Save multiple devices at once (from selection screen)
    func saveDevices(identifiers: Set<UUID>) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            var newSavedDevices: [String: SavedDeviceInfo] = [:]
            
            for uuid in identifiers {
                let identifier = uuid.uuidString
                if let deviceInfo = self.devices[identifier] {
                    let savedDevice = SavedDeviceInfo(
                        identifier: identifier,
                        name: deviceInfo.name,
                        displayName: deviceInfo.displayName,
                        lastConnected: nil,
                        connectionStatus: .new
                    )
                    newSavedDevices[identifier] = savedDevice
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.savedDevices = newSavedDevices
                self.saveToPersistentStorage()
                self.objectWillChange.send()
            }
        }
    }
    
    // Update a saved device's connection status
    func updateConnectionStatus(identifier: String, status: SavedDeviceInfo.ConnectionStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  var device = self.savedDevices[identifier] else { return }
            
            device.connectionStatus = status
            
            if status == .connected {
                device.lastConnected = Date()
            }
            
            self.savedDevices[identifier] = device
            self.saveToPersistentStorage()
            self.objectWillChange.send()
        }
    }
    
    // Get all saved devices
    func getAllSavedDevices() -> [SavedDeviceInfo] {
        return Array(savedDevices.values)
    }
    
    // MARK: - Persistence
    
    // Save to UserDefaults
    private func saveToPersistentStorage() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(Array(savedDevices.values))
            UserDefaults.standard.set(data, forKey: "SavedDevices")
            print("DEBUG: Saved \(savedDevices.count) devices to persistent storage")
        } catch {
            print("ERROR: Failed to save devices: \(error.localizedDescription)")
        }
    }
    
    // Load from UserDefaults
    private func loadSavedDevices() {
        guard let data = UserDefaults.standard.data(forKey: "SavedDevices") else {
            print("DEBUG: No saved devices found in persistent storage")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let decodedDevices = try decoder.decode([SavedDeviceInfo].self, from: data)
            
            var loadedDevices: [String: SavedDeviceInfo] = [:]
            for device in decodedDevices {
                loadedDevices[device.identifier] = device
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.savedDevices = loadedDevices
                print("DEBUG: Loaded \(loadedDevices.count) devices from persistent storage")
                self.objectWillChange.send()
            }
        } catch {
            print("ERROR: Failed to load devices: \(error.localizedDescription)")
        }
    }
}