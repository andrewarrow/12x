import Foundation
import SwiftUI

/// Simple test view to verify our SyncPackage implementation works
struct SyncPackageTester: View {
    @State private var testOutput: String = "Test results will appear here..."
    @State private var isRunningTests = false
    
    var body: some View {
        VStack {
            Text("SyncPackage Test Runner")
                .font(.headline)
                .padding()
            
            Button(action: {
                isRunningTests = true
                testOutput = "Running tests...\n"
                
                // Run tests in background
                DispatchQueue.global(qos: .background).async {
                    let results = runTests()
                    
                    // Update UI on main thread
                    DispatchQueue.main.async {
                        testOutput = results
                        isRunningTests = false
                    }
                }
            }) {
                HStack {
                    Text("Run Tests")
                    if isRunningTests {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isRunningTests)
            .padding()
            
            ScrollView {
                Text(testOutput)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            .background(Color.black.opacity(0.05))
            .cornerRadius(8)
            .padding()
        }
    }
    
    /// Run tests and return results as a string
    private func runTests() -> String {
        var output = "SyncPackage Tests\n==================\n\n"
        
        // Test DeviceInfo
        output += "Testing DeviceInfo\n"
        let deviceInfo = DeviceInfo.current
        output += "Device: \(deviceInfo.name)\n"
        output += "ID: \(deviceInfo.identifier)\n"
        output += "System: \(deviceInfo.system)\n"
        output += "App Version: \(deviceInfo.appVersion)\n\n"
        
        // Test CalendarEventSync
        output += "Testing CalendarEventSync\n"
        let event = CalendarEventSync(
            month: 7,
            monthName: "July",
            title: "Summer Party",
            location: "Beach",
            day: 15
        )
        output += "Created event: \(event.title) in \(event.monthName) on day \(event.day)\n"
        output += "Is valid: \(event.isValid())\n\n"
        
        // Test Converting to CalendarEvent
        let calendarEvent = event.toCalendarEvent()
        output += "Converted to CalendarEvent: \(calendarEvent.title) on day \(calendarEvent.day)\n\n"
        
        // Test SyncPackage
        output += "Testing SyncPackage\n"
        let syncPackage = SyncPackage(events: [event])
        output += "Created package with \(syncPackage.events.count) events\n"
        output += "From device: \(syncPackage.sourceDevice.name)\n"
        output += "Is valid: \(syncPackage.isValid())\n\n"
        
        // Test JSON serialization
        output += "Testing JSON serialization\n"
        if let jsonData = syncPackage.toJSON() {
            output += "Serialized to \(jsonData.count) bytes\n"
            
            // Deserialize
            if let deserializedPackage = SyncPackage.fromJSON(jsonData) {
                output += "Successfully deserialized package\n"
                output += "Events count: \(deserializedPackage.events.count)\n"
                if !deserializedPackage.events.isEmpty {
                    let firstEvent = deserializedPackage.events[0]
                    output += "First event: \(firstEvent.title) in \(firstEvent.monthName)\n\n"
                }
            } else {
                output += "Failed to deserialize package\n\n"
            }
        } else {
            output += "Failed to serialize package\n\n"
        }
        
        // Test SyncUtility
        output += "Testing SyncUtility\n"
        // Create and update a test event in the CalendarStore
        let calendarStore = CalendarStore.shared
        calendarStore.updateEvent(
            month: 6,
            title: "Test Event",
            location: "Test Location",
            day: 15
        )
        
        // Generate sync package from calendar
        let generatedPackage = SyncUtility.generateSyncPackage()
        output += "Generated package with \(generatedPackage.events.count) events\n"
        
        // Create a modified package
        var modifiedEvents = generatedPackage.events
        if let index = modifiedEvents.firstIndex(where: { $0.month == 6 }) {
            var modifiedEvent = modifiedEvents[index]
            modifiedEvent = CalendarEventSync(
                month: 6,
                monthName: "June",
                title: "Modified Test Event",
                location: "New Location",
                day: 20
            )
            modifiedEvents[index] = modifiedEvent
            
            let modifiedPackage = SyncPackage(events: modifiedEvents)
            let pendingUpdates = SyncUtility.processSyncPackage(modifiedPackage)
            
            output += "Found \(pendingUpdates.count) pending updates\n"
            for update in pendingUpdates {
                output += "Update: \(update.description)\n"
            }
        }
        
        output += "\nAll tests completed!\n"
        return output
    }
}