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
            
            CalendarView()
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