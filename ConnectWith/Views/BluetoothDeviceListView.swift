import SwiftUI

struct BluetoothDeviceListView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var showingDeviceDetail = false
    @State private var selectedDevice: BluetoothDevice?
    
    // Track refresh state completely separately from the scanning state
    @State private var isRefreshing = false
    
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
                    
                    // Device List
                    ScrollView {
                        // Pull-to-refresh implementation using built-in refreshable
                        RefreshableScrollView(
                            onRefresh: { done in
                                // Signal that refresh has started
                                isRefreshing = true
                                
                                // Start scanning only after the pull is released
                                Task {
                                    // Give UI time to update
                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                    
                                    // Actually perform the scan
                                    bluetoothManager.performScan()
                                    
                                    // Wait for scan to complete
                                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                                    
                                    // Complete the refresh
                                    isRefreshing = false
                                    done()
                                }
                            }
                        ) {
                            LazyVStack(spacing: 10) {
                                // Header for the list
                                HStack {
                                    Text("NEARBY DEVICES")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fontWeight(.semibold)
                                        .padding(.leading, 16)
                                        .padding(.top, 20)
                                        .padding(.bottom, 8)
                                    
                                    Spacer()
                                    
                                    // Show number of devices
                                    if !bluetoothManager.discoveredDevices.isEmpty {
                                        Text("\(bluetoothManager.discoveredDevices.count)")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.accentColor)
                                            .clipShape(Capsule())
                                            .padding(.trailing, 16)
                                    }
                                }
                                
                                // Device list
                                if bluetoothManager.discoveredDevices.isEmpty {
                                    // Empty state
                                    EmptyDeviceListView()
                                } else {
                                    // Device rows
                                    ForEach(bluetoothManager.discoveredDevices) { device in
                                        BluetoothDeviceRow(device: device)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedDevice = device
                                                bluetoothManager.connect(to: device)
                                                showingDeviceDetail = true
                                            }
                                            .padding(.horizontal, 16)
                                    }
                                }
                                
                                // Bottom spacer
                                Spacer(minLength: 40)
                            }
                        }
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
}

// A custom RefreshableScrollView that provides reliable iOS-like pull-to-refresh
struct RefreshableScrollView<Content: View>: View {
    var onRefresh: (@escaping () -> Void) -> Void
    let content: Content
    
    @State private var previousScrollOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var frozen: Bool = false
    @State private var refreshing: Bool = false
    
    init(onRefresh: @escaping (@escaping () -> Void) -> Void, @ViewBuilder content: () -> Content) {
        self.onRefresh = onRefresh
        self.content = content()
    }
    
    var body: some View {
        VStack {
            ScrollView {
                ZStack(alignment: .top) {
                    MovingView()
                    
                    VStack {
                        if refreshing {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding(.top, 20)
                        }
                        
                        content
                            .alignmentGuide(.top) { d in
                                // Store the current scroll position if we're refreshing
                                if refreshing {
                                    return -scrollOffset + d[.top]
                                } else {
                                    return d[.top]
                                }
                            }
                    }
                }
                .background(FixedView())
            }
            .disabled(refreshing) // Disable scrolling while refreshing
        }
        .onPreferenceChange(RefreshableKeyTypes.PrefKey.self) { values in
            self.refreshLogic(values: values)
        }
    }
    
    func refreshLogic(values: [RefreshableKeyTypes.PrefData]) {
        DispatchQueue.main.async {
            // Calculate scroll offset
            let movingBounds = values.first(where: { $0.vType == .movingView })?.bounds ?? .zero
            let fixedBounds = values.first(where: { $0.vType == .fixedView })?.bounds ?? .zero
            
            // Negative because scrollView.contentOffset.y is negative when pulled down
            self.scrollOffset = movingBounds.minY - fixedBounds.minY
            
            // If we're already refreshing, don't do anything
            if refreshing {
                return
            }
            
            // If offset crosses threshold and scrolling upwards, start refresh
            if previousScrollOffset > 120 && scrollOffset < 80 && scrollOffset < previousScrollOffset {
                refreshing = true
                onRefresh {
                    withAnimation(.linear) {
                        self.refreshing = false
                    }
                }
            }
            
            // Update previous offset
            previousScrollOffset = scrollOffset
        }
    }
    
    struct MovingView: View {
        var body: some View {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: RefreshableKeyTypes.PrefKey.self, value: [RefreshableKeyTypes.PrefData(vType: .movingView, bounds: proxy.frame(in: .global))])
            }
            .frame(height: 0)
        }
    }
    
    struct FixedView: View {
        var body: some View {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: RefreshableKeyTypes.PrefKey.self, value: [RefreshableKeyTypes.PrefData(vType: .fixedView, bounds: proxy.frame(in: .global))])
            }
        }
    }
}

// Helper types for the custom RefreshableScrollView
enum RefreshableKeyTypes {
    enum ViewType: Int {
        case movingView
        case fixedView
    }
    
    struct PrefData: Equatable {
        let vType: ViewType
        let bounds: CGRect
    }
    
    struct PrefKey: PreferenceKey {
        static var defaultValue: [PrefData] = []
        
        static func reduce(value: inout [PrefData], nextValue: () -> [PrefData]) {
            value.append(contentsOf: nextValue())
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
                    .foregroundColor(.primary)
                
                HStack {
                    Text("RSSI: \(device.displayRssi) dBm")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(device.signalStrengthDescription)
                        .font(.subheadline)
                        .foregroundColor(signalColor(for: device.displayRssi))
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            // Signal strength indicator with better visual style
            HStack(spacing: 8) {
                SignalStrengthIndicator(strength: signalStrength(for: device.displayRssi))
                    .foregroundColor(signalColor(for: device.displayRssi))
                
                if device.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(colorScheme == .dark ? 0.1 : 0.2), lineWidth: 0.5)
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
        
        if let mostRecent = bluetoothManager.discoveredDevices.max(by: { $0.lastUpdated < $1.lastUpdated }) {
            return formatter.string(from: mostRecent.lastUpdated)
        } else {
            return "Unknown"
        }
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