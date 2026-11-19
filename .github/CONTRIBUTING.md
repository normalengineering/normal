# Contributing

## Open an issue first
Every PR needs an issue. Search the existing issues before opening a new one:
- If it's already been reported, use that issue.
- If that issue is closed, comment there saying why it should be reopened.

## Pull requests
- Link the issue with `Closes #N`, and keep the PR to what it asks for.
- Say how you tested it: the tests you added or ran, and a screen recording for UI changes.
- Say what you couldn't test. Screen Time, NFC and real location don't work in the simulator.
- CI must pass.

Build, test and project-file notes are in [AGENTS.md](../AGENTS.md).

## AI tools
AI tools are accepted, but review everything they produce yourself before opening a PR.
You're responsible for the result.
- Say in the PR description which tools you used and for what. If an agent wrote code,
  add a `Co-authored-by: <agent> (<model>)` line there.
- Commits are authored by your own account only. Don't add an AI as author or co-author
  of a commit, including `Co-authored-by` trailers.
- Understand every change and be able to explain it. Reply to review comments yourself.
- Don't weaken or delete tests to make them pass.
- If tests need changing, provide justification.
- PRs that look unreviewed may be closed without review.

## Hard to reverse
Changes here can break installed apps, widgets or people's Shortcuts. Agree on them in
the issue first:
- SwiftData models, which need a migration
- Data shared through the App Group between the app and its extensions
- `normal://` links and widget intent and entity types
- Keychain items
- App Intents and Shortcuts names and parameters
- Screen Time store and activity names
- Entitlements and permission prompts

## Security
Report vulnerabilities privately, as described in [SECURITY.md](SECURITY.md).
