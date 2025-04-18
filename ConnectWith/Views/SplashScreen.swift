import SwiftUI
import Foundation

struct SplashScreen: View {
    @Binding var isShowingSplash: Bool
    let startupTime = Date()
    
    var body: some View {
        ZStack {
            Color.blue.opacity(0.7)
                .ignoresSafeArea()
            
            VStack {
                Text("connectWith___")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                    .padding()
                
                Image(systemName: "link.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.white)
                    .padding()
                
                // Display startup confirmation
                Text("App Started at: \(formattedTime(startupTime))")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .onAppear {
            print("SPLASH SCREEN APPEARED at \(formattedTime(Date()))")
            
            // Auto-dismiss splash screen after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isShowingSplash = false
                }
            }
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

#Preview {
    SplashScreen(isShowingSplash: .constant(true))
}
