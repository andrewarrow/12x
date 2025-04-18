import Foundation
import CoreBluetooth

// This file contains runtime Bluetooth configuration
// Since it's challenging to modify the Info.plist build settings without Xcode,
// this file provides a way to override those settings at runtime

// Set environment variables for Bluetooth permissions
func setupBluetoothPermissions() {
    // These values will be used if Info.plist entries are not found
    setenv("NSBluetoothAlwaysUsageDescription", "This app uses Bluetooth to connect with nearby family members' devices", 1)
    setenv("NSBluetoothPeripheralUsageDescription", "This app uses Bluetooth to connect with nearby family members' devices", 1)
    
    // Also set as UserDefaults
    let defaults = UserDefaults.standard
    defaults.set("This app uses Bluetooth to connect with nearby family members' devices", forKey: "NSBluetoothAlwaysUsageDescription")
    defaults.set("This app uses Bluetooth to connect with nearby family members' devices", forKey: "NSBluetoothPeripheralUsageDescription")
    
    // Print setup confirmation
    print("Bluetooth permissions configured at runtime")
    print("NSBluetoothAlwaysUsageDescription: \(getenv("NSBluetoothAlwaysUsageDescription") ?? "not set")")
    print("NSBluetoothPeripheralUsageDescription: \(getenv("NSBluetoothPeripheralUsageDescription") ?? "not set")")
    
    // Info.plist check
    let bundle = Bundle.main
    if let usageDesc = bundle.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") as? String {
        print("Info.plist has NSBluetoothAlwaysUsageDescription: \(usageDesc)")
    } else {
        print("⚠️ WARNING: Info.plist missing NSBluetoothAlwaysUsageDescription!")
    }
}

// Call this function before any Bluetooth operations
// setupBluetoothPermissions()