# InputForge — Product Specification

> Transform multi-modal inputs into structured project plans exported as OmniFocus-compatible TaskPaper.

## Overview

InputForge is a native macOS 26+ Swift/SwiftUI application. It ingests heterogeneous inputs (screenshots, documents, audio, video, mindmaps, Wardley maps, text), processes them through AI with persona-driven prompts, and outputs structured project plans in TaskPaper format compatible with OmniFocus.

---

## Architecture

- **App type**: Multi-document NSDocument-based macOS app
- **UI**: SwiftUI with AppKit bridging for NSDocument lifecycle
- **Context segregation**: Work vs Personal — permanent per project, separate Gemini API keys
- **AI Backend**:
  - Google Gemini API (cloud) — primary
  - Apple Foundation Models (local, macOS 26+) — secondary/offline
- **Persona system**: name + system prompt, affects all AI output
  - Built-in personas: CPO, Engineer, Parent, Homeowner
  - Custom personas supported

---

## Core Workflow (Wizard)

### Step 1: Context Fork
- Choose **Work** or **Personal**
- Locks UI theme, API key, and default persona for the project
- Permanent per project (cannot change after creation)

### Step 2: Input Stage
- Drag-and-drop zone for all supported input types
- Clipboard paste support
- In-app audio recording
- Each input gets:
  - Auto-generated thumbnail
  - 0..N sticky-note annotations (user-added context)
- Scrollable tray/grid layout for managing inputs

### Step 3: Analyze
- Process all inputs + annotations through active persona
- Output: structured project plan + uncertainty flags + clarity score
- Auto-version created on every analysis run
- Progress indicator during processing

### Step 4: Interrogation Mode (Optional)
- Chat-style Q&A interface with AI
- Multi-modal replies (AI can reference specific inputs)
- Running summary displayed alongside chat
- Live clarity score updates as conversation progresses
- "Done Refining" button exits and triggers re-analysis

### Step 5: Preview & Export
- TaskPaper hierarchy preview (rendered, not raw text)
- Copy to clipboard
- Save as .taskpaper file
- Version history browser with diff between versions

---

## Supported Input Types

| Type | Formats | Notes |
|------|---------|-------|
| Documents | .pdf, .docx, .txt, .md, .rtf, .pages | Text extraction |
| Images | .png, .jpg, .jpeg, .heic, .webp, .tiff | Vision analysis |
| Screenshots | (same as images) | Captured or dropped |
| Audio | .m4a, .mp3, .wav, .aac | In-app recording + file drop |
| Video | .mp4, .mov | Frame extraction + audio transcription |
| Text | Direct paste / typed | Inline text input |
| Mindmap files | .mindnode, .mm, .opml | Structure extraction |
| Mindmap screenshots | (image formats) | Vision-based extraction |
| Wardley map screenshots | (image formats) | Vision-based extraction |
| Chat messages | Pasted text | Conversation extraction |

---

## Output Structure

```
Project
├── Description
├── Milestone 1
│   ├── Deliverable 1.1
│   │   ├── Task 1.1.1
│   │   │   ├── Next Action (GTD) @context(mac)
│   │   │   └── Next Action (GTD) @context(calls)
│   │   └── Task 1.1.2
│   └── Deliverable 1.2
└── Milestone 2
    └── ...
```

Hierarchy: Project → Description → Milestones → Deliverables → Tasks → Next Actions (GTD)

---

## TaskPaper Export Format

```taskpaper
Project Name:
	Description line as note
	Milestone 1:
		Deliverable 1.1:
			- Task 1.1.1 @due(2025-03-15) @estimate(2h) @context(mac) @type(development) @persona(Engineer)
				Note providing additional context
			- Task 1.1.2 @defer(2025-03-10) @flagged @context(calls) @type(coordination)
		Deliverable 1.2:
			- Task 1.2.1 @estimate(30m) @context(anywhere)
	Milestone 2:
		...
```

### Supported Tags
- `@due(date)` — Due date
- `@defer(date)` — Defer/start date
- `@context(name)` — GTD context
- `@estimate(duration)` — Time estimate
- `@flagged` — Flagged/priority
- `@type(category)` — Task type (development, design, coordination, research, etc.)
- `@persona(name)` — Which persona generated this

### Notes
- Notes on indented lines below their task
- Must be OmniFocus-compatible (tested against OmniFocus import)

---

## Version History

- **Auto-version**: Created on every Analyze run
- **Stored per version**:
  - Full structured output
  - Timestamp
  - Active persona
  - Clarity score
  - Input snapshot (references, not copies)
- **Diff view**: Side-by-side or inline diff between any two versions
- **Restore**: Non-destructive — restoring creates a new version

---

## Data Model

### File Format
- Extension: `.inputforge` (package/bundle) or `.inputforge.json` + companion assets folder
- Preferred: Package bundle (`.inputforge` directory presented as single file)

### Package Structure
```
MyProject.inputforge/
├── project.json          # Main project data
├── assets/               # Input files (copied into package)
│   ├── screenshot-1.png
│   ├── recording-1.m4a
│   └── ...
└── versions/             # Version history snapshots
    ├── v001.json
    ├── v002.json
    └── ...
```

### project.json Schema
```json
{
  "id": "uuid",
  "name": "Project Name",
  "context": "work|personal",
  "createdAt": "ISO8601",
  "modifiedAt": "ISO8601",
  "persona": {
    "name": "Engineer",
    "systemPrompt": "..."
  },
  "inputs": [
    {
      "id": "uuid",
      "type": "image|document|audio|video|text|mindmap|wardleyMap|chat",
      "filename": "screenshot-1.png",
      "assetPath": "assets/screenshot-1.png",
      "annotations": [
        { "id": "uuid", "text": "This shows the current login flow", "createdAt": "ISO8601" }
      ],
      "addedAt": "ISO8601"
    }
  ],
  "currentAnalysis": {
    "plan": { "...structured output..." },
    "clarityScore": 0.85,
    "uncertaintyFlags": ["unclear timeline", "missing budget info"],
    "version": 3
  },
  "interrogation": {
    "messages": [
      { "role": "user|assistant", "content": "...", "timestamp": "ISO8601" }
    ],
    "summary": "Running summary text"
  }
}
```

### Security
- API keys stored in macOS Keychain only (never in project files)
- Separate keychain items for Work and Personal Gemini API keys

---

## Design Language

**Aesthetic**: Teenage Engineering / Cyberdeck / DIY Glitch

- Industrial, utilitarian feel
- Lo-fi textures and grain overlays
- Exposed-grid layouts
- Monospaced type accents (system mono, SF Mono)
- High-contrast color palette
- Subtle glitch/scan-line effects on transitions
- Chunky, tactile UI elements (knobs, switches, thick borders)
- Dark mode primary, light mode secondary
- Work context: orange/amber accent
- Personal context: teal/cyan accent

---

## Key Frameworks

| Framework | Purpose |
|-----------|---------|
| SwiftUI | Primary UI |
| AppKit (bridged) | NSDocument lifecycle, file handling |
| Foundation Models | Local AI inference (macOS 26+) |
| AVFoundation | Audio recording, video frame extraction |
| Speech | Audio transcription |
| Vision | Image/screenshot analysis, OCR |
| UniformTypeIdentifiers | File type identification |
| Security (Keychain) | API key storage |
| CryptoKit | UUID generation, hashing |

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘N | New project |
| ⌘O | Open project |
| ⌘V | Paste input (context-aware) |
| ⌘⇧A | Run analysis |
| ⌘⇧Q | Enter interrogation mode |
| ⌘⇧E | Export to TaskPaper |
| ⌘⇧R | Start/stop audio recording |
| ⌘⇧P | Switch persona |
| ⌘⇧V | Open version history |

---

## Acceptance Criteria

### Context Fork
- [ ] New project requires Work/Personal selection before proceeding
- [ ] Context is permanent — no UI to change after creation
- [ ] UI theme changes based on context (orange for Work, teal for Personal)
- [ ] Correct API key is used based on context

### Input Handling
- [ ] Drag-and-drop works for all supported file types
- [ ] Clipboard paste adds input items
- [ ] In-app audio recording with waveform visualization
- [ ] Thumbnails auto-generated for all visual inputs
- [ ] Sticky-note annotations can be added/edited/deleted per input
- [ ] Input tray scrolls and supports reordering

### Analysis
- [ ] All inputs + annotations sent to AI with active persona prompt
- [ ] Structured plan output matches the defined hierarchy
- [ ] Uncertainty flags identified and displayed
- [ ] Clarity score computed and displayed (0.0–1.0)
- [ ] Auto-version created on each analysis
- [ ] Progress indicator shown during processing

### Persona System
- [ ] Four built-in personas available
- [ ] Custom personas can be created/edited/deleted
- [ ] Active persona affects all AI interactions
- [ ] Persona shown in analysis output and TaskPaper tags

### Interrogation Mode
- [ ] Chat UI with message history
- [ ] Multi-modal AI responses
- [ ] Running summary updates live
- [ ] Clarity score updates live
- [ ] "Done Refining" triggers re-analysis

### TaskPaper Export
- [ ] Valid TaskPaper syntax
- [ ] All supported tags present where applicable
- [ ] Notes properly indented
- [ ] OmniFocus import tested and working
- [ ] Copy to clipboard works
- [ ] Save to file works

### Version History
- [ ] Auto-version on every Analyze
- [ ] Version list with timestamps and clarity scores
- [ ] Diff view between any two versions
- [ ] Restore creates new version (non-destructive)

### Project Persistence
- [ ] .inputforge package bundle saves/loads correctly
- [ ] Assets copied into package on input
- [ ] Recent documents tracked by macOS
- [ ] Document dirty state tracked properly

### Keyboard Shortcuts
- [ ] All listed shortcuts functional
- [ ] No conflicts with system shortcuts
- [ ] Shortcuts shown in menu bar

---

## Implementation Phases

1. **Data model + document persistence** — InputForgeDocument, .inputforge.json read/write
2. **Context fork UI + theme system** — Work/Personal selection, themed UI
3. **Input stage** — Drag-drop, clipboard, audio recording, thumbnails, annotations
4. **AI integration layer** — Gemini API client, persona injection, structured output parsing
5. **Analyze flow** — Process inputs → structured plan → uncertainty flags → clarity score
6. **Interrogation mode** — Chat UI, multi-modal replies, live updates
7. **TaskPaper export** — Preview, copy, save
8. **Version history** — Auto-version, diff, restore
9. **Settings** — API keys in Keychain, persona management, AI backend selection
10. **Polish** — Cyberdeck design language, keyboard shortcuts, error handling
