# InputForge — Product Specification

## Overview

InputForge is a macOS application for designing, testing, and exporting complex input device configurations. It targets game controllers, accessibility devices, flight sticks, steering wheels, and other HID peripherals.

## Architecture

- **Platform**: macOS 26+
- **Language**: Swift 6.2, SwiftUI app lifecycle
- **Build system**: Swift Package Manager (no .xcodeproj)
- **Document model**: FileDocument-based multi-document architecture via SwiftUI `DocumentGroup`
- **Sandbox**: App sandbox enabled

## Document Format

- **Extension**: `.inputforge`
- **UTI**: `com.inputforge.project` (conforms to `public.json`)
- **Content**: JSON file with project metadata and configuration

## Project Structure

```
Package.swift                        Swift Package Manager manifest
Info.plist                           UTI and document type declarations (for Xcode)
Sources/
└── InputForge/
    ├── App/
    │   ├── InputForgeApp.swift      SwiftUI App with DocumentGroup
    │   └── InputForgeDocument.swift FileDocument implementation
    ├── Views/
    │   └── ContentView.swift        Document content view
    ├── Models/                      Data models (Phase 2)
    └── Services/                    Business logic (Phase 2)
```

## Phase 1: Scaffolding (Current)

- Swift Package Manager project with SwiftUI DocumentGroup
- FileDocument implementation saving JSON
- Custom UTI registration for .inputforge
- `swift build` compiles successfully
- Open Package.swift in Xcode to run the app

## Verification Criteria

- `swift build` compiles without errors
- App launches and shows empty document window
- Cmd-N creates new document
- Cmd-S saves .inputforge file
- Cmd-O reopens saved document
- Multiple documents open simultaneously
