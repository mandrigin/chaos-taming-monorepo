import AppKit
import SwiftUI

/// Handles Cmd-V clipboard paste, importing images or text as input items.
enum ClipboardHandler {
    /// Reads the pasteboard and returns an InputItem + optional asset data.
    @MainActor
    static func importFromClipboard() -> (InputItem, Data?)? {
        let pasteboard = NSPasteboard.general

        // Try image first
        if let imageData = pasteboard.data(forType: .tiff)
            ?? pasteboard.data(forType: .png) {
            // Convert to PNG for storage
            guard let bitmapRep = NSBitmapImageRep(data: imageData),
                  let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                return nil
            }

            let filename = "clipboard-\(UUID().uuidString).png"
            let item = InputItem(
                type: .image,
                filename: filename,
                assetPath: filename
            )
            return (item, pngData)
        }

        // Try text
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let item = InputItem(
                type: .text,
                textContent: text
            )
            return (item, nil)
        }

        return nil
    }
}
