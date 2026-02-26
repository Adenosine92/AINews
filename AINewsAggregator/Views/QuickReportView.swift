import SwiftUI

struct QuickReportView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var selectedPeriod: QuickReport.ReportPeriod = .today
    @State private var showingExport = false
    @State private var exportText = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.articles.isEmpty {
                    LoadingView()
                } else if let report = viewModel.currentReport {
                    reportContent(report)
                } else {
                    generatePrompt
                }
            }
            .navigationTitle("Quick Report")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.currentReport != nil {
                        Button {
                            exportReport()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingExport) {
                ShareSheet(items: [exportText])
            }
        }
    }

    // MARK: - Report Content

    private func reportContent(_ report: QuickReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                reportHeader(report)

                // Period picker
                periodPicker

                // Stats strip
                statsStrip(report)

                // Top sources
                if !report.topSources.isEmpty {
                    topSourcesSection(report)
                }

                // Sections
                ForEach(report.sections) { section in
                    reportSection(section)
                }

                // Footer
                reportFooter(report)
            }
            .padding(16)
        }
    }

    private func reportHeader(_ report: QuickReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.title)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(report.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
        }
    }

    private var periodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REPORT PERIOD")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Picker("Period", selection: $selectedPeriod) {
                ForEach(QuickReport.ReportPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedPeriod) { _, newValue in
                viewModel.regenerateReport(period: newValue)
            }
        }
    }

    private func statsStrip(_ report: QuickReport) -> some View {
        HStack(spacing: 0) {
            statItem(value: "\(report.totalArticles)", label: "Articles", icon: "newspaper.fill", color: .blue)
            Divider().frame(height: 40)
            statItem(value: "\(report.sections.count)", label: "Categories", icon: "folder.fill", color: .purple)
            Divider().frame(height: 40)
            statItem(value: "\(report.topSources.count)", label: "Sources", icon: "antenna.radiowaves.left.and.right", color: .green)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func topSourcesSection(_ report: QuickReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "Top Sources", icon: "star.fill", color: .orange)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(report.topSources, id: \.self) { source in
                        SourceBadgeView(name: source)
                    }
                }
            }
        }
    }

    private func reportSection(_ section: QuickReport.ReportSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(section.emoji)
                    .font(.title3)
                Text(section.category)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(section.articles.count) articles")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }

            // Section summary
            Text(section.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)

            // Articles in section
            ForEach(section.articles) { article in
                NavigationLink(destination: ArticleDetailView(article: article)) {
                    ReportArticleRow(article: article)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .cornerRadius(14)
    }

    private func reportFooter(_ report: QuickReport) -> some View {
        VStack(spacing: 8) {
            Divider()
            Text("Generated by AI News Aggregator · \(report.formattedDate)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var generatePrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No report yet")
                .font(.headline)
            Text("Fetch some news first, then come back to generate your report")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Generate Report") {
                viewModel.generateReport()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Export

    private func exportReport() {
        guard let report = viewModel.currentReport else { return }
        var text = "# \(report.title)\n"
        text += "Generated: \(report.formattedDate)\n\n"
        text += "**Total Articles:** \(report.totalArticles)\n\n"

        for section in report.sections {
            text += "## \(section.emoji) \(section.category)\n"
            text += "\(section.summary)\n\n"
            for article in section.articles {
                text += "- **\(article.title)**\n"
                text += "  Source: \(article.source) | \(article.formattedDate)\n"
                text += "  URL: \(article.url.absoluteString)\n\n"
            }
        }
        exportText = text
        showingExport = true
    }
}

// MARK: - Supporting Views

struct ReportArticleRow: View {
    let article: NewsArticle

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: article.sourceIcon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                HStack {
                    Text(article.source)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("·")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(article.timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SectionHeaderView: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
}

struct SourceBadgeView: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .clipShape(Capsule())
    }
}

#Preview {
    QuickReportView()
        .environmentObject(NewsViewModel())
}
