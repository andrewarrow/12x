import SwiftUI
import Foundation
import CoreBluetooth
import UIKit

// Next View for showing selected devices and confirming completion
struct NextView: View {
    let selectedDevices: Set<UUID>
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var navigateToMainView = false
    
    var body: some View {
        ZStack {
            if navigateToMainView {
                MainTabView(bluetoothManager: bluetoothManager)
                    .transition(.opacity)
            } else {
                VStack(spacing: 30) {
                    Text("Family Connected!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.green)
                    
                    Text("You've successfully selected \(selectedDevices.count) family device\(selectedDevices.count == 1 ? "" : "s").")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    List {
                        Section(header: Text("Selected Family Members")) {
                            // Create a computed filteredDevices array to simplify the ForEach
                            let filteredDevices = bluetoothManager.nearbyDevices.filter { 
                                selectedDevices.contains($0.identifier) 
                            }
                            
                            ForEach(filteredDevices, id: \.identifier) { device in
                                // Get the display name from device store
                                let deviceInfo = DeviceStore.shared.getDevice(identifier: device.identifier.uuidString)
                                let displayName = deviceInfo?.displayName ?? (device.name ?? "Unknown Device")
                                
                                HStack {
                                    // Icon with signal strength color
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(displayName)
                                            .font(.headline)
                                        
                                        // Show signal strength if available
                                        if let info = deviceInfo {
                                            HStack {
                                                Text("Signal Quality: \(info.signalStrength)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    
                    Spacer()
                    
                    Text("Your family network is ready to use")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding()
                    
                    Button(action: {
                        saveDevicesAndContinue()
                    }) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    .padding(.bottom)
                }
                .padding()
                .navigationTitle("Setup Complete")
            }
        }
    }
    
    // Save devices to persistent storage and navigate to main view
    private func saveDevicesAndContinue() {
        // Save selected devices to device store
        DeviceStore.shared.saveDevices(identifiers: selectedDevices)
        
        // Transition to the main app view with animation
        withAnimation(.easeInOut(duration: 0.5)) {
            navigateToMainView = true
        }
    }
}

// Main TabView for the app
struct MainTabView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Family tab
            FamilyView(bluetoothManager: bluetoothManager)
                .tabItem {
                    Label("Family", systemImage: "person.2.fill")
                }
                .tag(0)
            
            // Calendar tab (placeholder)
            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(1)
            
            // Settings tab (placeholder)
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

// Family View - Shows connected family devices
struct FamilyView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject private var deviceStore = DeviceStore.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background with new color scheme
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack {
                    if deviceStore.getAllSavedDevices().isEmpty {
                        // No saved devices view
                        VStack(spacing: 20) {
                            Image(systemName: "person.badge.plus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.blue.opacity(0.8))
                            
                            Text("No Family Members Added")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Go back to the setup screen to add family members.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 50)
                            
                            Button(action: {
                                // Return to setup screen (would need to be implemented)
                            }) {
                                Text("Add Family Members")
                                    .fontWeight(.semibold)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.top, 30)
                        }
                        .padding(.horizontal)
                    } else {
                        // List of saved family devices
                        List {
                            ForEach(deviceStore.getAllSavedDevices()) { device in
                                SavedDeviceRow(
                                    device: device,
                                    bluetoothManager: bluetoothManager
                                )
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
            }
            .navigationTitle("Family")
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
}

// Row for saved devices with connection status
struct SavedDeviceRow: View {
    let device: DeviceStore.SavedDeviceInfo
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var isConnecting = false
    
    var body: some View {
        HStack {
            // Icon for device
            Image(systemName: "iphone.circle.fill")
                .foregroundColor(.blue)
                .font(.title)
                .frame(width: 40)
            
            // Device info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.headline)
                
                HStack {
                    // Status indicator
                    Image(systemName: device.connectionStatus.icon)
                        .foregroundColor(device.connectionStatus.color)
                    
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lastConnected = device.lastConnected {
                        Text("Last: \(timeAgo(from: lastConnected))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Connect button
            if device.connectionStatus != .connected {
                Button(action: {
                    connectToDevice()
                }) {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Connect")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(isConnecting)
            } else {
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
    }
    
    // Helper computed properties
    private var statusText: String {
        switch device.connectionStatus {
        case .new: return "New"
        case .connected: return "Connected"
        case .error: return "Error"
        }
    }
    
    // Format time ago
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Connect to the device
    private func connectToDevice() {
        isConnecting = true
        
        // Test connection with the device
        bluetoothManager.testConnection(with: device.identifier)
        
        // Set a timeout to stop the connecting spinner after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            isConnecting = false
        }
    }
}

// Calendar View (Placeholder)
struct CalendarView: View {
    var body: some View {
        NavigationView {
            ZStack {
                // Background with same color scheme
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.green.opacity(0.1)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack {
                    Image(systemName: "calendar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue.opacity(0.7))
                        .padding()
                    
                    Text("Family Calendar")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Coming Soon")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .navigationTitle("Calendar")
        }
    }
}

// Settings View (Placeholder)
struct SettingsView: View {
    var body: some View {
        NavigationView {
            ZStack {
                // Background with same color scheme
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                List {
                    Section(header: Text("Account")) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            Text("Profile")
                        }
                        
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.blue)
                            Text("Notifications")
                        }
                    }
                    
                    Section(header: Text("Device")) {
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundColor(.blue)
                            Text("Network Settings")
                        }
                        
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.blue)
                            Text("Privacy & Security")
                        }
                    }
                    
                    Section(header: Text("About")) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Version 1.0.0")
                        }
                        
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.blue)
                            Text("Help & Support")
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Device Selection Views

// SelectDevicesView for choosing devices to connect with
struct SelectDevicesView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var selectedDevices: Set<UUID> = []
    @State private var showNextScreen = false
    @State private var isScanningActive = false
    
    var body: some View {
        ZStack {
            // Background color change to indicate stage transition
            Color.green.opacity(0.2).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Family Devices Found!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.top, 30)
                
                // Device list
                List {
                    ForEach(bluetoothManager.nearbyDevices, id: \.identifier) { device in
                        // Get more information from the device store
                        let deviceInfo = DeviceStore.shared.getDevice(identifier: device.identifier.uuidString)
                        
                        DeviceSelectionRow(
                            device: device,
                            deviceInfo: deviceInfo,
                            isSelected: selectedDevices.contains(device.identifier),
                            toggleSelection: {
                                if selectedDevices.contains(device.identifier) {
                                    selectedDevices.remove(device.identifier)
                                } else {
                                    selectedDevices.insert(device.identifier)
                                }
                            }
                        )
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                // Refresh button for rescanning
                Button(action: {
                    bluetoothManager.startScanning()
                    isScanningActive = true
                    // Auto-turn off scanning indicator after 10 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        isScanningActive = false
                    }
                }) {
                    Label(
                        isScanningActive ? "Scanning..." : "Refresh Device List",
                        systemImage: isScanningActive ? "antenna.radiowaves.left.and.right" : "arrow.clockwise"
                    )
                    .font(.footnote)
                    .foregroundColor(.blue)
                }
                .padding(.top, 5)
                
                Text("Select family members' devices to connect with")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // Direct navigation to MainTabView, bypassing the "Setup Complete" screen
                NavigationLink(
                    destination: MainTabView(bluetoothManager: bluetoothManager),
                    isActive: $showNextScreen
                ) {
                    Button(action: {
                        // Save selected devices before navigating
                        DeviceStore.shared.saveDevices(identifiers: selectedDevices)
                        showNextScreen = true
                    }) {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 30)
                .disabled(selectedDevices.isEmpty)
                .opacity(selectedDevices.isEmpty ? 0.6 : 1.0)
            }
            .padding()
        }
        .navigationTitle("Select Devices")
        .navigationBarBackButtonHidden(true)
    }
}

struct DeviceSelectionRow: View {
    let device: CBPeripheral
    let deviceInfo: DeviceStore.BluetoothDeviceInfo?
    let isSelected: Bool
    let toggleSelection: () -> Void
    
    // We'll use different device icons based on the signal strength
    private var deviceIcon: String {
        guard let info = deviceInfo else { return "iphone.circle" }
        
        // Parse the RSSI value from the string
        let rssiString = info.signalStrength.replacingOccurrences(of: " dBm", with: "")
        if let rssi = Int(rssiString) {
            if rssi >= -60 {
                return "iphone.circle.fill"
            } else if rssi >= -70 {
                return "iphone.circle.fill"
            } else if rssi >= -80 {
                return "iphone.circle"
            } else {
                return "iphone"
            }
        }
        return "iphone.circle"
    }
    
    // Color also changes based on signal strength
    private var iconColor: Color {
        guard let info = deviceInfo else { return .gray }
        
        // Parse the RSSI value from the string
        let rssiString = info.signalStrength.replacingOccurrences(of: " dBm", with: "")
        if let rssi = Int(rssiString) {
            if rssi >= -60 {
                return .green
            } else if rssi >= -70 {
                return .blue
            } else if rssi >= -80 {
                return .orange
            } else {
                return .gray
            }
        }
        return .gray
    }
    
    var body: some View {
        HStack {
            // Icon indicating device type with signal strength color
            Image(systemName: deviceIcon)
                .font(.title)
                .foregroundColor(iconColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                if let info = deviceInfo {
                    // Display the clean name
                    Text(info.displayName)
                        .font(.headline)
                    
                    // Show signal strength
                    HStack(spacing: 4) {
                        Text("Signal: \(info.signalStrength)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Signal bars based on RSSI value
                        let rssiString = info.signalStrength.replacingOccurrences(of: " dBm", with: "")
                        if let rssi = Int(rssiString) {
                            if rssi >= -60 {
                                Text("📶")
                            } else if rssi >= -70 {
                                Text("📶")
                            } else if rssi >= -80 {
                                Text("📶")
                            } else {
                                Text("📶").foregroundColor(.gray.opacity(0.5))
                            }
                        } else {
                            Text("📶")
                        }
                    }
                } else {
                    // Fallback if no device info
                    Text(device.name ?? "Unknown Device")
                        .font(.headline)
                    
                    Text("Identifier: \(device.identifier.uuidString.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Checkbox
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.title2)
                .foregroundColor(isSelected ? .green : .gray)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection()
        }
        .padding(.vertical, 8)
    }
}

struct OnboardingView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var progressValue: Double = 0.0
    @State private var emojiIndex = 0
    @State private var debugText = "Initializing..."
    @State private var showDeviceSelectionView = false
    @State private var showDevicesList = false
    @State private var runTime: Int = 0
    @State private var hasFoundDevices = false
    
    // Track active timers to avoid duplicates
    @State private var progressTimer: Timer? = nil
    @State private var emojiTimer: Timer? = nil
    @State private var debugTimer: Timer? = nil
    
    let emojis = ["📱", "🔄", "✨", "🚀", "🔍", "📡"]
    
    var body: some View {
        NavigationView {
            ZStack {
                if hasFoundDevices {
                    // Show the select devices view when devices are found
                    NavigationLink(
                        destination: SelectDevicesView(bluetoothManager: bluetoothManager),
                        isActive: $showDeviceSelectionView
                    ) {
                        EmptyView()
                    }
                    .hidden()
                    
                    // The transition UI, shown briefly before navigation
                    VStack(spacing: 30) {
                        Text("Device Found!")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.green)
                        
                        Text("Connecting you to your family")
                            .font(.title3)
                        
                        Button(action: {
                            showDeviceSelectionView = true
                        }) {
                            Text("Select Family Members")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                        .padding(.top, 40)
                    }
                    .padding()
                    .onAppear {
                        // Auto-navigate after a brief pause to show the green screen
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showDeviceSelectionView = true
                        }
                    }
                } else {
                    // Original onboarding UI when no devices found yet
                    VStack(spacing: 30) {
                        Text("Welcome to 12x")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding()
                        
                        Text(bluetoothManager.scanningMessage)
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            // Emoji animation
                            ZStack {
                                ForEach(0..<emojis.count, id: \.self) { index in
                                    Text(emojis[index])
                                        .font(.system(size: 40))
                                        .opacity(index == emojiIndex ? 1 : 0)
                                        .scaleEffect(index == emojiIndex ? 1.2 : 1.0)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: emojiIndex)
                                }
                            }
                            .frame(width: 60, height: 60)
                            
                            ProgressView(value: progressValue)
                                .progressViewStyle(LinearProgressViewStyle())
                                .tint(.blue)
                                .frame(height: 10)
                        }
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Now have your family member also install this app and launch it on their phone.")
                                .font(.body)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .padding()
                        
                        // Debug text - shows log status
                        Text(debugText)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("Waiting for devices...")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .navigationTitle("Setup")
                }
            }
            .onAppear {
                print("ONBOARDING VIEW APPEARED")
                debugText = "View appeared at \(formattedTime(Date()))"
                
                // Only start animations and timers if they're not already running
                startAnimationsAndTimers()
                
                // Setup observer for device discovery
                startDeviceObserver()
            }
            .onDisappear {
                // Clean up timers when view disappears
                stopTimers()
            }
        }
    }
    
    private func startDeviceObserver() {
        // Create an observer to watch for device discovery
        DispatchQueue.main.async {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                if !bluetoothManager.nearbyDevices.isEmpty && !hasFoundDevices {
                    // When first device is found, stop animations and show the transition
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        hasFoundDevices = true
                        stopTimers()
                    }
                    timer.invalidate()
                }
            }
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func startAnimationsAndTimers() {
        // Only start timers if they're not already running
        if progressTimer == nil {
            startProgressAnimation()
        }
        
        if emojiTimer == nil {
            startEmojiAnimation()
        }
        
        if debugTimer == nil {
            startDebugUpdates()
        }
    }
    
    private func stopTimers() {
        progressTimer?.invalidate()
        progressTimer = nil
        
        emojiTimer?.invalidate()
        emojiTimer = nil
        
        debugTimer?.invalidate()
        debugTimer = nil
    }
    
    func startProgressAnimation() {
        // Loop the progress animation indefinitely
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            withAnimation {
                if progressValue >= 1.0 {
                    progressValue = 0.0
                } else {
                    progressValue += 0.01
                }
            }
        }
    }
    
    func startEmojiAnimation() {
        // Cycle through emojis
        emojiTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            withAnimation {
                emojiIndex = (emojiIndex + 1) % emojis.count
            }
        }
    }
    
    func startDebugUpdates() {
        // Update debug text periodically to show app is running
        runTime = 0
        debugTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [self] timer in
            runTime += 5
            debugText = "Running for \(runTime)s (at \(formattedTime(Date())))"
            print("App running for \(runTime) seconds")
        }
    }
}

#Preview {
    OnboardingView()
}