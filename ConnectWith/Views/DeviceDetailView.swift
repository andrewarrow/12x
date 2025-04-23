import SwiftUI
import CoreBluetooth

struct DeviceDetailView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    let device: BluetoothDevice
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var messageText = ""
    @State private var showDebugLog = false
    
    // Send message function
    func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        // Send the message
        bluetoothManager.sendMessage(text: messageText, to: device)
        
        // Clear the text field
        messageText = ""
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background for entire view
                Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Device Information Card
                        VStack(spacing: 12) {
                            Text("Device Information")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 4)
                            
                            InfoRow(label: "Name", value: device.name)
                            InfoRow(label: "ID", value: device.id.uuidString)
                            InfoRow(label: "Signal Strength", value: "\(device.rssi) dBm (\(device.signalStrengthDescription))")
                            InfoRow(label: "Status", value: device.isConnected ? "Connected" : "Disconnected", 
                                    valueColor: device.isConnected ? .green : nil)
                            
                            // Only show connect button for non-app devices
                            if !device.isConnected && !device.isSameApp {
                                Button(action: {
                                    bluetoothManager.connect(to: device)
                                }) {
                                    Text("Connect to Device")
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                        .padding(.horizontal)
                        
                        // Chat UI for special devices
                        if device.isSameApp {
                            // Message input
                            VStack(spacing: 0) {
                                HStack {
                                    TextField("Type a message...", text: $messageText)
                                        .padding(12)
                                        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                                        .cornerRadius(25)
                                        .disabled(bluetoothManager.sendingMessage)
                                    
                                    Button(action: {
                                        sendMessage()
                                    }) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(messageText.isEmpty || bluetoothManager.sendingMessage ? .gray : .blue)
                                    }
                                    .disabled(messageText.isEmpty || bluetoothManager.sendingMessage)
                                    .padding(.leading, 8)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                )
                                
                                // Status indicator
                                if bluetoothManager.sendingMessage {
                                    HStack {
                                        ProgressView()
                                            .padding(.trailing, 8)
                                        Text("Sending message...")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                }
                                
                                // Messages section
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Messages")
                                        .font(.headline)
                                        .padding(.vertical, 8)
                                    
                                    if device.receivedMessages.isEmpty && bluetoothManager.sentMessages.isEmpty {
                                        Text("No messages yet. Send a message to start chatting!")
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.vertical, 20)
                                    } else {
                                        // Show sent messages
                                        ForEach(bluetoothManager.sentMessages) { message in
                                            MessageBubble(message: message, isSent: true)
                                        }
                                        
                                        // Show received messages
                                        ForEach(device.receivedMessages) { message in
                                            MessageBubble(message: message, isSent: false)
                                        }
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                )
                            }
                            .padding(.horizontal)
                        }
                
                        // Debug log for special devices
                        if device.isSameApp {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Debug Log")
                                        .font(.headline)
                                        .padding(.vertical, 8)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        showDebugLog.toggle()
                                    }) {
                                        Text(showDebugLog ? "Hide" : "Show")
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(8)
                                    }
                                }
                                
                                if showDebugLog {
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(bluetoothManager.debugMessages, id: \.self) { message in
                                                Text(message)
                                                    .font(.system(.caption, design: .monospaced))
                                                    .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                                                    .padding(.vertical, 2)
                                            }
                                        }
                                    }
                                    .frame(height: 200)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Services and characteristics
                        if !bluetoothManager.services.isEmpty && !device.isSameApp {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Services")
                                    .font(.headline)
                                    .padding(.vertical, 8)
                                
                                ForEach(bluetoothManager.services, id: \.uuid) { service in
                                    ServiceRow(service: service)
                                        .padding(.vertical, 4)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                        if !bluetoothManager.characteristics.isEmpty && !device.isSameApp {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Characteristics")
                                    .font(.headline)
                                    .padding(.vertical, 8)
                                
                                ForEach(bluetoothManager.characteristics, id: \.uuid) { characteristic in
                                    CharacteristicRow(characteristic: characteristic)
                                        .padding(.vertical, 4)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Connection status at the bottom
                        if bluetoothManager.isConnecting {
                            HStack {
                                Spacer()
                                ProgressView("Connecting...")
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Add some spacing at the bottom
                        Spacer().frame(height: 40)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle(device.isSameApp ? "Chat with \(device.name)" : "Device Details")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if device.isConnected && !device.isSameApp {
                        Button("Disconnect", role: .destructive) {
                            bluetoothManager.disconnect()
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        if device.isConnected && !device.isSameApp {
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

// InfoRow component for the device information section
struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color? = nil
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(valueColor ?? .secondary)
        }
        .padding(.vertical, 4)
    }
}

// Message bubble for chat
struct MessageBubble: View {
    let message: ChatMessage
    let isSent: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            if isSent {
                Spacer()
            }
            
            VStack(alignment: isSent ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .padding(10)
                    .background(
                        isSent 
                        ? Color.blue 
                        : (colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                    )
                    .foregroundColor(
                        isSent 
                        ? .white 
                        : (colorScheme == .dark ? .white : .primary)
                    )
                    .cornerRadius(16)
                
                Text(formattedTime(date: message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !isSent {
                Spacer()
            }
        }
    }
    
    private func formattedTime(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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