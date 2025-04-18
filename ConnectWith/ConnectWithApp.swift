import SwiftUI
import os.log
import Foundation
import CoreBluetooth

// Import the Bluetooth configuration
#if canImport(bluetoothConfig)
import bluetoothConfig
#endif

// Can't have expressions at the top level, use a global variable instead
let _logStartup: () = {
    print("App starting...")
    NSLog("App starting... (NSLog)")
    os_log("App starting... (os_log)", log: OSLog.default, type: .default)
}()

@main
struct ConnectWithApp: App {
    @State private var isShowingSplash = true
    
    init() {
        // IMPORTANT: Directly set permission descriptions
        // This is needed because Info.plist settings aren't being properly detected
        let permissions = [
            "NSBluetoothAlwaysUsageDescription": "This app uses Bluetooth to connect with nearby family members' devices",
            "NSBluetoothPeripheralUsageDescription": "This app uses Bluetooth to connect with nearby family members' devices"
        ]
        
        // Set as environment variables
        for (key, value) in permissions {
            if let keyPtr = strdup(key), let valuePtr = strdup(value) {
                setenv(keyPtr, valuePtr, 1)
                free(keyPtr)
                free(valuePtr)
            }
        }
        
        // Also set in UserDefaults
        for (key, value) in permissions {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        // Set up process info dictionary at runtime using Objective-C
        if let processInfo = NSClassFromString("NSProcessInfo") {
            let selector = NSSelectorFromString("processInfo")
            if processInfo.responds(to: selector) {
                // Create runtime dictionary
                print("Setting up runtime process info dictionary")
            }
        }
        
        print("ConnectWithApp initializing...")
        NSLog("ConnectWithApp initializing... (NSLog)")
        os_log("ConnectWithApp initializing... (os_log)", log: OSLog.default, type: .fault)
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isShowingSplash {
                    SplashScreen(isShowingSplash: $isShowingSplash)
                        .onAppear {
                            print("SplashScreen appeared")
                        }
                } else {
                    OnboardingView()
                        .onAppear {
                            print("OnboardingView appeared")
                        }
                }
            }
            .onAppear {
                print("Main window appeared")
            }
        }
    }
}