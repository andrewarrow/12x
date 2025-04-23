import Foundation
import CoreBluetooth

// Chat message model for Bluetooth communication
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let text: String
    let senderName: String
    let timestamp: Date
    var isIncoming: Bool
    
    init(text: String, senderName: String, isIncoming: Bool = false) {
        self.id = UUID()
        self.text = text
        self.senderName = senderName
        self.timestamp = Date()
        self.isIncoming = isIncoming
    }
    
    // Convert to Data for Bluetooth transmission
    func toData() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self)
    }
    
    // Convert from Data received over Bluetooth
    static func fromData(_ data: Data) -> ChatMessage? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ChatMessage.self, from: data)
    }
}

struct BluetoothDevice: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral?
    var name: String
    
    // The actual last received RSSI value (updates frequently)
    private var _currentRssi: Int
    // The RSSI snapshot used for display and sorting (updates every 60 seconds)
    private var _displayRssi: Int
    
    // Last time the display RSSI was updated
    var lastSnapshotTime: Date = Date()
    var isConnected: Bool = false
    var lastUpdated: Date = Date()
    var isSameApp: Bool = false
    
    // Chat messages received from this device
    var receivedMessages: [ChatMessage] = []
    
    // Getter for the actual current RSSI (for details screen)
    var rssi: Int { 
        return _currentRssi 
    }
    
    // Getter for the display RSSI (for list sorting and display)
    var displayRssi: Int {
        return _displayRssi
    }
    
    init(peripheral: CBPeripheral?, name: String, rssi: Int, isSameApp: Bool = false) {
        if let peripheral = peripheral {
            self.id = peripheral.identifier
        } else {
            // For preview purposes, generate a random UUID
            self.id = UUID()
        }
        self.peripheral = peripheral
        self.name = name
        self._currentRssi = rssi
        self._displayRssi = rssi
        self.isSameApp = isSameApp
    }
    
    // Called when a new RSSI reading is received
    mutating func updateRssi(_ newRssi: Int) {
        self._currentRssi = newRssi
        self.lastUpdated = Date()
        
        // Only update the display RSSI if it's been at least 60 seconds
        // or if this is a significant change (device getting much closer or farther)
        let timeInterval = Date().timeIntervalSince(lastSnapshotTime)
        let significantChange = abs(newRssi - _displayRssi) > 20 // 20 dBm is a significant change
        
        if timeInterval > 60 || significantChange {
            self._displayRssi = newRssi
            self.lastSnapshotTime = Date()
        }
    }
    
    // Get the sort key - combines category and name for very stable ordering
    var sortKey: String {
        let categoryPrefix = String(format: "%d", signalCategory)
        // Using the full original name without any manipulation
        return "\(categoryPrefix)_\(name)_\(id.uuidString)"
    }
    
    var signalStrengthIcon: String {
        if displayRssi > -50 {
            return "wifi"
        } else if displayRssi > -70 {
            return "wifi"
        } else {
            return "wifi"
        }
    }
    
    var signalStrengthDescription: String {
        if displayRssi > -50 {
            return "Strong"
        } else if displayRssi > -70 {
            return "Good"
        } else if displayRssi > -90 {
            return "Weak"
        } else {
            return "Poor"
        }
    }
    
    // Used for sorting devices into stable buckets
    var signalCategory: Int {
        if displayRssi > -50 {
            return 1  // Close (Strong)
        } else if displayRssi > -80 {
            return 2  // Medium (Good-Weak)
        } else {
            return 3  // Far (Poor)
        }
    }
}