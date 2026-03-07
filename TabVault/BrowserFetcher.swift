import Foundation
import AppKit
import Combine

struct BrowserTab: Identifiable, Hashable {
    let id = UUID()
    let browserName: String
    let windowIndex: Int
    let title: String
    let url: String
}

class BrowserFetcher: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var isFetching = false
    @Published var runningBrowsers: [String] = []
    @Published var permissionErrorBrowsers: Set<String> = []
    
    private let allSupportedBrowsers = [
        "Safari", "Google Chrome", "Chrome Canary", "Brave Browser",
        "Arc", "Microsoft Edge", "Opera", "Vivaldi", "Chromium", "Orion"
    ]
    
    private var timer: AnyCancellable?
    private var activeSubscription: AnyCancellable?
    
    init() {
        updateRunningBrowsers()
        
        // Periodically refresh ONLY if the app is active
        timer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard NSApp.isActive else { return }
                self?.fetchAllURLs(showLoadingIndicator: false)
            }
            
        // Instantly do a silent refresh whenever the app comes back to the foreground
        activeSubscription = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.fetchAllURLs(showLoadingIndicator: false)
            }
    }
    
    func updateRunningBrowsers() {
        let running = allSupportedBrowsers.filter { isAppRunning($0) }
        DispatchQueue.main.async {
            self.runningBrowsers = running
        }
    }
    
    func fetchAllURLs(showLoadingIndicator: Bool = true) {
        updateRunningBrowsers()
        refresh(for: "All", showLoadingIndicator: showLoadingIndicator)
    }
    
    func refresh(for targetBrowser: String, showLoadingIndicator: Bool = true) {
        updateRunningBrowsers()
        
        if showLoadingIndicator {
            isFetching = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let browsersToFetch = targetBrowser == "All" ? self.allSupportedBrowsers : [targetBrowser]
            var collectedTabs: [BrowserTab] = []
            
            for browser in browsersToFetch {
                if self.isAppRunning(browser) {
                    collectedTabs.append(contentsOf: self.fetchTabs(for: browser))
                }
            }
            
            DispatchQueue.main.async {
                // Swap in the new tabs all at once to avoid UI flickering
                if targetBrowser == "All" {
                    self.tabs = collectedTabs
                } else {
                    self.tabs.removeAll { $0.browserName == targetBrowser }
                    self.tabs.append(contentsOf: collectedTabs)
                }
                
                if showLoadingIndicator {
                    self.isFetching = false
                }
            }
        }
    }
    
    private func isAppRunning(_ appName: String) -> Bool {
        return NSWorkspace.shared.runningApplications.contains { $0.localizedName == appName }
    }
    
    private func fetchTabs(for browser: String) -> [BrowserTab] {
        var scriptSource = ""
        
        if browser == "Safari" || browser == "Orion" {
            scriptSource = """
            tell application "\(browser)"
                set resultList to {}
                set wIdx to 0
                repeat with w in windows
                    set wIdx to wIdx + 1
                    repeat with t in tabs of w
                        set end of resultList to (wIdx as string & "|||" & name of t & "|||" & URL of t)
                    end repeat
                end repeat
                return resultList
            end tell
            """
        } else {
            // Chromium based browsers (Chrome, Brave, Arc, Edge)
            scriptSource = """
            tell application "\(browser)"
                set resultList to {}
                set wIdx to 0
                repeat with w in windows
                    set wIdx to wIdx + 1
                    repeat with t in tabs of w
                        set end of resultList to (wIdx as string & "|||" & title of t & "|||" & URL of t)
                    end repeat
                end repeat
                return resultList
            end tell
            """
        }
        
        guard let script = NSAppleScript(source: scriptSource) else { return [] }
        
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        
        if let error = error {
            print("Error executing script for \(browser): \(error)")
            // Many errors from NSAppleScript in this context mean permission denied (like -1743)
            DispatchQueue.main.async {
                self.permissionErrorBrowsers.insert(browser)
            }
            return []
        } else {
            DispatchQueue.main.async {
                self.permissionErrorBrowsers.remove(browser)
            }
        }
        
        var browserTabs: [BrowserTab] = []
        
        // The result is an AppleEvent descriptor representing a list of strings
        for i in 0..<result.numberOfItems {
            if let item = result.atIndex(i+1)?.stringValue {
                let parts = item.components(separatedBy: "|||")
                if parts.count >= 3, let windowIdx = Int(parts[0]) {
                    browserTabs.append(BrowserTab(browserName: browser, windowIndex: windowIdx, title: parts[1], url: parts[2]))
                }
            }
        }
        
        return browserTabs
    }
}

