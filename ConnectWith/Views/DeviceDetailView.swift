import SwiftUI
import CoreBluetooth

struct DeviceDetailView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    let device: BluetoothDevice
    @State private var messageText = ""
    
    // Send message function
    func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        // Send the message
        bluetoothManager.sendMessage(text: messageText, to: device)
        
        // Clear the text field
        messageText = ""
    }
    
    var body: some View {
        VStack {
            // Message input at the top
            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button(action: {
                    sendMessage()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                .disabled(messageText.isEmpty)
                .padding(.trailing)
            }
            .padding(.top)
            
            Divider()
                .padding(.vertical)
            
            // Messages list
            if device.receivedMessages.isEmpty && bluetoothManager.sentMessages.isEmpty {
                Spacer()
                Text("No messages yet")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(bluetoothManager.sentMessages) { message in
                            HStack {
                                Spacer()
                                Text(message.text)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                        
                        ForEach(device.receivedMessages) { message in
                            HStack {
                                Text(message.text)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Chat with \(device.name)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        DeviceDetailView(device: BluetoothDevice(peripheral: nil, name: "Test Device", rssi: -50, isSameApp: true))
            .environmentObject(BluetoothManager())
    }
}