import SwiftUI

@main
struct AINewsAggregatorApp: App {
    @StateObject private var viewModel = NewsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .task {
                    await viewModel.loadInitialData()
                }
        }
    }
}
