import SwiftUI

@main
struct TripperPilotApp: App {
    @StateObject private var tripper = TripperBluetoothController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tripper)
        }
    }
}

