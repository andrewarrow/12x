import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        NavigationView {
            VStack {
                // Calendar entries summary
                Text("Your Calendar Entries")
                    .font(.headline)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top)
                
                if bluetoothManager.calendarEntries.isEmpty {
                    // Create 12 blank entries if none exist
                    VStack {
                        Text("No entries yet. We've created blank entries for each month.")
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Button(action: {
                            initializeEmptyEntries()
                        }) {
                            Text("Show Entries")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(bluetoothManager.calendarEntries.sorted(by: { $0.month < $1.month })) { entry in
                                NavigationLink(destination: CalendarEntryEditView(entry: entry)) {
                                    CalendarEntryCard(entry: entry)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("My Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Make sure we have entries for all months
                ensureEntriesForAllMonths()
            }
        }
    }
    
    // Make sure we have entries for all 12 months
    private func ensureEntriesForAllMonths() {
        // Get the existing months
        let existingMonths = Set(bluetoothManager.calendarEntries.map { $0.month })
        
        // For any missing month, create a blank entry
        for month in 1...12 {
            if !existingMonths.contains(month) {
                bluetoothManager.updateCalendarEntry(
                    forMonth: month,
                    title: "",
                    location: ""
                )
            }
        }
    }
    
    // Initialize empty entries for all 12 months if we have none
    private func initializeEmptyEntries() {
        if bluetoothManager.calendarEntries.isEmpty {
            for month in 1...12 {
                bluetoothManager.updateCalendarEntry(
                    forMonth: month,
                    title: "",
                    location: ""
                )
            }
        }
    }
}

struct CalendarEntryCard: View {
    let entry: CalendarEntry
    
    // Month names for displaying month label
    private let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(monthNames[entry.month - 1]) \(entry.day)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Day \(entry.day)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
            }
            
            if entry.title.isEmpty && entry.location.isEmpty {
                Text("No events scheduled")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .italic()
            } else {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.white.opacity(0.8))
                    Text(entry.title.isEmpty ? "No title" : entry.title)
                        .font(.body)
                        .foregroundColor(.white)
                }
                
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.white.opacity(0.8))
                    Text(entry.location.isEmpty ? "No location" : entry.location)
                        .font(.body)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.8))
        )
    }
}

#Preview {
    CalendarView()
        .environmentObject(BluetoothManager())
}