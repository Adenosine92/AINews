# AI News Aggregator — iOS App

An iOS app that aggregates AI news from X (Twitter) and top AI news websites, delivering quick, formatted reports with full metadata.

## Features

- **Live News Feed** — Pulls from 13+ RSS sources simultaneously (TechCrunch AI, The Verge, VentureBeat, MIT Technology Review, Wired, OpenAI Blog, Anthropic, Google DeepMind, Meta AI, Microsoft AI, ArXiv AI/ML, and more)
- **Quick Reports** — Auto-categorized reports for Last Hour / Today / This Week with sections for Models & Research, Industry & Business, Policy & Safety, Products & Tools, and Open Source
- **X (Twitter) Integration** — Optional live AI tweet aggregation via Twitter API v2 Bearer Token
- **Article Detail View** — Full metadata: source, author, publish date, relative time, tags, direct link
- **Smart Search** — Full-text search across title, summary, source, and tags
- **Filter Tabs** — Quickly filter by All / Research / News / Company Blog / Bookmarks
- **Bookmarks** — Save articles with swipe gesture; persisted across sessions
- **Source Management** — Enable/disable individual sources; grouped by category
- **Export Reports** — Share Quick Reports as formatted text
- **15-minute cache** — Instant load from cache while refreshing in background

## Requirements

- **Xcode 15+**
- **iOS 16.0+** (iPhone & iPad)
- **Swift 5.9+**
- X/Twitter integration (optional): Bearer Token from [Twitter Developer Portal](https://developer.twitter.com/en/portal/dashboard)

## Getting Started

```bash
git clone https://github.com/Adenosine92/AINews.git
cd AINews
open AINewsAggregator.xcodeproj
```

In Xcode:
1. Select your development team in **Signing & Capabilities**
2. Choose a simulator or device
3. Press **Cmd+R** to build and run

## X (Twitter) Setup (Optional)

1. Go to [developer.twitter.com](https://developer.twitter.com/en/portal/dashboard)
2. Create a project and get a **Bearer Token** (free tier: 500K tweets/month)
3. Open the app → **Settings** → **X (Twitter) Integration** → paste your token

## News Sources

| Source | Category | Type |
|--------|----------|------|
| OpenAI Blog | Company | RSS |
| Anthropic | Company | RSS |
| Google DeepMind | Company | RSS |
| Meta AI | Company | RSS |
| Microsoft AI Blog | Company | RSS |
| TechCrunch AI | News | RSS |
| The Verge AI | News | RSS |
| VentureBeat AI | News | RSS |
| Wired AI | News | RSS |
| MIT Technology Review | News | RSS |
| AI News | News | RSS |
| ArXiv cs.AI | Research | RSS |
| ArXiv cs.LG | Research | RSS |
| X (Twitter) | Social | API v2 |

## Architecture

```
AINewsAggregator/
├── AINewsAggregatorApp.swift
├── Models/
│   ├── NewsArticle.swift       # Article model with metadata
│   ├── NewsSource.swift        # 13+ built-in sources
│   └── QuickReport.swift       # Report model + auto-categorizer
├── ViewModels/
│   └── NewsViewModel.swift     # State, filtering, bookmarks, cache
├── Services/
│   ├── RSSFeedParser.swift     # XML RSS/Atom parser
│   ├── NewsService.swift       # Concurrent multi-source fetcher
│   └── TwitterService.swift    # X API v2 integration
└── Views/
    ├── ContentView.swift        # 5-tab navigation
    ├── NewsListView.swift       # Feed + filters + search
    ├── ArticleDetailView.swift  # Full article + share + Safari
    ├── QuickReportView.swift    # Categorized daily report
    ├── BookmarksView.swift      # Saved articles
    ├── SourcesView.swift        # Source toggle management
    └── SettingsView.swift       # Settings + Twitter config
```

**Pattern**: MVVM + SwiftUI + async/await
**Networking**: URLSession + concurrent TaskGroup
**Persistence**: UserDefaults (bookmarks, sources, cache)
**Parsing**: Foundation XMLParser for RSS/Atom

## Quick Report Categories

Reports auto-categorize articles by keyword matching:

- **Models & Research** — model releases, papers, benchmarks, LLMs
- **Industry & Business** — funding, acquisitions, partnerships
- **Policy & Safety** — regulation, EU AI Act, ethics
- **Products & Tools** — launches, updates, APIs
- **Open Source** — GitHub, Hugging Face, community releases

## Privacy

No user data collected. All data stays on-device. No analytics.

## License

MIT
