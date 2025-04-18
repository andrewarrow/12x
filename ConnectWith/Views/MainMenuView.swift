import SwiftUI
import Foundation
import CoreBluetooth
import UIKit

// Define DeviceStore here for simplicity
class DeviceStore {
    static let shared = DeviceStore()
    
    private init() {}
    
    // In-memory store for devices
    private var devices: [String: BluetoothDeviceInfo] = [:]
    private let queue = DispatchQueue(label: "com.12x.DeviceStoreQueue", attributes: .concurrent)
    
    struct BluetoothDeviceInfo {
        let identifier: String
        var name: String
        var lastSeen: Date
    }
    
    // Add or update a device
    func addDevice(identifier: String, name: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let device = BluetoothDeviceInfo(
                identifier: identifier,
                name: name,
                lastSeen: Date()
            )
            self.devices[identifier] = device
        }
    }
    
    // Get all devices
    func getAllDevices() -> [BluetoothDeviceInfo] {
        var result: [BluetoothDeviceInfo] = []
        queue.sync {
            result = Array(devices.values)
        }
        return result
    }
    
    // Get a specific device
    func getDevice(identifier: String) -> BluetoothDeviceInfo? {
        var result: BluetoothDeviceInfo?
        queue.sync {
            result = devices[identifier]
        }
        return result
    }
    
    // Update a device's last seen time
    func updateLastSeen(identifier: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if var device = self.devices[identifier] {
                device.lastSeen = Date()
                self.devices[identifier] = device
            }
        }
    }
}

// Define BluetoothManager here since we can't easily reference it from another file
// This implementation includes the thread fixes

// MARK: - BluetoothManager
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
    
    // MARK: - Device Store
    private let deviceStore = DeviceStore.shared
    
    // Use a dedicated serial queue for Bluetooth operations
    private let bluetoothQueue = DispatchQueue(label: "com.12x.BluetoothQueue", qos: .userInitiated)
    
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
        ]
        
        print("Creating Bluetooth managers with dedicated queue")
        DispatchQueue.main.async { [weak self] in
            self?.scanningMessage = "Initializing Bluetooth..."
        }
        
        // Create the managers with our dedicated queue
        centralManager = CBCentralManager(delegate: self, queue: bluetoothQueue, options: centralOptions)
        peripheralManager = CBPeripheralManager(delegate: self, queue: bluetoothQueue)
        
        print("BluetoothManager initialization complete")
    }
    
    // MARK: - Central Methods
    func startScanning() {
        // Check for Bluetooth permission and power state
        switch centralManager.state {
        case .poweredOn:
            // Bluetooth is on and ready
            break
        case .poweredOff:
            DispatchQueue.main.async { [weak self] in
                self?.scanningMessage = "Bluetooth is powered off. Please turn on Bluetooth."
            }
            return
        case .unauthorized:
            DispatchQueue.main.async { [weak self] in
                self?.scanningMessage = "Bluetooth permission denied. Please enable in Settings."
            }
            print("IMPORTANT: Bluetooth permission is required. Add NSBluetoothAlwaysUsageDescription to Info.plist")
            return
        case .unsupported:
            DispatchQueue.main.async { [weak self] in
                self?.scanningMessage = "Bluetooth is not supported on this device"
            }
            return
        default:
            DispatchQueue.main.async { [weak self] in
                self?.scanningMessage = "Bluetooth is not ready. Please wait..."
            }
            return
        }
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.nearbyDevices.removeAll()
            self.isScanning = true
            self.scanningMessage = "Scanning for devices..."
        }
        
        // Start scanning for devices with our service UUID
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        print("Started scanning for devices with UUID: \(serviceUUID.uuidString)")
    }
    
    func stopScanning() {
        centralManager.stopScan()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isScanning = false
            self.scanningMessage = "Scanning stopped"
        }
        
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
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAdvertising = true
        }
        
        print("Started advertising as: 12x App \(UIDevice.current.name)")
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAdvertising = false
        }
        
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
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                for peripheral in peripherals {
                    if !self.nearbyDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                        self.nearbyDevices.append(peripheral)
                    }
                }
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // This runs on the bluetoothQueue, update UI properties on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch central.state {
            case .poweredOn:
                print("Central manager powered on")
                self.startScanning()
                self.startAdvertising()
            case .poweredOff:
                print("Central manager powered off")
                self.scanningMessage = "Bluetooth is powered off"
            case .resetting:
                print("Central manager resetting")
            case .unauthorized:
                print("Central manager unauthorized")
                self.scanningMessage = "Bluetooth permission denied"
            case .unsupported:
                print("Central manager unsupported")
                self.scanningMessage = "Bluetooth not supported"
            case .unknown:
                print("Central manager unknown state")
            @unknown default:
                print("Central manager unknown default")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Check if the device has a name
        let deviceName = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown Device"
        
        // Only add devices that have "12x App" in their name
        guard deviceName.contains("12x App") else {
            return
        }
        
        // Save to our device store (thread-safe operation)
        deviceStore.addDevice(identifier: peripheral.identifier.uuidString, name: deviceName)
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // See if we already found this device
            if !self.nearbyDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                print("Discovered device: \(deviceName) (RSSI: \(RSSI))")
                self.nearbyDevices.append(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to device: \(peripheral.name ?? peripheral.identifier.uuidString)")
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !self.connectedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                self.connectedPeripherals.append(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to device: \(peripheral.name ?? peripheral.identifier.uuidString), error: \(error?.localizedDescription ?? "unknown error")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from device: \(peripheral.name ?? peripheral.identifier.uuidString)")
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connectedPeripherals.removeAll(where: { $0.identifier == peripheral.identifier })
        }
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
        // This runs on the bluetoothQueue, update UI properties on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch peripheral.state {
            case .poweredOn:
                print("Peripheral manager powered on")
                self.startAdvertising()
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
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("Error adding service: \(error.localizedDescription)")
        } else {
            print("Service added successfully")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let error = error {
                print("Error starting advertising: \(error.localizedDescription)")
                self.isAdvertising = false
            } else {
                print("Advertising started successfully")
                self.isAdvertising = true
            }
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
    @State private var showDeviceSelectionView = false
    @State private var showDevicesList = false
    @State private var runTime: Int = 0
    @State private var hasFoundDevices = false
    
    // Track active timers to avoid duplicates
    @State private var progressTimer: Timer? = nil
    @State private var emojiTimer: Timer? = nil
    @State private var debugTimer: Timer? = nil
    
    let emojis = ["📱", "🔄", "✨", "🚀", "🔍", "📡"]
    
    var body: some View {
        NavigationView {
            ZStack {
                if hasFoundDevices {
                    // Show the select devices view when devices are found
                    NavigationLink(
                        destination: SelectDevicesView(bluetoothManager: bluetoothManager),
                        isActive: $showDeviceSelectionView
                    ) {
                        EmptyView()
                    }
                    .hidden()
                    
                    // The transition UI, shown briefly before navigation
                    VStack(spacing: 30) {
                        Text("Device Found!")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.green)
                        
                        Text("Connecting you to your family")
                            .font(.title3)
                        
                        Button(action: {
                            showDeviceSelectionView = true
                        }) {
                            Text("Select Family Members")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                        .padding(.top, 40)
                    }
                    .padding()
                    .onAppear {
                        // Auto-navigate after a brief pause to show the green screen
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showDeviceSelectionView = true
                        }
                    }
                } else {
                    // Original onboarding UI when no devices found yet
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
                        
                        // Debug text - shows log status
                        Text(debugText)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("Waiting for devices...")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .navigationTitle("Setup")
                }
            }
            .onAppear {
                print("ONBOARDING VIEW APPEARED")
                debugText = "View appeared at \(formattedTime(Date()))"
                
                // Only start animations and timers if they're not already running
                startAnimationsAndTimers()
                
                // Setup observer for device discovery
                startDeviceObserver()
            }
            .onDisappear {
                // Clean up timers when view disappears
                stopTimers()
            }
        }
    }
    
    private func startDeviceObserver() {
        // Create an observer to watch for device discovery
        DispatchQueue.main.async {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                if !bluetoothManager.nearbyDevices.isEmpty && !hasFoundDevices {
                    // When first device is found, stop animations and show the transition
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        hasFoundDevices = true
                        stopTimers()
                    }
                    timer.invalidate()
                }
            }
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func startAnimationsAndTimers() {
        // Only start timers if they're not already running
        if progressTimer == nil {
            startProgressAnimation()
        }
        
        if emojiTimer == nil {
            startEmojiAnimation()
        }
        
        if debugTimer == nil {
            startDebugUpdates()
        }
    }
    
    private func stopTimers() {
        progressTimer?.invalidate()
        progressTimer = nil
        
        emojiTimer?.invalidate()
        emojiTimer = nil
        
        debugTimer?.invalidate()
        debugTimer = nil
    }
    
    func startProgressAnimation() {
        // Loop the progress animation indefinitely
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
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
        emojiTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            withAnimation {
                emojiIndex = (emojiIndex + 1) % emojis.count
            }
        }
    }
    
    func startDebugUpdates() {
        // Update debug text periodically to show app is running
        runTime = 0
        debugTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [self] timer in
            runTime += 5
            debugText = "Running for \(runTime)s (at \(formattedTime(Date())))"
            print("App running for \(runTime) seconds")
        }
    }
}

#Preview {
    OnboardingView()
}

// MARK: - Device Selection Views

// SelectDevicesView for choosing devices to connect with
struct SelectDevicesView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var selectedDevices: Set<UUID> = []
    @State private var showNextScreen = false
    
    var body: some View {
        ZStack {
            // Background color change to indicate stage transition
            Color.green.opacity(0.2).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Family Devices Found!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.top, 30)
                
                // Device list
                List {
                    ForEach(bluetoothManager.nearbyDevices, id: \.identifier) { device in
                        DeviceSelectionRow(
                            device: device,
                            isSelected: selectedDevices.contains(device.identifier),
                            toggleSelection: {
                                if selectedDevices.contains(device.identifier) {
                                    selectedDevices.remove(device.identifier)
                                } else {
                                    selectedDevices.insert(device.identifier)
                                }
                            }
                        )
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                Text("Select family members' devices to connect with")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                NavigationLink(
                    destination: NextView(selectedDevices: selectedDevices, bluetoothManager: bluetoothManager),
                    isActive: $showNextScreen
                ) {
                    Button(action: {
                        showNextScreen = true
                    }) {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 30)
                .disabled(selectedDevices.isEmpty)
                .opacity(selectedDevices.isEmpty ? 0.6 : 1.0)
            }
            .padding()
        }
        .navigationTitle("Select Devices")
        .navigationBarBackButtonHidden(true)
    }
}

struct DeviceSelectionRow: View {
    let device: CBPeripheral
    let isSelected: Bool
    let toggleSelection: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.name ?? "Unknown Device")
                    .font(.headline)
                
                Text(device.identifier.uuidString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.title2)
                .foregroundColor(isSelected ? .green : .gray)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection()
        }
        .padding(.vertical, 8)
    }
}

// NextView for showing selected devices and confirming completion
struct NextView: View {
    let selectedDevices: Set<UUID>
    @ObservedObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Family Connected!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.green)
            
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.green)
            
            Text("You've successfully selected \(selectedDevices.count) family device\(selectedDevices.count == 1 ? "" : "s").")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
            
            List {
                Section(header: Text("Selected Devices")) {
                    ForEach(bluetoothManager.nearbyDevices.filter { selectedDevices.contains($0.identifier) }, id: \.identifier) { device in
                        HStack {
                            Image(systemName: "iphone.circle.fill")
                                .foregroundColor(.green)
                            Text(device.name ?? "Unknown Device")
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            Spacer()
            
            Text("Continue setting up your family connections")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("Setup Complete")
    }
}
