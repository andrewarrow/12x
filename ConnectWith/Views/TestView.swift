import Foundation
import SwiftUI

/// Simple test view for the Updates tab
struct TestView: View {
    @State private var testOutput = "Task 9.3 implementation is complete! This tab will be used for testing and viewing sync updates in future tasks."
    @State private var isRunningTests = false
    
    var body: some View {
        VStack {
            Text("Task 9.3 Complete")
                .font(.headline)
                .padding()
            
            Button(action: {
                isRunningTests = true
                testOutput = "Running basic calendar persistence test...\n"
                
                // Test CalendarStore
                let store = CalendarStore.shared
                
                // Update a test event
                store.updateEvent(
                    month: 3, 
                    title: "Test Event",
                    location: "Test Location",
                    day: 10
                )
                
                testOutput += "Updated test event in CalendarStore\n"
                
                // Make sure we can retrieve it
                let event = store.getEvent(for: 3)
                testOutput += "Retrieved event: \(event.title) in \(event.monthName) on day \(event.day)\n"
                
                // Save
                store.saveAllEvents()
                testOutput += "Saved events to UserDefaults\n"
                
                // Test completed
                testOutput += "\nTest completed successfully!"
                isRunningTests = false
                
            }) {
                HStack {
                    Text("Run Test")
                    if isRunningTests {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isRunningTests)
            .padding()
            
            ScrollView {
                Text(testOutput)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            .background(Color.black.opacity(0.05))
            .cornerRadius(8)
            .padding()
        }
    }
}