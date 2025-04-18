import SwiftUI
import os.log
import Foundation
import UIKit

// MARK: - Simple Logging Tests in App File
print("TEST LOG A: Direct print in ConnectWithApp.swift")
NSLog("TEST LOG B: Direct NSLog in ConnectWithApp.swift")

@main
struct ConnectWithApp: App {
    @State private var isShowingSplash = true
    
    init() {
        print("TEST LOG C: Init print in ConnectWithApp")
        NSLog("TEST LOG D: Init NSLog in ConnectWithApp")
        
        // Create a system alert (this should definitely be visible)
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let alert = UIAlertController(
                title: "Logging Test", 
                message: "App is initializing. Check console for logs.", 
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            // In iOS 15+, we need to get the root controller differently
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            TestLogView()
        }
    }
}

// Simple view just for testing logging
struct TestLogView: View {
    @State private var logCount = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Logging Test View")
                .font(.largeTitle)
            
            Text("Log Count: \(logCount)")
                .font(.title)
            
            Button("Generate Log") {
                logCount += 1
                print("TEST LOG BUTTON: Button pressed \(logCount) times")
                NSLog("TEST LOG BUTTON: NSLog from button press \(logCount)")
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .onAppear {
            print("TEST LOG VIEW: onAppear called")
            NSLog("TEST LOG VIEW: NSLog from onAppear")
        }
    }
}
