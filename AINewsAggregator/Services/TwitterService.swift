import Foundation
import Combine

/// X (Twitter) API v2 integration for AI news tweets.
/// Requires a Bearer Token from the Twitter Developer Portal.
/// https://developer.twitter.com/en/docs/twitter-api
class TwitterService: ObservableObject {
    static let shared = TwitterService()

    @Published var tweets: [NewsArticle] = []
    @Published var isLoading = false
    @Published var error: TwitterError?
    @Published var isConfigured: Bool = false

    enum TwitterError: LocalizedError {
        case missingBearerToken
        case rateLimited
        case unauthorized
        case networkError(String)
        case parseError

        var errorDescription: String? {
            switch self {
            case .missingBearerToken:
                return "Twitter Bearer Token not configured. Add your token in Settings."
            case .rateLimited:
                return "Twitter API rate limit reached. Please wait before refreshing."
            case .unauthorized:
                return "Invalid Bearer Token. Please check your credentials in Settings."
            case .networkError(let msg):
                return "Network error: \(msg)"
            case .parseError:
                return "Failed to parse Twitter response."
            }
        }
    }

    // MARK: - Configuration

    private let bearerTokenKey = "twitter_bearer_token"

    var bearerToken: String? {
        get { UserDefaults.standard.string(forKey: bearerTokenKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: bearerTokenKey)
            isConfigured = newValue != nil && !(newValue?.isEmpty ?? true)
        }
    }

    init() {
        isConfigured = !(bearerToken?.isEmpty ?? true)
    }

    // MARK: - AI News Queries

    // Curated search query for high-quality AI news tweets
    private let aiNewsQuery = """
    (artificial intelligence OR "machine learning" OR "large language model" \
    OR ChatGPT OR GPT-4 OR Claude OR Gemini OR "AI safety" OR "generative AI" \
    OR "open source AI" OR LLM OR "AI regulation") \
    lang:en -is:retweet -is:reply has:links
    """

    // Key AI accounts to follow for breaking news
    private let aiAccountHandles = [
        "OpenAI", "AnthropicAI", "GoogleDeepMind", "MetaAI",
        "MistralAI", "sama", "ylecun", "karpathy", "drfeifei",
        "emollick", "benedictevans", "fchollet"
    ]

    // MARK: - Fetch Tweets

    func fetchAINewsTweets() async {
        guard let token = bearerToken, !token.isEmpty else {
            await MainActor.run {
                self.error = .missingBearerToken
            }
            return
        }

        await MainActor.run { self.isLoading = true }

        do {
            let articles = try await searchRecentTweets(query: aiNewsQuery, token: token)
            await MainActor.run {
                self.tweets = articles
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                if let twitterError = error as? TwitterError {
                    self.error = twitterError
                } else {
                    self.error = .networkError(error.localizedDescription)
                }
                self.isLoading = false
            }
        }
    }

    // MARK: - API Calls

    private func searchRecentTweets(query: String, token: String) async throws -> [NewsArticle] {
        var components = URLComponents(string: "https://api.twitter.com/2/tweets/search/recent")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "max_results", value: "50"),
            URLQueryItem(name: "tweet.fields", value: "created_at,author_id,entities,public_metrics,context_annotations"),
            URLQueryItem(name: "expansions", value: "author_id"),
            URLQueryItem(name: "user.fields", value: "name,username,profile_image_url,verified")
        ]

        guard let url = components.url else { throw TwitterError.parseError }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TwitterError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            return try parseTweetResponse(data: data)
        case 401:
            throw TwitterError.unauthorized
        case 429:
            throw TwitterError.rateLimited
        default:
            throw TwitterError.networkError("HTTP \(httpResponse.statusCode)")
        }
    }

    // MARK: - Parsing

    private func parseTweetResponse(data: Data) throws -> [NewsArticle] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tweetsData = json["data"] as? [[String: Any]] else {
            throw TwitterError.parseError
        }

        // Build user lookup map
        var userMap: [String: (name: String, username: String)] = [:]
        if let includes = json["includes"] as? [String: Any],
           let users = includes["users"] as? [[String: Any]] {
            for user in users {
                if let id = user["id"] as? String,
                   let name = user["name"] as? String,
                   let username = user["username"] as? String {
                    userMap[id] = (name: name, username: username)
                }
            }
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return tweetsData.compactMap { tweet -> NewsArticle? in
            guard let id = tweet["id"] as? String,
                  let text = tweet["text"] as? String else { return nil }

            let authorId = tweet["author_id"] as? String ?? ""
            let user = userMap[authorId]
            let authorName = user.map { "@\($0.username) (\($0.name))" } ?? "@unknown"
            let username = user?.username ?? "twitter"

            let createdAt: Date
            if let dateStr = tweet["created_at"] as? String,
               let date = isoFormatter.date(from: dateStr) {
                createdAt = date
            } else {
                createdAt = Date()
            }

            // Extract URL from entities
            var articleURL = URL(string: "https://twitter.com/\(username)/status/\(id)")!
            if let entities = tweet["entities"] as? [String: Any],
               let urls = entities["urls"] as? [[String: Any]],
               let firstURL = urls.first(where: { ($0["expanded_url"] as? String)?.contains("twitter.com") == false }),
               let urlStr = firstURL["expanded_url"] as? String,
               let url = URL(string: urlStr) {
                articleURL = url
            }

            // Extract metrics
            var summary = text
            if let metrics = tweet["public_metrics"] as? [String: Any] {
                let likes = metrics["like_count"] as? Int ?? 0
                let retweets = metrics["retweet_count"] as? Int ?? 0
                summary += "\n\n❤️ \(likes) likes · 🔁 \(retweets) retweets"
            }

            return NewsArticle(
                title: String(text.prefix(120)),
                summary: summary,
                url: articleURL,
                source: "X (Twitter)",
                sourceIcon: "bird.fill",
                publishedAt: createdAt,
                author: authorName,
                tags: ["Twitter", "Social"]
            )
        }
    }
}
