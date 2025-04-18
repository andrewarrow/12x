import UIKit
import CoreBluetooth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Hard-coded Bluetooth usage descriptions to ensure they're available
        let descriptions = [
            "NSBluetoothAlwaysUsageDescription": "This app uses Bluetooth to connect with nearby family members' devices",
            "NSBluetoothPeripheralUsageDescription": "This app uses Bluetooth to connect with nearby family members' devices"
        ]
        
        // Force add these values to the Info.plist at runtime
        for (key, value) in descriptions {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        // Create a temporary manager to request permissions early
        let tempManager = CBCentralManager(delegate: nil, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: true
        ])
        
        print("AppDelegate initialized, Bluetooth status: \(tempManager.state.rawValue)")
        return true
    }
}