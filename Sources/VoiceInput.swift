import Foundation
import Speech
import AVFoundation
import Observation

/// ⌘F でマイク起動 → 日本語音声認識。最終確定テキストを transcript に流す。
@MainActor
@Observable
final class VoiceInput {
    enum State { case idle, listening, denied }
    var state: State = .idle
    var partial: String = ""      // 認識途中のテキスト
    var lastFinal: String = ""    // 確定テキスト

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var onFinal: ((String) -> Void)?

    func toggle(onFinal: @escaping (String) -> Void) {
        state == .listening ? stop() : start(onFinal: onFinal)
    }

    func start(onFinal: @escaping (String) -> Void) {
        self.onFinal = onFinal
        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            Task { @MainActor in
                guard let self else { return }
                guard auth == .authorized else { self.state = .denied; return }
                self.beginSession()
            }
        }
    }

    private func beginSession() {
        guard let recognizer, recognizer.isAvailable else { return }
        stopEngineOnly()
        partial = ""

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak req] buf, _ in
            req?.append(buf)
        }
        engine.prepare()
        do { try engine.start() } catch { state = .idle; return }
        state = .listening

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.partial = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.finish(self.partial)
                    }
                }
                if error != nil { self.finish(self.partial) }
            }
        }
    }

    private func finish(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        stop()
        if !trimmed.isEmpty {
            lastFinal = trimmed
            onFinal?(trimmed)
        }
    }

    func stop() {
        stopEngineOnly()
        if state == .listening { state = .idle }
    }

    private func stopEngineOnly() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }
}
