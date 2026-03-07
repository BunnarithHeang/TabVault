//
//  ContentView.swift
//  SafariExporter
//
//  Created by Bunnarith Heang on 3/7/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var fetcher: BrowserFetcher
    @State private var selectedBrowser: String? = "All"
    @State private var selectedWindow: Int? = nil  // nil = All windows
    @State private var toastMessage: String? = nil

    var sidebarBrowsers: [String] {
        ["All"] + fetcher.runningBrowsers
    }

    /// Tabs for the selected browser (before window filter)
    var browserFilteredTabs: [BrowserTab] {
        if selectedBrowser == "All" || selectedBrowser == nil {
            return fetcher.tabs
        } else {
            return fetcher.tabs.filter { $0.browserName == selectedBrowser }
        }
    }

    /// Distinct window indices available for the current browser selection
    var availableWindows: [Int] {
        guard selectedBrowser != "All", selectedBrowser != nil else { return [] }
        return Array(Set(browserFilteredTabs.map { $0.windowIndex })).sorted()
    }

    var filteredTabs: [BrowserTab] {
        guard let window = selectedWindow else { return browserFilteredTabs }
        return browserFilteredTabs.filter { $0.windowIndex == window }
    }
    
    var hasPermissionError: Bool {
        if let selected = selectedBrowser, selected != "All" {
            return fetcher.permissionErrorBrowsers.contains(selected)
        }
        return !fetcher.permissionErrorBrowsers.isDisjoint(with: fetcher.runningBrowsers)
    }
    
    var body: some View {
        NavigationSplitView {
            List(sidebarBrowsers, id: \.self, selection: $selectedBrowser) { browser in
                NavigationLink(value: browser) {
                    Label(browser, systemImage: browserIcon(for: browser))
                }
            }
            .navigationTitle("Browsers")
            .safeAreaInset(edge: .bottom) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Developed by:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            
                        Link("Bunnarith Heang", destination: URL(string: "https://github.com/BunnarithHeang")!)
                            .font(.caption)
                            .fontWeight(.medium)
                            .help("View GitHub Profile")
                    }
                    Spacer()
                }
                .padding()
                .background(.regularMaterial)
            }
        } detail: {
            ZStack {
                VStack(spacing: 0) {
                    if fetcher.isFetching && fetcher.tabs.isEmpty {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Fetching browser tabs...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if fetcher.tabs.isEmpty {
                        if !fetcher.permissionErrorBrowsers.isEmpty {
                            permissionErrorView
                        } else {
                            emptyStateView
                        }
                    } else if filteredTabs.isEmpty {
                        if hasPermissionError {
                            permissionErrorView
                        } else {
                            noResultsView
                        }
                    } else {
                        ZStack {
                            VStack(spacing: 0) {
                                if hasPermissionError {
                                    permissionWarningBanner
                                }
                                tabListView
                            }
                            
                            if fetcher.isFetching {
                                VStack {
                                    ProgressView()
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(8)
                                    Spacer()
                                }
                                .padding(.top, 40)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }
                }
                
                if let message = toastMessage {
                    VStack {
                        Spacer()
                        Text(message)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .padding(.bottom, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.spring(), value: toastMessage)
                }
            }
            .navigationTitle(selectedBrowser ?? "All")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { fetcher.fetchAllURLs() }) {
                        Label("Fetch", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh list from all browsers")
                    
                    Button(action: copyAllToClipboard) {
                        Label("Copy All", systemImage: "doc.on.doc.fill")
                    }
                    .disabled(filteredTabs.isEmpty)
                    .help("Copy filtered URLs to clipboard")
                    
                    Button(action: exportToFile) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(filteredTabs.isEmpty)
                    .help("Export filtered URLs to text file")
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            fetcher.fetchAllURLs()
        }
        .onChange(of: selectedBrowser) { oldSelection, newSelection in
            selectedWindow = nil
            if let newSelection = newSelection, newSelection != "All" {
                fetcher.refresh(for: newSelection)
            } else if newSelection == "All" {
                fetcher.refresh(for: "All")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "safari.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
            
            Text("No URLs Fetched")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Open browser windows and click Fetch to see all tabs.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { fetcher.fetchAllURLs() }) {
                Label("Fetch browser URLs", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var permissionErrorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange.gradient)
            
            Text("Action Required")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("macOS blocked SafariExporter from reading tabs in \(selectedBrowser == "All" || selectedBrowser == nil ? "your browsers" : selectedBrowser!).\nCheck the Automation panel in System Settings.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Open System Settings") {
                // Navigates directly to the Automation privacy settings pane
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var permissionWarningBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Some running browsers couldn't be read due to missing macOS permissions.")
                .font(.subheadline)
            Spacer()
            Button("Fix") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.orange.opacity(0.3)), alignment: .bottom)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No tabs found for \(selectedBrowser ?? "")")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var windowTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                windowTabButton(label: "All", window: nil)
                ForEach(availableWindows, id: \.self) { idx in
                    windowTabButton(label: "Window \(idx)", window: idx)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.primary.opacity(0.1)), alignment: .bottom)
    }

    private func windowTabButton(label: String, window: Int?) -> some View {
        let isSelected = selectedWindow == window
        return Button(action: { selectedWindow = window }) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor : Color.clear)
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var tabListView: some View {
        VStack(spacing: 0) {
            if !availableWindows.isEmpty {
                windowTabBar
            }
            List {
                ForEach(filteredTabs) { tab in
                    HStack(alignment: .top) {
                        Image(systemName: browserIcon(for: tab.browserName))
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                            .padding(.top, 3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(tab.title)
                                .font(.headline)
                                .lineLimit(1)

                            Text(tab.url)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button(action: { copyToClipboard(tab.url, label: "URL") }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        .help("Copy URL")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        copyToClipboard(tab.url, label: "URL")
                    }
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button(action: { copyToClipboard(tab.title, label: "Title") }) {
                            Label("Copy Title", systemImage: "pencil")
                        }

                        Button(action: { copyToClipboard(tab.url, label: "URL") }) {
                            Label("Copy URL", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
        }
    }
    
    private func browserIcon(for name: String) -> String {
        switch name {
        case "All": return "square.grid.2x2"
        case "Safari": return "safari"
        case "Google Chrome", "Chrome Canary", "Chromium": return "globe"
        case "Brave Browser": return "shield.fill"
        case "Arc": return "hexagon.fill"
        case "Microsoft Edge": return "e.circle.fill"
        case "Opera": return "o.circle.fill"
        case "Vivaldi": return "v.circle.fill"
        case "Orion": return "moon.fill"
        default: return "window.badge.magnifyingglass"
        }
    }
    
    private func copyToClipboard(_ text: String, label: String = "") {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        showToast("Copied \(label) to clipboard!")
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
    
    private func copyAllToClipboard() {
        let allUrls = filteredTabs.map { "\($0.title): \($0.url)" }.joined(separator: "\n")
        copyToClipboard(allUrls, label: "All URLs")
    }
    
    private func exportToFile() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "exported_\(selectedBrowser?.lowercased().replacingOccurrences(of: " ", with: "_") ?? "all")_urls.txt"
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                let content = filteredTabs.map { "\($0.title)\n\($0.url)\n" }.joined(separator: "\n")
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
