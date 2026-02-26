import Foundation

struct QuickReport: Identifiable, Codable {
    let id: UUID
    var title: String
    var generatedAt: Date
    var period: ReportPeriod
    var sections: [ReportSection]
    var totalArticles: Int
    var topSources: [String]

    enum ReportPeriod: String, Codable, CaseIterable {
        case lastHour = "Last Hour"
        case today = "Today"
        case thisWeek = "This Week"
        case custom = "Custom"
    }

    struct ReportSection: Identifiable, Codable {
        let id: UUID
        var category: String
        var headline: String
        var summary: String
        var articles: [NewsArticle]
        var emoji: String

        init(
            id: UUID = UUID(),
            category: String,
            headline: String,
            summary: String,
            articles: [NewsArticle],
            emoji: String
        ) {
            self.id = id
            self.category = category
            self.headline = headline
            self.summary = summary
            self.articles = articles
            self.emoji = emoji
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        generatedAt: Date = Date(),
        period: ReportPeriod,
        sections: [ReportSection],
        totalArticles: Int,
        topSources: [String]
    ) {
        self.id = id
        self.title = title
        self.generatedAt = generatedAt
        self.period = period
        self.sections = sections
        self.totalArticles = totalArticles
        self.topSources = topSources
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: generatedAt)
    }
}

// Report generator
struct ReportGenerator {
    static func generate(from articles: [NewsArticle], period: QuickReport.ReportPeriod) -> QuickReport {
        let filteredArticles = filterArticles(articles, for: period)
        let categorized = categorizeArticles(filteredArticles)
        let sections = buildSections(from: categorized)
        let topSources = topSourceNames(from: filteredArticles)

        return QuickReport(
            title: "\(period.rawValue) AI News Report",
            period: period,
            sections: sections,
            totalArticles: filteredArticles.count,
            topSources: topSources
        )
    }

    private static func filterArticles(_ articles: [NewsArticle], for period: QuickReport.ReportPeriod) -> [NewsArticle] {
        let now = Date()
        let cutoff: Date
        switch period {
        case .lastHour:
            cutoff = now.addingTimeInterval(-3600)
        case .today:
            cutoff = Calendar.current.startOfDay(for: now)
        case .thisWeek:
            cutoff = now.addingTimeInterval(-7 * 86400)
        case .custom:
            cutoff = now.addingTimeInterval(-86400)
        }
        return articles.filter { $0.publishedAt >= cutoff }
    }

    private static func categorizeArticles(_ articles: [NewsArticle]) -> [String: [NewsArticle]] {
        var categories: [String: [NewsArticle]] = [
            "Models & Research": [],
            "Industry & Business": [],
            "Policy & Safety": [],
            "Products & Tools": [],
            "Open Source": []
        ]

        let modelKeywords = ["gpt", "llm", "model", "claude", "gemini", "llama", "benchmark", "paper", "research", "arxiv", "training", "fine-tun"]
        let industryKeywords = ["funding", "acquisition", "billion", "startup", "investment", "revenue", "partnership", "deal", "valuation"]
        let policyKeywords = ["regulation", "policy", "law", "eu", "act", "safety", "risk", "ethics", "bias", "governance", "ban"]
        let productKeywords = ["launch", "release", "update", "feature", "app", "tool", "platform", "product", "api", "sdk"]
        let openSourceKeywords = ["open source", "github", "hugging face", "mistral", "ollama", "community", "weights"]

        for article in articles {
            let text = (article.title + " " + article.summary).lowercased()

            if openSourceKeywords.contains(where: { text.contains($0) }) {
                categories["Open Source"]?.append(article)
            } else if policyKeywords.contains(where: { text.contains($0) }) {
                categories["Policy & Safety"]?.append(article)
            } else if industryKeywords.contains(where: { text.contains($0) }) {
                categories["Industry & Business"]?.append(article)
            } else if modelKeywords.contains(where: { text.contains($0) }) {
                categories["Models & Research"]?.append(article)
            } else if productKeywords.contains(where: { text.contains($0) }) {
                categories["Products & Tools"]?.append(article)
            } else {
                categories["Products & Tools"]?.append(article)
            }
        }

        return categories
    }

    private static func buildSections(from categorized: [String: [NewsArticle]]) -> [QuickReport.ReportSection] {
        let emojiMap: [String: String] = [
            "Models & Research": "🧠",
            "Industry & Business": "💼",
            "Policy & Safety": "⚖️",
            "Products & Tools": "🛠️",
            "Open Source": "🔓"
        ]

        return categorized
            .filter { !$0.value.isEmpty }
            .sorted { $0.value.count > $1.value.count }
            .map { category, articles in
                let topArticles = Array(articles.prefix(5))
                let headline = topArticles.first?.title ?? "No headlines"
                let summary = buildSummary(from: topArticles, category: category)
                return QuickReport.ReportSection(
                    category: category,
                    headline: headline,
                    summary: summary,
                    articles: topArticles,
                    emoji: emojiMap[category] ?? "📰"
                )
            }
    }

    private static func buildSummary(from articles: [NewsArticle], category: String) -> String {
        guard !articles.isEmpty else { return "No news in this category." }
        let count = articles.count
        let sources = Set(articles.map { $0.source }).prefix(3).joined(separator: ", ")
        let topTitle = articles.first?.title ?? ""
        return "\(count) article\(count == 1 ? "" : "s") from \(sources). Top story: \(topTitle)"
    }

    private static func topSourceNames(from articles: [NewsArticle]) -> [String] {
        let sourceCounts = Dictionary(grouping: articles, by: { $0.source })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        return Array(sourceCounts.prefix(5).map { $0.key })
    }
}
