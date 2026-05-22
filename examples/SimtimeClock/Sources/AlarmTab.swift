import SwiftUI

struct Alarm: Identifiable, Equatable {
    let id = UUID()
    var time: Date
    var label: String
    var enabled: Bool
}

struct AlarmTab: View {
    @State private var now = Date()
    @State private var alarms: [Alarm] = [
        Alarm(time: cal(hour: 7, minute: 30), label: "Wake up", enabled: true),
        Alarm(time: cal(hour: 8, minute: 15), label: "Standup", enabled: true),
        Alarm(time: cal(hour: 18, minute: 0), label: "Stop working", enabled: false),
    ]
    @State private var firing: Alarm? = nil
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static func cal(hour: Int, minute: Int) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return c.date(from: comps) ?? Date()
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    nextAlarmHeader
                        .listRowBackground(Color.clear)
                }
                Section("All Alarms") {
                    ForEach($alarms) { $alarm in
                        AlarmRow(alarm: $alarm, now: now)
                    }
                }
            }
            .navigationTitle("Alarm")
            .toolbarTitleDisplayMode(.large)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .onReceive(timer) { d in
                now = d
                checkFiring()
            }
            .alert("Alarm - \(firing?.label ?? "")", isPresented: Binding(
                get: { firing != nil },
                set: { if !$0 { firing = nil } }
            )) {
                Button("Dismiss") { firing = nil }
            } message: {
                if let f = firing {
                    Text("It's \(f.time.formatted(date: .omitted, time: .shortened))")
                }
            }
        }
    }

    private var nextAlarmHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next = nextAlarm() {
                Text("Next alarm")
                    .font(.caption)
                    .foregroundStyle(.gray)
                HStack(alignment: .bottom) {
                    Text(next.time, format: .dateTime.hour().minute())
                        .font(.system(size: 54, weight: .thin, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                    Text("· \(next.label)")
                        .foregroundStyle(.gray)
                        .padding(.bottom, 14)
                }
                Text("in \(timeUntil(next.time))")
                    .foregroundStyle(.orange)
            } else {
                Text("No active alarms")
                    .foregroundStyle(.gray)
            }
        }
        .padding(.vertical, 6)
    }

    private func nextAlarm() -> Alarm? {
        alarms
            .filter { $0.enabled }
            .map { (alarm: $0, next: nextOccurrence(of: $0.time, after: now)) }
            .sorted { $0.next < $1.next }
            .first?.alarm
    }

    private func nextOccurrence(of time: Date, after: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: time)
        var todays = cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: after) ?? after
        if todays < after { todays = cal.date(byAdding: .day, value: 1, to: todays) ?? todays }
        return todays
    }

    private func timeUntil(_ d: Date) -> String {
        let secs = Int(d.timeIntervalSince(now))
        let h = secs / 3600
        let m = (secs / 60) % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private func checkFiring() {
        guard firing == nil else { return }
        for alarm in alarms where alarm.enabled {
            let cal = Calendar.current
            let nowC = cal.dateComponents([.hour, .minute], from: now)
            let aC = cal.dateComponents([.hour, .minute], from: alarm.time)
            if nowC.hour == aC.hour && nowC.minute == aC.minute {
                let secs = cal.component(.second, from: now)
                if secs < 5 {
                    firing = alarm
                    return
                }
            }
        }
    }
}

private struct AlarmRow: View {
    @Binding var alarm: Alarm
    let now: Date

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(alarm.time, format: .dateTime.hour().minute())
                    .font(.system(size: 38, weight: .light, design: .rounded).monospacedDigit())
                    .foregroundStyle(alarm.enabled ? .white : .gray)
                Text(alarm.label)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            Spacer()
            Toggle("", isOn: $alarm.enabled)
                .labelsHidden()
                .tint(.orange)
        }
        .padding(.vertical, 4)
    }
}
