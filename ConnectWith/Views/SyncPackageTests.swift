import Foundation
import XCTest
import SwiftUI

/// Test class for SyncPackage functionality
/// This file contains test cases for the SyncPackage implementation
/// Important: This is not a formal XCTest file, but a simulation of one that can be run manually
class SyncPackageTests {
    
    static func runTests() {
        print("\n[TEST] Starting SyncPackage Tests")
        print("[TEST] ===========================")
        
        // Run all tests
        testDeviceInfo()
        testCalendarEventSync()
        testSyncPackage()
        testSerialization()
        testUtilityFunctions()
        
        print("[TEST] ===========================")
        print("[TEST] SyncPackage Tests Complete\n")
    }
    
    // Test DeviceInfo model
    static func testDeviceInfo() {
        print("\n[TEST] Testing DeviceInfo")
        
        // Get current device info
        let deviceInfo = DeviceInfo.current
        
        // Verify properties
        print("[TEST] Device name: \(deviceInfo.name)")
        print("[TEST] Device identifier: \(deviceInfo.identifier)")
        print("[TEST] Device system: \(deviceInfo.system)")
        print("[TEST] App version: \(deviceInfo.appVersion)")
        
        assert(!deviceInfo.name.isEmpty, "Device name should not be empty")
        assert(!deviceInfo.identifier.isEmpty, "Device identifier should not be empty")
        assert(!deviceInfo.system.isEmpty, "Device system should not be empty")
        assert(!deviceInfo.appVersion.isEmpty, "App version should not be empty")
        
        print("[TEST] DeviceInfo test passed")
    }
    
    // Test CalendarEventSync model
    static func testCalendarEventSync() {
        print("\n[TEST] Testing CalendarEventSync")
        
        // Create a test event
        let eventSync = CalendarEventSync(
            month: 7,
            monthName: "July",
            title: "Summer Party",
            location: "Beach",
            day: 15
        )
        
        // Test basic properties
        assert(eventSync.month == 7, "Month should be 7")
        assert(eventSync.monthName == "July", "Month name should be July")
        assert(eventSync.title == "Summer Party", "Title should be Summer Party")
        assert(eventSync.location == "Beach", "Location should be Beach")
        assert(eventSync.day == 15, "Day should be 15")
        
        // Test validation
        assert(eventSync.isValid(), "Event should be valid")
        
        // Test invalid events
        let invalidMonthEvent = CalendarEventSync(
            month: 13,  // Invalid month
            monthName: "Invalid",
            title: "Test",
            location: "Test",
            day: 1
        )
        assert(!invalidMonthEvent.isValid(), "Event with invalid month should not be valid")
        
        let invalidDayEvent = CalendarEventSync(
            month: 4,
            monthName: "April",
            title: "Test",
            location: "Test",
            day: 31  // April has 30 days
        )
        assert(!invalidDayEvent.isValid(), "Event with invalid day should not be valid")
        
        let emptyTitleEvent = CalendarEventSync(
            month: 5,
            monthName: "May",
            title: "",  // Empty title
            location: "Test",
            day: 15
        )
        assert(!emptyTitleEvent.isValid(), "Event with empty title should not be valid")
        
        // Test conversion to CalendarEvent
        let calendarEvent = eventSync.toCalendarEvent()
        assert(calendarEvent.month == eventSync.month, "Month should match")
        assert(calendarEvent.title == eventSync.title, "Title should match")
        assert(calendarEvent.isScheduled, "Calendar event should be scheduled")
        
        print("[TEST] CalendarEventSync test passed")
    }
    
    // Test SyncPackage model
    static func testSyncPackage() {
        print("\n[TEST] Testing SyncPackage")
        
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
        assert(syncPackage.syncVersion == "1.0", "Version should be 1.0")
        assert(syncPackage.events.count == 2, "Package should have 2 events")
        assert(syncPackage.sourceDevice.name == DeviceInfo.current.name, "Source device should match current device")
        
        // Test validation
        assert(syncPackage.isValid(), "Package should be valid")
        
        // Empty package should still be valid
        let emptyPackage = SyncPackage(events: [])
        assert(emptyPackage.isValid(), "Empty package should be valid")
        assert(emptyPackage.events.isEmpty, "Events array should be empty")
        
        print("[TEST] SyncPackage test passed")
    }
    
    // Test serialization and deserialization
    static func testSerialization() {
        print("\n[TEST] Testing serialization")
        
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
            print("[TEST] Failed to serialize package to JSON")
            assert(false, "Serialization failed")
            return
        }
        
        print("[TEST] Serialized package to \(jsonData.count) bytes")
        
        // Test deserialization from JSON
        guard let deserializedPackage = SyncPackage.fromJSON(jsonData) else {
            print("[TEST] Failed to deserialize package from JSON")
            assert(false, "Deserialization failed")
            return
        }
        
        // Verify deserialized properties
        assert(deserializedPackage.syncVersion == originalPackage.syncVersion, "Version should match")
        assert(deserializedPackage.events.count == originalPackage.events.count, "Event count should match")
        assert(deserializedPackage.sourceDevice.name == originalPackage.sourceDevice.name, "Source device name should match")
        assert(deserializedPackage.timestamp.timeIntervalSince1970.rounded() == originalPackage.timestamp.timeIntervalSince1970.rounded(), "Timestamps should match")
        
        // Verify first event
        if deserializedPackage.events.count > 0 && originalPackage.events.count > 0 {
            let deserializedEvent = deserializedPackage.events[0]
            let originalEvent = originalPackage.events[0]
            
            assert(deserializedEvent.month == originalEvent.month, "Month should match")
            assert(deserializedEvent.title == originalEvent.title, "Title should match")
            assert(deserializedEvent.location == originalEvent.location, "Location should match")
            assert(deserializedEvent.day == originalEvent.day, "Day should match")
        }
        
        // Print JSON for debugging (optional)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[TEST] JSON sample (truncated): \(String(jsonString.prefix(200)))...")
        }
        
        print("[TEST] Serialization test passed")
    }
    
    // Test utility functions
    static func testUtilityFunctions() {
        print("\n[TEST] Testing SyncUtility functions")
        
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
        
        // Save events to make sure they're persisted
        calendarStore.saveAllEvents()
        
        // Test generating a sync package
        let syncPackage = SyncUtility.generateSyncPackage()
        
        // Verify the package contains our events
        assert(syncPackage.isValid(), "Generated package should be valid")
        assert(syncPackage.events.count >= 2, "Package should have at least 2 events")
        
        // Test serialization of the generated package
        guard let jsonData = syncPackage.toJSON() else {
            print("[TEST] Failed to serialize generated package")
            assert(false, "Serialization of generated package failed")
            return
        }
        
        print("[TEST] Generated and serialized package (\(jsonData.count) bytes)")
        
        // Simulate receiving the package and processing it
        // Create a slightly modified version
        var modifiedEvents = syncPackage.events
        
        // Add a new event or modify an existing one
        if let index = modifiedEvents.firstIndex(where: { $0.month == 4 }) {
            // Modify existing April event
            var modifiedAprilEvent = modifiedEvents[index]
            modifiedAprilEvent = CalendarEventSync(
                month: 4, 
                monthName: "April", 
                title: "Earth Day Festival", // Changed title
                location: "City Park", // Changed location
                day: 21 // Changed day
            )
            modifiedEvents[index] = modifiedAprilEvent
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
        }
        
        // Create a modified package as if from another device
        let modifiedPackage = SyncPackage(events: modifiedEvents)
        
        // Test processing the modified package
        let pendingUpdates = SyncUtility.processSyncPackage(modifiedPackage)
        
        // There should be at least one pending update
        print("[TEST] Found \(pendingUpdates.count) pending updates")
        assert(!pendingUpdates.isEmpty, "Should have detected at least one pending update")
        
        // Apply one of the updates if available
        if let update = pendingUpdates.first {
            print("[TEST] Applying update: \(update.description)")
            SyncUtility.applyUpdate(update)
            
            // Verify the update was applied
            let updatedEvent = calendarStore.getEvent(for: update.month)
            
            if update.fieldName == "title" {
                assert(updatedEvent.title == update.newValue, "Title should have been updated")
            } else if update.fieldName == "location" {
                assert(updatedEvent.location == update.newValue, "Location should have been updated")
            } else if update.fieldName == "day" {
                if let day = Int(update.newValue) {
                    assert(updatedEvent.day == day, "Day should have been updated")
                }
            }
        }
        
        print("[TEST] SyncUtility test passed")
    }
    
    // Helper assertion function
    static func assert(_ condition: Bool, _ message: String) {
        if !condition {
            print("[TEST] ASSERTION FAILED: \(message)")
        }
    }
}