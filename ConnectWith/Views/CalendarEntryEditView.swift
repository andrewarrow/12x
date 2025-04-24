import SwiftUI

struct CalendarEntryEditView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Environment(\.presentationMode) var presentationMode
    
    let entry: CalendarEntry
    
    @State private var entryTitle: String = ""
    @State private var entryLocation: String = ""
    @State private var selectedDay: Int = 1
    @State private var isEditSuccessful: Bool = false
    
    // Month names for displaying month label
    private let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    
    // Day of week names
    private let weekdayNames = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ]
    
    // Get the days available for the selected month in the current year
    private var availableDays: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return getDaysInMonth(month: entry.month, year: currentYear)
    }
    
    // Get day of week for a specific day in the month
    private func dayOfWeek(forDay day: Int) -> String {
        let currentYear = Calendar.current.component(.year, from: Date())
        var dateComponents = DateComponents()
        dateComponents.year = currentYear
        dateComponents.month = entry.month
        dateComponents.day = day
        
        if let date = Calendar.current.date(from: dateComponents) {
            let weekday = Calendar.current.component(.weekday, from: date)
            // weekday is 1-based with 1 being Sunday
            return weekdayNames[weekday - 1]
        }
        return ""
    }
    
    // Calculate number of days in a month for a specific year
    private func getDaysInMonth(month: Int, year: Int) -> [Int] {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        
        // Get the range of days in the month
        guard let date = Calendar.current.date(from: dateComponents),
              let range = Calendar.current.range(of: .day, in: .month, for: date) else {
            return Array(1...31) // Fallback to 31 days if calculation fails
        }
        
        return Array(range)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Month header
                HStack {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text(monthNames[entry.month - 1])
                        .font(.title)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical)
                
                // Entry form
                VStack(alignment: .leading, spacing: 20) {
                    Text("Event Details")
                        .font(.headline)
                    
                    // Day picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Day")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Day", selection: $selectedDay) {
                            ForEach(availableDays, id: \.self) { day in
                                Text("\(day) (\(dayOfWeek(forDay: day)))").tag(day)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(height: 120)
                        .padding(.bottom, 8)
                    }
                    
                    // Title field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Event Title")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Event Title", text: $entryTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.bottom, 8)
                    }
                    
                    // Location field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Location", text: $entryLocation)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.bottom, 8)
                    }
                    
                    // Success message
                    if isEditSuccessful {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Changes saved successfully!")
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .transition(.opacity)
                    }
                    
                    // Save button
                    Button(action: {
                        // Save the current entry
                        bluetoothManager.updateCalendarEntry(
                            forMonth: entry.month,
                            title: entryTitle,
                            location: entryLocation,
                            day: selectedDay
                        )
                        
                        // Show success message
                        withAnimation {
                            isEditSuccessful = true
                        }
                        
                        // Hide success message after delay and go back
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Text("Save Changes")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("Edit \(monthNames[entry.month - 1]) Entry")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load the entry data when the view appears
            loadEntryData()
        }
    }
    
    // Load entry data
    private func loadEntryData() {
        // Find the current entry data
        if let currentEntry = bluetoothManager.calendarEntries.first(where: { $0.month == entry.month }) {
            entryTitle = currentEntry.title
            entryLocation = currentEntry.location
            
            // Make sure the selected day is valid for this month
            let currentYear = Calendar.current.component(.year, from: Date())
            let daysInMonth = getDaysInMonth(month: entry.month, year: currentYear)
            
            // If the current day is valid for this month, use it; otherwise use day 1
            if daysInMonth.contains(currentEntry.day) {
                selectedDay = currentEntry.day
            } else {
                selectedDay = 1
            }
        }
    }
}

#Preview {
    NavigationView {
        CalendarEntryEditView(entry: CalendarEntry(month: 1))
            .environmentObject(BluetoothManager())
    }
}