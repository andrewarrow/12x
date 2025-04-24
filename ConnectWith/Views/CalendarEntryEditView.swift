import SwiftUI
import Combine
import Foundation
import CoreBluetooth
import UIKit

// UIKit-based TextField that ensures keyboard appears
struct CustomKeyboardTextField: UIViewRepresentable {
    @Binding var text: String
    var isFirstResponder: Bool = false
    var placeholder: String = "Tap to edit"
    var onCommit: (() -> Void)? = nil
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var onCommit: (() -> Void)? = nil
        
        init(text: Binding<String>, onCommit: (() -> Void)? = nil) {
            self._text = text
            self.onCommit = onCommit
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            onCommit?()
            return true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, onCommit: onCommit)
    }
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.font = UIFont.systemFont(ofSize: 22)
        textField.borderStyle = .none
        textField.returnKeyType = .done
        textField.autocorrectionType = .default // Enable autocorrection
        textField.backgroundColor = .clear
        textField.placeholder = placeholder
        
        // Add padding
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: textField.frame.height))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        
        // Manage keyboard focus
        if isFirstResponder && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFirstResponder && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
}

// Custom large tappable text field
struct LargeTextField: View {
    @Binding var text: String
    var placeholder: String
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(Color(.placeholderText))
                        .font(.system(size: 22))
                        .padding(.leading, 8)
                }
                
                Text(text.isEmpty ? " " : text) // Non-empty even when text is empty
                    .foregroundColor(.primary)
                    .font(.system(size: 22))
                    .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 80) // Even taller for easier tapping
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Month colors definition - directly included to avoid import issues
fileprivate struct MonthColors {
    // Array of color pairs for each month (1-based indexing)
    static let colors: [(primary: Color, secondary: Color)] = [
        // January - Deep blue (Winter)
        (primary: Color(red: 0.20, green: 0.40, blue: 0.70),
         secondary: Color(red: 0.10, green: 0.30, blue: 0.60)),
        
        // February - Royal purple (Winter)
        (primary: Color(red: 0.45, green: 0.30, blue: 0.75),
         secondary: Color(red: 0.35, green: 0.22, blue: 0.65)),
        
        // March - Teal (Early Spring)
        (primary: Color(red: 0.20, green: 0.60, blue: 0.65),
         secondary: Color(red: 0.15, green: 0.50, blue: 0.55)),
        
        // April - Lime green (Spring)
        (primary: Color(red: 0.55, green: 0.75, blue: 0.25),
         secondary: Color(red: 0.45, green: 0.65, blue: 0.15)),
        
        // May - Salmon (Late Spring)
        (primary: Color(red: 0.95, green: 0.55, blue: 0.55),
         secondary: Color(red: 0.85, green: 0.45, blue: 0.45)),
        
        // June - Golden (Early Summer)
        (primary: Color(red: 0.95, green: 0.77, blue: 0.30),
         secondary: Color(red: 0.85, green: 0.67, blue: 0.20)),
        
        // July - Deep orange (Summer)
        (primary: Color(red: 0.95, green: 0.45, blue: 0.20),
         secondary: Color(red: 0.85, green: 0.35, blue: 0.10)),
        
        // August - Ocean blue (Late Summer)
        (primary: Color(red: 0.15, green: 0.55, blue: 0.85),
         secondary: Color(red: 0.05, green: 0.45, blue: 0.75)),
        
        // September - Burgundy (Early Fall)
        (primary: Color(red: 0.65, green: 0.12, blue: 0.25),
         secondary: Color(red: 0.55, green: 0.08, blue: 0.18)),
        
        // October - Rusty orange (Fall)
        (primary: Color(red: 0.85, green: 0.35, blue: 0.10),
         secondary: Color(red: 0.75, green: 0.25, blue: 0.05)),
        
        // November - Forest green (Late Fall)
        (primary: Color(red: 0.15, green: 0.45, blue: 0.20),
         secondary: Color(red: 0.10, green: 0.35, blue: 0.15)),
        
        // December - Indigo (Winter)
        (primary: Color(red: 0.25, green: 0.25, blue: 0.55),
         secondary: Color(red: 0.15, green: 0.15, blue: 0.45))
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

struct CalendarEntryEditView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Environment(\.presentationMode) var presentationMode
    
    let entry: CalendarEntry
    
    @State private var entryTitle: String = ""
    @State private var entryLocation: String = ""
    @State private var selectedDay: Int = 1
    @State private var isEditSuccessful: Bool = false
    @State private var isEditingTitle: Bool = false
    @State private var isEditingLocation: Bool = false
    
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
                        .foregroundColor(.white)
                    Text(monthNames[entry.month - 1])
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            MonthColors.primaryForMonth(entry.month),
                            MonthColors.secondaryForMonth(entry.month)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .cornerRadius(10)
                )
                .padding(.horizontal)
                
                // Entry form
                VStack(alignment: .leading, spacing: 20) {
                    // Day picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Day")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.bottom, 8)
                            
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
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.bottom, 8)
                        
                        if isEditingTitle {
                            // Use UIKit TextField for better keyboard control
                            CustomKeyboardTextField(text: $entryTitle, isFirstResponder: true, placeholder: "Event Title", onCommit: {
                                isEditingTitle = false
                            })
                            .frame(height: 80) // Even taller for easier tapping
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                            .padding(.bottom, 16)
                        } else {
                            LargeTextField(text: $entryTitle, placeholder: "Event Title", onTap: {
                                isEditingTitle = true
                            })
                            .padding(.bottom, 16)
                        }
                    }
                    
                    // Location field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.bottom, 8)
                        
                        if isEditingLocation {
                            // Use UIKit TextField for better keyboard control
                            CustomKeyboardTextField(text: $entryLocation, isFirstResponder: true, placeholder: "Location", onCommit: {
                                isEditingLocation = false
                            })
                            .frame(height: 80) // Even taller for easier tapping
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                            .padding(.bottom, 16)
                        } else {
                            LargeTextField(text: $entryLocation, placeholder: "Location", onTap: {
                                isEditingLocation = true
                            })
                            .padding(.bottom, 16)
                        }
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
                        // Hide keyboard if it's showing
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        
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
                            .background(MonthColors.primaryForMonth(entry.month))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top, 8)
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
        // Add a background view to capture taps for dismissing the keyboard
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    // Dismiss the keyboard and exit editing mode
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    isEditingTitle = false
                    isEditingLocation = false
                }
        )
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