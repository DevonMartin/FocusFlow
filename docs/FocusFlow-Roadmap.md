# FocusFlow Development Roadmap

Personal checklist for tracking progress. Check items off as you complete them.

---

## Week 1-2: Foundation

### Project Setup
- [X] Create Xcode project (iOS App, SwiftUI, SwiftData, Swift Testing)
- [X] Add `CLAUDE.md` to repo root
- [X] Add `docs/FocusFlow-Project-Spec.md` to repo
- [X] Initial commit

### Design System
- [X] `DesignSystem/Colors.swift` — Teal palette, no reds
- [X] `DesignSystem/Typography.swift` — Rounded fonts, timer styles
- [X] `DesignSystem/Language.swift` — All ADHD-friendly copy

### Data Models
- [X] `Models/TaskRecord.swift` — Main task with SwiftData @Model
- [X] `Models/SubtaskRecord.swift` — Child steps with cascade delete
- [X] `Tests/ModelTests/TaskRecordTests.swift`
- [X] `Tests/ModelTests/SubtaskRecordTests.swift`

### Basic UI
- [X] `Views/TaskList/TaskListView.swift` — Main list screen
- [X] `Views/TaskList/TaskRowView.swift` — Single task row
- [X] `Views/Components/GentleButton.swift`
- [ ] Task CRUD working (create, read, delete)

---

## Week 3-4: AI Integration

### Foundation Models Setup
- [X] `Models/TaskBreakdown.swift` — @Generable struct for LLM output
- [X] `Models/TaskStep.swift` — @Generable struct for individual steps
- [X] `Services/TaskBreakdownService.swift` — Streaming + error handling
- [X] `Tests/ServiceTests/TaskBreakdownServiceTests.swift`

### Task Creation Flow
- [ ] `Views/TaskDetail/CreateTaskView.swift` — Input + AI breakdown
- [ ] `Views/TaskDetail/SubtaskListView.swift` — Display generated steps
- [ ] Loading states with streaming partial results
- [ ] Fallback UI for unsupported devices

### Availability Handling
- [X] Check `SystemLanguageModel.default.isAvailable`
- [X] User-friendly messages for each unavailability reason
- [ ] Graceful degradation (manual task entry without AI)

---

## Week 5-6: Timer & Live Activity

### Time Estimation
- [X] `Utilities/EWMAEstimator.swift` — Exponential weighted moving average
- [X] `Services/TimeEstimationService.swift` — Progressive tiers
- [X] `Tests/UtilityTests/EWMAEstimatorTests.swift`
- [ ] Confidence display ("rough guess" → "based on your history")

### Live Activity
- [ ] Create Widget Extension target in Xcode
- [ ] `LiveActivity/TaskTimerAttributes.swift` — ActivityAttributes
- [ ] `LiveActivity/TaskTimerLiveActivity.swift` — Lock screen + Dynamic Island
- [ ] `Services/LiveActivityManager.swift` — Start/update/end
- [ ] **Use `timerInterval` initializer** (critical for background updates)

### Timer Flow
- [ ] `Views/Timer/ActiveTaskView.swift` — In-app timer screen
- [ ] Start task → Live Activity appears
- [ ] Complete task → Activity ends, duration recorded
- [ ] Overtime handling (no shame, just "take your time")

---

## Week 7-8: Polish & Ship

### Personalization
- [ ] Record actual durations on completion
- [ ] Feed data to EWMAEstimator
- [ ] Display estimate source ("AI estimate" → "based on similar tasks")
- [ ] Category-based learning working

### Completion Flow
- [ ] Completion celebration (same regardless of timing)
- [ ] "This took X min. Update estimate?" prompt
- [ ] Data persisted for future learning

### Accessibility
- [ ] VoiceOver labels on all interactive elements
- [ ] Dynamic Type support
- [ ] Reduce Motion respected
- [ ] Test with accessibility inspector

### Final Polish
- [ ] App icon
- [ ] Launch screen
- [ ] Empty states ("Ready to add your first task?")
- [ ] Return-after-absence messaging (no guilt)
- [ ] TestFlight build

---

## Post-MVP (v1.1)

- [ ] CreateML MLLinearRegressor training pipeline
- [ ] Background retraining (BGTaskScheduler)
- [ ] HealthKit sleep correlation
- [ ] Expanded Dynamic Island presentation
- [ ] Analytics/insights view
- [ ] iCloud sync

---

## Key Technical Reminders

**Foundation Models:**
- Requires iOS 26+ and iPhone 15 Pro+
- Always check availability before using
- Use `@Generable` for structured output
- Stream responses for responsive UI

**Live Activity:**
- Use `timerInterval:countsDown:` — NOT manual text updates
- Max 8 hours active
- 4KB max ContentState

**Time Estimation Tiers:**
1. 0-9 tasks → LLM baseline
2. 10-49 → Category averages  
3. 50-99 → EWMA
4. 100+ → ML model (future)

**Colors (copy these):**
- Primary: `#4A90A4`
- Secondary: `#7BB3C0`
- Gentle (success): `#8FBC8F`
- Background: `#F8FAFB`

---

## Files Quick Reference

| What | Where |
|------|-------|
| Project rules (Claude Code) | `CLAUDE.md` |
| Full spec with code examples | `docs/FocusFlow-Project-Spec.md` |
| SwiftData models | `Models/` |
| Foundation Models integration | `Services/TaskBreakdownService.swift` |
| Time prediction | `Services/TimeEstimationService.swift` + `Utilities/EWMAEstimator.swift` |
| Live Activity | `LiveActivity/` folder + `Services/LiveActivityManager.swift` |
| Design constants | `DesignSystem/` |
