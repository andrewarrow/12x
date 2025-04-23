import SwiftUI

struct SplashScreen: View {
    @Binding var isShowingSplash: Bool
    
    var body: some View {
        ZStack {
            Color.blue.opacity(0.7)
                .ignoresSafeArea()
            
            VStack {
                Text("12x")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                    .padding()
                
                ZStack {
                    Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.white)
                    
                    Image(systemName: "calendar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.white.opacity(0.8))
                        .offset(x: 25, y: 25)
                }
                .padding()
                
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
            }
        }
        .onAppear {
            // Auto-dismiss splash screen after 2.5 seconds (slightly longer to show the tab animation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    isShowingSplash = false
                }
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