import SwiftUI
import CoreBluetooth

struct DeviceDetailView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    let device: BluetoothDevice
    
    // Track sending progress
    @State private var sendingProgress: Double = 0
    
    var body: some View {
        VStack {
            Spacer()
            
            // Information about the device
            VStack(spacing: 15) {
                Image(systemName: "iphone.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Connected to \(device.name)")
                    .font(.headline)
                
                Text("Signal Strength: \(device.signalStrengthDescription)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Device ID: \(device.id.uuidString.prefix(8))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Spacer()
            
            // Send data button
            Button(action: {
                // Start progress animation
                withAnimation(.linear(duration: 5)) {
                    sendingProgress = 1.0
                }
                
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
            
            // Progress bar
            if bluetoothManager.sendingCalendarData {
                VStack(spacing: 10) {
                    ProgressView(value: sendingProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.horizontal)
                    
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Sending calendar data...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .navigationTitle("Connect with \(device.name)")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: bluetoothManager.sendingCalendarData) { isSending in
            if isSending {
                // Reset and animate progress when sending starts
                sendingProgress = 0
                withAnimation(.linear(duration: 5)) {
                    sendingProgress = 1.0
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        DeviceDetailView(device: BluetoothDevice(peripheral: nil, name: "Test Device", rssi: -50, isSameApp: true))
            .environmentObject(BluetoothManager())
    }
}