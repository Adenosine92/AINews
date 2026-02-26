import Foundation

struct NewsArticle: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var summary: String
    var url: URL
    var source: String
    var sourceIcon: String
    var publishedAt: Date
    var imageURL: URL?
    var author: String?
    var tags: [String]
    var isBookmarked: Bool

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        url: URL,
        source: String,
        sourceIcon: String,
        publishedAt: Date,
        imageURL: URL? = nil,
        author: String? = nil,
        tags: [String] = [],
        isBookmarked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.url = url
        self.source = source
        self.sourceIcon = sourceIcon
        self.publishedAt = publishedAt
        self.imageURL = imageURL
        self.author = author
        self.tags = tags
        self.isBookmarked = isBookmarked
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: publishedAt)
    }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: publishedAt, relativeTo: Date())
    }

    var timeAgo: String {
        let seconds = Date().timeIntervalSince(publishedAt)
        if seconds < 3600 {
            let mins = Int(seconds / 60)
            return mins <= 1 ? "Just now" : "\(mins)m ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(seconds / 86400)
            return "\(days)d ago"
        }
    }
}

extension NewsArticle {
    static var placeholder: NewsArticle {
        NewsArticle(
            title: "Loading AI news...",
            summary: "Fetching latest artificial intelligence news from multiple sources.",
            url: URL(string: "https://example.com")!,
            source: "Loading",
            sourceIcon: "newspaper",
            publishedAt: Date()
        )
    }

    static var sampleArticles: [NewsArticle] = [
        NewsArticle(
            title: "GPT-5 Sets New Benchmark Records Across All Categories",
            summary: "OpenAI's latest language model achieves unprecedented performance on MMLU, HumanEval, and reasoning benchmarks, surpassing previous state-of-the-art by significant margins.",
            url: URL(string: "https://openai.com")!,
            source: "OpenAI Blog",
            sourceIcon: "brain.head.profile",
            publishedAt: Date().addingTimeInterval(-3600),
            tags: ["OpenAI", "LLM", "Benchmark"],
            isBookmarked: false
        ),
        NewsArticle(
            title: "Anthropic Releases Claude 4 with Enhanced Reasoning",
            summary: "Anthropic unveils Claude 4, featuring improved multi-step reasoning, longer context windows, and better instruction-following capabilities for enterprise applications.",
            url: URL(string: "https://anthropic.com")!,
            source: "Anthropic",
            sourceIcon: "cpu",
            publishedAt: Date().addingTimeInterval(-7200),
            tags: ["Anthropic", "Claude", "Safety"],
            isBookmarked: true
        ),
        NewsArticle(
            title: "EU AI Act: Full Implementation Guidelines Released",
            summary: "The European Union publishes comprehensive implementation guidelines for the AI Act, detailing compliance requirements for high-risk AI systems across sectors.",
            url: URL(string: "https://techcrunch.com")!,
            source: "TechCrunch",
            sourceIcon: "globe",
            publishedAt: Date().addingTimeInterval(-14400),
            tags: ["Regulation", "EU", "Policy"],
            isBookmarked: false
        )
    ]
}
