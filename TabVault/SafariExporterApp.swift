//
//  TabVaultApp.swift
//  TabVault
//
//  Created by Bunnarith Heang on 3/7/26.
//

import SwiftUI

@main
struct TabVaultApp: App {
    @StateObject private var fetcher = BrowserFetcher()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(fetcher)
        }
    }
}
