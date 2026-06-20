# Contributing to RUKK

Thanks for your interest! RUKK is a native macOS app written entirely in Swift.

## Getting started

```sh
git clone https://github.com/nnv-ark/kula-invoicing.git
cd kula-invoicing
open RUKK.xcodeproj      # build & run with ⌘R
swift test               # run the unit tests
```

- **Requirements:** macOS 14+, Xcode 16+ (Swift 6).
- The app target lives in the Xcode project; the same `Sources/` also builds as a SwiftPM
  library so tests can run via `swift test`.

## Guidelines

- **Swift 6 idioms** — `@Observable`/SwiftData, `async`/`await`, `NavigationSplitView`,
  no `ObservableObject`/`@StateObject`.
- **Money is `Decimal`**, never `Double`. Totals are derived, not stored.
- **No `try!` / `try?`** in production paths — handle or rethrow errors.
- Keep views small; put logic in models/helpers where practical.
- Add or update tests in `Tests/RUKKTests/` for any behaviour change to invoice math,
  settings resolution, or export.
- Run `swift test` before opening a pull request — CI must stay green.

## Pull requests

1. Branch off `main`.
2. Keep changes focused; describe the *why* in the PR body.
3. Make sure `swift build` and `swift test` pass locally.

## Reporting bugs

Open an issue using the **Bug report** template and include macOS version, steps to
reproduce, and what you expected.
