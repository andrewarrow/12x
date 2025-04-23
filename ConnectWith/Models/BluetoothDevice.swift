import Foundation
import CoreBluetooth

struct BluetoothDevice: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral?
    var name: String
    var rssi: Int
    var isConnected: Bool = false
    var lastUpdated: Date = Date()
    
    init(peripheral: CBPeripheral?, name: String, rssi: Int) {
        if let peripheral = peripheral {
            self.id = peripheral.identifier
        } else {
            // For preview purposes, generate a random UUID
            self.id = UUID()
        }
        self.peripheral = peripheral
        self.name = name
        self.rssi = rssi
    }
    
    var signalStrengthIcon: String {
        if rssi > -50 {
            return "wifi.high"
        } else if rssi > -70 {
            return "wifi.medium"
        } else {
            return "wifi.low"
        }
    }
    
    var signalStrengthDescription: String {
        if rssi > -50 {
            return "Strong"
        } else if rssi > -70 {
            return "Good"
        } else if rssi > -90 {
            return "Weak"
        } else {
            return "Poor"
        }
    }
}