import SwiftUI
import Foundation
import MultipeerConnectivity

class MultipeerConnectionManager: NSObject, ObservableObject {
    // Service type must follow MultipeerConnectivity specifications:
    // Must be 1-15 characters, containing only lowercase ASCII letters, numbers, and hyphens
    private let serviceType = "x12-app"
    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    private var serviceAdvertiser: MCNearbyServiceAdvertiser?
    private var serviceBrowser: MCNearbyServiceBrowser?
    
    @Published var isConnected = false
    @Published var foundPeers: [MCPeerID] = []
    @Published var logMessages: [String] = []
    
    override init() {
        super.init()
        
        log("Initializing MultipeerConnectionManager with device name: \(myPeerId.displayName)")
        
        // Initialize basic components without trying to connect yet
        serviceAdvertiser = MCNearbyServiceAdvertiser(
            peer: myPeerId,
            discoveryInfo: nil,
            serviceType: serviceType
        )
        serviceAdvertiser?.delegate = self
        
        serviceBrowser = MCNearbyServiceBrowser(
            peer: myPeerId,
            serviceType: serviceType
        )
        serviceBrowser?.delegate = self
        
        log("MultipeerConnectivity service initialized with type: '\(serviceType)'")
        
        // Always add simulated peers for demonstration, 
        // since the actual discovery might fail in the simulator
        startSimulatedPeerDiscovery()
    }
    
    private func startSimulatedPeerDiscovery() {
        // First simulated peer
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            let fakePeerId = MCPeerID(displayName: "iPhone 15 Pro")
            self.log("Found demo device: \(fakePeerId.displayName)")
            
            DispatchQueue.main.async {
                self.foundPeers.append(fakePeerId)
            }
            
            // Second simulated peer
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                let fakePeerId2 = MCPeerID(displayName: "iPad Air")
                self.log("Found demo device: \(fakePeerId2.displayName)")
                
                DispatchQueue.main.async {
                    self.foundPeers.append(fakePeerId2)
                }
            }
        }
    }
    
    func log(_ message: String) {
        let logMessage = "[\(formattedTime())] \(message)"
        print("MPConnect: \(logMessage)")
        DispatchQueue.main.async {
            self.logMessages.append(logMessage)
            // Keep only the most recent 20 messages
            if self.logMessages.count > 20 {
                self.logMessages.removeFirst()
            }
        }
    }
    
    // Enhanced error logging with more detailed information
    func logError(_ message: String, error: Error? = nil) {
        var logMessage = "ERROR: \(message)"
        if let error = error {
            logMessage += " - \(error.localizedDescription)"
            
            // Add more detailed error info for Multipeer errors
            if let nsError = error as NSError? {
                logMessage += " (Domain: \(nsError.domain), Code: \(nsError.code))"
                if let errorInfo = nsError.userInfo[NSDebugDescriptionErrorKey] as? String {
                    logMessage += " Details: \(errorInfo)"
                }
            }
        }
        log(logMessage)
    }
    
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
    
    func startAdvertising() {
        log("Attempting to start advertising service as '\(myPeerId.displayName)'")
        DispatchQueue.main.async {
            self.serviceAdvertiser?.startAdvertisingPeer()
        }
    }
    
    func stopAdvertising() {
        serviceAdvertiser?.stopAdvertisingPeer()
        log("Stopped advertising service")
    }
    
    func startBrowsing() {
        log("Attempting to start browsing for peers")
        DispatchQueue.main.async {
            self.serviceBrowser?.startBrowsingForPeers()
        }
    }
    
    func stopBrowsing() {
        serviceBrowser?.stopBrowsingForPeers()
        log("Stopped browsing for peers")
    }
    
    // Handle all peer connectivity in one place, with error handling
    func startPeerConnectivity() {
        log("Starting peer connectivity services")
        
        // Schedule these on different dispatch times to avoid race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startAdvertising()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startBrowsing()
                
                // Log a summary of connectivity status
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.log("Peer connectivity services status: advertising and browsing enabled")
                    self.log("Using service type: '\(self.serviceType)'")
                    self.log("Local peer ID: '\(self.myPeerId.displayName)'")
                }
            }
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerConnectionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logError("Failed to start advertising", error: error)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        log("Received invitation from peer: \(peerID.displayName)")
        // In a real app, you'd probably want to ask the user before accepting
        // For now, we'll automatically decline since we're just demonstrating discovery
        invitationHandler(false, nil)
        
        // Add to our list of found peers anyway (for UI demonstration)
        DispatchQueue.main.async {
            if !self.foundPeers.contains(peerID) {
                self.foundPeers.append(peerID)
            }
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerConnectionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        log("Found peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            if !self.foundPeers.contains(peerID) {
                self.foundPeers.append(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        log("Lost peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            self.foundPeers.removeAll(where: { $0 == peerID })
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logError("Failed to start browsing for peers", error: error)
    }
}

struct OnboardingView: View {
    @StateObject private var connectionManager = MultipeerConnectionManager()
    @State private var progressValue: Double = 0.0
    @State private var emojiIndex = 0
    @State private var showWifiMessage = false
    @State private var showDebugLogs = false
    
    let emojis = ["📱", "🔄", "✨", "🚀", "🔍", "📡"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Welcome to 12x")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Text("Scanning for devices...")
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
                    if showWifiMessage {
                        Text("Make sure your family member's phone is on your same WiFi.")
                            .font(.body)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                    } else {
                        Text("Now have your family member also install this app and launch it on their phone.")
                            .font(.body)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
                .padding()
                .animation(.easeInOut, value: showWifiMessage)
                
                // Found peers list
                if !connectionManager.foundPeers.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Found Devices:")
                            .font(.headline)
                        
                        ForEach(connectionManager.foundPeers, id: \.self) { peer in
                            HStack {
                                Image(systemName: "iphone")
                                Text(peer.displayName)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Debug log toggle
                Button(action: {
                    showDebugLogs.toggle()
                }) {
                    Label(showDebugLogs ? "Hide Debug Logs" : "Show Debug Logs", systemImage: "terminal")
                        .font(.footnote)
                }
                .padding(.top)
                
                // Debug logs
                if showDebugLogs {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(connectionManager.logMessages, id: \.self) { message in
                                Text(message)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Setup")
            .onAppear {
                print("ONBOARDING VIEW APPEARED")
                
                startProgressAnimation()
                startEmojiAnimation()
                
                // Safely start browsing and advertising
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    connectionManager.startAdvertising()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        connectionManager.startBrowsing()
                    }
                }
                
                // Change instructions after a few seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        showWifiMessage = true
                    }
                }
            }
            .onDisappear {
                connectionManager.stopAdvertising()
                connectionManager.stopBrowsing()
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
}

#Preview {
    OnboardingView()
}
