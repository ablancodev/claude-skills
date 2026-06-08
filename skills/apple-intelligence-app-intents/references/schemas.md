# App schema domains (WWDC 2026)

Schemas are the **contract** between your app and Apple Intelligence / Siri AI. Adopt one and Siri can match natural phrases automatically. Invent your own only when nothing fits.

## Apple-Intelligence-and-Siri-AI domains

These domains expose actions to Siri AI (system-wide voice & assistant matching):

| Domain | Use for |
|---|---|
| `audio` | Audio playback (play, pause, skip, set track) |
| `calendar` | Calendar events |
| `camera` | Camera capture |
| `clock` | Alarms, timers |
| `files` | File management actions |
| `mail` | Email actions |
| `maps` | Navigation |
| `messages` | Messaging |
| `notes` | Note taking |
| `phone` | Calling |
| `photos` | Photo + video management (entity: `photos.asset`) |
| `reminders` | Reminders |
| System / in-app search | Searching your app's content |

## Single-purpose domains

| Domain | Use for |
|---|---|
| `assistant` | Voice-based conversational app launched from iPhone side button (Japan) |
| `visual-intelligence` | Show search results when camera points at content |

## Shortcuts-only domains

These appear in the Shortcuts app but are not (yet) matched by Siri AI conversation:

| Domain | Use for |
|---|---|
| `books` | Ebook reader |
| `browser` | Web browser |
| `journaling` | Journal entries |
| `presentation` | Slide decks |
| `reader` | Document viewer |
| `spreadsheet` | Spreadsheets |
| `whiteboard` | Whiteboards |
| `word-processor` | Word processors |

## How to adopt

```swift
@AppEntity(schema: .photos.asset)
public struct PhotoEntity: IndexedEntity, SyncableEntity { /* … */ }

@AssistantIntent(schema: .messages.sendMessage)
struct SendMessageIntent: AppIntent { /* … */ }
```

The schema gives the system a vocabulary and parameter shape. You may extend with extra `@Parameter`s, but **do not rename** the schema-required properties — Siri AI matches phrases to those names.

## Picking the right schema

1. Search the domain list above for the noun ("photo" → `photos`, "doc" → `word-processor` or `reader`).
2. Open the domain page in the docs and pick the intent or entity schema that matches the verb ("send" → `messages.sendMessage`).
3. If nothing matches the verb but the noun does, define a custom intent on the schema entity — keep the entity's schema-conformant shape.
4. Only when neither the noun nor verb appears, define a fully custom `AppEntity` + `AppIntent` (no schema).
