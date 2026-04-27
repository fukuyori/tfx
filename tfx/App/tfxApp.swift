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
#endif

    var body: some Scene {
        WindowGroup {
            ContentView()
#if os(macOS)
                .onOpenURL { url in
                    AppOpenDirectoryRouter.shared.open([url])
                }
#endif
        }
    }
}
