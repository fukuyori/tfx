//
//  tfxApp.swift
//  tfx
//
//  Created by 福寄典明 on 2026/04/26.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct tfxApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(AppOpenDirectoryDelegate.self) private var appDelegate
    /// App-wide design store. Held here so every file pane shares the same
    /// tokens through the SwiftUI environment.
    @StateObject private var designStore = DesignStore()
#endif

    var body: some Scene {
        WindowGroup {
            ContentView()
#if os(macOS)
                .environmentObject(designStore)
                .onOpenURL { url in
                    AppOpenDirectoryRouter.shared.open([url])
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    designStore.reload()
                }
#endif
        }
#if os(macOS)
        .commands {
            ViewMenuCommands()
            DeveloperMenuCommands()
        }
#endif
    }
}
