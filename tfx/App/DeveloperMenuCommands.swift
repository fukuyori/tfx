#if os(macOS)
import SwiftUI

/// Developer-only menu commands inserted into the macOS menu bar.
///
/// Currently exposes the in-app toggle for `PerformanceTrace` output.
/// `TFX_PERFORMANCE_LOGS=1` in the environment still wins so CI and
/// scripted runs do not have to flip the toggle first.
struct DeveloperMenuCommands: Commands {
    @AppStorage(PerformanceTrace.userDefaultsKey) private var showsPerformanceLogs = false

    var body: some Commands {
        CommandMenu("Developer") {
            Toggle("Show Performance Logs", isOn: $showsPerformanceLogs)
        }
    }
}

#endif
