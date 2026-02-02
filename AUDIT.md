# SPEC.md vs Implementation — Gap Analysis

**Auditor**: polecat/jasper
**Date**: 2026-02-02
**Branch**: `polecat/jasper/ch-3vq2@ml57h4fq`
**Bead**: ch-3vq2

---

## Structural Issue: Dual Package Layout

The repository has **two competing SPM packages** that both define `@main`:

| Location | Package.swift | Files | Document Type |
|----------|---------------|-------|---------------|
| `Sources/InputForge/` (top-level) | `Package.swift` | 3 stub files | `FileDocument` (flat JSON) |
| `InputForge/Sources/InputForge/` | `InputForge/Package.swift` | 27 full files | `ReferenceFileDocument` (package bundle) |

The **top-level `Package.swift`** builds the **stub**, not the full implementation. Both have `@main struct InputForgeApp`. The audit below evaluates the **full implementation** in `InputForge/Sources/InputForge/`, but the build configuration means only the stub may actually compile as the primary target.

Additionally, `Info.plist` declares the UTType as conforming to `public.json`, while the code declares it as conforming to `.package`. This mismatch may cause the `.inputforge` bundle format to not work correctly with Finder/macOS.

---

## 1. IMPLEMENTED

Features fully present in code with working UI/logic.

### Context Fork
- **Work/Personal selection required** — `ContentView.swift:14`: `ContextForkView` gates access to workspace via `document.hasChosenContext`.
- **Context is permanent** — `InputForgeDocument.swift:174`: `setContext()` has `guard !hasChosenContext else { return }`. No UI exists to change context after creation.
- **UI theme changes by context** — `Theme.swift:11-19`: Work = orange (hue 0.08), Personal = teal (hue 0.5). Injected via `Environment(\.forgeTheme)`.
- **Correct API key per context** — `GeminiAIService.swift:8-9`: Takes `ProjectContext`, uses `KeychainService.retrieveAPIKey(for: context)`.

### Input Handling (Basic)
- **Clipboard paste** — `ClipboardHandler.swift`: Handles image (tiff/png) and plain text. Wired via `onPasteCommand` in `ContentView.swift:217`.
- **Annotations add/edit/delete** — `AnnotationEditorView.swift`: Full CRUD — add via text field, double-click to edit, swipe to delete.

### Persona System (Data + Settings)
- **Four built-in personas** — `Persona.swift:18-55`: CPO, Engineer, Parent, Homeowner with system prompts.
- **Custom personas CRUD** — `PersonaStore.swift`: `add()`, `update()`, `delete()` with `UserDefaults` persistence. `SettingsView.swift:96-151`: Full settings UI with editor sheet.

### AI Backend
- **Gemini API client** — `GeminiAIService.swift`: Full implementation with multi-modal support, retry with exponential backoff, rate limit handling, timeout.
- **Foundation Models client** — `FoundationModelsAIService.swift`: Uses `LanguageModelSession` for on-device inference.
- **AI backend picker** — `SettingsView.swift:253-292`: UI for selecting between Gemini and Foundation Models. Persisted via `UserDefaults`.
- **AIService protocol** — `AIService.swift:77-94`: `analyze()` and `chat()` methods, `isAvailable` property.

### API Key Management
- **Keychain storage** — `KeychainService.swift`: Full Keychain API integration with separate Work/Personal items. Store, retrieve, delete, check existence.
- **Settings UI** — `SettingsView.swift:22-92`: Separate Work and Personal key entry fields with save/clear.

### Data Model (Types)
- **Full type hierarchy** — `AnalysisResult.swift`: `ProjectPlan -> Milestone -> Deliverable -> PlanTask -> NextAction` matches SPEC.md hierarchy.
- **ProjectData** — `ProjectData.swift`: All spec fields: id, name, context, dates, persona, inputs, currentAnalysis, interrogation.
- **InputItem** — `InputItem.swift`: All spec fields: id, type, filename, assetPath, textContent, annotations, addedAt.
- **InputType enum** — All 9 types from spec: document, image, screenshot, audio, video, text, mindmap, wardleyMap, chat.
- **InterrogationState** — `InterrogationMessage.swift`: Messages with role/content/timestamp, summary string.
- **VersionSnapshot** — `VersionSnapshot.swift`: versionNumber, timestamp, personaName, clarityScore, plan, uncertaintyFlags, inputRefs.

### AI Prompt Building
- **Analysis prompts** — `PromptBuilder.swift:17-29`: Builds system prompt with persona + JSON schema instructions, user content with input descriptions.
- **Chat prompts** — `PromptBuilder.swift:41-69`: Builds interrogation context with history replay.
- **Multi-modal support** — `PromptBuilder.swift:79-106`: `buildMultiModalAnalysisContent()` attaches image data.
- **Response parsing** — `AIResponseParser.swift`: JSON extraction, clarity score computation, structured plan parsing.

### Keyboard Shortcuts (Menu Items)
- **Forge menu** — `InputForgeCommands.swift`: All 6 custom shortcuts registered as menu items with correct key combos (Cmd-Shift-A/Q/E/R/P/V).
- **Audio recording shortcut** — `ContentView.swift:182-188`: Cmd-Shift-R is wired to `AudioRecordingService.toggle()` via `NotificationCenter`.

### Design Language (Partial Elements)
- **Scan-line overlay** — `Theme.swift:51-68`: Canvas-based horizontal scan lines at 0.035 opacity.
- **Grain overlay** — `Theme.swift:71-93`: Canvas-based static film grain at 0.02 opacity.
- **Monospaced type accents** — Used consistently throughout all views (`.system(.*, design: .monospaced)`).
- **Dark mode primary** — `ContentView.swift:25`: `.preferredColorScheme(.dark)`.
- **Orange/teal color scheme** — Implemented in `ForgeTheme`.

### Package Persistence (Model Layer)
- **Package bundle read/write** — `InputForgeDocument.swift:64-141`: `ReferenceFileDocument` with `FileWrapper`-based read/write for project.json, assets/, versions/.
- **Asset staging** — `InputForgeDocument.swift:146-160`: `pendingAssets` dictionary queued for next save.
- **Version snapshot serialization** — Written as `v001.json`, `v002.json` etc.
- **Restore creates new version** — `InputForgeDocument.swift:200-209`: `restoreVersion()` creates new version number.

---

## 2. PARTIAL

Features partially implemented — key pieces missing.

### Drag-and-Drop
- **Present**: `InputDropZone.swift` and `InputTrayView.swift` accept file drops via `.onDrop`. `InputTypeDetector` handles documents, images, audio, video, mindmaps.
- **Missing**: File type detection covers most spec types but there is no specific handling for Wardley map files (they would be detected as images, which is probably correct since spec says "Vision-based extraction"). Chat message files have no distinct format to detect.

### Audio Recording
- **Present**: `AudioRecordingService.swift` — records M4A via AVFoundation. `AudioRecordingBar` shows recording indicator with pseudo-animated waveform bars.
- **Missing**: Waveform visualization is **fake** — uses `sin()` of elapsed time, not actual audio levels. No `AVAudioRecorder.isMeteringEnabled` or level sampling. Spec says "waveform visualization."

### Thumbnails
- **Present**: `InputTrayItemView.thumbnailView` renders a visual per input type.
- **Missing**: All thumbnails are **SF Symbol placeholders** (e.g., `photo.fill` for images). No actual image thumbnail generation from file data. Spec says "auto-generated thumbnail" which implies real previews.

### Input Tray Reordering
- **Present**: `InputSidebarView` has `.onMove` on the sidebar list (supports drag reorder). `InputTrayView` grid items have `.draggable()`.
- **Missing**: The grid itself lacks a corresponding `.onDrop` for reorder between items — you can drag items but can't drop them to reorder within the grid.

### Analysis Flow
- **Present**: Full backend — `PromptBuilder`, `AIResponseParser`, `AIService` protocol, `GeminiAIService`, `FoundationModelsAIService`. `InputForgeDocument.setAnalysisResult()` creates version snapshots.
- **Missing**: **No analysis controller/view** — nothing wires the "Analyze" menu item notification (`.runAnalysis`) to actually calling `AIService.analyze()`, building prompts, parsing results, and updating the document. The `AnalysisPreviewPlaceholder` is literally a placeholder text view.

### Interrogation Mode
- **Present**: Data model (`InterrogationState`, `InterrogationMessage`), prompt building (`PromptBuilder.buildChatMessages()`), AI service `chat()` method.
- **Missing**: **No interrogation UI** — no chat view, no message list, no input field, no "Done Refining" button. The `.enterInterrogation` notification is posted but nothing handles it.

### Version History
- **Present**: `VersionSnapshot` model, `InputForgeDocument.versions` array, `setAnalysisResult()` auto-creates snapshots, `restoreVersion()` is non-destructive.
- **Missing**: **No version history UI** — no version list view, no diff view, no restore button. The `.showVersionHistory` notification is posted but nothing handles it.

### Keyboard Shortcuts (Handling)
- **Present**: All 6 Forge menu shortcuts defined with correct key combos. Audio recording shortcut is wired.
- **Missing**: 5 of 6 shortcuts post `NotificationCenter` events that **nothing listens for** (runAnalysis, enterInterrogation, exportTaskPaper, switchPersona, showVersionHistory). Only `toggleAudioRecording` is handled.
- **Conflict**: `Cmd-Shift-Q` conflicts with macOS system shortcut for "Log Out User."

### Design Language
- **Present**: Scan lines, grain, monospaced fonts, dark mode, orange/teal themes, thick borders on context cards.
- **Missing**: No "chunky, tactile UI elements (knobs, switches)" beyond context cards. No glitch effects on transitions (scan lines are static background, not transition animations). "Exposed-grid layouts" not clearly present. Design is applied to context fork and toolbar but not uniformly to all views.

### Project Persistence (Info.plist)
- **Present**: `Info.plist` declares `com.inputforge.project` UTType with `.inputforge` extension.
- **Missing**: Info.plist says `UTTypeConformsTo: public.json` but code uses `conformingTo: .package`. Package bundles need to conform to `com.apple.package` for Finder to treat them as opaque files. The current mismatch means `.inputforge` directories may show as folders, not files.

---

## 3. MISSING

Features not implemented at all.

### TaskPaper Export
- **No code exists** for generating TaskPaper syntax from `ProjectPlan`/`AnalysisResult`.
- No export view, no `.taskpaper` file writing, no clipboard copy of TaskPaper format.
- No OmniFocus compatibility testing infrastructure.
- The `@persona(name)` tag generation is absent.
- The `.exportTaskPaper` notification posts but nothing handles it.

### Analysis UI
- No progress indicator during AI processing.
- No view to display analysis results (plan hierarchy, uncertainty flags, clarity score).
- `AnalysisPreviewPlaceholder` is a literal placeholder with text "ANALYSIS RESULTS".

### Interrogation Mode UI
- No chat interface.
- No multi-modal AI response display.
- No running summary sidebar.
- No live clarity score display.
- No "Done Refining" button.

### Version History UI
- No version list view with timestamps and clarity scores.
- No diff view between versions (side-by-side or inline).
- No restore UI (model method exists, but no button/view triggers it).

### Persona Switcher (In-Document)
- Settings allows creating/managing personas, but there is **no in-document persona picker** — the `.switchPersona` notification is unhandled. The toolbar shows the current persona name but provides no way to change it.

### Supported Framework Usage
- **AVFoundation**: Used for recording only. No **video frame extraction** (spec mentions video inputs with "frame extraction + audio transcription").
- **Speech**: Not imported or used anywhere. Spec lists it for "audio transcription."
- **Vision**: Not imported or used anywhere. Spec lists it for "image/screenshot analysis, OCR."
- **CryptoKit**: Not imported. Spec lists it for "UUID generation, hashing" (though `Foundation.UUID` is used directly).

---

## 4. EXTRA

Features implemented but not specified in SPEC.md.

### Foundation Models AI Backend
- `FoundationModelsAIService.swift` — full on-device AI client using Apple's Foundation Models framework. The spec mentions it under Architecture but provides no acceptance criteria for it specifically. The settings UI for backend selection is also extra relative to acceptance criteria (though it aligns with the Architecture section).

### Dual Package Structure
- The repo has two separate SPM packages — one at the root (`Sources/InputForge/` with stub files) and one inside `InputForge/` (with the full implementation). The stub package appears to be vestigial from an earlier phase.

### Notification-Based Command Dispatch
- `InputForgeCommands.swift` establishes a `NotificationCenter`-based pattern for dispatching menu commands. This is an implementation pattern choice not specified in the spec.

---

## Summary Table

| Category | Implemented | Partial | Missing | Total Criteria |
|----------|------------|---------|---------|----------------|
| Context Fork | 4 | 0 | 0 | 4 |
| Input Handling | 2 | 4 | 0 | 6 |
| Analysis | 0 | 4 | 2 | 6 |
| Persona System | 2 | 2 | 0 | 4 |
| Interrogation Mode | 0 | 1 | 4 | 5 |
| TaskPaper Export | 0 | 0 | 6 | 6 |
| Version History | 0 | 2 | 2 | 4 |
| Project Persistence | 0 | 3 | 1 | 4 |
| Keyboard Shortcuts | 1 | 1 | 1 | 3 |
| Design Language | 5 | 2 | 2 | 9 |
| Data Model | 3 | 0 | 0 | 3 |
| **TOTAL** | **17** | **19** | **18** | **54** |

**Overall completion: ~31% fully implemented, ~35% partial, ~33% missing.**

---

## Priority Gaps (Recommended Fix Order)

1. **Build structure** — Resolve dual-package layout so the full implementation actually compiles as the primary target.
2. **Info.plist UTType** — Change `UTTypeConformsTo` from `public.json` to `com.apple.package` for proper bundle handling.
3. **Analysis flow** — Wire up the Analyze command to AIService, add progress indicator and results view.
4. **TaskPaper export** — Implement TaskPaper syntax generation, preview, copy, and save.
5. **Interrogation mode UI** — Build chat interface with live summary and clarity score.
6. **Version history UI** — Build version list, diff view, and restore button.
7. **Persona switcher** — Handle `.switchPersona` notification with in-document picker.
8. **Real thumbnails** — Generate actual image thumbnails instead of SF Symbol placeholders.
9. **Wire remaining shortcuts** — Handle the 5 unhandled notification events.
10. **Framework integration** — Add Vision (OCR), Speech (transcription), AVFoundation (video frames).
