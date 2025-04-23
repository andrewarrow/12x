import SwiftUI

struct BluetoothDeviceListView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var showingDeviceDetail = false
    @State private var selectedDevice: BluetoothDevice?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - simple color that adapts to light/dark mode
                Color(UIColor.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Error Banner (if needed)
                    if let error = bluetoothManager.error {
                        ErrorBanner(message: error)
                    }
                    
                    // Safe area spacer
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 8)
                    
                    // Simple List with built-in refreshable that works reliably
                    List {
                        // Section header
                        Section(header: Text("NEARBY DEVICES").font(.caption).foregroundColor(.secondary)) {
                            // Empty state or device rows
                            if bluetoothManager.discoveredDevices.isEmpty {
                                EmptyDeviceListView()
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            } else {
                                ForEach(bluetoothManager.discoveredDevices) { device in
                                    BluetoothDeviceRow(device: device)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedDevice = device
                                            bluetoothManager.connect(to: device)
                                            showingDeviceDetail = true
                                        }
                                        .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    // Standard pull-to-refresh with an animation that works reliably
                    .refreshable {
                        // Clear & immediate feedback to the user
                        print("Refreshing...")
                        
                        // Perform the scan (this happens AFTER the user releases)
                        await performScan()
                    }
                    
                    // Footer with last scan time
                    BluetoothFooter()
                }
            }
            .navigationTitle("Bluetooth Devices")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingDeviceDetail) {
                if let device = selectedDevice {
                    DeviceDetailView(device: device)
                        .environmentObject(bluetoothManager)
                }
            }
        }
        .accentColor(Color.blue)
    }
    
    // Helper method to handle pull-to-refresh
    func performScan() async {
        // Use the special refresh method that doesn't update UI until complete
        bluetoothManager.performRefresh()
        
        // Wait for scan to complete (3 seconds)
        do {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        } catch {
            print("Sleep interrupted")
        }
    }
}

// Empty state view with better dark mode support
struct EmptyDeviceListView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 50))
                    .foregroundColor(Color.accentColor)
            }
            .padding(.top, 30)
            
            // Text
            Text("No Bluetooth Devices Found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Pull down to refresh and scan for nearby Bluetooth devices")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 10)
            
            // Pull indicator
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(Color.accentColor.opacity(0.8))
                .padding(.bottom, 30)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5)
        )
        .padding(.horizontal, 20)
    }
}

// Bluetooth device row with better dark mode support
struct BluetoothDeviceRow: View {
    let device: BluetoothDevice
    @State private var showTooltip = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(device.name)
                    .font(.headline)
                    .foregroundColor(device.isSameApp ? .white : .primary)
                
                HStack {
                    Text("RSSI: \(device.displayRssi) dBm")
                        .font(.subheadline)
                        .foregroundColor(device.isSameApp ? .white.opacity(0.9) : .secondary)
                    
                    Text("•")
                        .foregroundColor(device.isSameApp ? .white.opacity(0.9) : .secondary)
                    
                    Text(device.signalStrengthDescription)
                        .font(.subheadline)
                        .foregroundColor(device.isSameApp ? .white : signalColor(for: device.displayRssi))
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            // Signal strength indicator with better visual style
            HStack(spacing: 8) {
                SignalStrengthIndicator(strength: signalStrength(for: device.displayRssi))
                    .foregroundColor(device.isSameApp ? .white : signalColor(for: device.displayRssi))
                
                if device.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(device.isSameApp ? .white : .green)
                        .font(.system(size: 18))
                }
                
                if device.isSameApp {
                    Image(systemName: "person.wave.2.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(device.isSameApp ? 
                      (colorScheme == .dark ? Color.blue : Color.blue) : 
                      Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(device.isSameApp ? 
                        Color.white.opacity(0.3) : 
                        Color.gray.opacity(colorScheme == .dark ? 0.1 : 0.2), 
                        lineWidth: device.isSameApp ? 2.0 : 0.5)
        )
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

// Custom signal strength indicator with modern design
struct SignalStrengthIndicator: View {
    let strength: Int  // 1-3, where 3 is strongest
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 3) {
            Capsule()
                .frame(width: 4, height: 8)
                .opacity(strength >= 1 ? 1.0 : (colorScheme == .dark ? 0.4 : 0.25))
            
            Capsule()
                .frame(width: 4, height: 12)
                .opacity(strength >= 2 ? 1.0 : (colorScheme == .dark ? 0.4 : 0.25))
            
            Capsule()
                .frame(width: 4, height: 16)
                .opacity(strength >= 3 ? 1.0 : (colorScheme == .dark ? 0.4 : 0.25))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
    }
}

// Enhanced footer with adaptive colors
struct BluetoothFooter: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: "clock")
                .font(.caption)
                .foregroundColor(Color.accentColor.opacity(0.8))
            
            Text("Last scan: \(formattedDate())")
                .font(.caption)
                .foregroundColor(.primary.opacity(0.8))
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(UIColor.systemGroupedBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: -2)
        )
    }
    
    private func formattedDate() -> String {
        if bluetoothManager.discoveredDevices.isEmpty {
            return "Never"
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        
        // Use the tracked last scan date
        return formatter.string(from: bluetoothManager.getLastScanDate())
    }
}

// Enhanced error banner
struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
                .font(.system(size: 16))
                .padding(.trailing, 4)
            
            Text(message)
                .foregroundColor(.white)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.red.opacity(0.8), Color.red.opacity(0.9)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    BluetoothDeviceListView()
        .environmentObject(BluetoothManager())
}