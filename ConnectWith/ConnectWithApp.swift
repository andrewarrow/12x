import SwiftUI

@main
struct ConnectWithApp: App {
    @State private var isShowingSplash = true
    @StateObject private var bluetoothManager = BluetoothManager()
    
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