import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    // State variables for the currently selected month and entry
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var entryTitle: String = ""
    @State private var entryLocation: String = ""
    
    // Month names
    let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // Month selector
                HStack {
                    Button(action: {
                        selectedMonth = selectedMonth > 1 ? selectedMonth - 1 : 12
                        loadSelectedMonthData()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Text(monthNames[selectedMonth - 1])
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        selectedMonth = selectedMonth < 12 ? selectedMonth + 1 : 1
                        loadSelectedMonthData()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                Divider()
                    .padding(.vertical)
                
                // Calendar entry form
                VStack(alignment: .leading, spacing: 20) {
                    Text("Event Details")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    TextField("Event Title", text: $entryTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    TextField("Location", text: $entryLocation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Button(action: {
                        // Save the current entry
                        bluetoothManager.updateCalendarEntry(
                            forMonth: selectedMonth,
                            title: entryTitle,
                            location: entryLocation
                        )
                    }) {
                        Text("Save Entry")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                
                // Calendar entries summary
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Calendar Entries")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if bluetoothManager.calendarEntries.isEmpty {
                        Text("No entries yet. Add some events!")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(bluetoothManager.calendarEntries.filter { !$0.title.isEmpty }) { entry in
                                    CalendarEntryCard(entry: entry, monthNames: monthNames)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("My Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Load data for the current month
                loadSelectedMonthData()
            }
        }
    }
    
    // Load entry data for the selected month
    private func loadSelectedMonthData() {
        if let entry = bluetoothManager.calendarEntries.first(where: { $0.month == selectedMonth }) {
            entryTitle = entry.title
            entryLocation = entry.location
        } else {
            // If no entry exists for this month, clear the fields
            entryTitle = ""
            entryLocation = ""
        }
    }
}

struct CalendarEntryCard: View {
    let entry: CalendarEntry
    let monthNames: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthNames[entry.month - 1])
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.white.opacity(0.8))
                Text(entry.title)
                    .font(.body)
                    .foregroundColor(.white)
            }
            
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.white.opacity(0.8))
                Text(entry.location)
                    .font(.body)
                    .foregroundColor(.white)
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