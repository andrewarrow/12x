import SwiftUI
import CoreBluetooth

struct DeviceDetailView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    let device: BluetoothDevice
    
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
            
            // Success message
            if bluetoothManager.transferSuccess == true {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Calendar Sent Successfully!")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
                .padding()
            }
            
            // Error message
            if bluetoothManager.transferSuccess == false {
                VStack(spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Failed to Send Calendar")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    if let errorMessage = bluetoothManager.transferError {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
                .padding()
            }
            
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
            
            // Progress bar and status
            if bluetoothManager.sendingCalendarData {
                VStack(spacing: 12) {
                    // Progress label based on current progress
                    // Use a state variable to hold the status text to avoid flickering
                    Text(progressStatusText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .animation(.none) // Disable animations for the text to prevent flickering
                        .fixedSize(horizontal: false, vertical: true) // Ensure consistent height
                        .frame(height: 20) // Fix the height to prevent layout shifts
                    
                    // Progress bar using the actual transfer progress
                    ProgressView(value: bluetoothManager.transferProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.horizontal)
                        .animation(.linear(duration: 0.3), value: bluetoothManager.transferProgress) // Smooth animation
                    
                    // Percentage text
                    Text("\(Int(bluetoothManager.transferProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .animation(.none) // Disable animations for percentage text
                    
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
    }
    
    // Helper to determine the appropriate progress status text
    private var progressStatusText: String {
        // Calculating once and then using the local value to avoid race conditions
        let progress = bluetoothManager.transferProgress
        
        // Use broader ranges to avoid flickering between states
        if progress < 0.15 {
            return "Connecting to device..."
        } else if progress < 0.25 {
            return "Discovering services..."
        } else if progress < 0.35 {
            return "Preparing data to send..."
        } else if progress < 0.85 {
            return "Sending calendar data..."
        } else if progress < 0.99 {
            return "Finalizing transfer..."
        } else {
            return "Transfer complete!"
        }
    }
}

#Preview {
    NavigationView {
        DeviceDetailView(device: BluetoothDevice(peripheral: nil, name: "Test Device", rssi: -50, isSameApp: true))
            .environmentObject(BluetoothManager())
    }
}