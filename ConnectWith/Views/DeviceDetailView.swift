import SwiftUI
import CoreBluetooth

struct DeviceDetailView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    let device: BluetoothDevice
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Device Information") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(device.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("ID")
                        Spacer()
                        Text(device.id.uuidString)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Signal Strength")
                        Spacer()
                        Text("\(device.rssi) dBm (\(device.signalStrengthDescription))")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(device.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(device.isConnected ? .green : .secondary)
                    }
                    
                    if !device.isConnected {
                        Button(action: {
                            bluetoothManager.connect(to: device)
                        }) {
                            HStack {
                                Spacer()
                                Text("Connect to Device")
                                Spacer()
                            }
                        }
                        .buttonStyle(BorderedButtonStyle())
                        .controlSize(.large)
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 4)
                    }
                }
                
                if bluetoothManager.isConnecting {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Connecting...")
                            Spacer()
                        }
                    }
                }
                
                if !bluetoothManager.services.isEmpty {
                    Section("Services") {
                        ForEach(bluetoothManager.services, id: \.uuid) { service in
                            ServiceRow(service: service)
                        }
                    }
                }
                
                if !bluetoothManager.characteristics.isEmpty {
                    Section("Characteristics") {
                        ForEach(bluetoothManager.characteristics, id: \.uuid) { characteristic in
                            CharacteristicRow(characteristic: characteristic)
                        }
                    }
                }
            }
            .navigationTitle("Device Details")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if device.isConnected {
                        Button("Disconnect", role: .destructive) {
                            bluetoothManager.disconnect()
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        if device.isConnected {
                            bluetoothManager.disconnect()
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ServiceRow: View {
    let service: CBService
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(serviceName(for: service.uuid))
                .font(.headline)
            
            Text(service.uuid.uuidString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func serviceName(for uuid: CBUUID) -> String {
        switch uuid.uuidString {
        case "1800":
            return "Generic Access"
        case "1801":
            return "Generic Attribute"
        case "180F":
            return "Battery Service"
        case "180A":
            return "Device Information"
        case "1812":
            return "Human Interface Device"
        default:
            return "Unknown Service (\(uuid.uuidString))"
        }
    }
}

struct CharacteristicRow: View {
    let characteristic: CBCharacteristic
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(characteristicName(for: characteristic.uuid))
                .font(.headline)
            
            Text(characteristic.uuid.uuidString)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Properties:")
                    .font(.caption)
                
                ForEach(propertyDescriptions, id: \.self) { property in
                    Text(property)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            if let value = characteristic.value {
                Text("Value: \(formatCharacteristicValue(value, for: characteristic.uuid))")
                    .font(.caption)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var propertyDescriptions: [String] {
        var descriptions: [String] = []
        
        if characteristic.properties.contains(.read) {
            descriptions.append("Read")
        }
        if characteristic.properties.contains(.write) {
            descriptions.append("Write")
        }
        if characteristic.properties.contains(.writeWithoutResponse) {
            descriptions.append("Write No Response")
        }
        if characteristic.properties.contains(.notify) {
            descriptions.append("Notify")
        }
        if characteristic.properties.contains(.indicate) {
            descriptions.append("Indicate")
        }
        if characteristic.properties.contains(.broadcast) {
            descriptions.append("Broadcast")
        }
        
        return descriptions
    }
    
    private func characteristicName(for uuid: CBUUID) -> String {
        switch uuid.uuidString {
        case "2A19":
            return "Battery Level"
        case "2A29":
            return "Manufacturer Name"
        case "2A24":
            return "Model Number"
        case "2A25":
            return "Serial Number"
        case "2A27":
            return "Hardware Revision"
        case "2A26":
            return "Firmware Revision"
        case "2A28":
            return "Software Revision"
        default:
            return "Unknown Characteristic"
        }
    }
    
    private func formatCharacteristicValue(_ value: Data, for uuid: CBUUID) -> String {
        switch uuid.uuidString {
        case "2A19": // Battery Level
            if let byte = value.first {
                return "\(byte)%"
            }
            
        case "2A29", "2A24", "2A25", "2A26", "2A27", "2A28": // String values
            return String(data: value, encoding: .utf8) ?? "Unable to decode"
            
        default:
            break
        }
        
        // Default: return hex representation
        return value.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

#Preview {
    let device = BluetoothDevice(
        peripheral: nil,
        name: "Example Device",
        rssi: -65
    )
    
    DeviceDetailView(device: device)
        .environmentObject(BluetoothManager())
}