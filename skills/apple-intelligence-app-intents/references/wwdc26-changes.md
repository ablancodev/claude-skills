# App Intents — WWDC 2026 changelog (verbatim)

Source: `developer.apple.com/documentation/Updates/AppIntents` (June 2026).

## Apple Intelligence

- `SyncableEntity` — protocol declaring that an entity's identifier is stable across devices. Required so Siri AI can resolve the same entity when a conversation continues on another device.
- `OwnershipProvidingEntity` — protocol used to prompt for confirmation before destructive or sensitive actions on shared or publicly-accessible entities.
- `EntityOwnership` — type representing ownership / sharing characteristics of an app entity.
- `RelevantEntities` — enables Apple Intelligence to suggest media-related entities (songs, albums) during contexts like workouts.
- `IntentValueRepresentation` — bridges app entities to system intent value types via the entity's `transferRepresentation`.
- `app-schema-domains` — conform app intents, app entities, and app enums to system-defined app schemas.

## App Intents

- `RunSystemShortcutIntent` — perform App Shortcuts, custom shortcuts, system actions, or open another app from an interactive widget.
- `LongRunningIntent` — extend an app intent's background runtime.
- `LongRunningIntent.performBackgroundTask(options:operation:)` — extend background execution time, configured via `LongRunningTaskOptions`.
- `CancellableIntent` — handle cancellation cleanup gracefully.
- `IntentCancellationReason` — distinguish deliberate cancellation from timeout / system reclaim.
- `UndoableIntent` — reverse the effect of an app intent's action.
- `supportedModes` (property) — specify foreground / background / both via `IntentModes`.
- `IntentSystemContext.currentMode` — consult the current execution mode inside `perform()`.
- `allowedExecutionTargets` (property) — set to `IntentExecutionTargets` to pin which target may perform the intent (`.main`, `.appIntentsExtension`, `.widgetKitExtension`).

## App Entities

- `EntityCollection` — refer to large sets of entities efficiently, storing only identifiers and resolving on demand.
- `AppUnionValue` (and `@UnionValue` macro) — define union-type Shortcuts parameters with rich picker UI and custom metadata.
- `AppUnionValueCasesProviding` — cases enum for `AppUnionValue`.
- `IndexedEntityQuery` — system retrieves indexed entities by identifier from the Spotlight index.

## Errors

- `AppIntentError(description:)` — provide a localized failure description.
- Existing errors that conform to `CustomLocalizedStringResourceConvertible` can be wrapped.

## Companion framework deltas (WWDC 2026)

- **Foundation Models framework** — Swift API for on-device + Private Cloud Compute Apple models and Language-Model-protocol providers (Claude, Gemini). Multimodal, Vision tool calls, dynamic profiles.
- **Core AI framework** — OS-level model runtime for Apple Silicon. AOT compilation, zero-copy, stateful execution.
- **Evaluations framework** — `/documentation/evaluations`. Datasets, graders, hill-climbing for prompt optimization.
- **MLX** — Metal 4 + GPU Neural Accelerator. Distributed training over Thunderbolt RDMA. Better LLM fine-tuning.
