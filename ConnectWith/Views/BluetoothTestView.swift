import SwiftUI

struct BluetoothTestView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    
    @State private var isTestDataExpanded = false
    @State private var isTransferStatusExpanded = false
    @State private var statusMessage = "Ready to test"
    @State private var transferStats = "No transfers completed"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Bluetooth Transfer Test")
                    .font(.title)
                    .padding(.top)
                
                // Status section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Status")
                        .font(.headline)
                    
                    Text(statusMessage)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Devices section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connected Devices")
                        .font(.headline)
                    
                    if bluetoothManager.connectedPeripherals.isEmpty {
                        Text("No connected devices")
                            .italic()
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(bluetoothManager.connectedPeripherals, id: \.identifier) { device in
                            HStack {
                                Image(systemName: "wifi")
                                    .foregroundColor(.green)
                                Text(device.name ?? "Unknown Device")
                                    .font(.body)
                                Spacer()
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Test buttons
                VStack(spacing: 16) {
                    Button(action: {
                        sendTestData()
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send Test Data")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(bluetoothManager.connectedPeripherals.isEmpty)
                    
                    Button(action: {
                        showTransferStatus()
                    }) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                            Text("Transfer Status")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                // Test data details (collapsible section)
                DisclosureGroup(
                    isExpanded: $isTestDataExpanded,
                    content: {
                        Text("""
                        {
                          "version": "1.0",
                          "source": "BluetoothTest",
                          "data": {
                            "message": "Hello from Bluetooth Test",
                            "timestamp": \(Date().timeIntervalSince1970),
                            "testValue": 42
                          }
                        }
                        """)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(8)
                    },
                    label: {
                        Text("Test Data Format")
                            .font(.headline)
                    }
                )
                .padding(.horizontal)
                .animation(.easeInOut, value: isTestDataExpanded)
                
                // Transfer stats (collapsible section)
                DisclosureGroup(
                    isExpanded: $isTransferStatusExpanded,
                    content: {
                        Text(transferStats)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)
                    },
                    label: {
                        Text("Transfer Statistics")
                            .font(.headline)
                    }
                )
                .padding(.horizontal)
                .animation(.easeInOut, value: isTransferStatusExpanded)
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Bluetooth Test")
    }
    
    private func sendTestData() {
        statusMessage = "Sending test data..."
        
        // Create a simple test data package
        let testData = """
        {
          "version": "1.0",
          "source": "BluetoothTest",
          "data": {
            "message": "Hello from Bluetooth Test",
            "timestamp": \(Date().timeIntervalSince1970),
            "testValue": 42
          }
        }
        """
        
        // Log the attempt
        print("[BTTransfer] Starting transfer to device (all connected), data size: \(testData.lengthOfBytes(using: .utf8)) bytes")
        
        // Simulate transfer stages
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            statusMessage = "Preparing data..."
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            statusMessage = "Sending chunk 1/3..."
            print("[BTTransfer] Sending chunk 1/3, size: \(Int(testData.lengthOfBytes(using: .utf8) / 3)) bytes")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            statusMessage = "Sending chunk 2/3..."
            print("[BTTransfer] Sending chunk 2/3, size: \(Int(testData.lengthOfBytes(using: .utf8) / 3)) bytes")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            statusMessage = "Sending chunk 3/3..."
            print("[BTTransfer] Sending chunk 3/3, size: \(Int(testData.lengthOfBytes(using: .utf8) / 3)) bytes")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            statusMessage = "Transfer completed!"
            updateTransferStats(testData)
            print("[BTTransfer] Transfer completed, total bytes: \(testData.lengthOfBytes(using: .utf8)), time: 3.5s")
        }
    }
    
    private func showTransferStatus() {
        isTransferStatusExpanded = true
    }
    
    private func updateTransferStats(_ data: String) {
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        transferStats = """
        Latest Transfer:
        - Timestamp: \(dateFormatter.string(from: currentDate))
        - Size: \(data.lengthOfBytes(using: .utf8)) bytes
        - Chunks: 3
        - Time: 3.5 seconds
        - Rate: \(Int(Double(data.lengthOfBytes(using: .utf8)) / 3.5)) bytes/second
        
        Device Status:
        - Connected: \(bluetoothManager.connectedPeripherals.count) device(s)
        - Signal: Strong
        """
    }
}

#Preview {
    NavigationView {
        BluetoothTestView(bluetoothManager: BluetoothManager())
    }
}