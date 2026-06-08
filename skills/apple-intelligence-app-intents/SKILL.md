---
name: apple-intelligence-app-intents
description: Use when writing or reviewing Swift code that integrates with Apple Intelligence, Siri AI, or the App Intents framework on iOS 26 / iPadOS 26 / macOS 26 (WWDC 2026). Covers AppIntent / AppEntity / AppEnum, App Shortcuts, app schema domains, on-screen context (`.appEntityIdentifier`), Spotlight indexing, Visual Intelligence, snippets, and the WWDC26 additions: `SyncableEntity`, `OwnershipProvidingEntity`, `EntityCollection`, `@UnionValue` / `AppUnionValue`, `LongRunningIntent`, `CancellableIntent`, `UndoableIntent`, `RunSystemShortcutIntent`, `supportedModes` / `IntentModes`, `allowedExecutionTargets` / `IntentExecutionTargets`, `IntentValueRepresentation`, `RelevantEntities`, `IndexedEntityQuery`, `AppIntentError`. Also covers the Foundation Models framework, Core AI framework, Evaluations and MLX updates from WWDC 2026. Trigger when the user mentions: App Intents, Siri AI, Apple Intelligence, AppEntity, AppShortcut, AssistantSchema, app schema, Foundation Models, on-device LLM, Visual Intelligence, or asks to expose an iOS/macOS app's actions to Siri / Spotlight / Shortcuts.
---

# Apple Intelligence + App Intents (WWDC 2026)

This skill encodes the WWDC 2026 / iOS 26 way of exposing an app's content and actions to **Apple Intelligence**, **Siri AI**, **Spotlight**, **Shortcuts**, **Visual Intelligence**, **widgets** and the **Action button**. It is the authoritative pattern reference — prefer these APIs over older `INIntent` / SiriKit / Intents.framework code.

## When to use this skill

Load this skill whenever you are about to:

- Define a new `AppIntent`, `AppEntity`, `AppEnum`, `AppShortcut` or `WidgetConfigurationIntent`.
- Make app data discoverable by Siri AI, Apple Intelligence, Spotlight, or Visual Intelligence.
- Adopt an **app schema domain** (`mail`, `photos`, `messages`, `browser`, `books`, `presentation`, `reader`, `spreadsheet`, `whiteboard`, `word-processor`, `journaling`, `maps`, `notes`, `phone`, `reminders`, `audio`, `clock`, `camera`, `files`, `assistant`, `visual-intelligence`, system/in-app search).
- Build an **interactive snippet**, **Live Activity progress**, **long-running upload**, **undoable action**, or **cancellable task** through App Intents.
- Use the new **Foundation Models** / **Core AI** / **Evaluations** / **MLX** frameworks announced at WWDC 2026.

Skip this skill for older SiriKit (`INIntent`, `IntentsUI`) code — those APIs are superseded.

## Hard rules

1. **One source of truth.** Put `AppIntent`, `AppEntity`, `AppEnum` and helpers in a **shared Swift package** that both the main app and every extension (widget, App Intents extension) import. Never duplicate intent declarations.
2. **Always adopt a schema when one fits.** Use `@AppEntity(schema: .photos.asset)` and `@AssistantIntent(schema:)` from the `app-schema-domains` list before defining a custom shape. Schemas are the contract Siri AI uses to match natural phrases.
3. **Make entities `Transferable`** with multiple representations (image / PDF / plainText / `ValueRepresentation`) so Apple Intelligence can move them between apps. Use `IntentValueRepresentation` for structured types like `PlaceDescriptor`.
4. **Stable IDs across devices.** If an entity travels in a Siri conversation that may continue on another device, conform to `SyncableEntity` (or use `SyncableEntityIdentifier<Local, Stable>`). Locally-generated UUIDs alone will break cross-device handoff.
5. **Guard destructive actions on shared content** with `OwnershipProvidingEntity` + `EntityOwnership` so Apple Intelligence prompts for confirmation.
6. **Mark execution target explicitly** with `static var allowedExecutionTargets: ExecutionTargets` (`.main`, `.appIntentsExtension`, `.widgetKitExtension`) — never let the system guess for write-capable intents.
7. **Pick the right base protocol:**
   - Default: `AppIntent`.
   - Opens app to a scene: `OpenIntent` (no `perform()` needed on iOS).
   - Runs > 30s or shows progress: `LongRunningIntent` (+ usually `CancellableIntent`).
   - Reversible action: `UndoableIntent`.
   - Returns a snippet UI: `... & ShowsSnippetIntent & ProvidesDialog` (returning a `SnippetIntent`).
   - Widget config: `WidgetConfigurationIntent`.
8. **Bulk operations: use `EntityCollection<T>`** instead of `[T]` so the system passes identifiers without resolving every entity.
9. **Spotlight: conform to `IndexedEntity`**, expose `@ComputedProperty(indexingKey:)` for built-in keys and `@ComputedProperty(customIndexingKey:)` for custom ones, then donate via `CSSearchableIndex.default().indexAppEntities(...)`.
10. **On-screen context: attach `.appEntityIdentifier(EntityIdentifier(for: T.self, identifier: id))`** to every view that shows an entity so Siri can resolve "this one" / "the second one".
11. **Errors:** throw `AppIntentError(description:)` with a localized string; wrap underlying errors that conform to `CustomLocalizedStringResourceConvertible`.
12. **Foundation Models calls** must use prompt caching and structured `@Generable` outputs; do not roll a custom JSON parser around the LLM response. See `references/foundation-models.md`.

## File layout

```
MyAppPackage/
├── Sources/
│   ├── MyAppCore/           // models, persistence, no App Intents imports
│   ├── MyAppIntents/        // AppEntity / AppIntent / AppEnum / queries
│   └── MyAppSnippets/       // SwiftUI snippet views + SnippetIntents
└── Package.swift
```

The main app and every extension link `MyAppIntents`; only the main app links the snippet/UI layer.

## Decision flow

```
User says “expose action X to Siri / Shortcuts / Spotlight” →
  1. Is there a matching schema in app-schema-domains? → use it (@AppEntity(schema:), @AssistantIntent(schema:))
  2. Otherwise define a custom AppIntent and AppEntity
  3. Pick base protocols (LongRunning? Undoable? Open? SnippetIntent? WidgetConfig?)
  4. Add Transferable + Spotlight + onscreen modifier
  5. Wire an AppShortcut in AppShortcutsProvider with phrases
  6. Set allowedExecutionTargets
  7. Donate (IndexAppEntities + intent donation on use)
```

## Quick reference — canonical snippets

The following snippets are the shape Apple uses in the official "TravelTracking" WWDC26 sample. Adapt parameter names but keep the protocol/property structure intact.

### A basic OpenIntent

```swift
public struct OpenLandmarkIntent: OpenIntent {
    public static let title: LocalizedStringResource = "Open Landmark"
    public init() {}

    @Parameter(title: "Landmark", requestValueDialog: "Which landmark?")
    public var target: LandmarkEntity

    public init(target: LandmarkEntity) { self.target = target }

    #if os(macOS)
    @Dependency var navigator: Navigator
    public func perform() async throws -> some IntentResult {
        await navigator.navigate(to: target)
        return .result()
    }
    #endif
}
```

On iOS/iPadOS/Catalyst, `OpenIntent` requires no `perform()`.

### AppEntity adopting a schema with Spotlight indexing

```swift
@AppEntity(schema: .photos.asset)
public struct PhotoEntity: IndexedEntity, SyncableEntity {
    public var id: Int  // stable across devices

    @ComputedProperty(indexingKey: \.displayName)
    public var name: String { /* … */ }

    @ComputedProperty(indexingKey: \.contentDescription)
    public var description: String { /* … */ }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Photo", numericFormat: "\(placeholder: .int) photos")
    }
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    public static let defaultQuery = PhotoEntityQuery()
}
```

### Transferable with multiple representations

See `references/transferable.md` for the full multi-rep example (`FileRepresentation` PDF, `DataRepresentation` image / plainText, `ValueRepresentation` for `PlaceDescriptor`).

### EntityCollection for bulk ops

```swift
@Parameter(title: "Photos", requestValueDialog: "Which photo?")
var photos: EntityCollection<PhotoEntity>
// later:
await modelData.tagPhotos(ids: photos.identifiers, tag: tag)
```

### Union-value parameter

```swift
@UnionValue
enum TravelGalleryContent {
    case landmarkCollection(LandmarkCollectionEntity)
    case photoAlbum(PhotoAlbumEntity)
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Travel Gallery" }
    static let caseDisplayRepresentations: [Cases: DisplayRepresentation] = [
        .landmarkCollection: "Landmark Collection",
        .photoAlbum: "Photo Album"
    ]
}
```

Use inside a `WidgetConfigurationIntent` with a `Switch(\.$content)` parameter summary.

### Long-running + cancellable + progress

```swift
public struct UploadPhotoIntent: LongRunningIntent, CancellableIntent {
    public static let title: LocalizedStringResource = "Upload Photo"
    @Parameter(requestValueDialog: "Which photo?") public var photo: IntentFile
    public init() {}
    public init(photo: IntentFile) { self.photo = photo }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try await performBackgroundTask { @Sendable in
            progress.totalUnitCount = Int64(chunks)
            for chunk in 1...chunks {
                try await uploadChunk(chunk)
                progress.completedUnitCount = Int64(chunk)
                progress.localizedAdditionalDescription = "Uploaded \(Int((Double(chunk)/Double(chunks))*100))%"
            }
            return "Uploaded successfully!"
        } onCancel: { reason in
            cleanup(for: reason)   // reason is IntentCancellationReason
        }
        return .result(dialog: "\(result)")
    }
}
```

### Undoable intent

```swift
public struct UpdateFavoriteIntent: AppIntent, UndoableIntent {
    public func perform() async throws -> some IntentResult { /* apply */ ; .result() }
    public func undo() async throws { /* reverse with same parameters */ }
}
```

### Snippet intent (interactive overlay)

```swift
public func perform() async throws -> some ReturnsValue<LandmarkEntity> & ShowsSnippetIntent & ProvidesDialog {
    let landmark = await findClosest()
    return .result(
        value: landmark,
        dialog: IntentDialog(full: "The closest landmark is \(landmark.name).",
                             supporting: "Located in \(landmark.continent)."),
        snippetIntent: LandmarkSnippetIntent(landmark: landmark)
    )
}
```

### On-screen context

```swift
ScrollView { /* landmark content */ }
    .appEntityIdentifier(EntityIdentifier(for: LandmarkEntity.self, identifier: landmark.id))
```

For galleries:

```swift
GalleryHorizontalListView(
    items: list,
    entityIdentifier: { EntityIdentifier(for: LandmarkEntity.self, identifier: $0.id) }
)
```

### Execution target

```swift
static var allowedExecutionTargets: ExecutionTargets { .main }
// or .appIntentsExtension, .widgetKitExtension, or a union
```

### Spotlight donation

```swift
try await CSSearchableIndex.default().indexAppEntities(landmarkEntities)
```

### Visual Intelligence query

```swift
struct LandmarkIntentValueQuery: IntentValueQuery {
    @Dependency var modelData: ModelData
    func values(for input: SemanticContentDescriptor) async throws -> [VisualSearchResult] {
        guard let pixelBuffer = input.pixelBuffer else { return [] }
        return try await modelData.search(matching: pixelBuffer)
    }
}
```

## WWDC 2026 — what is new (cheat sheet)

| Area | New API | Use it when |
|---|---|---|
| Apple Intelligence | `SyncableEntity`, `SyncableEntityIdentifier` | Conversation continues on another device |
| Apple Intelligence | `OwnershipProvidingEntity`, `EntityOwnership` | Destructive action on shared content |
| Apple Intelligence | `RelevantEntities` | Suggest media during workouts / contexts |
| Apple Intelligence | `IntentValueRepresentation` | Bridge entity to structured intent values |
| Apple Intelligence | `app-schema-domains` (books, browser, journaling, presentation, reader, spreadsheet, whiteboard, word-processor, …) | Match the domain instead of inventing one |
| App Intents | `RunSystemShortcutIntent` | Trigger App Shortcuts from a widget |
| App Intents | `LongRunningIntent` + `performBackgroundTask(options:operation:)` | Multi-minute work with Live Activity progress |
| App Intents | `CancellableIntent` + `IntentCancellationReason` | Clean up on cancel/timeout |
| App Intents | `UndoableIntent` | Reversible action |
| App Intents | `supportedModes` / `IntentModes` + `IntentSystemContext.currentMode` | Run in foreground / background / both |
| App Intents | `allowedExecutionTargets` / `IntentExecutionTargets` | Pin write intents to the main app |
| App Entities | `EntityCollection` | Bulk operations by identifier |
| App Entities | `@UnionValue` / `AppUnionValue` / `AppUnionValueCasesProviding` | Parameter that accepts several entity types |
| App Entities | `IndexedEntityQuery` | Resolve entities by Spotlight identifier |
| Errors | `AppIntentError(description:)` | Localized failure message |

## Companion frameworks (WWDC 2026)

- **Foundation Models** — Swift API for on-device + private-cloud Apple models, plus pluggable providers (Claude, Gemini). Multimodal (images), Vision tool calls (OCR, barcodes), dynamic profiles (swap model/tools/instructions mid-session). See `references/foundation-models.md`.
- **Core AI** — OS-level framework for loading/specializing/running custom models on Apple Silicon. AOT compilation, zero-copy, stateful execution.
- **Evaluations** — `/documentation/evaluations`. Define datasets + graders, integrate into CI, hill-climb prompts.
- **MLX** — Metal 4 + GPU Neural Accelerator, distributed training over Thunderbolt RDMA.

## Required testing

For any new intent, also write tests with `AppIntentsTesting`:

```swift
import AppIntentsTesting
let result = try await TestIntent(MyIntent(target: sampleEntity)).perform()
```

## See also (load on demand)

- `references/transferable.md` — multi-representation `Transferable` recipe
- `references/schemas.md` — full list of schema domains and how to pick one
- `references/foundation-models.md` — on-device LLM patterns with prompt caching and `@Generable`
- `references/wwdc26-changes.md` — full verbatim changelog from `/documentation/Updates/AppIntents`

## Anti-patterns to flag in code review

- Using `INIntent` / SiriKit `Intents.framework` for new code → migrate to App Intents.
- Defining `[MyEntity]` parameters for bulk ops → use `EntityCollection<MyEntity>`.
- Local-only UUIDs on entities used in Siri AI conversations → add `SyncableEntity`.
- Writing custom JSON serialization for entity → use `Transferable` + `IntentValueRepresentation`.
- Long upload/network work inside a plain `AppIntent` → use `LongRunningIntent` + `CancellableIntent`.
- Spotlight `CSSearchableItem` boilerplate → use `IndexedEntity` + `indexAppEntities(_:)`.
- Hard-coded "open the app" logic → use `OpenIntent` (no `perform()` needed on iOS).
- Skipping `allowedExecutionTargets` on a widget-triggered write → pin to `.main`.
- Inventing a custom schema when `mail` / `photos` / `messages` / `books` / `browser` / `presentation` / `reader` / `spreadsheet` / `whiteboard` / `word-processor` / `journaling` / `maps` / `notes` / `phone` / `reminders` / `audio` / `clock` / `camera` / `files` already fits.
