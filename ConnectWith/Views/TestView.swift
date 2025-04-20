import Foundation
import SwiftUI
import Combine
import CoreBluetooth

/// Bluetooth transfer debug view
struct TestView: View {
    @ObservedObject private var syncManager = SyncManager.shared
    @ObservedObject private var deviceStore = DeviceStore.shared
    @State private var selectedDeviceId: String? = nil
    @State private var showingLogView = false
    @State private var logs: [String] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Bluetooth Transfer Test")
                    .font(.title)
                    .padding(.top)
                
                // Device Selection
                VStack(alignment: .leading) {
                    Text("Select Connected Device:")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(deviceStore.getAllSavedDevices().filter { $0.connectionStatus == .connected }, id: \.id) { device in
                                Button(action: {
                                    selectedDeviceId = device.identifier
                                }) {
                                    HStack {
                                        Image(systemName: selectedDeviceId == device.identifier ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedDeviceId == device.identifier ? .blue : .gray)
                                        
                                        VStack(alignment: .leading) {
                                            Text(device.displayName)
                                                .font(.headline)
                                            Text(device.identifier)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            
                            if deviceStore.getAllSavedDevices().filter({ $0.connectionStatus == .connected }).isEmpty {
                                Text("No connected devices available. Connect to a device in the Family tab first.")
                                    .foregroundColor(.gray)
                                    .italic()
                                    .padding()
                            }
                        }
                        .padding()
                    }
                    .frame(height: 150)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Transfer Status
                VStack(alignment: .leading) {
                    Text("Transfer Status:")
                        .font(.headline)
                    
                    VStack(alignment: .leading) {
                        if syncManager.isSyncing {
                            Text("Syncing...")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            
                            ProgressView(value: syncManager.syncProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .padding(.vertical, 4)
                            
                            Text("\(Int(syncManager.syncProgress * 100))% Complete")
                                .font(.caption)
                            
                            Text("Transferred: \(formatBytes(syncManager.bytesTransferred)) of \(formatBytes(syncManager.bytesTotal))")
                                .font(.caption)
                        } else {
                            Text("No active transfer")
                                .foregroundColor(.gray)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        if let deviceId = selectedDeviceId {
                            logs.append("[SyncManager] Starting sync with device id: \(deviceId)")
                            
                            // Find the device name from store
                            let deviceName = deviceStore.getAllSavedDevices()
                                .first(where: { $0.identifier == deviceId })?.displayName ?? "Unknown Device"
                            
                            // Start sync
                            syncManager.startSync(with: deviceId, displayName: deviceName)
                        } else {
                            logs.append("[SyncManager] Error: No device selected")
                        }
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send Test Data")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedDeviceId != nil ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(selectedDeviceId == nil || syncManager.isSyncing)
                    
                    Button(action: {
                        showingLogView = true
                        
                        // Get sync status
                        logs.append("--- Sync Status ---")
                        logs.append("Sync in progress: \(syncManager.isSyncing ? "Yes" : "No")")
                        logs.append("Sync progress: \(Int(syncManager.syncProgress * 100))%")
                        logs.append("Current device: \(syncManager.currentSyncDevice ?? "None")")
                        logs.append("Bytes transferred: \(formatBytes(syncManager.bytesTransferred)) of \(formatBytes(syncManager.bytesTotal))")
                        
                        // Copy all sync logs
                        logs.append("--- Sync Logs ---")
                        syncManager.syncLog.forEach { logEntry in
                            logs.append(logEntry)
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("Transfer Status")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    if syncManager.isSyncing {
                        Button(action: {
                            logs.append("[SyncManager] Cancelling sync")
                            syncManager.cancelSync()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Cancel Sync")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical)
            .navigationBarTitle("Debug Tools", displayMode: .inline)
            .sheet(isPresented: $showingLogView) {
                LogView(logs: $logs)
            }
            .onAppear {
                logs = ["[BTTransfer] Debug view loaded"]
            }
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct LogView: View {
    @Binding var logs: [String]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(logs.indices, id: \.self) { index in
                                Text(logs[index])
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.horizontal)
                                    .padding(.vertical, 2)
                                    .id(index)
                            }
                        }
                        .onChange(of: logs.count) { _ in
                            if let lastIndex = logs.indices.last {
                                proxy.scrollTo(lastIndex, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color.black.opacity(0.05))
                
                HStack {
                    Button(action: {
                        logs.append("[BTTransfer] Log cleared")
                        logs.removeAll(keepingCapacity: true)
                        logs.append("[BTTransfer] Log started")
                    }) {
                        Text("Clear Logs")
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Close")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationBarTitle("Transfer Logs", displayMode: .inline)
        }
    }
}

#Preview {
    TestView()
}