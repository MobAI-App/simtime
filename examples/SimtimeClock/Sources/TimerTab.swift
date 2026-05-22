import SwiftUI

struct TimerTab: View {
    @State private var hours = 0
    @State private var minutes = 5
    @State private var seconds = 0
    @State private var fireAt: Date? = nil
    @State private var now = Date()
    @State private var didFire = false
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var isRunning: Bool { fireAt != nil }

    private var remaining: TimeInterval {
        guard let fireAt else { return TimeInterval(hours * 3600 + minutes * 60 + seconds) }
        return max(0, fireAt.timeIntervalSince(now))
    }

    var body: some View {
        NavigationStack {
            VStack {
                if isRunning {
                    countdownView
                } else {
                    pickerView
                }
                Spacer()
                actionButtons
                    .padding(.bottom, 32)
            }
            .navigationTitle("Timer")
            .toolbarTitleDisplayMode(.large)
            .onReceive(timer) { d in
                now = d
                if let fireAt, !didFire, d >= fireAt {
                    didFire = true
                }
            }
            .alert("Timer's up", isPresented: $didFire) {
                Button("OK") { reset() }
            } message: {
                Text("Fired at \(fireAt ?? now, format: .dateTime.hour().minute().second())")
            }
        }
    }

    private var countdownView: some View {
        VStack(spacing: 16) {
            Text(formatRemaining(remaining))
                .font(.system(size: 90, weight: .thin, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            if let fireAt {
                Label(fireAt.formatted(date: .omitted, time: .shortened), systemImage: "bell.fill")
                    .foregroundStyle(.gray)
            }
        }
        .padding(.top, 60)
    }

    private var pickerView: some View {
        HStack(spacing: 0) {
            wheel(value: $hours, range: 0..<24, label: "hours")
            wheel(value: $minutes, range: 0..<60, label: "min")
            wheel(value: $seconds, range: 0..<60, label: "sec")
        }
        .padding(.top, 60)
    }

    private func wheel(value: Binding<Int>, range: Range<Int>, label: String) -> some View {
        ZStack(alignment: .trailing) {
            Picker("", selection: value) {
                ForEach(range, id: \.self) { v in
                    Text(String(format: "%02d", v))
                        .font(.system(size: 32, weight: .regular).monospacedDigit())
                        .foregroundStyle(.white)
                        .tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            Text(label)
                .foregroundStyle(.white)
                .padding(.trailing, 8)
        }
    }

    private var actionButtons: some View {
        HStack {
            Button(action: reset) {
                Text("Cancel")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(Circle().fill(Color.gray.opacity(0.3)))
                    .overlay(Circle().stroke(.gray, lineWidth: 1))
            }
            .disabled(!isRunning)

            Spacer()

            Button(action: toggle) {
                Text(isRunning ? "Stop" : "Start")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(Circle().fill((isRunning ? Color.red : Color.green).opacity(0.3)))
                    .overlay(Circle().stroke(isRunning ? .red : .green, lineWidth: 1))
            }
            .disabled(!isRunning && hours == 0 && minutes == 0 && seconds == 0)
        }
        .padding(.horizontal, 32)
    }

    private func toggle() {
        if isRunning {
            reset()
        } else {
            let total = TimeInterval(hours * 3600 + minutes * 60 + seconds)
            fireAt = Date().addingTimeInterval(total)
            didFire = false
        }
    }

    private func reset() {
        fireAt = nil
        didFire = false
    }

    private func formatRemaining(_ t: TimeInterval) -> String {
        let total = Int(ceil(t))
        let h = total / 3600
        let m = (total / 60) % 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
