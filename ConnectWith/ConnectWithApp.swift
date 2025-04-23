import SwiftUI

@main
struct ConnectWithApp: App {
    @State private var isShowingSplash = true
    @StateObject private var bluetoothManager = BluetoothManager()
    
    init() {
        // Set up any app initialization here
        print("App initializing with Bluetooth manager")
    }
    
    var body: some Scene {
        WindowGroup {
            if isShowingSplash {
                SplashScreen(isShowingSplash: $isShowingSplash)
            } else {
                BluetoothDeviceListView()
                    .environmentObject(bluetoothManager)
            }
        }
    }
}