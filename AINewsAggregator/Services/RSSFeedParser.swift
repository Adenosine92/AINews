import Foundation

class RSSFeedParser: NSObject, XMLParserDelegate {

    private var articles: [NewsArticle] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var currentAuthor = ""
    private var currentImageURL = ""
    private var insideItem = false

    private var source: NewsSource
    private var completion: (([NewsArticle]) -> Void)?

    init(source: NewsSource) {
        self.source = source
    }

    func parse(data: Data, completion: @escaping ([NewsArticle]) -> Void) {
        self.completion = completion
        self.articles = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName

        if elementName == "item" || elementName == "entry" {
            insideItem = true
            currentTitle = ""
            currentDescription = ""
            currentLink = ""
            currentPubDate = ""
            currentAuthor = ""
            currentImageURL = ""
        }

        // Handle media:content and enclosure for images
        if insideItem {
            if elementName == "media:content" || elementName == "media:thumbnail" {
                currentImageURL = attributeDict["url"] ?? ""
            }
            if elementName == "enclosure" {
                let mimeType = attributeDict["type"] ?? ""
                if mimeType.hasPrefix("image/") {
                    currentImageURL = attributeDict["url"] ?? ""
                }
            }
            // Handle atom:link
            if elementName == "link" {
                if let href = attributeDict["href"], currentLink.isEmpty {
                    currentLink = href
                }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentElement {
        case "title":
            currentTitle += trimmed
        case "description", "summary", "content:encoded":
            currentDescription += trimmed
        case "link":
            if currentLink.isEmpty {
                currentLink += trimmed
            }
        case "pubDate", "published", "dc:date", "updated":
            if currentPubDate.isEmpty {
                currentPubDate = trimmed
            }
        case "author", "dc:creator", "name":
            currentAuthor += trimmed
        case "media:content":
            break
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            if insideItem {
                createArticle()
                insideItem = false
            }
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        completion?(articles)
    }

    // MARK: - Private

    private func createArticle() {
        guard !currentTitle.isEmpty, let url = parseURL(currentLink) else { return }

        let cleanTitle = stripHTML(currentTitle)
        let cleanSummary = stripHTML(currentDescription)
        let publishDate = parseDate(currentPubDate) ?? Date()
        let imageURL = currentImageURL.isEmpty ? nil : URL(string: currentImageURL)

        let article = NewsArticle(
            title: cleanTitle,
            summary: String(cleanSummary.prefix(400)),
            url: url,
            source: source.name,
            sourceIcon: source.iconName,
            publishedAt: publishDate,
            imageURL: imageURL,
            author: currentAuthor.isEmpty ? nil : currentAuthor
        )
        articles.append(article)
    }

    private func parseURL(_ string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: trimmed)
    }

    private func parseDate(_ string: String) -> Date? {
        let formatters: [DateFormatter] = {
            let rfc822 = DateFormatter()
            rfc822.locale = Locale(identifier: "en_US_POSIX")
            rfc822.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

            let rfc822Alt = DateFormatter()
            rfc822Alt.locale = Locale(identifier: "en_US_POSIX")
            rfc822Alt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

            let iso8601 = DateFormatter()
            iso8601.locale = Locale(identifier: "en_US_POSIX")
            iso8601.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

            let iso8601Alt = DateFormatter()
            iso8601Alt.locale = Locale(identifier: "en_US_POSIX")
            iso8601Alt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

            return [rfc822, rfc822Alt, iso8601, iso8601Alt]
        }()

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    private func stripHTML(_ html: String) -> String {
        // Remove CDATA wrappers
        var result = html
            .replacingOccurrences(of: "<![CDATA[", with: "")
            .replacingOccurrences(of: "]]>", with: "")

        // Remove HTML tags using regex-like approach
        var stripped = ""
        var inTag = false
        for char in result {
            if char == "<" { inTag = true }
            else if char == ">" { inTag = false }
            else if !inTag { stripped.append(char) }
        }

        // Decode common HTML entities
        result = stripped
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&apos;", with: "'")

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
