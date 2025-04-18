import SwiftUI
import Foundation

struct OnboardingView: View {
    @State private var progressValue: Double = 0.0
    @State private var emojiIndex = 0
    @State private var debugText = "Initializing..."
    
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
                
                // Debug text - shows log status
                Text(debugText)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Setup")
            .onAppear {
                print("ONBOARDING VIEW APPEARED")
                debugText = "View appeared at \(formattedTime(Date()))"
                
                startProgressAnimation()
                startEmojiAnimation()
                startDebugUpdates()
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
                    print("Progress reset at \(formattedTime(Date()))")
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
    
    func startDebugUpdates() {
        // Update debug text periodically to show app is running
        var count = 0
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            count += 1
            let runTime = Int(timer.timeInterval * Double(count))
            debugText = "Running for \(runTime)s (at \(formattedTime(Date())))"
            print("App running for \(runTime) seconds")
        }
    }
}

#Preview {
    OnboardingView()
}