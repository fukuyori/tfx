#if os(macOS)
import Foundation
import Testing
@testable import tfx

@Suite("FileBrowserNavigationHistory")
struct FileBrowserNavigationHistoryTests {
    private let a = URL(fileURLWithPath: "/tmp/tfx-test/a")
    private let b = URL(fileURLWithPath: "/tmp/tfx-test/b")
    private let c = URL(fileURLWithPath: "/tmp/tfx-test/c")

    @Test
    func freshHistoryCannotNavigate() {
        let history = FileBrowserNavigationHistory()
        #expect(!history.canGoBack)
        #expect(!history.canGoForward)
    }

    @Test
    func recordingEnablesBack() {
        var history = FileBrowserNavigationHistory()
        history.recordNavigation(from: a)
        #expect(history.canGoBack)
        #expect(!history.canGoForward)
    }

    @Test
    func previousReturnsLastRecorded() {
        var history = FileBrowserNavigationHistory()
        history.recordNavigation(from: a)
        #expect(history.previous(from: b) == a.standardizedFileURL)
        #expect(!history.canGoBack)
        #expect(history.canGoForward)
    }

    @Test
    func nextReturnsSubsequentDirectory() {
        var history = FileBrowserNavigationHistory()
        history.recordNavigation(from: a)
        _ = history.previous(from: b)
        #expect(history.next(from: a) == b.standardizedFileURL)
        #expect(history.canGoBack)
        #expect(!history.canGoForward)
    }

    @Test
    func recordingClearsForwardStack() {
        var history = FileBrowserNavigationHistory()
        history.recordNavigation(from: a)
        _ = history.previous(from: b)
        #expect(history.canGoForward)
        history.recordNavigation(from: c)
        #expect(!history.canGoForward)
    }

    @Test
    func previousReturnsNilWhenEmpty() {
        var history = FileBrowserNavigationHistory()
        #expect(history.previous(from: a) == nil)
    }

    @Test
    func nextReturnsNilWhenEmpty() {
        var history = FileBrowserNavigationHistory()
        #expect(history.next(from: a) == nil)
    }

    @Test
    func recordedURLsAreStandardized() {
        var history = FileBrowserNavigationHistory()
        // The trailing slash should be normalized through standardizedFileURL.
        let messy = URL(fileURLWithPath: "/tmp/tfx-test/./a")
        history.recordNavigation(from: messy)
        let returned = history.previous(from: b)
        #expect(returned == messy.standardizedFileURL)
        #expect(returned?.path == "/tmp/tfx-test/a")
    }
}
#endif
