import SwiftUI

@main
struct ConnectWithApp: App {
    @State private var isShowingSplash = true
    
    init() {
        print("ConnectWithApp initializing...")
    }
    
    var body: some Scene {
        WindowGroup {
            if isShowingSplash {
                SplashScreen(isShowingSplash: $isShowingSplash)
            } else {
                OnboardingView()
            }
        }
    }
}
