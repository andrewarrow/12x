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
                    bluetoothManager.startScanning()
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