import SwiftUI

struct CalendarEntryEditView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Environment(\.presentationMode) var presentationMode
    
    let entry: CalendarEntry
    
    @State private var entryTitle: String = ""
    @State private var entryLocation: String = ""
    @State private var isEditSuccessful: Bool = false
    
    // Month names for displaying month label
    private let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    
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
                            location: entryLocation
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
        }
    }
}

#Preview {
    NavigationView {
        CalendarEntryEditView(entry: CalendarEntry(month: 1))
            .environmentObject(BluetoothManager())
    }
}