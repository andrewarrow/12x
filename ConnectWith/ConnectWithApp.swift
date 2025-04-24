import SwiftUI
import CoreBluetooth
import UIKit
import Foundation

// MARK: - Forced Splash Coordinator
// This class handles showing a UIKit splash screen and Bluetooth permissions
class ForcedSplashCoordinator {
    static let shared = ForcedSplashCoordinator()
    
    // Window to show splash screen
    private var splashWindow: UIWindow?
    
    // Track whether we've shown the splash screen
    private var hasShownSplash = false
    
    // Track whether the Bluetooth permission has been requested
    private var hasRequestedPermission = false
    
    // Show the splash screen immediately
    func showSplash() {
        guard !hasShownSplash else { return }
        print("🚀 SPLASH: Showing forced splash screen")
        
        // Create a window to display on top of everything
        if splashWindow == nil {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let window = UIWindow(windowScene: windowScene)
                window.windowLevel = .alert + 1 // Above alerts
                
                // Create splash view controller
                let splashVC = ForcedSplashViewController()
                window.rootViewController = splashVC
                
                // Make window visible
                window.makeKeyAndVisible()
                splashWindow = window
                
                print("🚀 SPLASH: Created splash window with dimensions: \(window.bounds.width)x\(window.bounds.height)")
                hasShownSplash = true
                
                // Wait a short time, then request Bluetooth permission
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.requestBluetoothPermission()
                }
                
                // Dismiss after a delay, whether or not permission was shown
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                    self?.dismissSplash()
                }
            } else {
                print("🚀 SPLASH: No window scene found")
            }
        }
    }
    
    // Request Bluetooth permission explicitly
    private func requestBluetoothPermission() {
        guard !hasRequestedPermission else { return }
        hasRequestedPermission = true
        
        print("🚀 SPLASH: Requesting Bluetooth permission")
        
        // Create options that show permission dialog immediately
        let options: [String: Any] = [
            CBCentralManagerOptionShowPowerAlertKey: true
        ]
        
        // Creating a local class to handle callbacks
        class LocalPermissionDelegate: NSObject, CBCentralManagerDelegate {
            func centralManagerDidUpdateState(_ central: CBCentralManager) {
                print("🚀 SPLASH BT delegate: State updated to \(central.state.rawValue)")
                
                // Force scan to trigger permission dialog
                if central.state == .poweredOn {
                    central.scanForPeripherals(withServices: nil, options: nil)
                    
                    // Stop scanning after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        central.stopScan()
                    }
                }
            }
            
            func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
                print("🚀 SPLASH BT delegate: willRestoreState called")
            }
        }
        
        // Keep strong reference to delegate and manager
        let delegate = LocalPermissionDelegate()
        let manager = CBCentralManager(delegate: delegate, queue: .main, options: options)
        
        // Store these in a property to keep them alive
        permissionObjects = (manager, delegate)
    }
    
    // Keep strong references to prevent deallocation
    private var permissionObjects: (CBCentralManager, CBCentralManagerDelegate)?
    
    // Dismiss the splash screen
    func dismissSplash() {
        guard hasShownSplash, let splashWindow = splashWindow else { return }
        
        print("🚀 SPLASH: Dismissing forced splash screen")
        
        // Animate out
        UIView.animate(withDuration: 0.3) {
            splashWindow.alpha = 0
        } completion: { _ in
            // Remove window
            self.splashWindow = nil
        }
    }
}

// MARK: - View Controller for Forced Splash
class ForcedSplashViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the splash screen UI
        view.backgroundColor = UIColor(red: 0, green: 0.5, blue: 0.9, alpha: 0.9)
        
        // Create logo image view
        let logoImageView = UIImageView(image: UIImage(systemName: "antenna.radiowaves.left.and.right.circle.fill"))
        logoImageView.tintColor = .white
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create title label
        let titleLabel = UILabel()
        titleLabel.text = "12x"
        titleLabel.font = UIFont.systemFont(ofSize: 42, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add views to hierarchy
        view.addSubview(logoImageView)
        view.addSubview(titleLabel)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            logoImageView.widthAnchor.constraint(equalToConstant: 100),
            logoImageView.heightAnchor.constraint(equalToConstant: 100),
            
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20)
        ])
        
        print("🚀 SPLASH: Forced splash view controller loaded")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🚀 SPLASH: Forced splash view controller appeared")
    }
}

// Simple helper to request Bluetooth permission directly
func requestBluetoothPermission() {
    print("⚡️ Requesting Bluetooth permission")
    
    // Create a one-time use manager on main thread
    let _ = CBCentralManager(delegate: BluetoothPermissionDelegate(), queue: .main, options: [
        CBCentralManagerOptionShowPowerAlertKey: true
    ])
}

// Simple delegate for Bluetooth manager
class BluetoothPermissionDelegate: NSObject, CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("⚡️ Bluetooth state updated: \(central.state.rawValue)")
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        print("⚡️ Bluetooth will restore state")
    }
}

@main
struct TwelvexApp: App {
    @State private var isShowingSplash = true
    
    // Use deferred StateObject for BluetoothManager
    @StateObject private var bluetoothManager = BluetoothManager()
    
    // Register app delegate
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    // App delegate - not showing forced splash screen anymore
    class AppDelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
            print("🔶 LIFECYCLE: UIApplicationDelegate - didFinishLaunchingWithOptions")
            
            // Don't show the forced splash screen, using only SwiftUI splash
            // DispatchQueue.main.async {
            //    ForcedSplashCoordinator.shared.showSplash()
            // }
            
            return true
        }
    }
    
    init() {
        print("🔶 LIFECYCLE: TwelvexApp init START")
        
        // Set app-wide appearance settings
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
        
        print("🔶 LIFECYCLE: TwelvexApp init END")
    }
    
    var body: some Scene {
        WindowGroup {
            // Record when Scene is first evaluated
            let _ = print("🔶 LIFECYCLE: TwelvexApp body Scene evaluated")
            
            ZStack {
                // Using only the SwiftUI SplashScreen, removing the UIKit overlay splash
                if isShowingSplash {
                    SplashScreen(isShowingSplash: $isShowingSplash)
                        .onAppear {
                            print("🔶 LIFECYCLE: SwiftUI SplashScreen appeared")
                            // Ensure the UIKit splash is dismissed if it's showing
                            ForcedSplashCoordinator.shared.dismissSplash()
                        }
                } else {
                    MainTabView()
                        .environmentObject(bluetoothManager)
                        .onAppear {
                            print("🔶 LIFECYCLE: MainTabView appeared")
                        }
                }
            }
            .onAppear {
                print("🔶 LIFECYCLE: Root ZStack onAppear - UI should be visible now")
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
                
                Section(header: Text("History")) {
                    NavigationLink(destination: HistoryView().environmentObject(bluetoothManager)) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.blue)
                                .font(.title3)
                            
                            Text("Calendar Change History")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Badge to show number of history entries
                    .overlay(
                        Group {
                            if !bluetoothManager.historyEntries.isEmpty {
                                Text("\(bluetoothManager.historyEntries.count)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing)
                    )
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
                        Text(bluetoothManager.deviceCustomName)
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