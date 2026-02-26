import Foundation

struct NewsSource: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var feedURL: String
    var websiteURL: String
    var iconName: String
    var category: SourceCategory
    var isEnabled: Bool
    var color: String

    enum SourceCategory: String, Codable, CaseIterable {
        case research = "Research"
        case news = "News"
        case company = "Company Blog"
        case social = "Social"
        case podcast = "Podcast"

        var iconName: String {
            switch self {
            case .research: return "flask.fill"
            case .news: return "newspaper.fill"
            case .company: return "building.2.fill"
            case .social: return "person.2.fill"
            case .podcast: return "mic.fill"
            }
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        feedURL: String,
        websiteURL: String,
        iconName: String,
        category: SourceCategory,
        isEnabled: Bool = true,
        color: String
    ) {
        self.id = id
        self.name = name
        self.feedURL = feedURL
        self.websiteURL = websiteURL
        self.iconName = iconName
        self.category = category
        self.isEnabled = isEnabled
        self.color = color
    }
}

extension NewsSource {
    static let defaultSources: [NewsSource] = [
        // Company Blogs
        NewsSource(
            name: "OpenAI Blog",
            feedURL: "https://openai.com/blog/rss.xml",
            websiteURL: "https://openai.com/blog",
            iconName: "brain.head.profile",
            category: .company,
            color: "10A37F"
        ),
        NewsSource(
            name: "Anthropic",
            feedURL: "https://www.anthropic.com/rss.xml",
            websiteURL: "https://www.anthropic.com/news",
            iconName: "cpu",
            category: .company,
            color: "D4A843"
        ),
        NewsSource(
            name: "Google DeepMind",
            feedURL: "https://deepmind.google/blog/rss.xml",
            websiteURL: "https://deepmind.google/discover/blog",
            iconName: "g.circle.fill",
            category: .company,
            color: "4285F4"
        ),
        NewsSource(
            name: "Meta AI",
            feedURL: "https://ai.meta.com/blog/feed",
            websiteURL: "https://ai.meta.com/blog",
            iconName: "m.circle.fill",
            category: .company,
            color: "0082FB"
        ),
        NewsSource(
            name: "Microsoft AI",
            feedURL: "https://blogs.microsoft.com/ai/feed/",
            websiteURL: "https://blogs.microsoft.com/ai",
            iconName: "pc",
            category: .company,
            color: "00A4EF"
        ),
        // News Sites
        NewsSource(
            name: "TechCrunch AI",
            feedURL: "https://techcrunch.com/category/artificial-intelligence/feed/",
            websiteURL: "https://techcrunch.com/category/artificial-intelligence",
            iconName: "bolt.fill",
            category: .news,
            color: "0A8A00"
        ),
        NewsSource(
            name: "The Verge AI",
            feedURL: "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml",
            websiteURL: "https://www.theverge.com/ai-artificial-intelligence",
            iconName: "v.circle.fill",
            category: .news,
            color: "FA4522"
        ),
        NewsSource(
            name: "VentureBeat AI",
            feedURL: "https://venturebeat.com/category/ai/feed/",
            websiteURL: "https://venturebeat.com/category/ai",
            iconName: "chart.line.uptrend.xyaxis",
            category: .news,
            color: "8B5CF6"
        ),
        NewsSource(
            name: "Wired AI",
            feedURL: "https://www.wired.com/feed/tag/ai/latest/rss",
            websiteURL: "https://www.wired.com/tag/artificial-intelligence",
            iconName: "antenna.radiowaves.left.and.right",
            category: .news,
            color: "1A1A1A"
        ),
        NewsSource(
            name: "MIT Technology Review",
            feedURL: "https://www.technologyreview.com/feed/",
            websiteURL: "https://www.technologyreview.com",
            iconName: "graduationcap.fill",
            category: .news,
            color: "A31F34"
        ),
        NewsSource(
            name: "AI News",
            feedURL: "https://www.artificialintelligence-news.com/feed/",
            websiteURL: "https://www.artificialintelligence-news.com",
            iconName: "newspaper.fill",
            category: .news,
            color: "2563EB"
        ),
        // Research
        NewsSource(
            name: "ArXiv AI",
            feedURL: "https://export.arxiv.org/rss/cs.AI",
            websiteURL: "https://arxiv.org/list/cs.AI/recent",
            iconName: "doc.text.fill",
            category: .research,
            color: "B31B1B"
        ),
        NewsSource(
            name: "ArXiv ML",
            feedURL: "https://export.arxiv.org/rss/cs.LG",
            websiteURL: "https://arxiv.org/list/cs.LG/recent",
            iconName: "function",
            category: .research,
            color: "B31B1B"
        ),
        // Social/X
        NewsSource(
            name: "X (Twitter) AI",
            feedURL: "x://api/v2/tweets/search",
            websiteURL: "https://twitter.com",
            iconName: "bird.fill",
            category: .social,
            color: "000000"
        )
    ]
}
