import Foundation
import SwiftUI

/// Test view for verifying SyncPackage functionality
struct SyncPackageTester: View {
    @State private var testOutput: String = "Test results will appear here..."
    @State private var isRunningTests = false
    @State private var testJsonOutput: String = ""
    @State private var showJsonDetail = false
    
    var body: some View {
        VStack {
            Text("SyncPackage Test Suite")
                .font(.headline)
                .padding()
            
            HStack(spacing: 20) {
                Button(action: {
                    isRunningTests = true
                    testOutput = "Running tests...\n"
                    
                    // Run tests in background
                    DispatchQueue.global(qos: .userInitiated).async {
                        let results = runTests()
                        
                        // Update UI on main thread
                        DispatchQueue.main.async {
                            testOutput = results.output
                            testJsonOutput = results.json
                            isRunningTests = false
                        }
                    }
                }) {
                    HStack {
                        Text("Run Full Tests")
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
                
                Button(action: {
                    isRunningTests = true
                    testOutput = "Running serialization test...\n"
                    
                    // Run only serialization test
                    DispatchQueue.global(qos: .userInitiated).async {
                        let results = testSerialization()
                        
                        // Update UI on main thread
                        DispatchQueue.main.async {
                            testOutput = results.output
                            testJsonOutput = results.json
                            isRunningTests = false
                        }
                    }
                }) {
                    HStack {
                        Text("Test Serialization")
                        if isRunningTests {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isRunningTests)
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Test Results:")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    Text(testOutput)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !testJsonOutput.isEmpty {
                        Divider()
                            .padding(.vertical)
                        
                        Button(action: {
                            showJsonDetail.toggle()
                        }) {
                            HStack {
                                Image(systemName: showJsonDetail ? "chevron.down" : "chevron.right")
                                Text("JSON Output")
                                    .font(.headline)
                            }
                        }
                        .padding(.bottom, 5)
                        
                        if showJsonDetail {
                            Text(testJsonOutput)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.black.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: .infinity)
            .background(Color.black.opacity(0.05))
            .cornerRadius(8)
            .padding()
        }
    }
    
    /// Run all tests and return results as a string
    private func runTests() -> (output: String, json: String) {
        var output = "SyncPackage Tests\n==================\n\n"
        var jsonOutput = ""
        
        // Test DeviceInfo
        output += "1. Testing DeviceInfo\n"
        output += "--------------------\n"
        let deviceInfo = DeviceInfo.current
        output += "Device: \(deviceInfo.name)\n"
        output += "ID: \(deviceInfo.identifier)\n"
        output += "System: \(deviceInfo.system)\n"
        output += "App Version: \(deviceInfo.appVersion)\n\n"
        
        // Test CalendarEventSync
        output += "2. Testing CalendarEventSync\n"
        output += "---------------------------\n"
        let event = CalendarEventSync(
            month: 7,
            monthName: "July",
            title: "Summer Party",
            location: "Beach",
            day: 15
        )
        output += "Created event: \(event.title) in \(event.monthName) on day \(event.day)\n"
        output += "Is valid: \(event.isValid())\n\n"
        
        // Test Invalid Events
        output += "3. Testing Invalid Events\n"
        output += "------------------------\n"
        let invalidMonth = CalendarEventSync(
            month: 13,
            monthName: "Invalid",
            title: "Test",
            location: "Test",
            day: 15
        )
        output += "Invalid month (13): validation result = \(invalidMonth.isValid())\n"
        
        let invalidDay = CalendarEventSync(
            month: 4,
            monthName: "April",
            title: "Test",
            location: "Test",
            day: 31
        )
        output += "Invalid day (April 31): validation result = \(invalidDay.isValid())\n\n"
        
        // Test Converting to CalendarEvent
        let calendarEvent = event.toCalendarEvent()
        output += "4. Testing Conversion to CalendarEvent\n"
        output += "----------------------------------\n"
        output += "Converted to CalendarEvent: \(calendarEvent.title) on day \(calendarEvent.day)\n"
        output += "Is scheduled: \(calendarEvent.isScheduled)\n\n"
        
        // Test SyncPackage
        output += "5. Testing SyncPackage\n"
        output += "--------------------\n"
        let syncPackage = SyncPackage(events: [event])
        output += "Created package with \(syncPackage.events.count) events\n"
        output += "From device: \(syncPackage.sourceDevice.name)\n"
        output += "Is valid: \(syncPackage.isValid())\n\n"
        
        // Test JSON serialization
        let serializationResults = testSerialization()
        output += serializationResults.output
        jsonOutput = serializationResults.json
        
        // Test the SyncUtility functions
        output += "7. Testing SyncUtility\n"
        output += "--------------------\n"
        
        // Create test data in the calendar store
        let calendarStore = CalendarStore.shared
        calendarStore.updateEvent(
            month: 6,
            title: "Test Event",
            location: "Test Location",
            day: 15
        )
        
        // Generate sync package
        let generatedPackage = SyncUtility.generateSyncPackage()
        output += "Generated package with \(generatedPackage.events.count) events\n"
        
        // Create a modified package to test diff detection
        var modifiedEvents = generatedPackage.events.count > 0 ? generatedPackage.events : [event]
        
        // Add a new event if we don't have one for month 8
        if !modifiedEvents.contains(where: { $0.month == 8 }) {
            let augustEvent = CalendarEventSync(
                month: 8,
                monthName: "August",
                title: "Vacation",
                location: "Mountains",
                day: 10
            )
            modifiedEvents.append(augustEvent)
            output += "Added new event for August\n"
        }
        
        // Modify an existing event
        if let index = modifiedEvents.firstIndex(where: { $0.month == 6 }) {
            let original = modifiedEvents[index]
            let modified = CalendarEventSync(
                month: 6,
                monthName: "June",
                title: "Modified Test Event",
                location: "New Location",
                day: 20
            )
            modifiedEvents[index] = modified
            output += "Modified the June event (title: \(original.title) -> \(modified.title))\n"
        }
        
        // Create modified package and test diff detection
        let modifiedPackage = SyncPackage(events: modifiedEvents)
        let pendingUpdates = SyncUtility.processSyncPackage(modifiedPackage)
        
        output += "Found \(pendingUpdates.count) pending updates:\n"
        for (i, update) in pendingUpdates.enumerated() {
            output += "  \(i+1). \(update.sourceDevice) \(update.description)\n"
        }
        
        // Test applying an update
        if let firstUpdate = pendingUpdates.first {
            output += "\nTesting applying update: \(firstUpdate.description)\n"
            SyncUtility.applyUpdate(firstUpdate)
            output += "Update applied successfully\n"
        }
        
        output += "\nAll tests completed!\n"
        return (output, jsonOutput)
    }
    
    /// Test serialization and deserialization
    private func testSerialization() -> (output: String, json: String) {
        var output = "6. Testing JSON Serialization\n"
        output += "--------------------------\n"
        var jsonOutput = ""
        
        // Create test data
        let event1 = CalendarEventSync(
            month: 3,
            monthName: "March",
            title: "Spring Break",
            location: "Beach Resort",
            day: 10
        )
        
        let event2 = CalendarEventSync(
            month: 10,
            monthName: "October",
            title: "Halloween Party",
            location: "Community Center",
            day: 31
        )
        
        let originalPackage = SyncPackage(events: [event1, event2])
        
        // Test serialization to JSON
        if let jsonData = originalPackage.toJSON() {
            output += "Serialized to \(jsonData.count) bytes\n"
            
            // Store JSON for detailed view
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                // Pretty print the JSON
                if let jsonObj = try? JSONSerialization.jsonObject(with: jsonData),
                   let prettyData = try? JSONSerialization.data(withJSONObject: jsonObj, options: [.prettyPrinted, .sortedKeys]),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    jsonOutput = prettyString
                } else {
                    jsonOutput = jsonString
                }
                
                output += "JSON output sample (truncated):\n"
                let truncated = jsonString.count > 100 ? String(jsonString.prefix(100)) + "..." : jsonString
                output += truncated + "\n\n"
            }
            
            // Test deserialization
            if let deserializedPackage = SyncPackage.fromJSON(jsonData) {
                output += "Successfully deserialized package\n"
                output += "Deserialized package properties:\n"
                output += "- Version: \(deserializedPackage.syncVersion)\n"
                output += "- Source device: \(deserializedPackage.sourceDevice.name)\n"
                output += "- Events count: \(deserializedPackage.events.count)\n"
                output += "- Timestamp: \(formatDate(deserializedPackage.timestamp))\n"
                
                // Verify events
                output += "\nDeserialized events:\n"
                for (i, event) in deserializedPackage.events.enumerated() {
                    output += "  \(i+1). \(event.monthName): \(event.title) on day \(event.day) at \(event.location)\n"
                }
                
                output += "\nSerialization test passed ✓\n\n"
            } else {
                output += "Failed to deserialize package ✗\n\n"
            }
        } else {
            output += "Failed to serialize package ✗\n\n"
        }
        
        return (output, jsonOutput)
    }
    
    // Format date for display
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SyncPackageTester()
}