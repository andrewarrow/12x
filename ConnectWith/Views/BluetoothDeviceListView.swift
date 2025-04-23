import SwiftUI

struct BluetoothDeviceListView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var showingDeviceDetail = false
    @State private var selectedDevice: BluetoothDevice?
    
    var body: some View {
        NavigationView {
            VStack {
                if let error = bluetoothManager.error {
                    ErrorBanner(message: error)
                }
                
                List {
                    ForEach(bluetoothManager.discoveredDevices) { device in
                        BluetoothDeviceRow(device: device)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDevice = device
                                bluetoothManager.connect(to: device)
                                showingDeviceDetail = true
                            }
                    }
                }
                .refreshable {
                    // For iOS 16 compatibility - refreshable without returning anything
                    await withCheckedContinuation { continuation in
                        bluetoothManager.startScanning()
                        // Scan for 2 seconds then stop
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            bluetoothManager.stopScanning()
                            continuation.resume()
                        }
                    }
                }
                .overlay {
                    if bluetoothManager.discoveredDevices.isEmpty {
                        VStack {
                            Spacer()
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No Devices Found")
                                .font(.title2)
                                .padding(.top)
                            
                            Text("Pull down to scan for nearby Bluetooth devices")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding()
                            
                            Spacer()
                        }
                    }
                }
                
                BluetoothFooter()
            }
            .navigationTitle("Bluetooth Devices")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(bluetoothManager.isScanning ? "Stop Scan" : "Scan") {
                        if bluetoothManager.isScanning {
                            bluetoothManager.stopScanning()
                        } else {
                            bluetoothManager.startScanning()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDeviceDetail) {
                if let device = selectedDevice {
                    DeviceDetailView(device: device)
                        .environmentObject(bluetoothManager)
                }
            }
        }
        .onAppear {
            bluetoothManager.startScanning()
        }
        .onDisappear {
            bluetoothManager.stopScanning()
        }
    }
}

struct BluetoothDeviceRow: View {
    let device: BluetoothDevice
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                
                Text("RSSI: \(device.rssi) dBm • \(device.signalStrengthDescription)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: device.signalStrengthIcon)
                .foregroundColor(signalColor(for: device.rssi))
            
            if device.isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func signalColor(for rssi: Int) -> Color {
        if rssi > -50 {
            return .green
        } else if rssi > -70 {
            return .yellow
        } else {
            return .orange
        }
    }
}

struct BluetoothFooter: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack {
            if bluetoothManager.isScanning {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    
                    Text("Scanning for devices...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                Text("Last updated: \(formattedDate())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    private func formattedDate() -> String {
        if bluetoothManager.discoveredDevices.isEmpty {
            return "Never"
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        
        if let mostRecent = bluetoothManager.discoveredDevices.max(by: { $0.lastUpdated < $1.lastUpdated }) {
            return formatter.string(from: mostRecent.lastUpdated)
        } else {
            return "Unknown"
        }
    }
}

struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            
            Text(message)
                .foregroundColor(.white)
                .font(.subheadline)
            
            Spacer()
        }
        .padding()
        .background(Color.red)
    }
}

#Preview {
    BluetoothDeviceListView()
        .environmentObject(BluetoothManager())
}