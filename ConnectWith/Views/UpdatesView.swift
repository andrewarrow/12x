import Foundation
import SwiftUI
import Combine
import UIKit

// Updates View to display incoming calendar changes
struct UpdatesView: View {
    @ObservedObject private var syncManager = SyncManager.shared
    
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
                
                if !syncManager.pendingUpdates.isEmpty {
                    // Display real pending updates from sync operations
                    List {
                        Section(header: Text("Pending Calendar Updates")) {
                            ForEach(syncManager.pendingUpdates) { update in
                                UpdateItemRow(update: update)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                } else {
                    // Empty state when no updates are available
                    VStack(spacing: 20) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No Updates Available")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("When family members sync their calendars with you, pending changes will appear here.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        // This button is just for demo purposes - it creates a test sync package
                        Button(action: {
                            print("[SyncData] Creating demo updates for testing")
                            createDemoUpdates()
                        }) {
                            Text("Show Demo Updates")
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.top, 20)
                        
                        // Test buttons for SyncPackage
                        NavigationLink(destination: SyncPackageTester()) {
                            Text("Open Sync Tester")
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.top, 10)
                        
                        Button(action: {
                            print("[SyncData] Running SyncPackage tests")
                            let results = SyncPackageTests.runTests()
                            print(results)
                        }) {
                            Text("Run Sync Tests (Console)")
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.top, 5)
                    }
                    .padding()
                }
            }
            .navigationTitle("Updates")
        }
    }
    
    // Create demo updates for testing
    private func createDemoUpdates() {
        // Create a few test updates
        let update1 = PendingUpdateInfo(
            sourceDevice: "Bob's iPhone",
            month: 5,
            monthName: "May",
            updateType: .modifyField,
            fieldName: "day",
            oldValue: "15",
            newValue: "19",
            remoteEvent: CalendarEventSync(
                month: 5,
                monthName: "May",
                title: "Ski Trip",
                location: "Alps",
                day: 19
            )
        )
        
        let update2 = PendingUpdateInfo(
            sourceDevice: "Lisa's iPhone",
            month: 7,
            monthName: "July",
            updateType: .modifyField,
            fieldName: "location",
            oldValue: "Beach",
            newValue: "Grandma's House",
            remoteEvent: CalendarEventSync(
                month: 7,
                monthName: "July",
                title: "Family Reunion",
                location: "Grandma's House",
                day: 12
            )
        )
        
        let update3 = PendingUpdateInfo(
            sourceDevice: "Dad's iPad",
            month: 12,
            monthName: "December",
            updateType: .newEvent,
            fieldName: "event",
            oldValue: "No event",
            newValue: "Holiday Party",
            remoteEvent: CalendarEventSync(
                month: 12,
                monthName: "December",
                title: "Holiday Party",
                location: "Home",
                day: 24
            )
        )
        
        // Add updates to sync manager
        DispatchQueue.main.async {
            self.syncManager.pendingUpdates.append(contentsOf: [update1, update2, update3])
            print("[SyncData] Added \(self.syncManager.pendingUpdates.count) demo updates")
        }
    }
}

// Individual update item row
struct UpdateItemRow: View {
    let update: PendingUpdateInfo
    @ObservedObject private var syncManager = SyncManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(update.sourceDevice) \(update.description)")
                        .font(.body)
                    
                    Text(update.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 10) {
                Button(action: {
                    print("[SyncData] Update from \(update.sourceDevice) accepted for \(update.monthName)")
                    syncManager.acceptUpdate(update)
                }) {
                    Text("Accept")
                        .font(.caption)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    print("[SyncData] Update from \(update.sourceDevice) rejected for \(update.monthName)")
                    syncManager.rejectUpdate(update)
                }) {
                    Text("Reject")
                        .font(.caption)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 8)
    }
}