import AVFoundation
import SwiftUI

/// Manages in-app audio recording using AVFoundation.
@Observable
@MainActor
final class AudioRecordingService {
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var lastError: String?
    /// Rolling buffer of normalized audio levels (0.0–1.0) for waveform display.
    var audioLevels: [CGFloat] = Array(repeating: 0, count: 12)

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var tempURL: URL?

    /// Toggle recording on/off. Returns the recorded file URL when stopping, nil when starting.
    func toggle() -> URL? {
        if isRecording {
            return stopRecording()
        } else {
            startRecording()
            return nil
        }
    }

    private func startRecording() {
        let filename = "recording-\(UUID().uuidString).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        tempURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            isRecording = true
            recordingDuration = 0
            audioLevels = Array(repeating: 0, count: 12)
            lastError = nil
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.recordingDuration += 0.1
                    self.updateMetering()
                }
            }
        } catch {
            isRecording = false
            lastError = "Recording failed: \(error.localizedDescription)"
        }
    }

    private func updateMetering() {
        guard let recorder else { return }
        recorder.updateMeters()
        // averagePower returns dB in range roughly -160...0
        let dB = recorder.averagePower(forChannel: 0)
        // Normalize to 0.0–1.0 (treat -50 dB as silence, 0 dB as max)
        let normalized = CGFloat(max(0, min(1, (dB + 50) / 50)))
        audioLevels.removeFirst()
        audioLevels.append(normalized)
    }

    private func stopRecording() -> URL? {
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        audioLevels = Array(repeating: 0, count: 12)
        let url = tempURL
        tempURL = nil
        return url
    }
}

/// A recording indicator bar shown during audio capture.
struct AudioRecordingBar: View {
    let duration: TimeInterval
    let audioLevels: [CGFloat]
    let onStop: () -> Void

    @Environment(\.forgeTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(ForgeColors.error)
                .frame(width: 10, height: 10)

            Text("RECORDING")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .tracking(1)

            Text(formattedDuration)
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()

            // Waveform visualization driven by real audio levels
            HStack(spacing: 2) {
                ForEach(0..<audioLevels.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(theme.accent.opacity(0.7))
                        .frame(width: 3, height: barHeight(for: i))
                        .animation(.easeOut(duration: 0.08), value: audioLevels[i])
                }
            }
            .frame(height: 20)

            Spacer()

            Button(action: onStop) {
                Image(systemName: "stop.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ForgeColors.error)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            Rectangle()
                .fill(ForgeColors.surface)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ForgeColors.border)
                .frame(height: 1)
        }
    }

    private var formattedDuration: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let level = index < audioLevels.count ? audioLevels[index] : 0
        return 4 + level * 16
    }
}
