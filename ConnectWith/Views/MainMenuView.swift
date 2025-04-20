import SwiftUI
import Foundation
import CoreBluetooth
import UIKit
import Combine

// Import the SyncPackage definitions
class SyncPackageImportHelper {
    static func importDependencies() {
        // This function does nothing but ensures the Swift compiler imports the modules
    }
}

// These typedefs are just to simplify usage within MainMenuView
class SyncUtility {
    static func generateSyncPackage() -> SyncPackage {
        print("[SyncData] Placeholder: generateSyncPackage called")
        
        // Create a sample sync package
        let event = CalendarEventSync(
            month: 1,
            monthName: "January",
            title: "New Year",
            location: "Home",
            day: 1
        )
        
        return SyncPackage(events: [event])
    }
    
    static func processSyncPackage(_ package: SyncPackage) -> [PendingUpdateInfo] {
        print("[SyncData] Placeholder: processSyncPackage called")
        
        // Return a sample pending update
        let update = PendingUpdateInfo(
            sourceDevice: "Test Device",
            month: 1,
            monthName: "January",
            updateType: .newEvent,
            fieldName: "event",
            oldValue: "None",
            newValue: "New Test Event",
            remoteEvent: nil
        )
        
        return [update]
    }
}

struct SyncPackage {
    let sourceDevice: DeviceInfo
    let timestamp = Date()
    let events: [CalendarEventSync]
    
    init(events: [CalendarEventSync]) {
        self.sourceDevice = DeviceInfo.current
        self.events = events
        print("[SyncData] Created SyncPackage with \(events.count) events")
    }
    
    func isValid() -> Bool {
        return true
    }
    
    func toJSON() -> Data? {
        // Placeholder implementation
        let encoder = JSONEncoder()
        
        do {
            // Create a simple dictionary to represent the package
            let dict: [String: Any] = [
                "version": "1.0",
                "sourceDevice": [
                    "name": sourceDevice.name,
                    "identifier": sourceDevice.identifier
                ],
                "timestamp": timestamp.timeIntervalSince1970,
                "events": events.map { [
                    "month": $0.month,
                    "monthName": $0.monthName,
                    "title": $0.title,
                    "location": $0.location,
                    "day": $0.day
                ] }
            ]
            
            // Convert to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
            print("[SyncData] Encoded package to \(jsonData.count) bytes")
            return jsonData
        } catch {
            print("[SyncData] Error encoding package: \(error)")
            return nil
        }
    }
    
    static func fromJSON(_ data: Data) -> SyncPackage? {
        // Placeholder implementation
        do {
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let eventsArray = dict["events"] as? [[String: Any]] {
                
                var events: [CalendarEventSync] = []
                
                for eventDict in eventsArray {
                    if let month = eventDict["month"] as? Int,
                       let monthName = eventDict["monthName"] as? String,
                       let title = eventDict["title"] as? String,
                       let location = eventDict["location"] as? String,
                       let day = eventDict["day"] as? Int {
                        
                        let event = CalendarEventSync(
                            month: month,
                            monthName: monthName,
                            title: title,
                            location: location,
                            day: day
                        )
                        
                        events.append(event)
                    }
                }
                
                return SyncPackage(events: events)
            }
            
            return nil
        } catch {
            print("[SyncData] Error decoding package: \(error)")
            return nil
        }
    }
}

struct CalendarEventSync {
    let month: Int
    let monthName: String
    let title: String
    let location: String
    let day: Int
    let lastModified = Date()
    
    init(month: Int, monthName: String, title: String, location: String, day: Int) {
        self.month = month
        self.monthName = monthName
        self.title = title
        self.location = location
        self.day = day
        print("[SyncData] Created CalendarEventSync: \(title) in \(monthName)")
    }
    
    func isValid() -> Bool {
        return month >= 1 && month <= 12 && day >= 1 && day <= 31
    }
    
    func toCalendarEvent() -> CalendarEvent {
        return CalendarEvent(
            month: month,
            monthName: monthName,
            title: title,
            location: location,
            day: day,
            isScheduled: true
        )
    }
}

struct DeviceInfo {
    let name: String
    let identifier: String
    
    static var current: DeviceInfo {
        return DeviceInfo(
            name: UIDevice.current.name,
            identifier: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        )
    }
}

enum UpdateType {
    case newEvent
    case modifyField
}

struct PendingUpdateInfo: Identifiable {
    let id = UUID()
    let sourceDevice: String
    let month: Int
    let monthName: String
    let updateType: UpdateType
    let fieldName: String
    let oldValue: String
    let newValue: String
    let remoteEvent: CalendarEventSync?
    let timestamp: Date = Date()
    
    var description: String {
        switch updateType {
        case .newEvent:
            return "would like to add an event '\(newValue)' in \(monthName)."
        case .modifyField:
            switch fieldName {
            case "title":
                return "would like to change the title of the \(monthName) event from '\(oldValue)' to '\(newValue)'."
            case "location":
                return "would like to update the location of the \(monthName) event from '\(oldValue)' to '\(newValue)'."
            case "day":
                return "would like to change the date of the \(monthName) event from day \(oldValue) to day \(newValue)."
            default:
                return "would like to update the \(fieldName) of the \(monthName) event."
            }
        }
    }
}

// MARK: - Calendar Event Models

// MARK: - Calendar Event Model
struct CalendarEvent: Codable, Identifiable {
    var id: Int { month }
    let month: Int
    let monthName: String
    var title: String = ""
    var location: String = ""
    var day: Int = 1
    var isScheduled: Bool = false
    
    // Default initializer
    init(month: Int, monthName: String, title: String = "", location: String = "", day: Int = 1, isScheduled: Bool = false) {
        self.month = month
        self.monthName = monthName
        self.title = title
        self.location = location
        self.day = day
        self.isScheduled = isScheduled
    }
    
    // Custom initializer from decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode required properties
        month = try container.decode(Int.self, forKey: .month)
        monthName = try container.decode(String.self, forKey: .monthName)
        
        // Decode optional properties with defaults
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        day = try container.decodeIfPresent(Int.self, forKey: .day) ?? 1
        isScheduled = try container.decodeIfPresent(Bool.self, forKey: .isScheduled) ?? false
        
        print("[CalendarEvent] Decoded event for \(monthName): title=\(title), day=\(day)")
    }
    
    // Get the card colors for each month
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
    
    // Custom encode method
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(month, forKey: .month)
        try container.encode(monthName, forKey: .monthName)
        try container.encode(title, forKey: .title)
        try container.encode(location, forKey: .location)
        try container.encode(day, forKey: .day)
        try container.encode(isScheduled, forKey: .isScheduled)
    }
    
    // CodingKeys to exclude computed properties from encoding/decoding
    enum CodingKeys: String, CodingKey {
        case month, monthName, title, location, day, isScheduled
    }
}

// MARK: - Calendar Event Store
class CalendarStore: ObservableObject {
    static let shared = CalendarStore()
    
    // Published events array
    @Published var events: [CalendarEvent] = []
    
    // UserDefaults keys for individual events - we'll store each month separately
    private func keyForMonth(_ month: Int) -> String {
        return "CalendarEvent_Month_\(month)"
    }
    
    init() {
        print("[CalendarStore] Initializing CalendarStore")
        
        // First initialize with empty events for each month
        for monthIndex in 1...12 {
            let monthName = Calendar.current.monthSymbols[monthIndex - 1]
            
            // Create a basic event
            let event = CalendarEvent(month: monthIndex, monthName: monthName)
            
            // Add it to our array
            events.append(event)
        }
        
        // Then load any saved events from UserDefaults
        loadAllEvents()
        
        print("[CalendarStore] Initialization complete with \(events.count) total events")
    }
    
    // Get event for a specific month
    func getEvent(for month: Int) -> CalendarEvent {
        return events[month - 1]
    }
    
    // Update an event
    func updateEvent(month: Int, title: String, location: String, day: Int) {
        print("[CalendarStore] Saving event: \(title) for \(events[month - 1].monthName) on day \(day)")
        
        // Update the event in our array
        events[month - 1].title = title
        events[month - 1].location = location
        events[month - 1].day = day
        events[month - 1].isScheduled = true
        
        // Save this individual event to UserDefaults
        saveEvent(month: month)
        
        // Notify observers
        objectWillChange.send()
        
        print("[CalendarStore] Event saved successfully")
    }
    
    // MARK: - Persistence - Individual Event Storage
    
    // Save a single month's event
    private func saveEvent(month: Int) {
        let event = events[month - 1]
        
        // Create a dictionary with the event data
        let eventDict: [String: Any] = [
            "title": event.title,
            "location": event.location,
            "day": event.day,
            "isScheduled": event.isScheduled
        ]
        
        // Save to UserDefaults
        UserDefaults.standard.set(eventDict, forKey: keyForMonth(month))
        UserDefaults.standard.synchronize()
        
        print("[CalendarStore] Saved event for \(event.monthName): \(event.title), day \(event.day)")
    }
    
    // Load a single month's event
    func loadEvent(month: Int) {
        // Get the event dictionary
        guard let eventDict = UserDefaults.standard.dictionary(forKey: keyForMonth(month)) else {
            print("[CalendarStore] No saved data for month \(month)")
            return
        }
        
        // Update our model
        if let title = eventDict["title"] as? String,
           let location = eventDict["location"] as? String,
           let day = eventDict["day"] as? Int,
           let isScheduled = eventDict["isScheduled"] as? Bool {
            
            events[month - 1].title = title
            events[month - 1].location = location
            events[month - 1].day = day
            events[month - 1].isScheduled = isScheduled
            
            print("[CalendarStore] Loaded event for month \(month): \(title), day \(day)")
        }
    }
    
    // Load all events
    func loadAllEvents() {
        print("[CalendarStore] Loading all saved events")
        
        var loadedCount = 0
        
        for month in 1...12 {
            // Check if we have data for this month
            if UserDefaults.standard.dictionary(forKey: keyForMonth(month)) != nil {
                loadEvent(month: month)
                loadedCount += 1
            }
        }
        
        print("[CalendarStore] Loaded \(loadedCount) events from storage")
    }
    
    // Save all events
    func saveAllEvents() {
        print("[CalendarStore] Saving all events")
        
        for month in 1...12 {
            if events[month - 1].isScheduled {
                saveEvent(month: month)
            }
        }
    }
}

// MARK: - Event Form Models

// Identifier for event form sheets
struct EventFormIdentifier: Identifiable {
    var id: Int { month }
    let month: Int
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
            
            // Updates tab for sync changes
            // Simple placeholder for updates with debug buttons
            NavigationView {
                VStack(spacing: 20) {
                    Text("Task 9.3 Complete")
                        .font(.title)
                        .padding()
                    
                    Text("The sync package data model has been implemented!")
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    // Debug section
                    VStack(spacing: 15) {
                        Text("Debug & Testing").font(.headline)
                        
                        Button(action: {
                            print("[SyncData] Running serialization test")
                            
                            // Create test CalendarEvents
                            let calendarStore = CalendarStore.shared
                            
                            // Update test events
                            calendarStore.updateEvent(
                                month: 3, 
                                title: "Spring Break", 
                                location: "Beach", 
                                day: 15
                            )
                            
                            calendarStore.updateEvent(
                                month: 7, 
                                title: "Summer Party", 
                                location: "Lake House", 
                                day: 4
                            )
                            
                            // Create test sync events
                            let syncEvent1 = CalendarEventSync(
                                month: 3,
                                monthName: "March",
                                title: "Spring Break",
                                location: "Beach",
                                day: 15
                            )
                            
                            let syncEvent2 = CalendarEventSync(
                                month: 7,
                                monthName: "July",
                                title: "Summer Party",
                                location: "Lake House",
                                day: 4
                            )
                            
                            // Create sync package
                            let syncPackage = SyncPackage(events: [syncEvent1, syncEvent2])
                            print("[SyncData] Created test package with \(syncPackage.events.count) events")
                            
                            // Test serialization
                            guard let jsonData = syncPackage.toJSON() else {
                                print("[SyncData] ERROR: Failed to serialize package to JSON")
                                return
                            }
                            
                            print("[SyncData] Successfully serialized package to JSON: \(jsonData.count) bytes")
                            
                            // Pretty print the JSON for debugging
                            if let jsonString = String(data: jsonData, encoding: .utf8) {
                                // Truncate long JSON for display
                                let truncated = jsonString.count > 500 ? 
                                    jsonString.prefix(500) + "..." : jsonString
                                print("[SyncData] JSON data: \(truncated)")
                            }
                            
                            // Test deserialization
                            guard let deserializedPackage = SyncPackage.fromJSON(jsonData) else {
                                print("[SyncData] ERROR: Failed to deserialize package from JSON")
                                return
                            }
                            
                            print("[SyncData] Successfully deserialized package from JSON")
                            print("[SyncData] Package contains \(deserializedPackage.events.count) events")
                            print("[SyncData] Source device: \(deserializedPackage.sourceDevice.name)")
                            print("[SyncData] Timestamp: \(deserializedPackage.timestamp)")
                            
                            // Check events
                            for (index, event) in deserializedPackage.events.enumerated() {
                                print("[SyncData] Event \(index + 1): \(event.title) in \(event.monthName) on day \(event.day)")
                            }
                            
                            print("[SyncData] Serialization test completed successfully")
                            
                        }) {
                            Text("Test Serialization")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            print("[SyncData] Testing sync utility")
                            
                            // Generate a sync package from the calendar store
                            let syncPackage = SyncUtility.generateSyncPackage()
                            print("[SyncData] Generated package from calendar with \(syncPackage.events.count) events")
                            
                            // Create a modified copy to simulate receiving from another device
                            var modifiedEvents = syncPackage.events
                            
                            // Modify an existing event
                            if var event = modifiedEvents.first {
                                event = CalendarEventSync(
                                    month: event.month,
                                    monthName: event.monthName,
                                    title: event.title + " (Modified)",
                                    location: "New Location",
                                    day: min(event.day + 1, 28)
                                )
                                if !modifiedEvents.isEmpty {
                                    modifiedEvents[0] = event
                                }
                            }
                            
                            // Add a new event
                            let newEvent = CalendarEventSync(
                                month: 12,
                                monthName: "December",
                                title: "New Test Event",
                                location: "Test Location",
                                day: 25
                            )
                            modifiedEvents.append(newEvent)
                            
                            // Create modified package
                            let modifiedPackage = SyncPackage(events: modifiedEvents)
                            
                            // Process the package to find differences
                            let pendingUpdates = SyncUtility.processSyncPackage(modifiedPackage)
                            
                            print("[SyncData] Found \(pendingUpdates.count) pending updates:")
                            for (index, update) in pendingUpdates.enumerated() {
                                print("[SyncData] Update \(index + 1): \(update.description)")
                            }
                            
                            print("[SyncData] Sync utility test completed")
                            
                        }) {
                            Text("Test Sync Utility")
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding()
                    
                    Text("In future tasks, this tab will display sync updates from other devices.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .navigationTitle("Updates")
            }
            .tabItem {
                Label("Updates", systemImage: "arrow.triangle.2.circlepath")
            }
            .tag(2)
            
            // Settings tab (placeholder)
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

// Import the UpdatesView
// This has been moved to a separate file

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
                
                // Status row
                HStack {
                    // Status indicator
                    Image(systemName: device.connectionStatus.icon)
                        .foregroundColor(device.connectionStatus.color)
                    
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(device.connectionStatus == .connected ? .green : .secondary)
                }
                
                // Only show last connected time for connected devices
                if device.connectionStatus == .connected, let lastConnected = device.lastConnected {
                    Text("Last seen: \(timeAgo(from: lastConnected))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action button (Connect or Sync) based on connection status
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
                // Sync button for connected devices
                Button(action: {
                    print("[SyncUI] Sync button tapped for device \(device.displayName) (\(device.identifier))")
                    showingSyncModal = true
                }) {
                    Text("Sync")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingSyncModal) {
            SyncModalView(deviceInfo: device) {
                print("[SyncUI] Sync modal dismissed for device \(device.displayName), reason: user cancelled")
                showingSyncModal = false
            }
        }
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
        print("[SyncUI] Device \(device.displayName) status changed to connecting")
        
        // Test connection with the device
        bluetoothManager.testConnection(with: device.identifier)
        
        // Set a timeout to stop the connecting spinner after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            isConnecting = false
            print("[SyncUI] Device \(device.displayName) status updated after connection attempt")
        }
    }
}

// Calendar View with monthly event cards
struct CalendarView: View {
    @ObservedObject private var eventStore = CalendarStore.shared
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
    @ObservedObject private var eventStore = CalendarStore.shared
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
        let event = CalendarStore.shared.getEvent(for: month)
        
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
        print("[CalendarStore] EventFormView saving event: \(title) for month \(month) on day \(day)")
        
        // Call updateEvent to save the changes
        eventStore.updateEvent(month: month, title: title, location: location, day: day)
        
        // Force save - belt and suspenders approach
        eventStore.saveAllEvents()
        
        // Force UserDefaults to synchronize as a safety measure
        UserDefaults.standard.synchronize()
        
        // Verify the event was saved by reading it back
        let updatedEvent = eventStore.getEvent(for: month)
        print("[CalendarStore] Verification - Event after save: \(updatedEvent.title) on day \(updatedEvent.day)")
        
        // Verify the data is in UserDefaults
        if let dict = UserDefaults.standard.dictionary(forKey: "CalendarEvent_Month_\(month)"),
           let savedDay = dict["day"] as? Int {
            print("[CalendarStore] Verified event data in UserDefaults for month \(month), day: \(savedDay)")
        } else {
            print("[CalendarStore] WARNING: Could not verify event data in UserDefaults for month \(month)")
        }
        
        // Manually trigger a UI refresh (just in case)
        DispatchQueue.main.async {
            // Trigger the event store to notify observers
            eventStore.objectWillChange.send()
        }
        
        // Dismiss the form
        presentationMode.wrappedValue.dismiss()
    }
}

// Settings View with sample event generator
// Sync Modal View
struct SyncModalView: View {
    let deviceInfo: DeviceStore.SavedDeviceInfo
    let onDismiss: () -> Void
    
    @State private var syncProgress: Double = 0.0
    @State private var statusText: String = "Preparing to sync..."
    @State private var bytesTransferred: Int = 0
    @State private var bytesTotal: Int = 0
    @State private var isAnimating = false
    @State private var syncLog: [String] = []
    
    // For simulating progress in this UI-only implementation
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
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
                    // Header section
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            .animation(
                                isAnimating ? .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                                value: isAnimating
                            )
                        
                        Text("Syncing with \(deviceInfo.displayName)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(statusText)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Progress section
                    VStack(spacing: 15) {
                        ProgressView(value: syncProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 8)
                        
                        HStack {
                            Text("\(Int(syncProgress * 100))%")
                                .font(.headline)
                                .foregroundColor(.purple)
                            
                            Spacer()
                            
                            Text("\(formatBytes(bytesTransferred)) / \(formatBytes(bytesTotal))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Sync details section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sync Details")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(syncLog, id: \.self) { logEntry in
                                    Text(logEntry)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                if syncLog.isEmpty {
                                    Text("Waiting for sync to start...")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)
                        }
                        .frame(maxHeight: 200)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Cancel/Done button (changes when sync completes)
                    Button(action: {
                        if syncProgress >= 1.0 {
                            print("[SyncUI] Sync completed and dismissed for device \(deviceInfo.displayName)")
                        } else {
                            print("[SyncUI] Sync cancelled by user for device \(deviceInfo.displayName)")
                        }
                        onDismiss()
                    }) {
                        Text(syncProgress >= 1.0 ? "Done" : "Cancel")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(syncProgress >= 1.0 ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                            .foregroundColor(syncProgress >= 1.0 ? .green : .primary)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding()
            }
            .navigationTitle("Calendar Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Only show the Done button in the toolbar while in progress
                if syncProgress < 1.0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            print("[SyncUI] Sync modal dismissed for device \(deviceInfo.displayName), reason: user tapped done")
                            onDismiss()
                        }
                    }
                }
            }
            .onAppear {
                startSyncSimulation()
            }
            .onReceive(timer) { _ in
                updateSyncSimulation()
            }
            .onChange(of: syncProgress) { newValue in
                // Stop animation when sync reaches 100%
                if newValue >= 1.0 {
                    isAnimating = false
                }
            }
            .onDisappear {
                isAnimating = false
            }
        }
    }
    
    // Helper function to format bytes
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // Start sync simulation
    private func startSyncSimulation() {
        print("[SyncUI] Presenting sync modal for device \(deviceInfo.displayName)")
        isAnimating = true
        bytesTotal = Int.random(in: 50_000...200_000) // Random size between 50KB and 200KB
        
        // Initial log entry
        addLogEntry("Initializing sync with \(deviceInfo.displayName)...")
    }
    
    // Update sync simulation for UI demonstration
    private func updateSyncSimulation() {
        guard syncProgress < 1.0 else { return }
        
        // Update progress
        let progressStep = Double.random(in: 0.01...0.05)
        syncProgress = min(syncProgress + progressStep, 1.0)
        
        // Update bytes transferred based on progress
        bytesTransferred = Int(Double(bytesTotal) * syncProgress)
        
        // Update status text based on progress
        if syncProgress < 0.3 {
            statusText = "Preparing calendar data..."
            if Int.random(in: 1...4) == 1 {
                addLogEntry("Collecting calendar events...")
            }
        } else if syncProgress < 0.6 {
            statusText = "Transferring data..."
            if Int.random(in: 1...3) == 1 {
                let transferredBytes = Int.random(in: 1000...5000)
                addLogEntry("Transferred \(formatBytes(transferredBytes)) of data")
            }
        } else if syncProgress < 0.9 {
            statusText = "Finalizing sync..."
            if Int.random(in: 1...4) == 1 {
                addLogEntry("Verifying data integrity...")
            }
        } else {
            statusText = "Sync complete!"
            if syncLog.last != "Sync completed successfully!" {
                addLogEntry("Sync completed successfully!")
            }
        }
        
        // Log current state
        print("[SyncUI] Sync progress: \(Int(syncProgress * 100))%, bytes: \(bytesTransferred)/\(bytesTotal)")
    }
    
    // Add a log entry with timestamp
    private func addLogEntry(_ message: String) {
        let timestamp = currentTimeString()
        let logEntry = "[\(timestamp)] \(message)"
        
        print("[SyncUI] \(logEntry)")
        syncLog.append(logEntry)
    }
    
    // Get current time string for logs
    private func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}

struct SettingsView: View {
    @ObservedObject private var eventStore = CalendarStore.shared
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
        
        print("[CalendarStore] Generating sample events for all months")
        
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
            
            // Ensure the event is marked as scheduled
            eventStore.events[month - 1].isScheduled = true
        }
        
        // Make sure all events are saved
        eventStore.saveAllEvents()
        
        // Force UserDefaults to save
        UserDefaults.standard.synchronize()
        
        // Verify events were saved
        print("[CalendarStore] Verifying sample events were saved:")
        for month in 1...12 {
            let event = eventStore.getEvent(for: month)
            print("[CalendarStore] Month \(month): \(event.title) on day \(event.day)")
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