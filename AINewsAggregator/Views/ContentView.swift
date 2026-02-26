import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NewsListView()
                .tabItem {
                    Label("Feed", systemImage: "newspaper.fill")
                }
                .tag(0)

            QuickReportView()
                .tabItem {
                    Label("Report", systemImage: "doc.text.fill")
                }
                .tag(1)

            BookmarksView()
                .tabItem {
                    Label("Saved", systemImage: "bookmark.fill")
                }
                .badge(viewModel.bookmarkedArticles.count)
                .tag(2)

            SourcesView()
                .tabItem {
                    Label("Sources", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}

#Preview {
    ContentView()
        .environmentObject(NewsViewModel())
}
