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
                        // Start a new scan
                        bluetoothManager.startScanning()
                        
                        // The BluetoothManager will automatically stop scanning after 3 seconds
                        // Just need to wait for the scan to complete before ending the refresh
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                            continuation.resume()
                        }
                    }
                }
                .overlay {
                    if bluetoothManager.discoveredDevices.isEmpty {
                        VStack {
                            Spacer()
                            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No Bluetooth Devices Found")
                                .font(.title2)
                                .padding(.top)
                            
                            Text("Pull down to refresh and scan for nearby Bluetooth devices")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding()
                                
                            Image(systemName: "arrow.down")
                                .font(.title)
                                .foregroundColor(.blue)
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
                    // Only show refresh indicator when scanning
                    if bluetoothManager.isScanning {
                        ProgressView()
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
        // No need to explicitly start scanning on appear
        // Bluetooth manager will do initial scan when ready
    }
}

struct BluetoothDeviceRow: View {
    let device: BluetoothDevice
    @State private var showTooltip = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                
                HStack {
                    Text("RSSI: \(device.displayRssi) dBm • \(device.signalStrengthDescription)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Only show this indicator if display RSSI is not the same as actual RSSI
                    if device.rssi != device.displayRssi {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .opacity(0.6)
                            .onTapGesture {
                                showTooltip.toggle()
                            }
                    }
                }
            }
            
            Spacer()
            
            // Signal strength indicator using proper SF Symbols
            SignalStrengthIndicator(strength: signalStrength(for: device.displayRssi))
                .foregroundColor(signalColor(for: device.displayRssi))
            
            if device.isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .padding(.leading, 4)
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .top) {
            if showTooltip {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Snapshot RSSI: \(device.displayRssi) dBm")
                        .font(.caption)
                    Text("Current RSSI: \(device.rssi) dBm")
                        .font(.caption)
                    Text("Updates every 60s for stability")
                        .font(.caption2)
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .padding(.top, 30)
                .transition(.opacity)
                .onTapGesture {
                    showTooltip = false
                }
                .zIndex(1)
            }
        }
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
    
    private func signalStrength(for rssi: Int) -> Int {
        if rssi > -50 {
            return 3       // Strong
        } else if rssi > -70 {
            return 2       // Medium
        } else {
            return 1       // Weak
        }
    }
}

// Custom signal strength indicator with proper SF Symbols
struct SignalStrengthIndicator: View {
    let strength: Int  // 1-3, where 3 is strongest
    
    var body: some View {
        HStack(spacing: 2) {
            Rectangle()
                .frame(width: 3, height: 5)
                .opacity(strength >= 1 ? 1.0 : 0.3)
            
            Rectangle()
                .frame(width: 3, height: 8)
                .opacity(strength >= 2 ? 1.0 : 0.3)
            
            Rectangle()
                .frame(width: 3, height: 12)
                .opacity(strength >= 3 ? 1.0 : 0.3)
        }
    }
}

struct BluetoothFooter: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack {
            Text("Last scan: \(formattedDate())")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
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