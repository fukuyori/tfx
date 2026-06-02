//
//  tfxApp.swift
//  tfx
//
//  Created by 福寄典明 on 2026/04/26.
//

import SwiftUI
#if os(macOS)
import AppKit
import Darwin
#endif

@main
struct tfxApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(AppOpenDirectoryDelegate.self) private var appDelegate
    /// App-wide design store. Held here so every file pane shares the same
    /// tokens through the SwiftUI environment.
    @StateObject private var designStore = DesignStore()
    @StateObject private var shortcutStore = ShortcutStore()
    @StateObject private var userCommandStore = UserCommandStore()
    @StateObject private var previewConfigurationStore = PreviewConfigurationStore()
#endif

    init() {
#if os(macOS)
        let launchArguments = AppLaunchArguments.parse()
        if launchArguments.shouldPrintHelp {
            print(AppLaunchArguments.helpText)
            Darwin.exit(0)
        }
        if launchArguments.shouldPrintVersion {
            print(AppLaunchArguments.versionString())
            Darwin.exit(0)
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
#if os(macOS)
                .environmentObject(designStore)
                .environmentObject(shortcutStore)
                .environmentObject(userCommandStore)
                .environmentObject(previewConfigurationStore)
                .onOpenURL { url in
                    AppOpenDirectoryRouter.shared.open([url])
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    designStore.reload()
                    shortcutStore.reload()
                    userCommandStore.reload()
                    previewConfigurationStore.reload()
                }
#endif
        }
#if os(macOS)
        .commands {
            ViewMenuCommands(shortcutStore: shortcutStore)
            DeveloperMenuCommands()
        }
#endif
    }
}
