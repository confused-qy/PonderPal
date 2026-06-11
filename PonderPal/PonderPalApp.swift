import SwiftUI

@main
struct PonderPalApp: App {
    @StateObject private var appState = AppState() // Properly initialize AppState

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState) // Pass appState properly
                .preferredColorScheme(.none) // Use system color scheme
        }
    }
}

// Preview setup, check visibility: make it compatible as required
#Preview {
    RootView()
        .environmentObject(AppState())
}
