import Foundation
import XCTest
import SwiftUI

/// Test class for SyncPackage functionality
/// This file contains test cases for the SyncPackage implementation
/// Important: This is not a formal XCTest file, but a simulation of one that can be run manually
class SyncPackageTests {
    
    /// Run all tests and return detailed results
    /// - Returns: A detailed test output string
    static func runTests() -> String {
        print("\n[TEST] Starting SyncPackage Tests")
        print("[TEST] ===========================")
        
        var output = ""
        var allTestsPassed = true
        
        // Run individual tests and collect results
        output += runTest("DeviceInfo", testDeviceInfo())
        output += runTest("CalendarEventSync Valid", testCalendarEventSync())
        output += runTest("CalendarEventSync Invalid", testInvalidCalendarEvents())
        output += runTest("SyncPackage Creation", testSyncPackage())
        output += runTest("JSON Serialization", testSerialization())
        output += runTest("JSON Deserialization", testDeserialization())
        output += runTest("Utility Functions", testUtilityFunctions())
        
        // Print test summary
        print("[TEST] ===========================")
        if allTestsPassed {
            output += "\n✅ All tests PASSED\n"
            print("[TEST] All tests PASSED")
        } else {
            output += "\n❌ Some tests FAILED\n"
            print("[TEST] Some tests FAILED")
        }
        print("[TEST] SyncPackage Tests Complete\n")
        
        return output
        
        // Helper function to run and format a test
        func runTest(_ name: String, _ result: (passed: Bool, message: String)) -> String {
            if !result.passed {
                allTestsPassed = false
            }
            
            let status = result.passed ? "✅ PASS" : "❌ FAIL"
            let output = "\n===== \(name) Test =====\n"
                + "\(result.message)\n"
                + "Result: \(status)\n"
            
            print("[TEST] \(name) Test: \(result.passed ? "PASSED" : "FAILED")")
            return output
        }
    }
    
    // Test DeviceInfo model
    static func testDeviceInfo() -> (passed: Bool, message: String) {
        var output = ""
        var passed = true
        
        // Get current device info
        let deviceInfo = DeviceInfo.current
        
        // Verify properties
        output += "Device name: \(deviceInfo.name)\n"
        output += "Device identifier: \(deviceInfo.identifier)\n"
        output += "Device system: \(deviceInfo.system)\n"
        output += "App version: \(deviceInfo.appVersion)\n\n"
        
        // Basic assertions
        if deviceInfo.name.isEmpty {
            output += "ERROR: Device name should not be empty\n"
            passed = false
        }
        
        if deviceInfo.identifier.isEmpty {
            output += "ERROR: Device identifier should not be empty\n"
            passed = false
        }
        
        if deviceInfo.system.isEmpty {
            output += "ERROR: Device system should not be empty\n"
            passed = false
        }
        
        if deviceInfo.appVersion.isEmpty {
            output += "ERROR: App version should not be empty\n"
            passed = false
        }
        
        return (passed, output)
    }
    
    // Test CalendarEventSync model
    static func testCalendarEventSync() -> (passed: Bool, message: String) {
        var output = ""
        var passed = true
        
        // Create a test event
        let eventSync = CalendarEventSync(
            month: 7,
            monthName: "July",
            title: "Summer Party",
            location: "Beach",
            day: 15
        )
        
        // Test basic properties
        output += "Created event: \(eventSync.title) in \(eventSync.monthName) on day \(eventSync.day)\n"
        output += "Validation result: \(eventSync.isValid())\n\n"
        
        // Test assertions
        if eventSync.month != 7 {
            output += "ERROR: Month should be 7\n"
            passed = false
        }
        
        if eventSync.monthName != "July" {
            output += "ERROR: Month name should be July\n"
            passed = false
        }
        
        if eventSync.title != "Summer Party" {
            output += "ERROR: Title should be Summer Party\n"
            passed = false
        }
        
        if eventSync.location != "Beach" {
            output += "ERROR: Location should be Beach\n"
            passed = false
        }
        
        if eventSync.day != 15 {
            output += "ERROR: Day should be 15\n"
            passed = false
        }
        
        if !eventSync.isValid() {
            output += "ERROR: Event should be valid\n"
            passed = false
        }
        
        // Test conversion to CalendarEvent
        let calendarEvent = eventSync.toCalendarEvent()
        output += "Converted to CalendarEvent:\n"
        output += "- Title: \(calendarEvent.title)\n"
        output += "- Month: \(calendarEvent.month) (\(calendarEvent.monthName))\n"
        output += "- Day: \(calendarEvent.day)\n"
        output += "- Location: \(calendarEvent.location)\n"
        output += "- Scheduled: \(calendarEvent.isScheduled)\n\n"
        
        if calendarEvent.month != eventSync.month {
            output += "ERROR: Calendar event month doesn't match\n"
            passed = false
        }
        
        if calendarEvent.title != eventSync.title {
            output += "ERROR: Calendar event title doesn't match\n"
            passed = false
        }
        
        if calendarEvent.day != eventSync.day {
            output += "ERROR: Calendar event day doesn't match\n"
            passed = false
        }
        
        if !calendarEvent.isScheduled {
            output += "ERROR: Calendar event should be scheduled\n"
            passed = false
        }
        
        return (passed, output)
    }
    
    // Test invalid CalendarEventSync instances
    static func testInvalidCalendarEvents() -> (passed: Bool, message: String) {
        var output = ""
        var passed = true
        
        // Test invalid month
        let invalidMonthEvent = CalendarEventSync(
            month: 13,  // Invalid month (should be 1-12)
            monthName: "Invalid",
            title: "Test",
            location: "Test",
            day: 1
        )
        
        output += "Testing invalid month (13):\n"
        output += "Validation result: \(invalidMonthEvent.isValid())\n\n"
        
        if invalidMonthEvent.isValid() {
            output += "ERROR: Event with month 13 should be invalid\n"
            passed = false
        }
        
        // Test invalid day
        let invalidDayEvent = CalendarEventSync(
            month: 4,  // April
            monthName: "April",
            title: "Test",
            location: "Test",
            day: 31  // April has 30 days
        )
        
        output += "Testing invalid day (April 31):\n"
        output += "Validation result: \(invalidDayEvent.isValid())\n\n"
        
        if invalidDayEvent.isValid() {
            output += "ERROR: Event with April 31 should be invalid\n"
            passed = false
        }
        
        // Test February with invalid day for leap year
        let currentYear = Calendar.current.component(.year, from: Date())
        let isLeapYear = (currentYear % 4 == 0 && currentYear % 100 != 0) || (currentYear % 400 == 0)
        let maxFebDay = isLeapYear ? 29 : 28
        
        let invalidFebDayEvent = CalendarEventSync(
            month: 2,  // February
            monthName: "February",
            title: "Test",
            location: "Test",
            day: 30  // February has 28 or 29 days
        )
        
        output += "Testing invalid February day (30):\n"
        output += "Current year: \(currentYear), is leap year: \(isLeapYear), max Feb days: \(maxFebDay)\n"
        output += "Validation result: \(invalidFebDayEvent.isValid())\n\n"
        
        if invalidFebDayEvent.isValid() {
            output += "ERROR: Event with February 30 should be invalid\n"
            passed = false
        }
        
        // Test empty title
        let emptyTitleEvent = CalendarEventSync(
            month: 5,
            monthName: "May",
            title: "",  // Empty title
            location: "Test",
            day: 15
        )
        
        output += "Testing empty title:\n"
        output += "Validation result: \(emptyTitleEvent.isValid())\n\n"
        
        if emptyTitleEvent.isValid() {
            output += "ERROR: Event with empty title should be invalid\n"
            passed = false
        }
        
        return (passed, output)
    }
    
    // Test SyncPackage model
    static func testSyncPackage() -> (passed: Bool, message: String) {
        var output = ""
        var passed = true
        
        // Create test events
        let event1 = CalendarEventSync(
            month: 3,
            monthName: "March",
            title: "Spring Break",
            location: "Mountains",
            day: 10
        )
        
        let event2 = CalendarEventSync(
            month: 8,
            monthName: "August",
            title: "Beach Trip",
            location: "Florida",
            day: 22
        )
        
        // Create a package with the events
        let syncPackage = SyncPackage(events: [event1, event2])
        
        // Verify properties
        output += "Created SyncPackage:\n"
        output += "- Version: \(syncPackage.syncVersion)\n"
        output += "- Source device: \(syncPackage.sourceDevice.name)\n"
        output += "- Events count: \(syncPackage.events.count)\n"
        output += "- Timestamp: \(formatDate(syncPackage.timestamp))\n\n"
        
        if syncPackage.syncVersion != "1.0" {
            output += "ERROR: Version should be 1.0\n"
            passed = false
        }
        
        if syncPackage.events.count != 2 {
            output += "ERROR: Package should have 2 events\n"
            passed = false
        }
        
        // Test validation
        output += "Package validation result: \(syncPackage.isValid())\n\n"
        
        if !syncPackage.isValid() {
            output += "ERROR: Package should be valid\n"
            passed = false
        }
        
        // Test empty package
        let emptyPackage = SyncPackage(events: [])
        output += "Empty package:\n"
        output += "- Events count: \(emptyPackage.events.count)\n"
        output += "- Validation result: \(emptyPackage.isValid())\n\n"
        
        if !emptyPackage.isValid() {
            output += "ERROR: Empty package should still be valid\n"
            passed = false
        }
        
        return (passed, output)
    }
    
    // Test serialization
    static func testSerialization() -> (passed: Bool, message: String) {
        var output = ""
        var passed = true
        
        // Create a test package
        let event1 = CalendarEventSync(
            month: 5,
            monthName: "May",
            title: "Graduation",
            location: "University",
            day: 25
        )
        
        let event2 = CalendarEventSync(
            month: 11,
            monthName: "November",
            title: "Thanksgiving",
            location: "Home",
            day: 24
        )
        
        let originalPackage = SyncPackage(events: [event1, event2])
        
        // Test serialization to JSON
        guard let jsonData = originalPackage.toJSON() else {
            output += "ERROR: Failed to serialize package to JSON\n"
            return (false, output)
        }
        
        output += "Successfully serialized package to JSON (\(jsonData.count) bytes)\n"
        
        // Check JSON format by logging a sample
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            let truncated = jsonString.count > 100 ? String(jsonString.prefix(100)) + "..." : jsonString
            output += "JSON sample: \(truncated)\n\n"
        }
        
        // Make sure we can convert it to a JSONObject
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
            guard let dict = jsonObject as? [String: Any] else {
                output += "ERROR: JSON is not a dictionary\n"
                passed = false
                return (passed, output)
            }
            
            // Verify required properties exist in JSON
            let requiredProperties = ["syncVersion", "sourceDevice", "timestamp", "events"]
            for property in requiredProperties {
                if dict[property] == nil {
                    output += "ERROR: JSON missing required property: \(property)\n"
                    passed = false
                }
            }
            
            // Verify events array
            if let events = dict["events"] as? [[String: Any]] {
                output += "JSON contains \(events.count) events\n"
                
                if events.count != originalPackage.events.count {
                    output += "ERROR: JSON events count doesn't match original package\n"
                    passed = false
                }
            } else {
                output += "ERROR: Events property is not an array\n"
                passed = false
            }
            
        } catch {
            output += "ERROR: JSON parsing failed: \(error.localizedDescription)\n"
            passed = false
        }
        
        return (passed, output)
    }
    
    // Test deserialization
    static func testDeserialization() -> (passed: Bool, message: String) {
        var output = ""
        var passed = true
        
        // Create a test package
        let event1 = CalendarEventSync(
            month: 5,
            monthName: "May",
            title: "Graduation",
            location: "University",
            day: 25
        )
        
        let event2 = CalendarEventSync(
            month: 11,
            monthName: "November",
            title: "Thanksgiving",
            location: "Home",
            day: 24
        )
        
        let originalPackage = SyncPackage(events: [event1, event2])
        
        // Test serialization to JSON
        guard let jsonData = originalPackage.toJSON() else {
            output += "ERROR: Failed to serialize package to JSON\n"
            return (false, output)
        }
        
        // Test deserialization from JSON
        guard let deserializedPackage = SyncPackage.fromJSON(jsonData) else {
            output += "ERROR: Failed to deserialize package from JSON\n"
            return (false, output)
        }
        
        output += "Successfully deserialized package from JSON\n"
        
        // Verify deserialized properties
        output += "Comparing original and deserialized packages:\n"
        
        // Check version
        if deserializedPackage.syncVersion != originalPackage.syncVersion {
            output += "ERROR: Deserialized version doesn't match: \(deserializedPackage.syncVersion) vs \(originalPackage.syncVersion)\n"
            passed = false
        } else {
            output += "✓ Version matches\n"
        }
        
        // Check source device
        if deserializedPackage.sourceDevice.name != originalPackage.sourceDevice.name {
            output += "ERROR: Deserialized source device name doesn't match\n"
            passed = false
        } else {
            output += "✓ Source device matches\n"
        }
        
        // Check events count
        if deserializedPackage.events.count != originalPackage.events.count {
            output += "ERROR: Deserialized event count doesn't match: \(deserializedPackage.events.count) vs \(originalPackage.events.count)\n"
            passed = false
        } else {
            output += "✓ Event count matches (\(deserializedPackage.events.count))\n"
        }
        
        // Check individual events
        output += "\nComparing events:\n"
        
        for i in 0..<min(deserializedPackage.events.count, originalPackage.events.count) {
            let original = originalPackage.events[i]
            let deserialized = deserializedPackage.events[i]
            
            output += "Event \(i+1):\n"
            
            if deserialized.month != original.month {
                output += "  ERROR: Month doesn't match: \(deserialized.month) vs \(original.month)\n"
                passed = false
            }
            
            if deserialized.title != original.title {
                output += "  ERROR: Title doesn't match: \(deserialized.title) vs \(original.title)\n"
                passed = false
            }
            
            if deserialized.location != original.location {
                output += "  ERROR: Location doesn't match: \(deserialized.location) vs \(original.location)\n"
                passed = false
            }
            
            if deserialized.day != original.day {
                output += "  ERROR: Day doesn't match: \(deserialized.day) vs \(original.day)\n"
                passed = false
            }
        }
        
        if passed {
            output += "\nAll event properties match correctly\n"
        }
        
        return (passed, output)
    }
    
    // Test utility functions
    static func testUtilityFunctions() -> (passed: Bool, message: String) {
        var output = ""
        var passed = true
        
        // Create and populate calendar store for testing
        let calendarStore = CalendarStore.shared
        
        // Update some test events in the calendar
        calendarStore.updateEvent(
            month: 4,
            title: "Earth Day Celebration",
            location: "Park",
            day: 22
        )
        
        calendarStore.updateEvent(
            month: 9,
            title: "Fall Festival",
            location: "Downtown",
            day: 15
        )
        
        output += "Created test calendar events:\n"
        output += "1. \(calendarStore.getEvent(for: 4).monthName): \(calendarStore.getEvent(for: 4).title)\n"
        output += "2. \(calendarStore.getEvent(for: 9).monthName): \(calendarStore.getEvent(for: 9).title)\n\n"
        
        // Save events to make sure they're persisted
        calendarStore.saveAllEvents()
        
        // Test generating a sync package
        let syncPackage = SyncUtility.generateSyncPackage()
        
        output += "Generated sync package from calendar data:\n"
        output += "- Events count: \(syncPackage.events.count)\n"
        output += "- Validation result: \(syncPackage.isValid())\n\n"
        
        if !syncPackage.isValid() {
            output += "ERROR: Generated package should be valid\n"
            passed = false
        }
        
        // Create a modified package to simulate receiving from another device
        var modifiedEvents = syncPackage.events
        
        // Modify an existing event if we have one for month 4
        if let index = modifiedEvents.firstIndex(where: { $0.month == 4 }) {
            let original = modifiedEvents[index]
            modifiedEvents[index] = CalendarEventSync(
                month: 4,
                monthName: "April",
                title: "Earth Day Festival", // Changed title
                location: "City Park",       // Changed location
                day: 21                      // Changed day
            )
            
            output += "Modified April event:\n"
            output += "- Original title: \(original.title) -> New title: Earth Day Festival\n"
            output += "- Original location: \(original.location) -> New location: City Park\n"
            output += "- Original day: \(original.day) -> New day: 21\n\n"
        }
        
        // Add a new December event if not present
        if !modifiedEvents.contains(where: { $0.month == 12 }) {
            let decemberEvent = CalendarEventSync(
                month: 12,
                monthName: "December",
                title: "Holiday Party",
                location: "Community Center",
                day: 20
            )
            modifiedEvents.append(decemberEvent)
            
            output += "Added new December event: Holiday Party\n\n"
        }
        
        // Create a modified package and test diff detection
        let modifiedPackage = SyncPackage(events: modifiedEvents)
        let pendingUpdates = SyncUtility.processSyncPackage(modifiedPackage)
        
        output += "Detected \(pendingUpdates.count) pending updates from modified package\n"
        
        for (i, update) in pendingUpdates.enumerated() {
            output += "\(i+1). \(update.sourceDevice) \(update.description)\n"
        }
        
        if pendingUpdates.isEmpty {
            output += "ERROR: Should have detected at least one update\n"
            passed = false
        }
        
        // Test applying an update
        if let firstUpdate = pendingUpdates.first {
            output += "\nApplying update: \(firstUpdate.description)\n"
            
            let originalEvent = calendarStore.getEvent(for: firstUpdate.month)
            let originalEventSnapshot = "Month: \(originalEvent.month), Title: \(originalEvent.title), Location: \(originalEvent.location), Day: \(originalEvent.day)"
            
            SyncUtility.applyUpdate(firstUpdate)
            
            let updatedEvent = calendarStore.getEvent(for: firstUpdate.month)
            let updatedEventSnapshot = "Month: \(updatedEvent.month), Title: \(updatedEvent.title), Location: \(updatedEvent.location), Day: \(updatedEvent.day)"
            
            output += "Before: \(originalEventSnapshot)\n"
            output += "After: \(updatedEventSnapshot)\n\n"
            
            let changeApplied = originalEventSnapshot != updatedEventSnapshot
            if !changeApplied {
                output += "ERROR: Update was not applied correctly\n"
                passed = false
            } else {
                output += "Update applied successfully\n"
            }
        }
        
        return (passed, output)
    }
    
    // Helper function to format dates
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}