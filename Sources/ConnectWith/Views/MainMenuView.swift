import SwiftUI

struct OnboardingView: View {
    @State private var progressValue: Double = 0.0
    @State private var emojiIndex = 0
    
    let emojis = ["📱", "🔄", "✨", "🚀", "🔍", "📡"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
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
                    Text("Now have your family member also install this app and launch it on their phone.")
                        .font(.body)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Setup")
            .onAppear {
                startProgressAnimation()
                startEmojiAnimation()
            }
        }
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