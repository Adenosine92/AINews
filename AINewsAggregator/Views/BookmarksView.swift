import SwiftUI

struct BookmarksView: View {
    @EnvironmentObject var viewModel: NewsViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.bookmarkedArticles.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(viewModel.bookmarkedArticles) { article in
                            NavigationLink(destination: ArticleDetailView(article: article)) {
                                ArticleRowView(article: article)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.toggleBookmark(article)
                                } label: {
                                    Label("Remove", systemImage: "bookmark.slash.fill")
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Saved Articles")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !viewModel.bookmarkedArticles.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            for article in viewModel.bookmarkedArticles {
                                viewModel.toggleBookmark(article)
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No saved articles")
                .font(.headline)
            Text("Swipe left on any article to save it for later")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    BookmarksView()
        .environmentObject(NewsViewModel())
}
