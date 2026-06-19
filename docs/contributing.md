# Contributing to tfx

Working notes for anyone changing tfx source. The user-facing documents (`README.md` and `README.ja.md`) cover what tfx is and how to use it. This file covers how to work on it.

## Requirements

- macOS matching the project deployment target (currently `MACOSX_DEPLOYMENT_TARGET = 26.4`).
- Xcode that supports macOS 26.4. Earlier Xcode versions cannot build the project.
- Apple Silicon. The project targets Apple Silicon natively; there is no Intel build path planned at the current deployment target.

## Local Build

The Xcode project drives everything. From the repo root:

```sh
xcodebuild build \
    -scheme tfx \
    -configuration Debug \
    -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO
```

Release configuration:

```sh
xcodebuild build \
    -scheme tfx \
    -configuration Release \
    -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO
```

For interactive development, open `tfx.xcodeproj` in Xcode and use the standard Run / Test commands.

## Running Tests

The `tfxTests` target uses [Swift Testing](https://developer.apple.com/documentation/testing). Run the full suite from the command line:

```sh
xcodebuild test \
    -scheme tfx \
    -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO
```

Per-test output is verbose; pipe through `xcpretty` or `xcbeautify` if you prefer:

```sh
xcodebuild test -scheme tfx -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO | xcbeautify
```

Selecting a specific test suite or test case:

```sh
xcodebuild test \
    -scheme tfx \
    -destination 'platform=macOS' \
    -only-testing:tfxTests/CSVParserTests \
    CODE_SIGNING_ALLOWED=NO
```

## Test Layout

Test sources live in `tfxTests/`. The directory is picked up automatically through `PBXFileSystemSynchronizedRootGroup`, so adding a new `*.swift` file under `tfxTests/` is enough — no project file edits required.

Conventions:

- One file per logical unit. Name it after the type or area under test, suffixed with `Tests` (`CSVParserTests.swift`, `FileBrowserModelTests.swift`).
- Use Swift Testing macros: `@Suite`, `@Test`, `#expect`, `#require`.
- Pure-logic tests should not touch the file system. Tests that need real files create a per-test directory under `FileManager.default.temporaryDirectory` and remove it via `defer` (see `FileBrowserFilterSortTests` for the pattern).
- Tests that touch `FileBrowserModel` (a `@MainActor` `ObservableObject`) need `@MainActor` on the suite. See `FileBrowserModelTests` for the shape.

## What Requires a Test

From the roadmap (`docs/development-roadmap.md` §3.2 Quality Gates):

- Every new public mutator on `FileBrowserModel` ships with at least one focused test.
- Pure-logic types (`CSVParser`, `FileBrowserFilterSort`, `FileBrowserNavigationHistory`, `FileBrowserSelectionSupport`, `FileBrowserDirectoryState`) keep coverage of their main behaviors. New cases should land with new tests.
- Bug fixes that were caught by a test should keep that test as a regression check.

## Performance Benchmarks

`tfxTests/PerformanceBenchmarks.swift` contains informational benchmarks that exercise the §3.1 performance targets in `docs/development-roadmap.md`. They run as part of the regular test suite and print per-scenario timings via `print` (visible in the xcresult bundle and in Xcode's test output). The benchmarks deliberately do **not** assert thresholds — CI hardware varies, so comparisons are reviewed manually or against rolling baselines on the same machine.

Run benchmarks in isolation:

```sh
xcodebuild test \
    -scheme tfx \
    -destination 'platform=macOS' \
    -only-testing:tfxTests/PerformanceBenchmarks \
    CODE_SIGNING_ALLOWED=NO
```

For in-app performance logging during interactive runs, enable **Developer → Show Performance Logs** in the menu bar (or set the `TFX_PERFORMANCE_LOGS=1` environment variable, which still wins regardless of the menu setting). Logs print to stdout in the form `[tfx perf] <label> <ms>ms <detail>`.

## Continuous Integration

GitHub Actions runs `.github/workflows/build.yml` on every push to `main` and every PR targeting `main`. The workflow runs `xcodebuild build` and `xcodebuild test` against `macos-latest`.

Expectations:

- CI must be green before a release tag is cut.
- New SwiftUI or Swift compiler warnings should not be introduced.
- On failure, the workflow uploads `test-results.xcresult` and the raw logs as artifacts; download them from the Actions run page to inspect locally.

If the `macos-latest` runner does not yet carry a Xcode version that can build the deployment target, CI will fail at the `Build` step. In that case the options are: bump the workflow to a pinned macOS runner that does carry it, lower the deployment target, or run on a self-hosted macOS runner. The decision belongs to the release maintainer.

## Code Style

There is no enforced formatter yet, but please follow the conventions already in the source:

- Files are organized per `docs/code-organization.md`. New files go under the appropriate feature directory.
- Type-per-file is the default. `FileBrowserModel` extensions follow the `FileBrowserModel+Feature.swift` pattern.
- Public types stay `internal` (no `public`) unless there is a reason to expose them — the app is a single module.
- Avoid introducing compiler warnings. If a warning is intentional, document why inline.
- Keep documentation comments brief and English-default (`README.ja.md` is the only Japanese long-form document).

## Documentation Updates

When changing user-facing behavior, update both `README.md` and `README.ja.md` together. When changing architecture or behavior described in `docs/detailed-design.md`, update that file in the same PR. See `docs/README.md` for the full set of documents and their maintenance rules.

## Release Process

Releases are built from a clean working tree after bumping `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, `README.md`, `README.ja.md`, and `CHANGELOG.md`.

Before building a signed release, confirm that both Developer ID identities are available in the login keychain:

```sh
security find-identity -v -p codesigning
```

The release script defaults to the current project team and identities:

- `TFX_DEVELOPMENT_TEAM=Q6GG27UYG5`
- `TFX_APP_SIGN_IDENTITY="Developer ID Application: Noriaki Fukuyori (Q6GG27UYG5)"`
- `TFX_PKG_SIGN_IDENTITY="Developer ID Installer: Noriaki Fukuyori (Q6GG27UYG5)"`
- `TFX_NOTARY_PROFILE=notarytool`

Override those environment variables when building with another Apple Developer account. If the signing identities are stored outside the default keychain search path, set `TFX_SIGNING_KEYCHAIN` to that keychain path.

For notarized direct-distribution builds, store a notarytool keychain profile once on the release machine:

```sh
xcrun notarytool store-credentials notarytool \
    --apple-id "APPLE_ID" \
    --team-id "Q6GG27UYG5" \
    --password "APP_SPECIFIC_PASSWORD"
```

Build a signed package without notarization:

```sh
TFX_SKIP_NOTARIZATION=1 ./scripts/build_release_pkg.sh
```

Build, submit for notarization, staple the ticket, and run Gatekeeper install assessment:

```sh
./scripts/build_release_pkg.sh
```

The output package is written to `artifacts/tfx-<version>.pkg`. The script verifies the app signature with `codesign`, verifies the package signature with `pkgutil`, validates the stapled ticket with `stapler`, and checks install assessment with `spctl`.

Unsigned local release builds remain available for debugging:

```sh
TFX_SKIP_SIGNING=1 ./scripts/build_release_pkg.sh
```

Sparkle appcast signing and channel layout will be added here when §2.7 lands.
