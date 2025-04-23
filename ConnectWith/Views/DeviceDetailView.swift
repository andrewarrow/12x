import SwiftUI
import CoreBluetooth

struct DeviceDetailView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    let device: BluetoothDevice
    
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
            
            Divider()
                .padding(.vertical)
            
            // Send data button
            Button(action: {
                // Send calendar data to this device
                bluetoothManager.sendCalendarData(to: device)
            }) {
                HStack {
                    Image(systemName: "arrow.up.doc.fill")
                    Text("Send Calendar to \(device.name)")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .disabled(bluetoothManager.sendingCalendarData)
            
            // Status indicator
            if bluetoothManager.sendingCalendarData {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Sending calendar data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            Spacer()
        }
        .navigationTitle("Calendar with \(device.name)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load data for the current month
            loadSelectedMonthData()
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

#Preview {
    NavigationView {
        DeviceDetailView(device: BluetoothDevice(peripheral: nil, name: "Test Device", rssi: -50, isSameApp: true))
            .environmentObject(BluetoothManager())
    }
}