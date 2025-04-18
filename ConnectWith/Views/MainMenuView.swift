import SwiftUI
import Foundation
import CoreBluetooth
import UIKit

// Full implementation of BluetoothManager 
class BluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var nearbyDevices: [CBPeripheral] = []
    @Published var connectedPeripherals: [CBPeripheral] = []
    @Published var isScanning: Bool = false
    @Published var isAdvertising: Bool = false
    @Published var scanningMessage: String = "Scanning for devices..."
    
    // MARK: - Core Bluetooth Managers
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    
    // MARK: - UUIDs
    private let serviceUUID = CBUUID(string: "4514d666-d6c9-49cb-bc31-dc6dfa28bd58")
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        print("Starting BluetoothManager initialization")
        
        // Force-set Bluetooth permission descriptions to ensure they're available
        let permissions = [
            "NSBluetoothAlwaysUsageDescription": "This app uses Bluetooth to connect with nearby family members' devices",
            "NSBluetoothPeripheralUsageDescription": "This app uses Bluetooth to connect with nearby family members' devices"
        ]
        
        // Set using UserDefaults
        for (key, value) in permissions {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        // Add additional check to warn if Info.plist is missing required permissions
        if Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") == nil {
            print("⚠️ WARNING: NSBluetoothAlwaysUsageDescription not found in Info.plist")
            scanningMessage = "Using runtime Bluetooth permissions"
        } else {
            print("✅ NSBluetoothAlwaysUsageDescription found in Info.plist")
        }
        
        // Initialize with options that explicitly request authorization
        let centralOptions: [String: Any] = [
            CBCentralManagerOptionShowPowerAlertKey: true
            // We now have the delegate method, but leaving this off for simplicity
            // CBCentralManagerOptionRestoreIdentifierKey: "dev.12x.bluetoothManagerRestore"
        ]
        
        print("Creating Bluetooth managers")
        scanningMessage = "Initializing Bluetooth..."
        
        // Create the managers
        centralManager = CBCentralManager(delegate: self, queue: nil, options: centralOptions)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        print("BluetoothManager initialization complete")
        
        // Add a delay before starting operations to ensure permissions are requested
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.centralManager.state == .poweredOn {
                print("✅ Bluetooth powered on after delay, starting operations")
                self.startScanning()
                self.startAdvertising()
            } else {
                let stateDesc: String
                switch self.centralManager.state {
                case .poweredOff: stateDesc = "poweredOff - Turn on Bluetooth in Control Center"
                case .unauthorized: stateDesc = "unauthorized - Permission denied in Settings"
                case .unsupported: stateDesc = "unsupported - Device doesn't support Bluetooth"
                case .resetting: stateDesc = "resetting - Bluetooth is restarting"
                case .unknown: stateDesc = "unknown - Bluetooth state undetermined"
                default: stateDesc = "other - state: \(self.centralManager.state.rawValue)"
                }
                
                print("❌ Bluetooth not ready after delay: \(stateDesc)")
                self.scanningMessage = "Bluetooth not ready: \(stateDesc)"
            }
        }
    }
    
    // MARK: - Central Methods
    func startScanning() {
        // Check for Bluetooth permission and power state
        switch centralManager.state {
        case .poweredOn:
            // Bluetooth is on and ready
            break
        case .poweredOff:
            scanningMessage = "Bluetooth is powered off. Please turn on Bluetooth."
            return
        case .unauthorized:
            scanningMessage = "Bluetooth permission denied. Please enable in Settings."
            // Display info about the required permission
            print("IMPORTANT: Bluetooth permission is required. Add NSBluetoothAlwaysUsageDescription to Info.plist")
            return
        case .unsupported:
            scanningMessage = "Bluetooth is not supported on this device"
            return
        default:
            scanningMessage = "Bluetooth is not ready. Please wait..."
            return
        }
        
        // Start scanning for devices with our service UUID
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        isScanning = true
        scanningMessage = "Scanning for devices..."
        print("Started scanning for devices with UUID: \(serviceUUID.uuidString)")
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        scanningMessage = "Scanning stopped"
        print("Stopped scanning for devices")
    }
    
    func connectToDevice(_ device: CBPeripheral) {
        centralManager.connect(device, options: nil)
        print("Connecting to device: \(device.name ?? device.identifier.uuidString)")
    }
    
    // MARK: - Peripheral Methods
    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else {
            print("Peripheral manager not powered on")
            return
        }
        
        // Create the service
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        // Add the service to the peripheral manager
        peripheralManager.add(service)
        
        // Start advertising
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "12x App \(UIDevice.current.name)"
        ])
        
        isAdvertising = true
        print("Started advertising as: 12x App \(UIDevice.current.name)")
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        isAdvertising = false
        print("Stopped advertising")
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    // This method is required if you use CBCentralManagerOptionRestoreIdentifierKey
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        print("Bluetooth central manager restoring state")
        
        // Retrieve any peripherals that were connected
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            print("Restored \(peripherals.count) peripherals")
            for peripheral in peripherals {
                if !nearbyDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                    nearbyDevices.append(peripheral)
                }
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Central manager powered on")
            startScanning()
            startAdvertising()
        case .poweredOff:
            print("Central manager powered off")
            scanningMessage = "Bluetooth is powered off"
        case .resetting:
            print("Central manager resetting")
        case .unauthorized:
            print("Central manager unauthorized")
            scanningMessage = "Bluetooth permission denied"
        case .unsupported:
            print("Central manager unsupported")
            scanningMessage = "Bluetooth not supported"
        case .unknown:
            print("Central manager unknown state")
        @unknown default:
            print("Central manager unknown default")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Check if the device has a name
        let deviceName = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown Device"
        
        // Only add devices that have "12x App" in their name
        guard deviceName.contains("12x App") else {
            return
        }
        
        // See if we already found this device
        if !nearbyDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            print("Discovered device: \(deviceName) (RSSI: \(RSSI))")
            nearbyDevices.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to device: \(peripheral.name ?? peripheral.identifier.uuidString)")
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
        
        if !connectedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            connectedPeripherals.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to device: \(peripheral.name ?? peripheral.identifier.uuidString), error: \(error?.localizedDescription ?? "unknown error")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from device: \(peripheral.name ?? peripheral.identifier.uuidString)")
        connectedPeripherals.removeAll(where: { $0.identifier == peripheral.identifier })
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("Discovered service: \(service.uuid)")
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BluetoothManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("Peripheral manager powered on")
            startAdvertising()
        case .poweredOff:
            print("Peripheral manager powered off")
        case .resetting:
            print("Peripheral manager resetting")
        case .unauthorized:
            print("Peripheral manager unauthorized")
        case .unsupported:
            print("Peripheral manager unsupported")
        case .unknown:
            print("Peripheral manager unknown state")
        @unknown default:
            print("Peripheral manager unknown default")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("Error adding service: \(error.localizedDescription)")
        } else {
            print("Service added successfully")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Error starting advertising: \(error.localizedDescription)")
        } else {
            print("Advertising started successfully")
        }
    }
}

// Full DevicesListView implementation
struct DevicesListView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        List {
            Section(header: Text("Nearby Devices")) {
                if bluetoothManager.nearbyDevices.isEmpty {
                    HStack {
                        Spacer()
                        Text("No devices found")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ForEach(bluetoothManager.nearbyDevices, id: \.identifier) { device in
                        DeviceRow(device: device)
                            .onTapGesture {
                                bluetoothManager.connectToDevice(device)
                            }
                    }
                }
            }
            
            Section(header: Text("Connected Devices")) {
                if bluetoothManager.connectedPeripherals.isEmpty {
                    HStack {
                        Spacer()
                        Text("No connected devices")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ForEach(bluetoothManager.connectedPeripherals, id: \.identifier) { device in
                        DeviceRow(device: device)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Available Devices")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    bluetoothManager.startScanning()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: CBPeripheral
    
    var body: some View {
        HStack {
            Image(systemName: "iphone.circle.fill")
                .font(.title)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(device.name ?? "Unknown Device")
                    .font(.headline)
                
                Text(device.identifier.uuidString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

struct OnboardingView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var progressValue: Double = 0.0
    @State private var emojiIndex = 0
    @State private var debugText = "Initializing..."
    @State private var showDevicesList = false
    
    let emojis = ["📱", "🔄", "✨", "🚀", "🔍", "📡"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Welcome to 12x")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Text(bluetoothManager.scanningMessage)
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                HStack {
                    // Emoji animation
                    ZStack {
                        ForEach(0..<emojis.count, id: \.self) { index in
                            Text(emojis[index])
                                .font(.system(size: 40))
                                .opacity(index == emojiIndex ? 1 : 0)
                                .scaleEffect(index == emojiIndex ? 1.2 : 1.0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: emojiIndex)
                        }
                    }
                    .frame(width: 60, height: 60)
                    
                    ProgressView(value: progressValue)
                        .progressViewStyle(LinearProgressViewStyle())
                        .tint(.blue)
                        .frame(height: 10)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Now have your family member also install this app and launch it on their phone.")
                        .font(.body)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding()
                
                // Shows found devices count
                if !bluetoothManager.nearbyDevices.isEmpty {
                    Button(action: {
                        showDevicesList = true
                    }) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.green)
                            Text("Found \(bluetoothManager.nearbyDevices.count) device\(bluetoothManager.nearbyDevices.count == 1 ? "" : "s")")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                
                // Debug text - shows log status
                Text(debugText)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if bluetoothManager.nearbyDevices.isEmpty {
                    Text("Waiting for devices...")
                        .foregroundColor(.secondary)
                } else {
                    NavigationLink(
                        destination: DevicesListView(bluetoothManager: bluetoothManager),
                        isActive: $showDevicesList
                    ) {
                        Button(action: {
                            showDevicesList = true
                        }) {
                            Text("View Available Devices")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Setup")
            .onAppear {
                print("ONBOARDING VIEW APPEARED")
                debugText = "View appeared at \(formattedTime(Date()))"
                
                startProgressAnimation()
                startEmojiAnimation()
                startDebugUpdates()
                
                // Start Bluetooth scanning and advertising
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    bluetoothManager.startScanning()
                    bluetoothManager.startAdvertising()
                }
            }
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    func startProgressAnimation() {
        // Loop the progress animation indefinitely
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            withAnimation {
                if progressValue >= 1.0 {
                    progressValue = 0.0
                } else {
                    progressValue += 0.01
                }
            }
        }
    }
    
    func startEmojiAnimation() {
        // Cycle through emojis
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            withAnimation {
                emojiIndex = (emojiIndex + 1) % emojis.count
            }
        }
    }
    
    func startDebugUpdates() {
        // Update debug text periodically to show app is running
        var count = 0
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            count += 1
            let runTime = Int(timer.timeInterval * Double(count))
            debugText = "Running for \(runTime)s (at \(formattedTime(Date())))"
            print("App running for \(runTime) seconds")
        }
    }
}

#Preview {
    OnboardingView()
}
