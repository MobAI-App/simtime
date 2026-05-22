import SwiftUI

struct WorldClockTab: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let cities: [(name: String, tz: TimeZone)] = [
        ("Cupertino",  TimeZone(identifier: "America/Los_Angeles")!),
        ("New York",   TimeZone(identifier: "America/New_York")!),
        ("London",     TimeZone(identifier: "Europe/London")!),
        ("Warsaw",     TimeZone(identifier: "Europe/Warsaw")!),
        ("Tokyo",      TimeZone(identifier: "Asia/Tokyo")!),
        ("Auckland",   TimeZone(identifier: "Pacific/Auckland")!),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    bigClock
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    ForEach(cities, id: \.name) { city in
                        cityRow(city.name, tz: city.tz)
                        Divider().background(Color.gray.opacity(0.3))
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("World Clock")
            .toolbarTitleDisplayMode(.large)
        }
        .onReceive(timer) { now = $0 }
    }

    private var bigClock: some View {
        VStack(spacing: 4) {
            Text(now, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
                .font(.system(size: 72, weight: .thin, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Text(now, format: .dateTime.weekday(.wide).month(.wide).day(.defaultDigits).year(.defaultDigits))
                .font(.title3.weight(.medium))
                .foregroundStyle(.gray)
        }
    }

    private func cityRow(_ name: String, tz: TimeZone) -> some View {
        let offsetSecs = tz.secondsFromGMT(for: now) - TimeZone.current.secondsFromGMT(for: now)
        let offsetH = Double(offsetSecs) / 3600
        let label = offsetH == 0 ? "Today" : (offsetH > 0 ? "+\(formatOffset(offsetH)) HRS" : "\(formatOffset(offsetH)) HRS")

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(name)
                    .font(.title2.weight(.regular))
                    .foregroundStyle(.white)
            }
            Spacer()
            Text(now, format: .dateTime.hour().minute().locale(Locale(identifier: "en_US")))
                .environment(\.timeZone, tz)
                .font(.system(size: 48, weight: .thin, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
    }

    private func formatOffset(_ h: Double) -> String {
        if h == floor(h) { return String(format: "%.0f", h) }
        return String(format: "%.1f", h)
    }
}
