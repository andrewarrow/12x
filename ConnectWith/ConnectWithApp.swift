import SwiftUI

@main
struct TwelvexApp: App {
    @State private var isShowingSplash = true
    @StateObject private var bluetoothManager = BluetoothManager()
    
    init() {
        // Set up any app initialization here
        print("App initializing with Bluetooth manager")
    }
    
    var body: some Scene {
        WindowGroup {
            if isShowingSplash {
                SplashScreen(isShowingSplash: $isShowingSplash)
            } else {
                MainTabView()
                    .environmentObject(bluetoothManager)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        TabView {
            BluetoothDeviceListView()
                .environmentObject(bluetoothManager)
                .tabItem {
                    Label("Devices", systemImage: "antenna.radiowaves.left.and.right")
                }
            
            InlineCalendarView()
                .environmentObject(bluetoothManager)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
            
            SettingsView()
                .environmentObject(bluetoothManager)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

// Inline version of CalendarView to avoid project file issues
struct InlineCalendarView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    // State variables for the currently selected month and entry
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var entryTitle: String = ""
    @State private var entryLocation: String = ""
    @State private var selectedDay: Int = 1
    
    // Month names
    let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    
    // Day options (1-31)
    let dayOptions = Array(1...31)
    
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
                    
                    // Day picker
                    HStack {
                        Text("Day:")
                            .frame(width: 80, alignment: .leading)
                        
                        Picker("Day", selection: $selectedDay) {
                            ForEach(dayOptions, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
                            location: entryLocation,
                            day: selectedDay
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
            selectedDay = entry.day
        } else {
            // If no entry exists for this month, clear the fields
            entryTitle = ""
            entryLocation = ""
            selectedDay = 1
        }
    }
}

struct CalendarEntryCard: View {
    let entry: CalendarEntry
    let monthNames: [String]
    
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

// Settings View
struct SettingsView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var showSampleDataAlert = false
    @State private var showSuccessAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Calendar Settings")) {
                    Button(action: {
                        showSampleDataAlert = true
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundColor(.blue)
                                .font(.title3)
                            
                            Text("Populate Sample Calendar Events")
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                Section(header: Text("Debug Information")) {
                    NavigationLink(destination: DebugLogView(debugMessages: bluetoothManager.debugMessages)) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.blue)
                                .font(.title3)
                            
                            Text("View Debug Logs")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    HStack {
                        Text("Bluetooth Status:")
                        Spacer()
                        if let centralManager = bluetoothManager.centralManager {
                            Text(centralManager.state == .poweredOn ? "Active" : "Inactive")
                                .foregroundColor(centralManager.state == .poweredOn ? .green : .red)
                        } else {
                            Text("Unknown")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    HStack {
                        Text("Device Name:")
                        Spacer()
                        Text(UIDevice.current.name)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version:")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Made with:")
                        Spacer()
                        Text("SwiftUI & CoreBluetooth")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showSampleDataAlert) {
                Alert(
                    title: Text("Populate Sample Data"),
                    message: Text("This will replace any existing calendar entries with 12 sample events. Continue?"),
                    primaryButton: .destructive(Text("Continue")) {
                        bluetoothManager.populateSampleCalendarEntries()
                        showSuccessAlert = true
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert("Sample Data Created", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("12 sample calendar entries have been created successfully.")
            }
        }
    }
}

// Debug Log View
struct DebugLogView: View {
    let debugMessages: [String]
    
    var body: some View {
        List {
            ForEach(debugMessages, id: \.self) { message in
                Text(message)
                    .font(.system(.body, design: .monospaced))
                    .padding(.vertical, 4)
            }
        }
        .navigationTitle("Debug Logs")
        .navigationBarTitleDisplayMode(.inline)
    }
}