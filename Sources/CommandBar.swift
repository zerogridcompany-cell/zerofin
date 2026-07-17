import SwiftUI

/// パネル下部の入力欄。⌘F で音声、テキストも打てる。AI応答も表示。
struct CommandBar: View {
    @Environment(DataStore.self) private var store
    @Environment(VoiceInput.self) private var voice
    @State private var text = ""
    @State private var answer: String?
    @State private var thinking = false
    @State private var focusValue: Int?
    @State private var focusLabel: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let answer {
                AnswerBubble(text: answer, thinking: false)
            } else if thinking {
                AnswerBubble(text: "考え中…", thinking: true)
            } else if let v = focusValue, let l = focusLabel {
                FocusResult(label: l, value: v)
            }

            HStack(spacing: 10) {
                Button(action: toggleVoice) {
                    Image(systemName: voice.state == .listening ? "waveform.circle.fill" : "mic.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(voice.state == .listening ? .red : .secondary)
                        .symbolEffect(.pulse, isActive: voice.state == .listening)
                }
                .buttonStyle(.plain)

                TextField(voice.state == .listening ? (voice.partial.isEmpty ? "聞いています…" : voice.partial) : "finance に聞く…",
                          text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($focused)
                    .onSubmit { run(text) }

                if voice.state == .listening {
                    Text("●REC").font(.system(size: 9, weight: .bold)).foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 0.5))
        }
    }

    private func toggleVoice() {
        voice.toggle { spoken in run(spoken) }
    }

    private func run(_ raw: String) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = ""
        answer = nil
        focusValue = nil
        guard !q.isEmpty else { return }
        switch Intent.parse(q) {
        case .showEverything:
            focusValue = nil; focusLabel = nil    // 全体表示は既にパネルに出ている
        case .metric(_, let label, let getter):
            focusLabel = label
            focusValue = getter(store.snapshot)
        case .freeform(let question):
            thinking = true
            Task {
                let a = await AIResponder.ask(question, context: store.snapshot)
                await MainActor.run { self.answer = a; self.thinking = false }
            }
        }
    }
}

private struct FocusResult: View {
    let label: String
    let value: Int
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            Text(Yen.full(value))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct AnswerBubble: View {
    let text: String
    let thinking: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(.purple)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(thinking ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}
