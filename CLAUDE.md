# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`reminders-cli` is a macOS command-line tool for interacting with Reminders.app via EventKit, built with Swift Package Manager and Apple's `swift-argument-parser`.

## Commands

- Build (debug): `swift build`
- Build matching CI exactly: `swift build -Xswiftc -warnings-as-errors`
- Run all tests: `swift test` (or `swift test -Xswiftc -warnings-as-errors` to match CI)
- Run a single test: `swift test --filter RemindersTests.NaturalLanguageTests/testTomorrow` (filter format is `<Target>.<TestCase>/<testMethod>`, method optional)
- Release build (universal arm64/x86_64 binary): `make build-release`
- Full release package (tarball + shasums, as used for GitHub releases): `make package`
- Clean build artifacts: `make clean`
- Run locally without installing: `swift run reminders <subcommand> ...`

There is no linter configured (no SwiftLint/SwiftFormat) — code quality is enforced only via `-warnings-as-errors` on both library targets, applied both in `Package.swift` and again explicitly in CI.

## Architecture

Execution flows in one direction through four layers:

1. **`Sources/reminders/main.swift`** — entry point. Requests Reminders access via EventKit (branches on macOS 14+ `requestFullAccessToReminders` vs. the older `requestAccess(to:)`), then hands off to `CLI.main()`.
2. **`Sources/RemindersLibrary/CLI.swift`** — the `CLI: ParsableCommand` root (command name `reminders`) and one private `ParsableCommand` struct per subcommand (`ShowLists`, `ShowAll`, `Show`, `Add`, `Complete`, `Uncomplete`, `Delete`, `Edit`, `NewList`). Each subcommand only declares its `@Argument`/`@Option`/`@Flag` properties and a thin `run()` that delegates to a single shared `Reminders()` instance. Shell-completion for list names is wired up here via `listNameCompletion(_:_:_:)`.
3. **`Sources/RemindersLibrary/Reminders.swift`** — all actual business logic, wrapping `EKEventStore`/`EKReminder`/`EKCalendar`. Every subcommand's real behavior (list/show, add, edit, complete/uncomplete, delete, new list) lives here, along with `OutputFormat`, `DisplayOptions`, and `Priority`. Since EventKit's APIs are callback-based, `DispatchSemaphore` is used to make them synchronous for the CLI.
4. **Supporting extensions**, used by the layers above:
   - `NaturalLanguage.swift` — `DateComponents(argument:)` (`ExpressibleByArgument`), parses natural-language date strings like `"tomorrow 9am"` for `--due-date` options via `NSDataDetector`. Known limitation: `"next weekend"` doesn't parse (Apple Feedback FB8921206), covered by a test expecting `nil`.
   - `Sort.swift` — `Sort`/`CustomSortOrder` enums backing `show --sort`/`--sort-order`.
   - `EKReminder+Encodable.swift` — manual `Encodable` conformance for `EKReminder`, used for `--format json` output.
   - `CollectionType+Extension.swift` — small `Collection` helpers (`find(where:)`, safe subscript) used by `Reminders.swift`.

When adding a new subcommand: add a `ParsableCommand` struct in `CLI.swift`, register it in `CLI`'s `subcommands`, and implement the actual behavior as a method on `Reminders` in `Reminders.swift` — keep `CLI.swift` limited to argument parsing/dispatch.

Tests (`Tests/RemindersTests/NaturalLanguageTests.swift`) currently only cover natural-language date parsing, via `XCTest` + `@testable import RemindersLibrary`.

## Release process

Releases are packaged manually, not via CI (the GitHub Actions workflow only builds and tests on push/PR to `main`). `make package` builds a universal release binary, generates a zsh completion script, and produces `reminders.tar.gz` plus SHA-256 checksums for both the tarball and the raw binary — these are what get attached to a GitHub release.
