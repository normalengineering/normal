# AGENTS.md

Normal is an iOS Screen Time blocker in SwiftUI and SwiftData, using FamilyControls,
ManagedSettings and DeviceActivity. It has no third-party dependencies.

## Targets
- `Normal`: the app
- `NormalMonitor`: DeviceActivity extension (schedules, timed unblock expiry)
- `NormalShield`: shield screen
- `NormalWidget`: widgets, Live Activity, controls
- `Shared/`: code used by the app and the extensions

## Build and test
```sh
xcodebuild test -project Normal.xcodeproj -scheme Normal \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:NormalTests CODE_SIGNING_ALLOWED=NO
```
- Unit tests use Swift Testing, UI tests use XCTest. CI runs the unit tests on every PR.
- UI tests launch with `-uiTestMode -uiTestSkipOnboarding`, which stub Screen Time, NFC,
  the camera and location. Other seeds are in `Normal/App/UITestSupport.swift`.
- Screen Time, NFC and real location don't work in the simulator. Say what you couldn't test.

## Project file
Folders are synchronized groups. Target membership comes from exception lists in
`Normal.xcodeproj/project.pbxproj`:
- A new `Shared/` file used by an extension goes in that extension's
  `Exceptions for "Shared" folder in "<Target>" target` list. Otherwise only the
  extension fails, with "cannot find type in scope".
- A new `NormalUITests/` file goes in both of that folder's lists (`NormalUITests`
  and `Normal`), or it compiles into the app.
- New `NormalTests/` files need nothing.
- Don't change `CURRENT_PROJECT_VERSION`. Version changes only touch `MARKETING_VERSION`.

## Code
- User-facing text lives in `Normal/Resources/Localizable.xcstrings` (English only).
  Xcode generates it, so don't edit it by hand. After changing text, sync it and commit
  the result. This adds new strings and removes unused ones; Xcode adds the comments
  when the project is next built in Xcode.
  ```sh
  xcodebuild -exportLocalizations -project Normal.xcodeproj -scheme Normal \
    -localizationPath /tmp/normal-loc -exportLanguage en
  ```
- Say block/unblock, not lock/unlock.
- Don't add code comments. Explain the reasoning in the PR.
- In tests, inject `now` instead of sleeping, put `.timeLimit` on tests that wait,
  and save SwiftData contexts explicitly.
- Don't weaken or delete tests to make them pass. If a test needs to change, say why
  in the PR.

## Commits and PRs
- Every PR needs an issue. Link it with `Closes #N`.
- Keep changes to what the issue asks for.
- Commits are authored by the human's account only. Never add an AI as author or
  co-author of a commit, including `Co-authored-by` trailers. Put
  `Co-authored-by: <agent> (<model>)` in the PR description instead.
- Fill in `.github/pull_request_template.md`.
- Changes to the areas under "Hard to reverse" in `.github/CONTRIBUTING.md` must be
  agreed in the issue first.
