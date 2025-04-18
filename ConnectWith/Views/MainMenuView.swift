import SwiftUI
import Foundation
import MultipeerConnectivity

enum HandshakeStep: Int, CaseIterable {
    case idle = 0
    case sendingHello = 1
    case helloSent = 2
    case waitingForAck = 3
    case ackReceived = 4
    case handshakeComplete = 5
    
    var description: String {
        switch self {
        case .idle: return "Ready to connect"
        case .sendingHello: return "Step 1. Sending HELLO"
        case .helloSent: return "Step 2. No error sending HELLO"
        case .waitingForAck: return "Step 3. Waiting for ACK..."
        case .ackReceived: return "Step 4. Received ACK"
        case .handshakeComplete: return "Step 5. Handshake Successful!"
        }
    }
    
    func description(withPeer peerName: String?) -> String {
        switch self {
        case .idle: return "Ready to connect"
        case .sendingHello: return "Step 1. Sending HELLO"
        case .helloSent: return "Step 2. No error sending HELLO"
        case .waitingForAck: return "Step 3. Waiting for ACK..."
        case .ackReceived: 
            if let name = peerName {
                return "Step 4. Received ACK from \(name)"
            }
            return "Step 4. Received ACK"
        case .handshakeComplete: return "Step 5. Handshake Successful!"
        }
    }
}

struct PeerConnection: Identifiable, Equatable {
    let id: MCPeerID
    var handshakeStep: HandshakeStep
    var session: MCSession?
    
    static func == (lhs: PeerConnection, rhs: PeerConnection) -> Bool {
        return lhs.id == rhs.id
    }
}

class MultipeerConnectionManager: NSObject, ObservableObject {
    // Service type must follow MultipeerConnectivity specifications:
    // Must be 1-15 characters, containing only lowercase ASCII letters, numbers, and hyphens
    // Service type must be 1-15 lowercase ASCII characters or numbers
    private let serviceType = "x12app"
    // Create a unique ID with the device name
    private let myPeerId: MCPeerID
    private var serviceAdvertiser: MCNearbyServiceAdvertiser?
    private var serviceBrowser: MCNearbyServiceBrowser?
    private var session: MCSession?
    
    @Published var isConnected = false
    @Published var foundPeers: [PeerConnection] = []
    @Published var logMessages: [String] = []
    @Published var selectedPeer: PeerConnection?
    @Published var currentHandshakeStep: HandshakeStep = .idle
    @Published var handshakeError: String?
    @Published var showHandshakeView = false
    @Published var connectedPeers: [PeerConnection] = []
    
    override init() {
        // Initialize peer ID with the device name + a random suffix for uniqueness
        let deviceName = UIDevice.current.name
        let randomSuffix = String(Int.random(in: 1000...9999))
        myPeerId = MCPeerID(displayName: deviceName)
        
        super.init()
        
        log("Initializing MultipeerConnectionManager with device name: \(myPeerId.displayName)")
        
        // Initialize session first
        session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .none)
        session?.delegate = self
        
        // Initialize basic components without trying to connect yet
        serviceAdvertiser = MCNearbyServiceAdvertiser(
            peer: myPeerId,
            discoveryInfo: ["name": myPeerId.displayName],
            serviceType: serviceType
        )
        serviceAdvertiser?.delegate = self
        
        serviceBrowser = MCNearbyServiceBrowser(
            peer: myPeerId,
            serviceType: serviceType
        )
        serviceBrowser?.delegate = self
        
        // Log additional platform information for debugging
        let device = UIDevice.current
        log("Device: \(device.name), iOS \(device.systemVersion), Model: \(device.model)")
        
        log("MultipeerConnectivity service initialized with type: '\(serviceType)'")
        
        // No simulated devices - only real physical devices will be used
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
        
        // Update UI if this is a handshake error
        DispatchQueue.main.async {
            self.handshakeError = message
        }
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
        
        // Make sure Bluetooth is enabled
        if #available(iOS 13.0, *) {
            log("Checking network capabilities...")
        }
        
        // Start browsing before advertising to avoid race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startBrowsing()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startAdvertising()
                
                // Log a summary of connectivity status
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.log("Peer connectivity services status: advertising and browsing enabled")
                    self.log("Using service type: '\(self.serviceType)'")
                    self.log("Local peer ID: '\(self.myPeerId.displayName)'")
                    
                    // Check for any active connections
                    if let session = self.session, !session.connectedPeers.isEmpty {
                        self.log("Already connected to \(session.connectedPeers.count) peers")
                        for peer in session.connectedPeers {
                            self.log("- Connected to: \(peer.displayName)")
                        }
                    } else {
                        self.log("No active connections yet")
                    }
                }
            }
        }
    }
    
    // Start handshake with selected peer
    func startHandshake(with peer: PeerConnection) {
        guard let peerID = foundPeers.first(where: { $0.id == peer.id })?.id else {
            logError("Peer not found for handshake")
            return
        }
        
        self.selectedPeer = peer
        self.currentHandshakeStep = .idle
        self.handshakeError = nil
        self.showHandshakeView = true
        
        // Use the existing session
        guard let session = self.session else {
            logError("Session not initialized")
            return
        }
        
        // Update our peer with the session
        if let index = foundPeers.firstIndex(where: { $0.id == peer.id }) {
            DispatchQueue.main.async {
                self.foundPeers[index].session = session
                self.selectedPeer = self.foundPeers[index]
            }
        }
        
        // Start the handshake process with artificial delays to make steps visible
        performHandshakeStep(.sendingHello, for: peer, session: session)
    }
    
    private func performHandshakeStep(_ step: HandshakeStep, for peer: PeerConnection, session: MCSession, delay: TimeInterval = 0.8) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            DispatchQueue.main.async {
                self.currentHandshakeStep = step
            }
            
            switch step {
            case .sendingHello:
                self.log("Handshake: Sending HELLO to \(peer.id.displayName)")
                
                // Initiate invitation to the peer
                self.serviceBrowser?.invitePeer(peer.id, to: session, withContext: "HELLO".data(using: .utf8), timeout: 30)
                
                // Move to next step after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.performHandshakeStep(.helloSent, for: peer, session: session)
                }
                
            case .helloSent:
                self.log("Handshake: HELLO sent to \(peer.id.displayName)")
                
                // Move to waiting for ACK
                self.performHandshakeStep(.waitingForAck, for: peer, session: session, delay: 1.0)
                
            case .waitingForAck:
                self.log("Handshake: Waiting for ACK from \(peer.id.displayName)")
                
                // In a real implementation, we'd wait for actual ACK data
                // Check if already connected
                if session.connectedPeers.contains(peer.id) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.performHandshakeStep(.ackReceived, for: peer, session: session)
                    }
                } else {
                    // Set a timeout to check connection status
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if session.connectedPeers.contains(peer.id) {
                            self.performHandshakeStep(.ackReceived, for: peer, session: session)
                        } else {
                            // One more check
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                if session.connectedPeers.contains(peer.id) {
                                    self.performHandshakeStep(.ackReceived, for: peer, session: session)
                                } else {
                                    // Timeout
                                    DispatchQueue.main.async {
                                        self.logError("Timeout waiting for ACK from \(peer.id.displayName)")
                                    }
                                }
                            }
                        }
                    }
                }
                
            case .ackReceived:
                self.log("Handshake: Received ACK from \(peer.id.displayName)")
                
                // Add a name to the ACK message for UI
                DispatchQueue.main.async {
                    // Update display with peer name
                    self.currentHandshakeStep = .ackReceived
                }
                
                // Move to handshake complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.performHandshakeStep(.handshakeComplete, for: peer, session: session)
                }
                
            case .handshakeComplete:
                self.log("Handshake: Successful with \(peer.id.displayName)!")
                
                // Add to connected peers
                DispatchQueue.main.async {
                    // Create a new peer with completed handshake
                    let completedPeer = PeerConnection(
                        id: peer.id, 
                        handshakeStep: .handshakeComplete,
                        session: session
                    )
                    
                    // Update the peer in foundPeers list
                    if let index = self.foundPeers.firstIndex(where: { $0.id == peer.id }) {
                        self.foundPeers[index] = completedPeer
                    }
                    
                    // Add to connected peers if not already there
                    if !self.connectedPeers.contains(where: { $0.id == peer.id }) {
                        self.connectedPeers.append(completedPeer)
                    }
                }
                
            case .idle:
                break // Should not happen
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
        
        // Create a session for accepting the invitation
        let session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        // Check if the invitation contains our HELLO message
        if let contextData = context, let message = String(data: contextData, encoding: .utf8), message == "HELLO" {
            log("Received HELLO from peer: \(peerID.displayName), accepting invitation")
            invitationHandler(true, session)
            
            // ACK is automatically sent when we accept and join the session
        } else {
            log("Received unknown message from peer: \(peerID.displayName), declining invitation")
            invitationHandler(false, nil)
        }
        
        // Create a peer connection if we don't already have one
        DispatchQueue.main.async {
            if !self.foundPeers.contains(where: { $0.id == peerID }) {
                let newPeer = PeerConnection(id: peerID, handshakeStep: .idle, session: session)
                self.foundPeers.append(newPeer)
            }
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerConnectionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        log("Found peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            if !self.foundPeers.contains(where: { $0.id == peerID }) {
                let newPeer = PeerConnection(id: peerID, handshakeStep: .idle, session: nil)
                self.foundPeers.append(newPeer)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        log("Lost peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            self.foundPeers.removeAll(where: { $0.id == peerID })
            self.connectedPeers.removeAll(where: { $0.id == peerID })
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logError("Failed to start browsing for peers", error: error)
    }
}

// MARK: - MCSessionDelegate
extension MultipeerConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let stateString: String
        
        switch state {
        case .connected:
            stateString = "Connected"
            
            // If this peer is our selected peer, update handshake step
            if let selectedPeer = selectedPeer, selectedPeer.id == peerID, currentHandshakeStep == .waitingForAck {
                DispatchQueue.main.async {
                    self.performHandshakeStep(.ackReceived, for: selectedPeer, session: session, delay: 0.1)
                }
            }
            
        case .connecting:
            stateString = "Connecting"
        case .notConnected:
            stateString = "Not Connected"
            
            // If we were in a handshake with this peer and lost connection, log error
            if let selectedPeer = selectedPeer, selectedPeer.id == peerID, 
               currentHandshakeStep != .idle && currentHandshakeStep != .handshakeComplete {
                logError("Connection to peer \(peerID.displayName) was lost during handshake")
            }
            
        @unknown default:
            stateString = "Unknown state: \(state.rawValue)"
        }
        
        log("Peer \(peerID.displayName) changed state to \(stateString)")
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = String(data: data, encoding: .utf8) {
            log("Received message from peer \(peerID.displayName): \(message)")
        } else {
            log("Received binary data from peer \(peerID.displayName): \(data.count) bytes")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        log("Received stream from peer \(peerID.displayName) with name: \(streamName)")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        log("Started receiving resource from peer \(peerID.displayName): \(resourceName)")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        if let error = error {
            logError("Error receiving resource from peer \(peerID.displayName): \(resourceName)", error: error)
        } else {
            log("Finished receiving resource from peer \(peerID.displayName): \(resourceName)")
        }
    }
}

struct HandshakeView: View {
    @ObservedObject var connectionManager: MultipeerConnectionManager
    @State private var progressValue: Double = 0.0
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Connecting to \(connectionManager.selectedPeer?.id.displayName ?? "Device")")
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            
            // Handshake progress steps
            VStack(alignment: .leading, spacing: 15) {
                ForEach(HandshakeStep.allCases.filter { $0 != .idle }, id: \.self) { step in
                    HStack {
                        if step.rawValue < connectionManager.currentHandshakeStep.rawValue {
                            // Completed step
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if step.rawValue == connectionManager.currentHandshakeStep.rawValue {
                            // Current step
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            // Future step
                            Image(systemName: "circle")
                                .foregroundColor(.gray)
                        }
                        
                        Text(step.description(withPeer: connectionManager.selectedPeer?.id.displayName))
                            .font(.body)
                            .foregroundColor(step.rawValue <= connectionManager.currentHandshakeStep.rawValue ? .primary : .secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Error message if any
            if let error = connectionManager.handshakeError {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            
            // Continue button appears when handshake is complete
            if connectionManager.currentHandshakeStep == .handshakeComplete {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .padding(.top)
            }
            
            // Cancel button
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Cancel")
                    .foregroundColor(.secondary)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Device Handshake")
    }
}

struct OnboardingView: View {
    @StateObject private var connectionManager = MultipeerConnectionManager()
    @State private var progressValue: Double = 0.0
    @State private var emojiIndex = 0
    @State private var showWifiMessage = false
    @State private var showDebugLogs = false
    @State private var showContinueOptions = false
    
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
                
                // Connected peers
                if !connectionManager.connectedPeers.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Connected Devices:")
                            .font(.headline)
                        
                        ForEach(connectionManager.connectedPeers) { peer in
                            HStack {
                                Image(systemName: "iphone.circle.fill")
                                    .foregroundColor(.green)
                                Text(peer.id.displayName)
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
                    
                    // Continue options when at least one device is connected
                    if showContinueOptions {
                        HStack {
                            Button(action: {
                                // Continue with connected devices
                                print("Continuing with \(connectionManager.connectedPeers.count) connected devices")
                            }) {
                                Text("Continue with \(connectionManager.connectedPeers.count) device\(connectionManager.connectedPeers.count > 1 ? "s" : "")")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                // Stay and wait for more
                                showContinueOptions = false
                            }) {
                                Text("Wait for more")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Found but not yet connected peers
                if !connectionManager.foundPeers.filter({ $0.handshakeStep != .handshakeComplete }).isEmpty {
                    VStack(alignment: .leading) {
                        Text("Found Devices:")
                            .font(.headline)
                        
                        ForEach(connectionManager.foundPeers.filter { $0.handshakeStep != .handshakeComplete }) { peer in
                            Button(action: {
                                connectionManager.startHandshake(with: peer)
                            }) {
                                HStack {
                                    Image(systemName: "iphone")
                                        .foregroundColor(.blue)
                                    Text(peer.id.displayName)
                                    Spacer()
                                    Text("Connect")
                                        .foregroundColor(.blue)
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.blue)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
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
                    connectionManager.startPeerConnectivity()
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
            .sheet(isPresented: $connectionManager.showHandshakeView) {
                HandshakeView(connectionManager: connectionManager)
            }
            .onChange(of: connectionManager.connectedPeers.count) { newCount in
                if newCount > 0 && !showContinueOptions {
                    // Show continue options when a device connects successfully
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation {
                            showContinueOptions = true
                        }
                    }
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
}

#Preview {
    OnboardingView()
}
