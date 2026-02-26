import SwiftUI

struct ArticleDetailView: View {
    let article: NewsArticle
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var showShareSheet = false
    @State private var showSafari = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header banner
                headerBanner

                // Content
                VStack(alignment: .leading, spacing: 16) {
                    // Meta row
                    metaRow

                    // Title
                    Text(article.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Summary", systemImage: "text.alignleft")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Text(article.summary)
                            .font(.body)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Details card
                    detailsCard

                    // Tags
                    if !article.tags.isEmpty {
                        tagsRow
                    }

                    // Action buttons
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        viewModel.toggleBookmark(article)
                    } label: {
                        Image(systemName: viewModel.isBookmarked(article) ? "bookmark.fill" : "bookmark")
                            .foregroundColor(.orange)
                    }
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [article.url, article.title])
        }
        .sheet(isPresented: $showSafari) {
            SafariView(url: article.url)
        }
    }

    // MARK: - Subviews

    private var headerBanner: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 120)

            HStack(spacing: 10) {
                Image(systemName: article.sourceIcon)
                    .font(.title2)
                    .foregroundColor(.white)
                Text(article.source)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .padding(16)
        }
    }

    private var metaRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Published", systemImage: "calendar")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(article.formattedDate)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            Divider().frame(height: 30)

            if let author = article.author {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Author", systemImage: "person")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(author)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Time badge
            Text(article.timeAgo)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Article Details")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 0) {
                detailItem(icon: "link", label: "Source", value: article.source)
                Spacer()
                detailItem(icon: "clock", label: "Published", value: article.relativeDate)
            }

            Divider()

            HStack {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(article.url.host ?? article.url.absoluteString)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func detailItem(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private var tagsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(article.tags, id: \.self) { tag in
                    TagBadge(text: tag)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                showSafari = true
            } label: {
                Label("Read Full Article", systemImage: "safari.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .fontWeight(.semibold)
            }

            Button {
                showShareSheet = true
            } label: {
                Label("Share Article", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Supporting Views

struct TagBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .clipShape(Capsule())
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > width && rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ArticleDetailView(article: NewsArticle.sampleArticles[0])
            .environmentObject(NewsViewModel())
    }
}
