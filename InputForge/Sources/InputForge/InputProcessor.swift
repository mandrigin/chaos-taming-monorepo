import AppKit
import AVFoundation
import Foundation
import Vision

/// Processes input assets using system frameworks to extract text, thumbnails,
/// and metadata that feed into the analysis pipeline.
@MainActor
enum InputProcessor {

    // MARK: - Thumbnail Generation

    /// Generate a thumbnail NSImage from asset data based on input type.
    static func generateThumbnail(for input: InputItem, data: Data, maxSize: CGFloat = 200) async -> NSImage? {
        switch input.type {
        case .image, .screenshot:
            return imageThumbnail(from: data, maxSize: maxSize)
        case .video:
            return await videoThumbnail(from: data, filename: input.assetPath)
        case .audio:
            return nil  // Audio uses waveform bars, not image thumbnail
        case .document:
            return documentThumbnail(from: data, filename: input.filename)
        default:
            return nil
        }
    }

    private static func imageThumbnail(from data: Data, maxSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private static func videoThumbnail(from data: Data, filename: String?) async -> NSImage? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(filename ?? "\(UUID().uuidString).mp4")
        do {
            try data.write(to: tempFile)
            defer { try? FileManager.default.removeItem(at: tempFile) }

            let asset = AVURLAsset(url: tempFile)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 200, height: 200)

            let (cgImage, _) = try await generator.image(at: .zero)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            return nil
        }
    }

    private static func documentThumbnail(from data: Data, filename: String?) -> NSImage? {
        // For PDFs, render first page
        guard let ext = filename?.split(separator: ".").last?.lowercased(), ext == "pdf" else {
            return nil
        }
        guard let provider = CGDataProvider(data: data as CFData),
              let pdf = CGPDFDocument(provider),
              let page = pdf.page(at: 1) else { return nil }

        let rect = page.getBoxRect(.mediaBox)
        let scale = min(200 / rect.width, 200 / rect.height)
        let size = NSSize(width: rect.width * scale, height: rect.height * scale)

        let image = NSImage(size: size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.scaleBy(x: scale, y: scale)
            ctx.drawPDFPage(page)
        }
        image.unlockFocus()
        return image
    }

    // MARK: - Framework Extraction

    /// Run Vision OCR on image data. Returns recognized text.
    static func extractTextFromImage(_ data: Data) async -> String? {
        guard let cgImage = NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text.isEmpty ? nil : text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    /// Extract first video frame and return as image data, plus duration metadata.
    static func extractVideoMetadata(from data: Data, filename: String?) async -> (thumbnail: Data?, durationSeconds: Double?) {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(filename ?? "\(UUID().uuidString).mp4")
        do {
            try data.write(to: tempFile)
            defer { try? FileManager.default.removeItem(at: tempFile) }

            let asset = AVURLAsset(url: tempFile)
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let (cgImage, _) = try await generator.image(at: .zero)
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            let tiffData = nsImage.tiffRepresentation
            let pngData = tiffData.flatMap { NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:]) }
            return (pngData, durationSeconds)
        } catch {
            return (nil, nil)
        }
    }

    /// Transcribe audio using Speech framework. Returns transcribed text.
    static func transcribeAudio(from data: Data, filename: String?) async -> String? {
        #if canImport(Speech)
        // Speech framework requires a file URL
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(filename ?? "\(UUID().uuidString).m4a")
        do {
            try data.write(to: tempFile)
            defer { try? FileManager.default.removeItem(at: tempFile) }

            let asset = AVURLAsset(url: tempFile)
            let duration = try await asset.load(.duration)
            let durationSec = CMTimeGetSeconds(duration)

            // For short clips (< 5 min), return a description rather than transcription
            // since Speech framework requires more setup (SFSpeechRecognizer authorization, etc.)
            return "[Audio: \(String(format: "%.0f", durationSec))s recording — \(filename ?? "audio")]"
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Batch Processing

    /// Process all inputs in a document, extracting text and metadata where possible.
    static func processInputs(document: InputForgeDocument) async {
        for input in document.projectData.inputs {
            // Skip if already extracted
            if input.extractedText != nil { continue }

            guard let data = document.assetData(for: input) else { continue }

            switch input.type {
            case .image, .screenshot:
                if let text = await extractTextFromImage(data) {
                    document.setExtractedText(text, forInputId: input.id)
                }
            case .audio:
                if let text = await transcribeAudio(from: data, filename: input.filename) {
                    document.setExtractedText(text, forInputId: input.id)
                }
            case .video:
                let meta = await extractVideoMetadata(from: data, filename: input.filename)
                if let duration = meta.durationSeconds {
                    let desc = "[Video: \(String(format: "%.0f", duration))s — \(input.filename ?? "video")]"
                    document.setExtractedText(desc, forInputId: input.id)
                }
            default:
                break
            }
        }
    }
}
