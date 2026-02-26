import Foundation
import Combine

class NewsService: ObservableObject {
    static let shared = NewsService()

    @Published var isLoading = false
    @Published var error: NewsError?

    enum NewsError: LocalizedError {
        case networkError(String)
        case parseError(String)
        case noData

        var errorDescription: String? {
            switch self {
            case .networkError(let msg): return "Network Error: \(msg)"
            case .parseError(let msg): return "Parse Error: \(msg)"
            case .noData: return "No data received"
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = [
            "User-Agent": "AINewsAggregator/1.0 (iOS; RSS Reader)"
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Fetch all sources

    func fetchAllNews(sources: [NewsSource]) async -> [NewsArticle] {
        let enabledSources = sources.filter { $0.isEnabled && $0.category != .social }

        await MainActor.run { self.isLoading = true }

        var allArticles: [NewsArticle] = []

        await withTaskGroup(of: [NewsArticle].self) { group in
            for source in enabledSources {
                group.addTask {
                    await self.fetchFeed(source: source)
                }
            }
            for await articles in group {
                allArticles.append(contentsOf: articles)
            }
        }

        // Sort by date, newest first
        allArticles.sort { $0.publishedAt > $1.publishedAt }

        // Deduplicate by URL
        var seen = Set<String>()
        let deduplicated = allArticles.filter { article in
            let key = article.url.absoluteString
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        await MainActor.run { self.isLoading = false }
        return deduplicated
    }

    // MARK: - Fetch single RSS feed

    func fetchFeed(source: NewsSource) async -> [NewsArticle] {
        guard let url = URL(string: source.feedURL) else { return [] }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return []
            }

            return await parseFeed(data: data, source: source)
        } catch {
            print("[\(source.name)] Fetch error: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Parse

    private func parseFeed(data: Data, source: NewsSource) async -> [NewsArticle] {
        return await withCheckedContinuation { continuation in
            let parser = RSSFeedParser(source: source)
            parser.parse(data: data) { articles in
                continuation.resume(returning: articles)
            }
        }
    }

    // MARK: - Cache

    private let cacheKey = "cached_articles"
    private let cacheExpiryKey = "cache_expiry"
    private let cacheDuration: TimeInterval = 900 // 15 minutes

    func cachedArticles() -> [NewsArticle]? {
        guard let expiry = UserDefaults.standard.object(forKey: cacheExpiryKey) as? Date,
              expiry > Date(),
              let data = UserDefaults.standard.data(forKey: cacheKey),
              let articles = try? JSONDecoder().decode([NewsArticle].self, from: data) else {
            return nil
        }
        return articles
    }

    func cacheArticles(_ articles: [NewsArticle]) {
        guard let data = try? JSONEncoder().encode(articles) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date().addingTimeInterval(cacheDuration), forKey: cacheExpiryKey)
    }
}
