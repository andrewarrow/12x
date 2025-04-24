import SwiftUI
import CoreBluetooth
import UIKit
import Foundation

// Inline function to request Bluetooth permission directly
// This avoids dependency issues when using functions from other files
func requestBluetoothPermissionFromSplash() {
    print("🔵 SplashScreen: Requesting Bluetooth permission")
    
    // Create options that show permission dialog immediately
    let options: [String: Any] = [
        CBCentralManagerOptionShowPowerAlertKey: true
    ]
    
    // Creating a local delegate class to handle callbacks
    class LocalPermissionDelegate: NSObject, CBCentralManagerDelegate {
        func centralManagerDidUpdateState(_ central: CBCentralManager) {
            print("🔵 SplashScreen BT delegate: State updated to \(central.state.rawValue)")
            
            // Force scan to trigger permission dialog
            if central.state == .poweredOn {
                central.scanForPeripherals(withServices: nil, options: nil)
                
                // Stop scanning after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    central.stopScan()
                }
            }
        }
        
        func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
            print("🔵 SplashScreen BT delegate: willRestoreState called")
        }
    }
    
    // Create a new instance of the delegate
    let delegate = LocalPermissionDelegate()
    
    // Create a manager that will trigger the permission dialog
    let _ = CBCentralManager(delegate: delegate, queue: .main, options: options)
    
    // Force UI updates by creating a background task
    let task = UIApplication.shared.beginBackgroundTask {
        print("🔵 SplashScreen background task expired")
    }
    
    // End task after a short delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        UIApplication.shared.endBackgroundTask(task)
    }
}

struct SplashScreen: View {
    @Binding var isShowingSplash: Bool
    @State private var permissionAttempts = 0
    @State private var animationComplete = false
    
    // Simple way to force UI updates: use a timer
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        // Log when this view is evaluated
        let _ = { print("🎨 RENDER: SplashScreen body evaluated") }()
        
        ZStack {
            Color.blue.opacity(0.7)
                .ignoresSafeArea()
                .onAppear {
                    print("🎨 SPLASH: Background color appeared")
                }
            
            VStack {
                Text("12x")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                    .padding()
                    .onAppear {
                        print("🎨 SPLASH: Title text appeared")
                    }
                
                ZStack {
                    Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.white)
                    

                }
                .padding()
                .onAppear {
                    print("🎨 SPLASH: Icon images appeared")
                    
                    // Force the UI to render by creating a background task
                    let task = UIApplication.shared.beginBackgroundTask {
                        print("🎨 SPLASH: Background task expired")
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        UIApplication.shared.endBackgroundTask(task)
                        print("🎨 SPLASH: Background task completed")
                    }
                }
                
                Text("connect 12 times a year")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                
                // Animation to show the tabs loading
                HStack(spacing: 16) {
                    TabIconPreview(iconName: "antenna.radiowaves.left.and.right", label: "Devices", delay: 0.5)
                    TabIconPreview(iconName: "calendar", label: "Calendar", delay: 1.0)
                    TabIconPreview(iconName: "gear", label: "Settings", delay: 1.5)
                }
                .padding(.top, 40)
                .onAppear {
                    print("🎨 SPLASH: Tab icons appeared")
                    
                    // Mark when animations will be complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        print("🎨 SPLASH: Animations should be complete now")
                        animationComplete = true
                        
                        // Try our inline approach to forcing permission dialog
                        requestBluetoothPermissionFromSplash()
                    }
                }
                
                // Debug status text
                Text("Preparing app...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 30)
            }
        }
        .onAppear {
            print("🎨 SPLASH: SplashScreen.onAppear called")
            
            // Log basic window info
            if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                print("🎨 SPLASH: Key window size: \(window.bounds.width)x\(window.bounds.height)")
            }
            
            // Use a timer to periodically force UI update and attempt permission
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                permissionAttempts += 1
                print("🎨 SPLASH: Timer tick #\(permissionAttempts)")
                
                // Retry permission request every 1 second until successful
                if permissionAttempts <= 5 {
                    print("🎨 SPLASH: Attempt #\(permissionAttempts) to trigger permission")
                    requestBluetoothPermissionFromSplash()
                } else {
                    // After 5 seconds, forcefully proceed even if permission wasn't shown
                    timer.invalidate()
                    print("🎨 SPLASH: Max permission attempts reached, dismissing")
                    
                    withAnimation {
                        isShowingSplash = false
                    }
                }
            }
        }
        .onReceive(timer) { time in
            print("🎨 SPLASH: Timer pulse at \(time)")
            
            // Use this to ensure we're updating the UI
            DispatchQueue.main.async {
                // Force UI update on each timer pulse
                let _ = animationComplete
            }
        }
    }
}

// Animation for tab icons on splash screen
struct TabIconPreview: View {
    let iconName: String
    let label: String
    let delay: Double
    
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.2))
        )
        .scaleEffect(isVisible ? 1.0 : 0.5)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(Animation.spring().delay(delay)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    SplashScreen(isShowingSplash: .constant(true))
}
