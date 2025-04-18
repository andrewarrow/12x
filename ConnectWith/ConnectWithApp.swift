import SwiftUI
import os.log
import Foundation

// Can't have expressions at the top level, use a global variable instead
let _logStartup: () = {
    print("App starting...")
    NSLog("App starting... (NSLog)")
    os_log("App starting... (os_log)", log: OSLog.default, type: .default)
}()

@main
struct ConnectWithApp: App {
    @State private var isShowingSplash = true
    
    init() {
        print("ConnectWithApp initializing...")
        NSLog("ConnectWithApp initializing... (NSLog)")
        os_log("ConnectWithApp initializing... (os_log)", log: OSLog.default, type: .fault)
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isShowingSplash {
                    SplashScreen(isShowingSplash: $isShowingSplash)
                        .onAppear {
                            print("SplashScreen appeared")
                        }
                } else {
                    OnboardingView()
                        .onAppear {
                            print("OnboardingView appeared")
                        }
                }
            }
            .onAppear {
                print("Main window appeared")
            }
        }
    }
}
