import Foundation
import UIKit
import SwiftUI

// MARK: - SyncPackage Models

/// SyncPackage - Main container for sync data exchange between devices
struct SyncPackage: Codable {
    /// Version for backwards compatibility
    let syncVersion: String = "1.0"
    
    /// Device information sending the package
    let sourceDevice: DeviceInfo
    
    /// Timestamp when package was created
    let timestamp: Date
    
    /// Events that are part of this sync package
    let events: [CalendarEventSync]
    
    /// Optional signature for verification (placeholder for future security)
    let signature: String?
    
    /// Initialize a new sync package
    /// - Parameter events: Calendar events to include in this package
    init(events: [CalendarEventSync], signature: String? = nil) {
        print("[SyncData] Creating sync package, version: \(syncVersion), events count: \(events.count)")
        
        self.sourceDevice = DeviceInfo.current
        self.timestamp = Date()
        self.events = events
        self.signature = signature
        
        print("[SyncData] Package created for device \(sourceDevice.name)")
    }
    
    /// Validate this sync package
    /// - Returns: Whether this package passes basic validation
    func isValid() -> Bool {
        print("[SyncData] Validating sync package: source=\(sourceDevice.name), events=\(events.count)")
        
        // Ensure we have a valid timestamp (not in the future)
        guard timestamp <= Date() else {
            print("[SyncData] Validation failed: Package timestamp is in the future")
            return false
        }
        
        // Ensure the package isn't too old (7 days)
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()),
              timestamp >= weekAgo else {
            print("[SyncData] Validation failed: Package is more than 7 days old")
            return false
        }
        
        // Check each event for validity
        for event in events {
            guard event.isValid() else {
                print("[SyncData] Validation failed: Invalid event for month \(event.month)")
                return false
            }
        }
        
        print("[SyncData] Validating sync package: isValid=true")
        return true
    }
    
    /// Convert this package to JSON data
    /// - Returns: JSON Data or nil if serialization fails
    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let jsonData = try encoder.encode(self)
            print("[SyncData] Serializing sync package to JSON, byte size: \(jsonData.count)")
            
            // For debugging: Print a readable version of the JSON
            if let jsonObj = try? JSONSerialization.jsonObject(with: jsonData),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObj, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                let truncated = prettyString.count > 500 ? String(prettyString.prefix(500)) + "..." : prettyString
                print("[SyncData] JSON content: \(truncated)")
            }
            
            return jsonData
        } catch {
            print("[SyncData] Error encoding sync package to JSON: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Create a SyncPackage from JSON data
    /// - Parameter data: The JSON data to decode
    /// - Returns: SyncPackage or nil if deserialization fails
    static func fromJSON(_ data: Data) -> SyncPackage? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let package = try decoder.decode(SyncPackage.self, from: data)
            print("[SyncData] Deserializing JSON to sync package, version: \(package.syncVersion)")
            print("[SyncData] Successfully decoded sync package from JSON (\(data.count) bytes)")
            print("[SyncData] Package from \(package.sourceDevice.name) with \(package.events.count) events")
            
            // Validate the package
            if !package.isValid() {
                print("[SyncData] Deserialized package failed validation")
                return nil
            }
            
            return package
        } catch {
            print("[SyncData] Error decoding sync package from JSON: \(error.localizedDescription)")
            return nil
        }
    }
}

/// CalendarEventSync - Represents a calendar event for syncing
struct CalendarEventSync: Codable {
    /// Month number (1-12)
    let month: Int
    
    /// Month name (January, etc.)
    let monthName: String
    
    /// Event title
    let title: String
    
    /// Event location
    let location: String
    
    /// Day of the month
    let day: Int
    
    /// Last modification date
    let lastModified: Date
    
    /// Initialize a new calendar event sync object
    /// - Parameters:
    ///   - month: Month number (1-12)
    ///   - monthName: Month name
    ///   - title: Event title
    ///   - location: Event location
    ///   - day: Day of month
    init(month: Int, monthName: String, title: String, location: String, day: Int) {
        self.month = month
        self.monthName = monthName
        self.title = title
        self.location = location
        self.day = day
        self.lastModified = Date()
        
        print("[SyncData] Created event sync object for \(monthName): \(title)")
    }
    
    /// Initialize from an existing CalendarEvent
    /// - Parameter event: The calendar event to convert
    init(from event: CalendarEvent) {
        self.month = event.month
        self.monthName = event.monthName
        self.title = event.title
        self.location = event.location
        self.day = event.day
        self.lastModified = Date()
        
        print("[SyncData] Converted CalendarEvent to sync object: \(event.monthName) - \(event.title)")
    }
    
    /// Validate this calendar event
    /// - Returns: Whether this event passes basic validation
    func isValid() -> Bool {
        // Validate month range
        guard month >= 1 && month <= 12 else {
            print("[SyncData] Invalid month: \(month)")
            return false
        }
        
        // Validate day range based on month
        let maxDay: Int
        switch month {
        case 2:
            // February (simple leap year calculation)
            let year = Calendar.current.component(.year, from: Date())
            let isLeapYear = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0)
            maxDay = isLeapYear ? 29 : 28
        case 4, 6, 9, 11:
            // April, June, September, November
            maxDay = 30
        default:
            maxDay = 31
        }
        
        guard day >= 1 && day <= maxDay else {
            print("[SyncData] Invalid day: \(day) for month \(month)")
            return false
        }
        
        // Validate we have a title
        guard !title.isEmpty else {
            print("[SyncData] Event has empty title")
            return false
        }
        
        return true
    }
    
    /// Convert to standard CalendarEvent
    /// - Returns: A CalendarEvent
    func toCalendarEvent() -> CalendarEvent {
        var event = CalendarEvent(
            month: month,
            monthName: monthName,
            title: title,
            location: location,
            day: day,
            isScheduled: true
        )
        
        print("[SyncData] Converted sync event to CalendarEvent: \(monthName) - \(title)")
        return event
    }
}

/// DeviceInfo - Information about a device sending sync data
struct DeviceInfo: Codable {
    /// Device name
    let name: String
    
    /// Device identifier
    let identifier: String
    
    /// Operating system information
    let system: String
    
    /// App version
    let appVersion: String
    
    /// Get information about the current device
    static var current: DeviceInfo {
        let device = UIDevice.current
        
        // Get app version from bundle
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        
        return DeviceInfo(
            name: device.name,
            identifier: device.identifierForVendor?.uuidString ?? UUID().uuidString,
            system: "\(device.systemName) \(device.systemVersion)",
            appVersion: appVersion
        )
    }
}

// MARK: - Sync Utilities

class SyncUtility {
    /// Generate a sync package from the local calendar store
    /// - Returns: A sync package with all local calendar events
    static func generateSyncPackage() -> SyncPackage {
        print("[SyncData] Generating sync package from local calendar data")
        
        let calendarStore = CalendarStore.shared
        var syncEvents: [CalendarEventSync] = []
        
        // Convert all scheduled events to sync events
        for event in calendarStore.events where event.isScheduled {
            let syncEvent = CalendarEventSync(from: event)
            syncEvents.append(syncEvent)
            print("[SyncData] Added event to sync package: \(event.monthName) - \(event.title)")
        }
        
        // Create the sync package
        let syncPackage = SyncPackage(events: syncEvents)
        print("[SyncData] Created sync package with \(syncEvents.count) events")
        
        return syncPackage
    }
    
    /// Process a received sync package and update local calendar
    /// - Parameter package: The sync package to process
    /// - Returns: Array of pending update info for confirmation
    static func processSyncPackage(_ package: SyncPackage) -> [PendingUpdateInfo] {
        guard package.isValid() else {
            print("[SyncData] Cannot process invalid sync package")
            return []
        }
        
        print("[SyncData] Processing sync package from \(package.sourceDevice.name)")
        
        var pendingUpdates: [PendingUpdateInfo] = []
        let calendarStore = CalendarStore.shared
        
        // Compare each remote event with local events
        for syncEvent in package.events {
            // Get the corresponding local event
            let localEvent = calendarStore.getEvent(for: syncEvent.month)
            
            // Skip if local event isn't scheduled (remote event takes precedence)
            if !localEvent.isScheduled {
                print("[SyncData] Month \(syncEvent.month) not scheduled locally, will accept remote")
                
                // Add this as a pending addition
                let updateInfo = PendingUpdateInfo(
                    sourceDevice: package.sourceDevice.name,
                    month: syncEvent.month,
                    monthName: syncEvent.monthName,
                    updateType: .newEvent,
                    fieldName: "event",
                    oldValue: "No event",
                    newValue: syncEvent.title,
                    remoteEvent: syncEvent
                )
                pendingUpdates.append(updateInfo)
                continue
            }
            
            // Check for title changes
            if localEvent.title != syncEvent.title {
                print("[SyncData] Title change detected for \(syncEvent.monthName)")
                
                let updateInfo = PendingUpdateInfo(
                    sourceDevice: package.sourceDevice.name,
                    month: syncEvent.month,
                    monthName: syncEvent.monthName,
                    updateType: .modifyField,
                    fieldName: "title",
                    oldValue: localEvent.title,
                    newValue: syncEvent.title,
                    remoteEvent: syncEvent
                )
                pendingUpdates.append(updateInfo)
            }
            
            // Check for location changes
            if localEvent.location != syncEvent.location {
                print("[SyncData] Location change detected for \(syncEvent.monthName)")
                
                let updateInfo = PendingUpdateInfo(
                    sourceDevice: package.sourceDevice.name,
                    month: syncEvent.month,
                    monthName: syncEvent.monthName,
                    updateType: .modifyField,
                    fieldName: "location",
                    oldValue: localEvent.location,
                    newValue: syncEvent.location,
                    remoteEvent: syncEvent
                )
                pendingUpdates.append(updateInfo)
            }
            
            // Check for day changes
            if localEvent.day != syncEvent.day {
                print("[SyncData] Day change detected for \(syncEvent.monthName)")
                
                let updateInfo = PendingUpdateInfo(
                    sourceDevice: package.sourceDevice.name,
                    month: syncEvent.month,
                    monthName: syncEvent.monthName,
                    updateType: .modifyField,
                    fieldName: "day",
                    oldValue: String(localEvent.day),
                    newValue: String(syncEvent.day),
                    remoteEvent: syncEvent
                )
                pendingUpdates.append(updateInfo)
            }
        }
        
        print("[SyncData] Identified \(pendingUpdates.count) pending updates from sync package")
        return pendingUpdates
    }
    
    /// Apply a specific pending update to the calendar
    /// - Parameter update: The pending update to apply
    static func applyUpdate(_ update: PendingUpdateInfo) {
        print("[SyncData] Applying update for \(update.monthName): \(update.fieldName)")
        
        let calendarStore = CalendarStore.shared
        let event = calendarStore.getEvent(for: update.month)
        
        switch update.updateType {
        case .newEvent:
            // Create a new event
            if let remoteEvent = update.remoteEvent {
                print("[SyncData] Creating new event for \(update.monthName): \(remoteEvent.title)")
                
                calendarStore.updateEvent(
                    month: update.month,
                    title: remoteEvent.title,
                    location: remoteEvent.location,
                    day: remoteEvent.day
                )
            }
            
        case .modifyField:
            // Update just one field
            var newTitle = event.title
            var newLocation = event.location
            var newDay = event.day
            
            switch update.fieldName {
            case "title":
                newTitle = update.newValue
                print("[SyncData] Updating title for \(update.monthName) to: \(newTitle)")
            case "location":
                newLocation = update.newValue
                print("[SyncData] Updating location for \(update.monthName) to: \(newLocation)")
            case "day":
                if let day = Int(update.newValue) {
                    newDay = day
                    print("[SyncData] Updating day for \(update.monthName) to: \(newDay)")
                }
            default:
                print("[SyncData] Unknown field: \(update.fieldName)")
                return
            }
            
            // Update the event with modified fields
            calendarStore.updateEvent(
                month: update.month,
                title: newTitle,
                location: newLocation,
                day: newDay
            )
        }
        
        // Force save after applying update
        calendarStore.saveAllEvents()
    }
}

/// Enum for update types
enum UpdateType: Codable {
    case newEvent
    case modifyField
}

/// Struct to represent a pending update that needs user confirmation
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
    
    /// Get a user-friendly description of the change
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