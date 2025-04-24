import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Welcome to connectWith___")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                NavigationLink(destination: BluetoothDeviceListView()) {
                    MenuButton(title: "Connect", iconName: "person.2.fill", color: .blue)
                }
                
                NavigationLink(destination: CalendarView()) {
                    MenuButton(title: "Calendar", iconName: "calendar", color: .green)
                }
                
                MenuButton(title: "Settings", iconName: "gear", color: .purple)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Main Menu")
        }
    }
}

#Preview {
    MainMenuView()
        .environmentObject(BluetoothManager())
}