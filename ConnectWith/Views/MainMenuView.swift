import SwiftUI
import Foundation
import CoreBluetooth
import UIKit
import Combine

// MARK: - Calendar Event Models

// Model for calendar events - one event per month
class CalendarEventStore: ObservableObject {
    static let shared = CalendarEventStore()
    
    // Published events array
    @Published var events: [CalendarEvent] = []
    
    init() {
        // Load calendar events from disk
        loadFromDisk()
    }
    
    // Get event for a specific month
    func getEvent(for month: Int) -> CalendarEvent {
        return events[month - 1]
    }
    
    // Update an event
    func updateEvent(month: Int, title: String, location: String, day: Int) {
        events[month - 1].title = title
        events[month - 1].location = location
        events[month - 1].day = day
        events[month - 1].isScheduled = true
        events[month - 1].lastUpdated = Date()
        objectWillChange.send()
        
        // Save to disk after updating
        saveToDisk()
    }
    
    // Save calendar events to disk
    @objc public func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(events)
            UserDefaults.standard.set(data, forKey: "CalendarEvents")
            print("Successfully saved calendar events to disk")
            
            // Force immediate synchronization to ensure data is written
            UserDefaults.standard.synchronize()
        } catch {
            print("Failed to save calendar events: \(error.localizedDescription)")
        }
    }
    
    // Load calendar events from disk
    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: "CalendarEvents") {
            do {
                let decoder = JSONDecoder()
                events = try decoder.decode([CalendarEvent].self, from: data)
                print("Successfully loaded \(events.count) calendar events from disk")
                
                // Check if we should integrate any synced events from paired devices
                loadSyncedEventsFromPairedDevices()
            } catch {
                print("Failed to load calendar events: \(error.localizedDescription)")
                initializeEmptyEvents()
            }
        } else {
            print("No saved calendar events found, initializing empty events")
            initializeEmptyEvents()
            
            // Even with empty events, check for synced events from paired devices
            loadSyncedEventsFromPairedDevices()
        }
    }
    
    // Load synced events from paired devices
    private func loadSyncedEventsFromPairedDevices() {
        // Look for remote device calendar data in UserDefaults
        // Keys will be in format "RemoteCalendarEvents_<deviceId>"
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        let syncedKeys = allKeys.filter { $0.hasPrefix("RemoteCalendarEvents_") }
        
        // If we found synced data from at least one device, integrate it
        if !syncedKeys.isEmpty {
            print("📱 Found synced calendar data from \(syncedKeys.count) paired devices")
            
            var hasChanges = false
            
            for key in syncedKeys {
                if let syncedData = UserDefaults.standard.data(forKey: key) {
                    do {
                        let decoder = JSONDecoder()
                        let syncedEvents = try decoder.decode([CalendarEvent].self, from: syncedData)
                        print("📱 Processing synced data from key: \(key), \(syncedEvents.count) events")
                        
                        // Integrate these events with our existing events
                        let syncMessages = syncEvents(with: syncedEvents)
                        if !syncMessages.isEmpty {
                            print("📱 Integrated \(syncMessages.count) events from paired device")
                            hasChanges = true
                        }
                    } catch {
                        print("📱 Error decoding synced data from key \(key): \(error)")
                    }
                }
            }
            
            // Save any changes back to disk
            if hasChanges {
                saveToDisk()
                print("📱 Saved integrated events back to disk")
            }
        }
    }
    
    // Initialize empty events for each month
    private func initializeEmptyEvents() {
        events = []
        for monthIndex in 1...12 {
            let monthName = Calendar.current.monthSymbols[monthIndex - 1]
            events.append(CalendarEvent(month: monthIndex, monthName: monthName))
        }
    }
    
    // Sync calendar events with another device over Bluetooth
    func syncEvents(with deviceEvents: [CalendarEvent]) -> [String] {
        var syncLogMessages: [String] = []
        print("📆 SYNC: Starting calendar sync with \(deviceEvents.count) events")
        
        // Compare each month's events and use the most recently updated one
        for deviceEvent in deviceEvents {
            let month = deviceEvent.month
            let ourEvent = events[month - 1]
            
            // If one has an event and the other doesn't, take the one with the event
            if deviceEvent.isScheduled && !ourEvent.isScheduled {
                let message = "\(deviceEvent.monthName) event '\(deviceEvent.title)' on day \(deviceEvent.day) received from connected device."
                syncLogMessages.append(message)
                print("📆 SYNC: \(message)")
                events[month - 1] = deviceEvent
            } 
            else if ourEvent.isScheduled && !deviceEvent.isScheduled {
                let message = "\(ourEvent.monthName) event '\(ourEvent.title)' on day \(ourEvent.day) sent to connected device."
                syncLogMessages.append(message)
                print("📆 SYNC: \(message)")
                // Keep our event (no change needed)
            }
            // If both have events, check if they're actually different
            else if deviceEvent.isScheduled && ourEvent.isScheduled {
                let deviceName = deviceEvent.lastUpdatedBy ?? "Connected device"
                let ourName = ourEvent.lastUpdatedBy ?? "You"
                
                // Only compare if the events are actually different
                let eventsAreDifferent = deviceEvent.title != ourEvent.title || 
                                          deviceEvent.location != ourEvent.location ||
                                          deviceEvent.day != ourEvent.day
                
                if eventsAreDifferent {
                    // If different, compare lastUpdated dates
                    if let deviceDate = deviceEvent.lastUpdated, let ourDate = ourEvent.lastUpdated, deviceDate > ourDate {
                        let message = "\(deviceEvent.monthName) event: \(deviceName) has '\(deviceEvent.title)' on day \(deviceEvent.day) but \(ourName) has '\(ourEvent.title)' on day \(ourEvent.day). Using newer version."
                        syncLogMessages.append(message)
                        print("📆 SYNC: \(message)")
                        events[month - 1] = deviceEvent
                    } else {
                        let message = "\(ourEvent.monthName) event: \(ourName) has '\(ourEvent.title)' on day \(ourEvent.day) but \(deviceName) has '\(deviceEvent.title)' on day \(deviceEvent.day). Keeping our version."
                        syncLogMessages.append(message)
                        print("📆 SYNC: \(message)")
                        // Keep our event (no change needed)
                    }
                } else {
                    print("📆 SYNC: \(deviceEvent.monthName) events are identical, no sync needed.")
                }
            }
        }
        
        // Save changes to disk after syncing
        if !syncLogMessages.isEmpty {
            print("📆 SYNC: Saving \(syncLogMessages.count) synchronized events to disk")
            saveToDisk()
        } else {
            print("📆 SYNC: No changes to save")
        }
        
        return syncLogMessages
    }
}

// Identifier for event form sheets
struct EventFormIdentifier: Identifiable {
    var id: Int { month }
    let month: Int
}

// Model for a single calendar event
struct CalendarEvent: Identifiable, Codable {
    var id: Int { month }
    let month: Int
    let monthName: String
    var title: String = ""
    var location: String = ""
    var day: Int = 1
    var isScheduled: Bool = false
    var lastUpdated: Date? = nil
    var lastUpdatedBy: String? = nil
    
    // Non-Codable UI properties with CodingKeys to exclude them
    var cardColor: (Color, Color) {
        let colors: [(Color, Color)] = [
            (Color.blue.opacity(0.7), Color.cyan.opacity(0.7)),                // January
            (Color.pink.opacity(0.6), Color.purple.opacity(0.7)),              // February
            (Color.green.opacity(0.6), Color.mint.opacity(0.6)),               // March
            (Color.indigo.opacity(0.6), Color.blue.opacity(0.7)),              // April
            (Color.purple.opacity(0.6), Color.indigo.opacity(0.7)),            // May
            (Color.red.opacity(0.6), Color.pink.opacity(0.6)),                 // June
            (Color.blue.opacity(0.6), Color.indigo.opacity(0.7)),              // July
            (Color.purple.opacity(0.6), Color.pink.opacity(0.6)),              // August
            (Color.mint.opacity(0.6), Color.green.opacity(0.7)),               // September
            (Color.blue.opacity(0.7), Color.cyan.opacity(0.7)),                // October
            (Color.brown.opacity(0.6), Color.red.opacity(0.6)),                // November
            (Color.purple.opacity(0.6), Color.pink.opacity(0.6))               // December
        ]
        return colors[month - 1]
    }
    
    // Gets a gradient for the card
    var gradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [cardColor.0, cardColor.1]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Custom encoding/decoding for SwiftUI types that aren't Codable
    enum CodingKeys: String, CodingKey {
        case month, monthName, title, location, day, isScheduled, lastUpdated, lastUpdatedBy
    }
}

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
        
        // Mark onboarding as completed in UserDefaults
        UserDefaults.standard.set(true, forKey: "HasCompletedOnboarding")
        UserDefaults.standard.synchronize()
        print("Onboarding marked as completed")
        
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
            
            // Calendar tab 
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
}

// Row for saved devices with connection status
struct SavedDeviceRow: View {
    let device: DeviceStore.SavedDeviceInfo
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var isConnecting = false
    @State private var showingSyncModal = false
    @State private var syncInProgress = false
    @State private var syncMessages: [String] = []
    @State private var bytesTransferred: Int = 0
    
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
            
            // Connect or Sync button based on status
            if device.connectionStatus == .connected {
                // Show Sync button for connected devices
                Button(action: {
                    showingSyncModal = true
                }) {
                    Text("Sync")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .sheet(isPresented: $showingSyncModal) {
                    SyncModalView(
                        deviceName: device.displayName,
                        syncInProgress: $syncInProgress,
                        syncMessages: $syncMessages,
                        bytesTransferred: $bytesTransferred,
                        onSync: performSync
                    )
                }
            } else if device.connectionStatus == .new || device.connectionStatus == .error {
                // Show Connect button for new or error devices
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
    
    // Perform calendar sync with the device
    private func performSync() {
        syncInProgress = true
        syncMessages = []
        bytesTransferred = 0
        
        // Simulate Bluetooth communication
        syncMessages.append("Initiating sync with \(device.displayName)...")
        print("🔄 SYNC: Initiating sync with \(device.displayName)...")
        
        // Store current device's name for simulation
        let deviceName = device.displayName
        let deviceId = device.identifier
        
        // Create a "simulation bridge" UserDefaults key for the remote device
        // This will allow us to simulate data storage on the other device
        let remoteDeviceKey = "RemoteCalendarEvents_\(deviceId)"
        
        // Fetch a reference to the peripheral we're syncing with (if available)
        let peripheral = bluetoothManager.nearbyDevices.first { $0.identifier.uuidString == deviceId }
        
        // Reference the bluetooth manager
        let btManager = bluetoothManager
        
        // Simulate the sync process with a timer
        var syncStage = 0
        Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { timer in
            guard syncInProgress else {
                timer.invalidate()
                return
            }
            
            // Increment bytes - simulate sending some data
            let newBytes = Int.random(in: 100...500)
            bytesTransferred += newBytes
            
            syncStage += 1
            
            switch syncStage {
            case 1:
                // Stage 1: Establish connection
                let message = "Establishing secure connection..."
                syncMessages.append(message)
                print("🔄 SYNC: \(message)")
                
                // Connect to the device if not already connected
                if let deviceToConnect = peripheral, !btManager.connectedPeripherals.contains(where: { $0.identifier == deviceToConnect.identifier }) {
                    btManager.connectToDevice(deviceToConnect)
                    print("🔄 SYNC: Connecting to device \(deviceToConnect.identifier)")
                }
                
            case 2:
                // Stage 2: Request remote calendar data
                let message = "Requesting calendar data..."
                syncMessages.append(message)
                print("🔄 SYNC: \(message)")
                
                // If we have a connected peripheral, discover services
                if let connectedPeripheral = peripheral, btManager.connectedPeripherals.contains(where: { $0.identifier == connectedPeripheral.identifier }) {
                    print("🔄 SYNC: Device is connected, discovering services...")
                    connectedPeripheral.discoverServices([btManager.serviceUUID])
                }
                
            case 3:
                // Stage 3: Get current device's calendar events
                let eventStore = CalendarEventStore.shared
                let ourEvents = eventStore.events
                
                // First, simulate receiving data from the remote device
                var remoteEvents: [CalendarEvent]
                
                // Check if we have previously synced data for the remote device
                if let remoteData = UserDefaults.standard.data(forKey: remoteDeviceKey) {
                    do {
                        let decoder = JSONDecoder()
                        remoteEvents = try decoder.decode([CalendarEvent].self, from: remoteData)
                        print("🔄 SYNC: Found existing remote device data")
                    } catch {
                        // If decode fails, generate empty events
                        remoteEvents = generateEmptyEvents(deviceName: deviceName)
                        print("🔄 SYNC: Error decoding remote data: \(error), using empty events")
                    }
                } else {
                    // If no previous data, generate some random events as if they were from the remote device
                    remoteEvents = generateRandomEvents()
                    print("🔄 SYNC: No existing data found for remote device, using simulated data")
                }
                
                // Log the incoming data from the remote device
                if let jsonData = self.getJsonRepresentation(of: remoteEvents) {
                    print("🔄 SYNC DATA (received from \(deviceName)): \(jsonData.count) bytes")
                    print(String(data: jsonData, encoding: .utf8) ?? "Invalid JSON")
                }
                
                // Sync our events with the remote events and capture the sync messages
                let syncMessages = eventStore.syncEvents(with: remoteEvents)
                
                // Display up to 3 sync messages in the UI (to avoid cluttering)
                for (index, message) in syncMessages.prefix(3).enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                        self.syncMessages.append(message)
                        self.bytesTransferred += Int.random(in: 100...300)
                    }
                }
                
                // If there are more messages, add a summary
                if syncMessages.count > 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.syncMessages.append("... \(syncMessages.count - 3) more events synced")
                        self.bytesTransferred += Int.random(in: 300...700)
                    }
                }
                
                // Now actually send our calendar data to the other device over Bluetooth
                // We need to ensure we have a connected peripheral and have discovered its services/characteristics
                print("🔄 SYNC: Connection status check...")
                
                if let connectedPeripheral = peripheral {
                    print("🔄 SYNC: Found peripheral: \(connectedPeripheral.identifier)")
                    
                    // First check if we're connected
                    if !btManager.connectedPeripherals.contains(where: { $0.identifier == connectedPeripheral.identifier }) {
                        print("🔄 SYNC: Not connected to peripheral, attempting connection...")
                        btManager.connectToDevice(connectedPeripheral)
                        
                        // Add a delay to allow connection
                        print("🔄 SYNC: Waiting for connection to complete...")
                        Thread.sleep(forTimeInterval: 1.0)
                    } else {
                        print("🔄 SYNC: Already connected to peripheral")
                    }
                    
                    // Now check if we have discovered the characteristics
                    if btManager.discoveredCharacteristics[connectedPeripheral.identifier] == nil {
                        print("🔄 SYNC: No characteristics discovered, initiating service discovery...")
                        connectedPeripheral.discoverServices([btManager.serviceUUID])
                        
                        // Add a delay to allow service discovery
                        print("🔄 SYNC: Waiting for service discovery to complete...")
                        Thread.sleep(forTimeInterval: 2.0)
                    } else {
                        print("🔄 SYNC: Characteristics already discovered")
                    }
                    
                    // Attempt to get the message characteristic
                    if let charDict = btManager.discoveredCharacteristics[connectedPeripheral.identifier],
                       let messageChar = charDict[btManager.messageCharacteristicUUID] {
                        
                        print("🔄 SYNC: Found message characteristic: \(messageChar.uuid)")
                        
                        do {
                            // First, send a special "SYNC_START" message to prepare the receiver
                            print("🔄 SYNC: Sending SYNC_START marker...")
                            let startMarker = "SYNC_START".data(using: .utf8)!
                            connectedPeripheral.writeValue(startMarker, for: messageChar, type: .withResponse)
                            
                            // Wait a bit for the receiver to process
                            Thread.sleep(forTimeInterval: 0.5)
                            
                            // Encode our calendar events to JSON data
                            let encoder = JSONEncoder()
                            encoder.outputFormatting = .prettyPrinted  // Make it human readable for debugging
                            let calendarData = try encoder.encode(ourEvents)
                            
                            // Use the message characteristic to write the data
                            print("🔄 SYNC: Sending \(calendarData.count) bytes of calendar data over Bluetooth...")
                            
                            // First, log a small preview of the data for debugging
                            if let preview = String(data: calendarData.prefix(200), encoding: .utf8) {
                                print("🔄 SYNC: Data preview: \(preview)...")
                            }
                            
                            // For large data, split into chunks
                            let maxChunkSize = 128 // Use a smaller chunk size for reliability
                            var offset = 0
                            
                            while offset < calendarData.count {
                                let chunkSize = min(maxChunkSize, calendarData.count - offset)
                                let range = offset..<(offset + chunkSize)
                                let chunk = calendarData.subdata(in: range)
                                
                                print("🔄 SYNC: Sending chunk \(offset) to \(offset + chunkSize) of \(calendarData.count)")
                                
                                // Use the characteristic to send the data
                                connectedPeripheral.writeValue(chunk, for: messageChar, type: .withResponse)
                                
                                offset += chunkSize
                                // Add a larger delay between chunks for reliability
                                Thread.sleep(forTimeInterval: 0.5)
                            }
                            
                            // Send a special "SYNC_END" message to indicate completion
                            print("🔄 SYNC: Sending SYNC_END marker...")
                            let endMarker = "SYNC_END".data(using: .utf8)!
                            connectedPeripheral.writeValue(endMarker, for: messageChar, type: .withResponse)
                            
                            print("🔄 SYNC: Calendar data sent successfully")
                        } catch {
                            print("🔄 SYNC ERROR: Failed to encode calendar data: \(error)")
                        }
                    } else {
                        print("🔄 SYNC ERROR: Message characteristic not found after discovery")
                    }
                } else {
                    print("🔄 SYNC ERROR: No peripheral found for device ID: \(deviceId)")
                }
                
                // Also save to the "remote device" storage for simulation
                do {
                    let encoder = JSONEncoder()
                    let updatedData = try encoder.encode(ourEvents)
                    UserDefaults.standard.set(updatedData, forKey: remoteDeviceKey)
                    print("🔄 SYNC: Successfully wrote \(updatedData.count) bytes to remote device storage")
                } catch {
                    print("🔄 SYNC ERROR: Failed to encode data for remote device: \(error)")
                }
                
            case 4:
                // Stage 4: Complete the sync
                let eventStore = CalendarEventStore.shared
                let ourEvents = eventStore.events
                let jsonString = getJsonPreview()
                let completeMessage = "Sync completed successfully! \(bytesTransferred) bytes transferred."
                syncMessages.append(completeMessage)
                syncMessages.append("JSON Data: \(jsonString)")
                
                // Log completion
                print("🔄 SYNC: \(completeMessage)")
                print("🔄 SYNC JSON: \(jsonString)")
                
                // Show how many events were scheduled on the remote device
                let remoteScheduledCount = UserDefaults.standard.data(forKey: remoteDeviceKey) != nil ? "updated" : "not updated"
                syncMessages.append("Remote device calendar \(remoteScheduledCount)")
                
                syncInProgress = false
                timer.invalidate()
                
            default:
                // Unexpected stage - stop the sync
                syncInProgress = false
                timer.invalidate()
            }
        }
    }
    
    // Generate set of empty events for a new device
    private func generateEmptyEvents(deviceName: String) -> [CalendarEvent] {
        var events: [CalendarEvent] = []
        
        for monthIndex in 1...12 {
            let monthName = Calendar.current.monthSymbols[monthIndex - 1]
            var event = CalendarEvent(month: monthIndex, monthName: monthName)
            event.lastUpdatedBy = deviceName
            events.append(event)
        }
        
        return events
    }
    
    // Get JSON representation of events to display and log
    private func getJsonRepresentation(of events: [CalendarEvent]) -> Data? {
        // Create a JSON encoder
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        // Encode the events
        do {
            let data = try encoder.encode(events)
            return data
        } catch {
            print("Error encoding events to JSON: \(error)")
            return nil
        }
    }
    
    // Get a preview of the JSON data for display
    private func getJsonPreview() -> String {
        let ourEvents = CalendarEventStore.shared.events
        
        // Filter to just show scheduled events to keep preview manageable
        let scheduledEvents = ourEvents.filter { $0.isScheduled }
        
        guard let jsonData = getJsonRepresentation(of: scheduledEvents) else {
            return "{\"error\": \"Failed to encode data\"}"
        }
        
        // Get the JSON string
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{\"error\": \"Invalid JSON encoding\"}"
        }
        
        // Only show the first part if it's very long
        if jsonString.count > 400 {
            let truncatedString = String(jsonString.prefix(400))
            return truncatedString + "... (truncated)"
        } else {
            return jsonString
        }
    }
    
    // Generate random events for simulation
    private func generateRandomEvents() -> [CalendarEvent] {
        var events: [CalendarEvent] = []
        
        // Get our current events to create differences for some of them
        let currentEvents = CalendarEventStore.shared.events
        
        // Check if the device is brand new (simulate empty calendar)
        let isBrandNewDevice = device.connectionStatus == .new || Int.random(in: 1...10) <= 3
        
        for monthIndex in 1...12 {
            let monthName = Calendar.current.monthSymbols[monthIndex - 1]
            var event = CalendarEvent(month: monthIndex, monthName: monthName)
            
            if isBrandNewDevice {
                // Brand new device has no events - leave all events unscheduled
                // This will make our events get synced to the device
                events.append(event)
                continue
            }
            
            // For some months, create an event with a 30% chance if we don't have one
            // or create a different event with a 20% chance if we already have one
            if !currentEvents[monthIndex-1].isScheduled && Int.random(in: 1...10) <= 3 {
                // Create a new event
                event.isScheduled = true
                event.title = "Family Trip"
                event.location = "Theme Park"
                event.day = Int.random(in: 1...28)
                event.lastUpdated = Date().addingTimeInterval(-Double(Int.random(in: 1...100000)))
                event.lastUpdatedBy = device.displayName
            } else if currentEvents[monthIndex-1].isScheduled && Int.random(in: 1...10) <= 2 {
                // Create a conflicting event (different than our current one)
                event.isScheduled = true
                event.title = "Birthday Party"
                event.location = "Grandma's House"
                event.day = Int.random(in: 1...28)
                
                // 50% chance the remote event is newer
                if Bool.random() {
                    event.lastUpdated = Date()
                } else {
                    event.lastUpdated = Date().addingTimeInterval(-Double(Int.random(in: 200000...500000)))
                }
                event.lastUpdatedBy = device.displayName
            } else if currentEvents[monthIndex-1].isScheduled {
                // For existing events, randomly decide whether to:
                // 1. Send the same event back (most common case)
                // 2. Don't have the event at all (less common)
                // 3. Have a conflicting event (least common)
                let rand = Int.random(in: 1...10)
                
                if rand <= 8 {
                    // Most likely: device does not have this event
                    // Do nothing, keep event unscheduled
                } else if rand == 9 {
                    // Sometimes: device has same event
                    event = currentEvents[monthIndex-1]
                    // But with different timestamps
                    event.lastUpdated = Date().addingTimeInterval(-Double(Int.random(in: 500000...1000000)))
                    event.lastUpdatedBy = device.displayName
                } else {
                    // Rarely: device has conflicting event
                    event.isScheduled = true
                    event.title = "Conference"
                    event.location = "Convention Center"
                    event.day = Int.random(in: 1...28)
                    
                    // 30% chance the device's event is newer
                    if Int.random(in: 1...10) <= 3 {
                        event.lastUpdated = Date()
                    } else {
                        event.lastUpdated = Date().addingTimeInterval(-Double(Int.random(in: 200000...500000)))
                    }
                    event.lastUpdatedBy = device.displayName
                }
            }
            
            events.append(event)
        }
        
        return events
    }
}

// Modal view for syncing calendar data with family members
// Helper view for displaying sync messages
struct MessageRow: View {
    let message: String
    
    var body: some View {
        if message.hasPrefix("JSON Data:") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Data Payload:")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                // Extract the JSON part
                let jsonPart = message.replacingOccurrences(of: "JSON Data: ", with: "")
                
                Text(jsonPart)
                    .font(.system(.caption, design: .monospaced))
                    .padding(10)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 10)
        } else {
            HStack(alignment: .top) {
                Text("•")
                    .foregroundColor(.blue)
                
                Text(message)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SyncModalView: View {
    let deviceName: String
    @Binding var syncInProgress: Bool
    @Binding var syncMessages: [String]
    @Binding var bytesTransferred: Int
    let onSync: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        
                        Text("Calendar Sync")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .padding(.top)
                    
                    // Device info
                    HStack {
                        Image(systemName: "iphone.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        Text("Syncing with: \(deviceName)")
                            .font(.headline)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Progress section
                    VStack(alignment: .leading, spacing: 10) {
                        if syncInProgress {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                
                                Text("Syncing in progress...")
                                    .foregroundColor(.blue)
                            }
                            
                            // Transfer stats
                            HStack {
                                Text("Bytes Transferred:")
                                    .font(.caption)
                                
                                Text("\(bytesTransferred)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                        } else if !syncMessages.isEmpty && syncMessages.last?.contains("completed") == true {
                            // Success message
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                
                                Text("Sync Completed")
                                    .foregroundColor(.green)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(10)
                    
                    // Sync log messages
                    VStack(alignment: .leading) {
                        Text("Sync Details:")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(syncMessages.enumerated()), id: \.offset) { item in
                                    let index = item.offset
                                    let message = item.element
                                    
                                    MessageRow(message: message)
                                        .padding(.vertical, 4)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 300)
                    }
                    .padding()
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(10)
                    
                    Spacer()
                    
                    // Action buttons
                    if syncInProgress {
                        Button(action: {
                            syncInProgress = false
                            syncMessages.append("Sync cancelled by user.")
                        }) {
                            Text("Cancel Sync")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                    } else if syncMessages.isEmpty {
                        Button(action: onSync) {
                            Text("Start Sync")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    } else {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Close")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            })
        }
    }
}

// Calendar View with monthly event cards
struct CalendarView: View {
    @ObservedObject private var eventStore = CalendarEventStore.shared
    @State private var selectedMonth: Int = 1
    @State private var isShowingEventForm = false
    
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
                
                // ScrollView containing the month cards
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Family Events")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top, 20)
                        
                        Text("Tap a month to add or edit your family event")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 10)
                        
                        // Month cards - one card per month
                        ForEach(eventStore.events) { event in
                            MonthCard(event: event)
                                .onTapGesture {
                                    selectedMonth = event.month
                                    isShowingEventForm = true
                                }
                        }
                        
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Calendar")
            .sheet(item: Binding<EventFormIdentifier?>(
                get: { isShowingEventForm ? EventFormIdentifier(month: selectedMonth) : nil },
                set: { newValue in
                    isShowingEventForm = newValue != nil
                }
            )) { identifier in
                EventFormView(month: identifier.month)
            }
        }
    }
}

// Card view for a single month
struct MonthCard: View {
    let event: CalendarEvent
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Card background with gradient
            event.gradient
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 8) {
                // Month name
                HStack {
                    Text(event.monthName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    
                    Spacer()
                    
                    if event.isScheduled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    }
                }
                .padding(.bottom, 5)
                
                // If there's an event scheduled, show the details
                if event.isScheduled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                            Text(event.location)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        }
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                            Text("Day \(event.day)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        }
                    }
                } else {
                    // If no event, show "Add event" prompt
                    Text("Tap to add event")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                }
            }
            .padding()
        }
        .frame(height: 150)
    }
}

// Form for adding/editing an event
struct EventFormView: View {
    let month: Int
    @ObservedObject private var eventStore = CalendarEventStore.shared
    @Environment(\.presentationMode) var presentationMode
    
    // Get the current event for this month
    private var currentEvent: CalendarEvent {
        eventStore.getEvent(for: month)
    }
    
    // Form fields with initial values directly from the current event
    @State private var title: String
    @State private var location: String
    @State private var day: Int
    
    // Initialize with proper values from the start
    init(month: Int) {
        self.month = month
        let event = CalendarEventStore.shared.getEvent(for: month)
        
        // Use existing values or defaults
        if event.isScheduled {
            _title = State(initialValue: event.title)
            _location = State(initialValue: event.location)
            _day = State(initialValue: event.day)
        } else {
            _title = State(initialValue: "")
            _location = State(initialValue: "")
            _day = State(initialValue: 1)
        }
    }
    
    // Maximum day for the selected month
    private var maxDay: Int {
        let dateComponents = DateComponents(year: Calendar.current.component(.year, from: Date()), month: month)
        let date = Calendar.current.date(from: dateComponents)!
        return Calendar.current.range(of: .day, in: .month, for: date)!.count
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Event Title", text: $title)
                    TextField("Location", text: $location)
                    
                    Picker("Day", selection: $day) {
                        ForEach(1...maxDay, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                }
                
                Section {
                    Button(action: saveEvent) {
                        Text("Save Event")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(title.isEmpty || location.isEmpty)
                }
            }
            .navigationTitle("\(currentEvent.monthName) Event")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func saveEvent() {
        // Get the device name
        let deviceName = UIDevice.current.name
        
        // Update the event with the device name as lastUpdatedBy
        eventStore.updateEvent(month: month, title: title, location: location, day: day)
        // Set the lastUpdatedBy field
        eventStore.events[month - 1].lastUpdatedBy = deviceName
        
        presentationMode.wrappedValue.dismiss()
    }
}

// Settings View with sample event generator
struct SettingsView: View {
    @ObservedObject private var eventStore = CalendarEventStore.shared
    @State private var showAlert = false
    
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
                    
                    Section(header: Text("Calendar")) {
                        Button(action: populateSampleEvents) {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundColor(.blue)
                                Text("Add Sample Events")
                            }
                        }
                        .alert(isPresented: $showAlert) {
                            Alert(
                                title: Text("Sample Events Added"),
                                message: Text("Sample events have been added to all 12 months of your calendar."),
                                dismissButton: .default(Text("OK"))
                            )
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
    
    private func populateSampleEvents() {
        // Sample event titles for each month with multiple options for randomness
        let sampleTitles: [[String]] = [
            ["Winter Festival", "Ski Trip", "Ice Skating Day", "New Year Celebration"],            // January
            ["Valentine's Dinner", "Family Game Night", "Weekend Getaway", "Movie Marathon"],      // February
            ["Spring Break Trip", "Garden Planting", "Hiking Adventure", "Museum Visit"],          // March
            ["Family Picnic", "Bike Riding Day", "Outdoor Concert", "Easter Celebration"],         // April
            ["Mother's Day Brunch", "Family Portrait", "Farmers Market Trip", "Spring Cleaning"],  // May
            ["Summer Camp Starts", "Beach Day", "Camping Trip", "Road Trip"],                      // June
            ["Independence Fireworks", "BBQ Party", "Pool Party", "Family Reunion"],               // July
            ["Family Reunion", "Water Park Day", "Fishing Trip", "Stargazing Night"],              // August
            ["Back to School", "Apple Picking", "Fall Festival", "Football Game"],                 // September
            ["Halloween Party", "Pumpkin Carving", "Haunted House Tour", "Costume Shopping"],      // October
            ["Thanksgiving Dinner", "Black Friday Shopping", "Family Photos", "Baking Day"],       // November
            ["Holiday Celebration", "Gift Exchange", "Cookie Decorating", "New Year's Eve Party"]  // December
        ]
        
        // Sample locations with multiple options for randomness
        let sampleLocations: [[String]] = [
            ["Town Square", "Ski Resort", "Winter Park", "Community Center"],                      // January
            ["Italian Restaurant", "Home", "Cozy Cabin", "Family Room"],                           // February
            ["Beach Resort", "Botanical Gardens", "Mountain Trails", "City Museum"],               // March
            ["Central Park", "Bike Trail", "Amphitheater", "Grandma's House"],                     // April
            ["Mom's Favorite Cafe", "Portrait Studio", "Local Market", "Home"],                    // May
            ["Camp Wilderness", "Sunny Beach", "National Park", "Interstate 95"],                  // June
            ["Lakeside", "Backyard", "Community Pool", "Uncle Bob's House"],                       // July
            ["Grandma's House", "Water World", "Lake Michigan", "Backyard"],                       // August
            ["Shopping Mall", "Apple Orchard", "County Fair", "Stadium"],                          // September
            ["Community Center", "Pumpkin Patch", "Haunted Mansion", "Costume Store"],             // October
            ["Home", "Downtown Mall", "Photography Studio", "Kitchen"],                            // November
            ["Mountain Cabin", "Living Room", "Bakery", "Downtown"]                                // December
        ]
        
        // Populate each month with a random event from options
        for month in 1...12 {
            // Get random title and location from options for this month
            let titles = sampleTitles[month - 1]
            let locations = sampleLocations[month - 1]
            
            let randomTitleIndex = Int.random(in: 0..<titles.count)
            let randomLocationIndex = Int.random(in: 0..<locations.count)
            
            // Get random day appropriate for the month
            let maxDay: Int
            switch month {
            case 2:
                // February (accounting for leap year)
                let year = Calendar.current.component(.year, from: Date())
                let isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
                maxDay = isLeapYear ? 29 : 28
            case 4, 6, 9, 11:
                // April, June, September, November
                maxDay = 30
            default:
                maxDay = 31
            }
            
            let randomDay = Int.random(in: 1...maxDay)
            
            // Update the event store with random values
            eventStore.updateEvent(
                month: month,
                title: titles[randomTitleIndex],
                location: locations[randomLocationIndex],
                day: randomDay
            )
        }
        
        // Show confirmation alert
        showAlert = true
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
                        
                        // Mark onboarding as completed in UserDefaults
                        UserDefaults.standard.set(true, forKey: "HasCompletedOnboarding")
                        UserDefaults.standard.synchronize()
                        print("Onboarding marked as completed")
                        
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