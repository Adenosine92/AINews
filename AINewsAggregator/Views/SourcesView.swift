import SwiftUI

struct SourcesView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var searchText = ""

    private var groupedSources: [NewsSource.SourceCategory: [NewsSource]] {
        Dictionary(grouping: filteredSources, by: { $0.category })
    }

    private var filteredSources: [NewsSource] {
        guard !searchText.isEmpty else { return viewModel.sources }
        return viewModel.sources.filter {
            $0.name.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Stats header
                statsHeader
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)

                ForEach(NewsSource.SourceCategory.allCases, id: \.self) { category in
                    if let sources = groupedSources[category], !sources.isEmpty {
                        Section {
                            ForEach(sources) { source in
                                SourceRowView(source: source) {
                                    viewModel.toggleSource(source)
                                }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: category.iconName)
                                    .font(.caption)
                                Text(category.rawValue.uppercased())
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search sources...")
        }
    }

    private var statsHeader: some View {
        let enabled = viewModel.sources.filter { $0.isEnabled }.count
        let total = viewModel.sources.count
        return HStack(spacing: 12) {
            Label("\(enabled)/\(total) active", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundColor(.green)
            Spacer()
            Text("Toggle to enable/disable")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct SourceRowView: View {
    let source: NewsSource
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: source.color)?.opacity(0.15) ?? Color.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: source.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: source.color) ?? .blue)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(source.websiteURL)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { source.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .opacity(source.isEnabled ? 1.0 : 0.5)
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    SourcesView()
        .environmentObject(NewsViewModel())
}
