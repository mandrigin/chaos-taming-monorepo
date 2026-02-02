import AppKit
import AVFoundation
import Foundation
import PDFKit
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

    // MARK: - Document Text Extraction

    /// Extract text from a document based on file extension.
    static func extractTextFromDocument(_ data: Data, filename: String?) -> String? {
        let ext = filename?.split(separator: ".").last?.lowercased() ?? ""

        switch ext {
        case "pdf":
            return extractTextFromPDF(data)
        case "rtf":
            return extractTextFromRichText(data, documentType: .rtf)
        case "doc":
            return extractTextFromRichText(data, documentType: .docFormat)
        case "docx":
            return extractTextFromDocx(data, filename: filename)
        case "txt", "md", "markdown", "text":
            return String(data: data, encoding: .utf8)
        default:
            return nil
        }
    }

    private static func extractTextFromPDF(_ data: Data) -> String? {
        guard let pdfDoc = PDFDocument(data: data) else { return nil }
        var text = ""
        for i in 0..<pdfDoc.pageCount {
            if let page = pdfDoc.page(at: i), let pageText = page.string {
                if !text.isEmpty { text += "\n" }
                text += pageText
            }
        }
        return text.isEmpty ? nil : text
    }

    private static func extractTextFromRichText(_ data: Data, documentType: NSAttributedString.DocumentType) -> String? {
        guard let attrString = try? NSAttributedString(
            data: data,
            options: [.documentType: documentType],
            documentAttributes: nil
        ) else { return nil }
        let text = attrString.string
        return text.isEmpty ? nil : text
    }

    private static func extractTextFromDocx(_ data: Data, filename: String?) -> String? {
        // NSAttributedString can read DOCX from a file URL on macOS
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(filename ?? "\(UUID().uuidString).docx")
        do {
            try data.write(to: tempFile)
            defer { try? FileManager.default.removeItem(at: tempFile) }

            let attrString = try NSAttributedString(
                url: tempFile,
                options: [:],
                documentAttributes: nil
            )
            let text = attrString.string
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    // MARK: - Mindmap Extraction

    /// Extract structured text from mindmap/outline files.
    static func extractTextFromMindmap(_ data: Data, filename: String?) -> String? {
        let ext = filename?.split(separator: ".").last?.lowercased() ?? ""

        switch ext {
        case "opml":
            return extractTextFromOPML(data)
        case "mm":
            return extractTextFromFreeMind(data)
        default:
            return nil
        }
    }

    private static func extractTextFromOPML(_ data: Data) -> String? {
        guard let xmlDoc = try? XMLDocument(data: data) else { return nil }
        guard let body = try? xmlDoc.nodes(forXPath: "//body").first else { return nil }

        var lines: [String] = []
        extractOPMLOutlines(from: body, depth: 0, into: &lines)
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private static func extractOPMLOutlines(from node: XMLNode, depth: Int, into lines: inout [String]) {
        guard let element = node as? XMLElement else { return }
        for child in element.children ?? [] {
            guard let outline = child as? XMLElement, outline.name == "outline" else { continue }
            let text = outline.attribute(forName: "text")?.stringValue ?? outline.attribute(forName: "_note")?.stringValue ?? ""
            if !text.isEmpty {
                let indent = String(repeating: "  ", count: depth)
                lines.append("\(indent)- \(text)")
            }
            extractOPMLOutlines(from: outline, depth: depth + 1, into: &lines)
        }
    }

    private static func extractTextFromFreeMind(_ data: Data) -> String? {
        guard let xmlDoc = try? XMLDocument(data: data) else { return nil }
        guard let root = try? xmlDoc.nodes(forXPath: "//node").first else { return nil }

        var lines: [String] = []
        extractFreeMindNodes(from: root, depth: 0, into: &lines)
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private static func extractFreeMindNodes(from node: XMLNode, depth: Int, into lines: inout [String]) {
        guard let element = node as? XMLElement else { return }
        let text = element.attribute(forName: "TEXT")?.stringValue ?? ""
        if !text.isEmpty {
            let indent = String(repeating: "  ", count: depth)
            lines.append("\(indent)- \(text)")
        }
        for child in element.children ?? [] {
            guard let childElement = child as? XMLElement, childElement.name == "node" else { continue }
            extractFreeMindNodes(from: childElement, depth: depth + 1, into: &lines)
        }
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
            case .document:
                if let text = extractTextFromDocument(data, filename: input.filename) {
                    document.setExtractedText(text, forInputId: input.id)
                }
            case .mindmap:
                if let text = extractTextFromMindmap(data, filename: input.filename) {
                    document.setExtractedText(text, forInputId: input.id)
                }
            default:
                break
            }
        }
    }
}
