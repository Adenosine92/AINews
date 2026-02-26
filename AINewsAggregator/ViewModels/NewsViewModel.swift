import Foundation
import Combine
import SwiftUI

@MainActor
class NewsViewModel: ObservableObject {
    // MARK: - Published state
    @Published var articles: [NewsArticle] = []
    @Published var filteredArticles: [NewsArticle] = []
    @Published var sources: [NewsSource] = NewsSource.defaultSources
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var lastRefreshed: Date?
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedFilter: ArticleFilter = .all
    @Published var bookmarkedArticles: [NewsArticle] = []
    @Published var currentReport: QuickReport?
    @Published var reportPeriod: QuickReport.ReportPeriod = .today

    enum ArticleFilter: String, CaseIterable {
        case all = "All"
        case research = "Research"
        case news = "News"
        case company = "Company"
        case bookmarks = "Bookmarks"

        var iconName: String {
            switch self {
            case .all: return "list.bullet"
            case .research: return "flask.fill"
            case .news: return "newspaper.fill"
            case .company: return "building.2.fill"
            case .bookmarks: return "bookmark.fill"
            }
        }
    }

    private let newsService = NewsService.shared
    private let twitterService = TwitterService.shared
    private var cancellables = Set<AnyCancellable>()
    private let bookmarksKey = "bookmarked_articles"
    private let sourcesKey = "user_sources"

    init() {
        loadPersistedData()
        setupSearch()
    }

    // MARK: - Setup

    private func setupSearch() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .combineLatest($selectedFilter, $articles, $bookmarkedArticles)
            .map { searchText, filter, articles, bookmarks -> [NewsArticle] in
                self.applyFilters(
                    articles: articles,
                    bookmarks: bookmarks,
                    search: searchText,
                    filter: filter
                )
            }
            .assign(to: &$filteredArticles)
    }

    private func applyFilters(
        articles: [NewsArticle],
        bookmarks: [NewsArticle],
        search: String,
        filter: ArticleFilter
    ) -> [NewsArticle] {
        var result: [NewsArticle]

        switch filter {
        case .all:
            result = articles
        case .research:
            result = articles.filter { $0.source.lowercased().contains("arxiv") || $0.tags.contains("Research") }
        case .news:
            let newsSources = sources.filter { $0.category == .news }.map { $0.name }
            result = articles.filter { newsSources.contains($0.source) }
        case .company:
            let companySources = sources.filter { $0.category == .company }.map { $0.name }
            result = articles.filter { companySources.contains($0.source) }
        case .bookmarks:
            result = bookmarks
        }

        if !search.isEmpty {
            let query = search.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.summary.lowercased().contains(query) ||
                $0.source.lowercased().contains(query) ||
                $0.tags.joined(separator: " ").lowercased().contains(query)
            }
        }

        return result
    }

    // MARK: - Fetch

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil

        let enabledSources = sources.filter { $0.isEnabled && $0.category != .social }
        let fetched = await newsService.fetchAllNews(sources: enabledSources)

        // Merge bookmarks info
        let bookmarkedURLs = Set(bookmarkedArticles.map { $0.url.absoluteString })
        let merged = fetched.map { article -> NewsArticle in
            var a = article
            a.isBookmarked = bookmarkedURLs.contains(a.url.absoluteString)
            return a
        }

        articles = merged
        newsService.cacheArticles(merged)
        lastRefreshed = Date()
        isRefreshing = false

        // Fetch Twitter in parallel if configured
        if twitterService.isConfigured {
            await twitterService.fetchAINewsTweets()
            let twitterArticles = twitterService.tweets
            let combined = (merged + twitterArticles).sorted { $0.publishedAt > $1.publishedAt }
            articles = combined
        }

        // Auto-generate report
        generateReport()
    }

    func loadInitialData() async {
        isLoading = true

        // Try cache first for instant display
        if let cached = newsService.cachedArticles(), !cached.isEmpty {
            articles = cached
            isLoading = false
            generateReport()
        }

        // Then refresh in background
        await refresh()
        isLoading = false
    }

    // MARK: - Report

    func generateReport() {
        guard !articles.isEmpty else { return }
        currentReport = ReportGenerator.generate(from: articles, period: reportPeriod)
    }

    func regenerateReport(period: QuickReport.ReportPeriod) {
        reportPeriod = period
        generateReport()
    }

    // MARK: - Bookmarks

    func toggleBookmark(_ article: NewsArticle) {
        if let idx = articles.firstIndex(where: { $0.id == article.id }) {
            articles[idx].isBookmarked.toggle()
            if articles[idx].isBookmarked {
                bookmarkedArticles.append(articles[idx])
            } else {
                bookmarkedArticles.removeAll { $0.id == article.id }
            }
        } else {
            // Article might be from bookmarks list
            if let idx = bookmarkedArticles.firstIndex(where: { $0.id == article.id }) {
                bookmarkedArticles.remove(at: idx)
            }
        }
        saveBookmarks()
    }

    func isBookmarked(_ article: NewsArticle) -> Bool {
        bookmarkedArticles.contains { $0.id == article.id }
    }

    // MARK: - Sources Management

    func toggleSource(_ source: NewsSource) {
        if let idx = sources.firstIndex(where: { $0.id == source.id }) {
            sources[idx].isEnabled.toggle()
            saveSources()
        }
    }

    // MARK: - Persistence

    private func loadPersistedData() {
        if let data = UserDefaults.standard.data(forKey: bookmarksKey),
           let saved = try? JSONDecoder().decode([NewsArticle].self, from: data) {
            bookmarkedArticles = saved
        }
        if let data = UserDefaults.standard.data(forKey: sourcesKey),
           let saved = try? JSONDecoder().decode([NewsSource].self, from: data) {
            sources = saved
        }
    }

    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarkedArticles) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }

    private func saveSources() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: sourcesKey)
        }
    }

    // MARK: - Stats

    var stats: NewsStats {
        NewsStats(
            totalArticles: articles.count,
            activeSources: sources.filter { $0.isEnabled }.count,
            lastUpdated: lastRefreshed,
            bookmarkCount: bookmarkedArticles.count
        )
    }
}

struct NewsStats {
    let totalArticles: Int
    let activeSources: Int
    let lastUpdated: Date?
    let bookmarkCount: Int

    var lastUpdatedString: String {
        guard let date = lastUpdated else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
