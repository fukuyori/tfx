//
//  tfxApp.swift
//  tfx
//
//  Created by 福寄典明 on 2026/04/26.
//

import SwiftUI

@main
struct tfxApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(AppOpenDirectoryDelegate.self) private var appDelegate
    /// App-wide theme store. Held here so the View → Theme menu and
    /// every file pane share the same instance via the SwiftUI
    /// environment — switching themes from the menu propagates to all
    /// views in one publish.
    @StateObject private var themeStore = ThemeStore()
#endif

    var body: some Scene {
        WindowGroup {
            ContentView()
#if os(macOS)
                .environment(\.theme, themeStore.activeTheme)
                .environmentObject(themeStore)
                .onOpenURL { url in
                    AppOpenDirectoryRouter.shared.open([url])
                }
#endif
        }
#if os(macOS)
        .commands {
            ViewMenuCommands(themeStore: themeStore)
            DeveloperMenuCommands()
        }
#endif
    }
}
