import SwiftUI

struct StopwatchTab: View {
    @State private var startedAt: Date? = nil
    @State private var accumulated: TimeInterval = 0  // total elapsed when paused
    @State private var laps: [TimeInterval] = []
    @State private var now = Date()
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var isRunning: Bool { startedAt != nil }

    private var elapsed: TimeInterval {
        if let startedAt {
            return accumulated + now.timeIntervalSince(startedAt)
        }
        return accumulated
    }

    var body: some View {
        NavigationStack {
            VStack {
                Text(format(elapsed))
                    .font(.system(size: 80, weight: .thin, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.top, 60)

                Spacer()

                HStack {
                    actionButton(
                        title: laps.isEmpty && !isRunning && accumulated == 0 ? "Lap" : (isRunning ? "Lap" : "Reset"),
                        color: .gray
                    ) {
                        if isRunning {
                            laps.insert(elapsed, at: 0)
                        } else {
                            accumulated = 0
                            laps = []
                        }
                    }
                    .disabled(!isRunning && accumulated == 0 && laps.isEmpty)

                    Spacer()

                    actionButton(
                        title: isRunning ? "Stop" : "Start",
                        color: isRunning ? .red : .green
                    ) {
                        if isRunning, let startedAt {
                            accumulated += now.timeIntervalSince(startedAt)
                            self.startedAt = nil
                        } else {
                            startedAt = Date()
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 8)

                if !laps.isEmpty {
                    lapList
                        .padding(.top, 24)
                }
            }
            .navigationTitle("Stopwatch")
            .toolbarTitleDisplayMode(.large)
            .onReceive(timer) { now = $0 }
        }
    }

    private var lapList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(laps.enumerated()), id: \.offset) { idx, lap in
                    HStack {
                        Text("Lap \(laps.count - idx)")
                            .foregroundStyle(.white)
                        Spacer()
                        Text(format(lap))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    Divider().background(Color.gray.opacity(0.3))
                }
            }
        }
        .frame(maxHeight: 250)
    }

    private func actionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(Circle().fill(color.opacity(0.3)))
                .overlay(Circle().stroke(color, lineWidth: 1))
        }
    }

    private func format(_ t: TimeInterval) -> String {
        let totalMs = Int((t * 100).rounded())
        let cs = totalMs % 100
        let total = totalMs / 100
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%d:%02d:%02d.%02d", h, m, s, cs)
        }
        return String(format: "%02d:%02d.%02d", m, s, cs)
    }
}
