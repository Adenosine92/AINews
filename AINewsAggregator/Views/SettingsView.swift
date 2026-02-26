import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var twitterToken = TwitterService.shared.bearerToken ?? ""
    @State private var showTokenField = false
    @State private var refreshInterval = 15
    @State private var showClearConfirm = false
    @AppStorage("app_theme") private var appTheme = 0
    @AppStorage("notifications_enabled") private var notificationsEnabled = false
    @AppStorage("auto_refresh") private var autoRefresh = true

    let refreshIntervals = [5, 10, 15, 30, 60]

    var body: some View {
        NavigationStack {
            Form {
                // App info header
                appInfoSection

                // X/Twitter
                xIntegrationSection

                // Preferences
                preferencesSection

                // Data
                dataSection

                // About
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Clear All Data", isPresented: $showClearConfirm) {
                Button("Clear", role: .destructive) { clearAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all bookmarks and cached articles. Sources will be reset to defaults.")
            }
        }
    }

    // MARK: - Sections

    private var appInfoSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI News Aggregator")
                        .font(.headline)
                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.stats.activeSources) sources active")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var xIntegrationSection: some View {
        Section {
            HStack {
                Image(systemName: "bird.fill")
                    .foregroundColor(.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("X (Twitter) Integration")
                        .font(.subheadline)
                    Text(TwitterService.shared.isConfigured ? "Connected" : "Not configured")
                        .font(.caption)
                        .foregroundColor(TwitterService.shared.isConfigured ? .green : .orange)
                }
                Spacer()
                Button(showTokenField ? "Hide" : "Configure") {
                    withAnimation { showTokenField.toggle() }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }

            if showTokenField {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bearer Token")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("Paste your X API Bearer Token", text: $twitterToken)
                        .font(.caption)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Save Token") {
                            TwitterService.shared.bearerToken = twitterToken
                            showTokenField = false
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(twitterToken.isEmpty)

                        if TwitterService.shared.isConfigured {
                            Button("Remove") {
                                twitterToken = ""
                                TwitterService.shared.bearerToken = nil
                            }
                            .foregroundColor(.red)
                        }
                    }
                    Link("Get a Bearer Token →", destination: URL(string: "https://developer.twitter.com/en/portal/dashboard")!)
                        .font(.caption)
                }
            }
        } header: {
            Text("Social Integration")
        } footer: {
            Text("X (Twitter) requires a Bearer Token from the Twitter Developer Portal. The free tier allows 500,000 tweets/month.")
        }
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            Toggle("Auto-Refresh", isOn: $autoRefresh)

            if autoRefresh {
                Picker("Refresh Interval", selection: $refreshInterval) {
                    ForEach(refreshIntervals, id: \.self) { interval in
                        Text("\(interval) minutes").tag(interval)
                    }
                }
            }

            Toggle("Notifications", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled { requestNotificationPermission() }
                }

            Picker("Theme", selection: $appTheme) {
                Text("System").tag(0)
                Text("Light").tag(1)
                Text("Dark").tag(2)
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Last Refreshed")
                Spacer()
                Text(viewModel.stats.lastUpdatedString)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }

            HStack {
                Image(systemName: "newspaper")
                Text("Total Articles")
                Spacer()
                Text("\(viewModel.stats.totalArticles)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "bookmark")
                Text("Bookmarks")
                Spacer()
                Text("\(viewModel.stats.bookmarkCount)")
                    .foregroundColor(.secondary)
            }

            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Link(destination: URL(string: "https://github.com/Adenosine92/AINews")!) {
                HStack {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                    Text("View Source Code")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Image(systemName: "shield.fill")
                    .foregroundColor(.green)
                Text("Privacy")
                Spacer()
                Text("No data collected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "info.circle")
                Text("Sources")
                Spacer()
                Text("RSS + X API v2")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func clearAllData() {
        UserDefaults.standard.removeObject(forKey: "bookmarked_articles")
        UserDefaults.standard.removeObject(forKey: "cached_articles")
        UserDefaults.standard.removeObject(forKey: "cache_expiry")
        UserDefaults.standard.removeObject(forKey: "user_sources")
        viewModel.bookmarkedArticles = []
        viewModel.articles = []
        viewModel.sources = NewsSource.defaultSources
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if !granted { notificationsEnabled = false }
            }
        }
    }
}

import UserNotifications

#Preview {
    SettingsView()
        .environmentObject(NewsViewModel())
}
