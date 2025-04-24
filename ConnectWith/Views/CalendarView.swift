import SwiftUI
import Combine
import Foundation
import CoreBluetooth

// Month colors definition - directly included to avoid import issues
fileprivate struct MonthColors {
    // Array of color pairs for each month (1-based indexing)
    static let colors: [(primary: Color, secondary: Color)] = [
        // January - Light blue (Winter)
        (primary: Color(red: 0.53, green: 0.81, blue: 0.92),
         secondary: Color(red: 0.40, green: 0.69, blue: 0.82)),
        
        // February - Medium blue (Winter)
        (primary: Color(red: 0.44, green: 0.73, blue: 0.84),
         secondary: Color(red: 0.35, green: 0.60, blue: 0.79)),
        
        // March - Light green (Spring)
        (primary: Color(red: 0.56, green: 0.78, blue: 0.55),
         secondary: Color(red: 0.40, green: 0.65, blue: 0.45)),
        
        // April - Fresh green (Spring)
        (primary: Color(red: 0.47, green: 0.75, blue: 0.48),
         secondary: Color(red: 0.35, green: 0.62, blue: 0.40)),
        
        // May - Vibrant green (Spring)
        (primary: Color(red: 0.36, green: 0.70, blue: 0.42),
         secondary: Color(red: 0.28, green: 0.56, blue: 0.35)),
        
        // June - Light gold (Summer)
        (primary: Color(red: 0.95, green: 0.77, blue: 0.42),
         secondary: Color(red: 0.85, green: 0.65, blue: 0.30)),
        
        // July - Orange (Summer)
        (primary: Color(red: 0.94, green: 0.65, blue: 0.30),
         secondary: Color(red: 0.82, green: 0.55, blue: 0.25)),
        
        // August - Coral (Summer)
        (primary: Color(red: 0.94, green: 0.52, blue: 0.30),
         secondary: Color(red: 0.82, green: 0.42, blue: 0.25)),
        
        // September - Light brown (Fall)
        (primary: Color(red: 0.80, green: 0.52, blue: 0.25),
         secondary: Color(red: 0.70, green: 0.42, blue: 0.20)),
        
        // October - Rust (Fall)
        (primary: Color(red: 0.70, green: 0.44, blue: 0.40),
         secondary: Color(red: 0.60, green: 0.35, blue: 0.30)),
        
        // November - Plum (Fall)
        (primary: Color(red: 0.55, green: 0.40, blue: 0.60),
         secondary: Color(red: 0.47, green: 0.32, blue: 0.50)),
        
        // December - Winter blue (Winter)
        (primary: Color(red: 0.40, green: 0.58, blue: 0.74),
         secondary: Color(red: 0.30, green: 0.48, blue: 0.62))
    ]
    
    // Helper to get the primary color for a given month (1-12)
    static func primaryForMonth(_ month: Int) -> Color {
        guard month >= 1 && month <= 12 else { return .blue }
        return colors[month - 1].primary
    }
    
    // Helper to get the secondary color for a given month (1-12)
    static func secondaryForMonth(_ month: Int) -> Color {
        guard month >= 1 && month <= 12 else { return .blue.opacity(0.7) }
        return colors[month - 1].secondary
    }
}

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
    
    // Day of week names
    private let weekdayNames = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ]
    
    // Get day of week for the entry
    private var dayOfWeek: String {
        let currentYear = Calendar.current.component(.year, from: Date())
        var dateComponents = DateComponents()
        dateComponents.year = currentYear
        dateComponents.month = entry.month
        dateComponents.day = entry.day
        
        if let date = Calendar.current.date(from: dateComponents) {
            let weekday = Calendar.current.component(.weekday, from: date)
            // weekday is 1-based with 1 being Sunday
            return weekdayNames[weekday - 1]
        }
        return ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(monthNames[entry.month - 1]) \(entry.day)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(dayOfWeek)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
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
            LinearGradient(
                gradient: Gradient(colors: [
                    MonthColors.primaryForMonth(entry.month),
                    MonthColors.secondaryForMonth(entry.month)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(12)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}

#Preview {
    CalendarView()
        .environmentObject(BluetoothManager())
}