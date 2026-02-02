# InputForge — Product Specification

## Overview

InputForge is a macOS application for designing, testing, and exporting complex input device configurations. It targets game controllers, accessibility devices, flight sticks, steering wheels, and other HID peripherals.

## Architecture

- **Platform**: macOS 26+
- **Language**: Swift 6, SwiftUI app lifecycle
- **Document model**: NSDocument-based multi-document architecture via SwiftUI `DocumentGroup`
- **Sandbox**: App sandbox enabled with user-selected file read/write

## Document Format

- **Extension**: `.inputforge`
- **UTI**: `com.inputforge.project` (conforms to `com.apple.package`)
- **Structure**: NSFileWrapper package directory containing:
  - `project.json` — project metadata and configuration
  - `assets/` — directory for associated asset files

## Project Structure

```
InputForge/
├── App/
│   ├── InputForgeApp.swift          SwiftUI App with DocumentGroup
│   ├── InputForgeDocument.swift     FileDocument implementation
│   └── ContentView.swift            Document content view
├── Models/                          Data models (Phase 2)
├── Views/                           UI views (Phase 2)
├── Services/                        Business logic services (Phase 2)
├── Resources/
│   └── Info.plist                   UTI and document type declarations
└── InputForge.entitlements          App sandbox entitlements
```

## Phase 1: Scaffolding (Current)

- Xcode project with SwiftUI DocumentGroup
- FileDocument implementation with package format
- Custom UTI registration for .inputforge
- App sandbox with file access entitlements
- Empty placeholder directories for Phase 2 modules

## Verification Criteria

- App launches and shows empty document window
- Cmd-N creates new document
- Cmd-S saves .inputforge package (directory containing project.json + assets/)
- Cmd-O reopens saved document
- Multiple documents open simultaneously
