import SwiftUI
import CoreBluetooth

struct DevicesListView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject private var deviceStore = DeviceStore.shared
    
    var body: some View {
        List {
            Section(header: Text("Nearby Devices")) {
                if deviceStore.getDevicesSortedBySignalStrength().isEmpty {
                    HStack {
                        Spacer()
                        Text("No devices found")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ForEach(deviceStore.getDevicesSortedBySignalStrength(), id: \.identifier) { deviceInfo in
                        DeviceRowInfo(deviceInfo: deviceInfo)
                            .onTapGesture {
                                if let device = bluetoothManager.nearbyDevices.first(where: { $0.identifier.uuidString == deviceInfo.identifier }) {
                                    bluetoothManager.connectToDevice(device)
                                }
                            }
                    }
                }
            }
            
            Section(header: Text("Connected Devices")) {
                if bluetoothManager.connectedPeripherals.isEmpty {
                    HStack {
                        Spacer()
                        Text("No connected devices")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ForEach(bluetoothManager.connectedPeripherals, id: \.identifier) { device in
                        DeviceRow(device: device)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Available Devices")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // First ensure we stop any existing scanning to reset state
                    bluetoothManager.stopScanning()
                    
                    // Create a state indicator for UI feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    print("Refresh: Starting new device scan...")
                    
                    // Start scanning with fresh state
                    bluetoothManager.startScanning()
                    
                    // Save initial device count to detect new devices
                    let initialSavedCount = deviceStore.getAllSavedDevices().count
                    let initialDiscoveredCount = deviceStore.getAllDevices().count
                    
                    // Process the results after a reasonable scan period
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        // Stop scanning after our timeout
                        bluetoothManager.stopScanning()
                        
                        // Get all devices from the updated device store
                        let allDevices = deviceStore.getAllDevices()
                        let savedIdentifierSet = Set(deviceStore.getAllSavedDevices().map { $0.identifier })
                        
                        print("Refresh: Found \(allDevices.count) total devices, \(initialDiscoveredCount) were already known")
                        
                        // Identify new devices that aren't already saved
                        var newDevicesAdded = 0
                        
                        for device in allDevices {
                            if !savedIdentifierSet.contains(device.identifier) {
                                print("Refresh: Found new device \(device.displayName) with ID \(device.identifier)")
                                // Add as a new device
                                deviceStore.saveDevice(identifier: device.identifier)
                                newDevicesAdded += 1
                            }
                        }
                        
                        // Verify by comparing saved count 
                        let finalSavedCount = deviceStore.getAllSavedDevices().count
                        print("Refresh: Added \(newDevicesAdded) new devices. Initial saved: \(initialSavedCount), Final saved: \(finalSavedCount)")
                        
                        // Provide haptic feedback on completion
                        let completionFeedback = UINotificationFeedbackGenerator()
                        completionFeedback.notificationOccurred(newDevicesAdded > 0 ? .success : .warning)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: CBPeripheral
    
    var body: some View {
        HStack {
            Image(systemName: "iphone.circle.fill")
                .font(.title)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(device.name ?? "Unknown Device")
                    .font(.headline)
                
                Text(device.identifier.uuidString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

struct DeviceRowInfo: View {
    let deviceInfo: DeviceStore.BluetoothDeviceInfo
    
    var body: some View {
        HStack {
            Image(systemName: "iphone.circle.fill")
                .font(.title)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(deviceInfo.displayName)
                    .font(.headline)
                
                Text(deviceInfo.identifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(deviceInfo.signalStrength)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    DevicesListView(bluetoothManager: BluetoothManager())
}