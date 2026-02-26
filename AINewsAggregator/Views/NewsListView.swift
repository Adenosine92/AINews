import SwiftUI

struct NewsListView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.articles.isEmpty {
                    LoadingView()
                } else if viewModel.filteredArticles.isEmpty && !viewModel.searchText.isEmpty {
                    EmptySearchView(query: viewModel.searchText)
                } else if viewModel.articles.isEmpty {
                    EmptyFeedView()
                } else {
                    articleList
                }
            }
            .navigationTitle("AI News")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    statsButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search AI news...")
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Subviews

    private var articleList: some View {
        List {
            filterBar
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if let lastRefreshed = viewModel.lastRefreshed {
                lastRefreshedRow(date: lastRefreshed)
            }

            ForEach(viewModel.filteredArticles) { article in
                NavigationLink(destination: ArticleDetailView(article: article)) {
                    ArticleRowView(article: article)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        viewModel.toggleBookmark(article)
                    } label: {
                        Label(
                            viewModel.isBookmarked(article) ? "Unsave" : "Save",
                            systemImage: viewModel.isBookmarked(article) ? "bookmark.slash.fill" : "bookmark.fill"
                        )
                    }
                    .tint(viewModel.isBookmarked(article) ? .gray : .orange)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NewsViewModel.ArticleFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        label: filter.rawValue,
                        icon: filter.iconName,
                        isSelected: viewModel.selectedFilter == filter
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func lastRefreshedRow(date: Date) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text("Updated \(date, style: .relative) ago")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(viewModel.filteredArticles.count) articles")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var statsButton: some View {
        let stats = viewModel.stats
        return Button {
            // could show stats sheet
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text("\(stats.activeSources) sources")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .disabled(true)
    }

    private var refreshButton: some View {
        Button {
            Task { await viewModel.refresh() }
        } label: {
            if viewModel.isRefreshing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(viewModel.isRefreshing)
    }
}

// MARK: - Article Row

struct ArticleRowView: View {
    let article: NewsArticle
    @EnvironmentObject var viewModel: NewsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: article.sourceIcon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(article.source)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                Text(article.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if viewModel.isBookmarked(article) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Text(article.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)
                .foregroundColor(.primary)

            Text(article.summary)
                .font(.system(size: 13))
                .lineLimit(2)
                .foregroundColor(.secondary)

            HStack {
                if let author = article.author {
                    Label(author, systemImage: "person.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(article.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty States

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Fetching AI news…")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Aggregating from multiple sources")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptySearchView: View {
    let query: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No results for \"\(query)\"")
                .font(.headline)
            Text("Try a different search term")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyFeedView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No articles yet")
                .font(.headline)
            Text("Pull to refresh or check your internet connection")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Refresh Now") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NewsListView()
        .environmentObject(NewsViewModel())
}
