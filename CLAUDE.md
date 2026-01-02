# FocusFlow — Claude Code Project Rules

## Commit Workflow

**NEVER run `git commit` yourself.** User commits manually.

When a commit checkpoint is reached:
1. Run `git status` to check for changes
2. Stop and provide a formatted commit message in a code block
3. Wait for user confirmation before proceeding

Commit checkpoints occur after:
- Completing any model, struct, or enum
- Completing any service or manager class
- Completing any view or component
- Adding or updating tests
- Before switching to a different feature

## Commit Message Format

Use Conventional Commits:

```
<type>(<scope>): <short description>

<optional body - explains WHY, not WHAT>
```

**Types:** feat, fix, refactor, style, test, docs, chore

**Scopes:** tasks, timer, estimation, ui, data, foundation, tests

**Example:**
```
feat(tasks): add Foundation Models task breakdown with @Generable

Implements structured task analysis using Apple's Foundation Models.
Uses @Generable macro for type-safe stepCount, complexity, and category output.
```

## Test Requirements (Swift Testing)

Every feature requires tests before commit:
- Unit tests for models and business logic
- Integration tests for persistence and services
- Use Swift Testing framework (`import Testing`), NOT XCTest
- Test file naming: `<Feature>Tests.swift`
- Use `@Suite` for grouping related tests
- Use `@Test("description")` for individual tests
- Use `#expect()` for assertions

Before providing a commit message, verify:
1. Tests exist for the new code
2. All tests pass
3. No compiler warnings

## Code Style

- Use SwiftUI and SwiftData
- Follow the DesignSystem for colors, typography, and language
- All user-facing text must use ADHD-friendly language patterns (see spec)
- Never use red for time/progress indicators
- Never use shame-inducing language ("overdue", "failed", "missed")

## Project Structure

```
FocusFlow/
├── App/
├── Models/           # SwiftData models, @Generable structs
├── Services/         # Business logic, Foundation Models, Live Activity
├── Views/            # SwiftUI views organized by feature
├── DesignSystem/     # Colors, Typography, Language patterns
├── LiveActivity/     # Widget extension
├── Utilities/        # EWMA, extensions
└── Tests/
```

## Key Technical Decisions

- **iOS 26+** minimum (Foundation Models requirement)
- **SwiftData** for persistence (not Core Data)
- **Foundation Models** for task breakdown (not external LLM)
- **timerInterval** initializer for Live Activity countdowns (critical for background updates)
- **Progressive time estimation**: User estimate → Category average → EWMA → ML (future)

## Reference Documents

The full project specification with code examples, data models, and design system is in `FocusFlow-Project-Spec.md`. Reference it for:
- Complete SwiftData model definitions
- Foundation Models @Generable struct patterns
- EWMAEstimator implementation
- Live Activity widget code
- ADHD-friendly color palette and copy
- Test examples

## MVP Scope

Build only what's in the MVP checklist (Weeks 1-8 in spec). Defer everything else.

If user asks for a feature not in MVP, confirm: "That's scoped for v1.1/v2.0. Want to add it now or stick to MVP?"
