import ArgumentParser
import Foundation
import SimtimeCore

struct Simtime: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "simtime",
        abstract: "Control the wall-clock an iOS Simulator app sees.",
        discussion: """
        simtime mocks the time APIs (gettimeofday, clock_gettime, +[NSDate date])
        inside a target app on a booted iOS Simulator, so you can collapse
        7-day trials, jump to expired states, or speed up timers without
        rebuilding the app.

        State lives at /private/tmp/simtime-<udid>-<bundle>.json - the same
        path is visible on the host and inside the simulator. The runtime
        dylib reloads state automatically.
        """,
        subcommands: [Inject.self, Freeze.self, Travel.self, Scale.self, Reset.self, Status.self],
        defaultSubcommand: Status.self
    )
}

// MARK: - Shared options

struct TargetOptions: ParsableArguments {
    @Option(name: [.short, .long], help: "Simulator UDID (xcrun simctl list devices).")
    var udid: String

    @Option(name: [.short, .long], help: "Target app bundle identifier.")
    var bundle: String

    func store() -> StateStore {
        StateStore(udid: udid, bundleID: bundle)
    }
}

// MARK: - freeze

struct Freeze: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Freeze the app's clock at an exact ISO 8601 instant."
    )

    @OptionGroup var target: TargetOptions

    @Argument(help: "ISO 8601 timestamp, e.g. 2026-01-01T10:00:00Z.")
    var datetime: String

    func run() throws {
        let when = try ISO8601.parse(datetime)
        let store = target.store()
        let state = try store.update { s in
            s.mode = .frozen
            s.frozenAt = when
            s.scaledRealAnchor = nil
            s.scaledMockAnchor = nil
            s.scale = nil
        }
        print("frozen at \(ISO8601.format(when))  (rev \(state.revision))")
    }
}

// MARK: - travel

struct Travel: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Shift the app's clock by a duration (+7d, -3h, 90m, …)."
    )

    @OptionGroup var target: TargetOptions

    @Argument(help: "Signed duration: +7d, -3h, 1d12h30m, 90s.")
    var offset: String

    func run() throws {
        let delta = try DurationParser.parse(offset)
        let store = target.store()
        let realNow = Date()
        let state = try store.update { s in
            // If we're not already mocked, anchor on real-now then jump.
            let basis: Date
            switch s.mode {
            case .real:
                basis = realNow
            case .frozen:
                basis = s.frozenAt ?? realNow
            case .scaled:
                basis = s.mockTime(forReal: realNow)
            }
            // travel implies freeze if not already frozen - predictable semantics.
            s.mode = .frozen
            s.frozenAt = basis.addingTimeInterval(delta)
            s.scaledRealAnchor = nil
            s.scaledMockAnchor = nil
            s.scale = nil
        }
        print("traveled by \(offset)  →  \(ISO8601.format(state.frozenAt!))  (rev \(state.revision))")
    }
}

// MARK: - scale

struct Scale: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Run the app's clock at N× real time."
    )

    @OptionGroup var target: TargetOptions

    @Argument(help: "Scale factor (e.g. 60 = 1 real-second is 60 app-seconds; 0.5 = half-speed).")
    var factor: Double

    func run() throws {
        guard factor > 0 else {
            throw ValidationError("scale factor must be > 0")
        }
        let store = target.store()
        let realNow = Date()
        let state = try store.update { s in
            let mockBasis = s.mockTime(forReal: realNow)
            s.mode = .scaled
            s.scaledRealAnchor = realNow
            s.scaledMockAnchor = mockBasis
            s.scale = factor
            s.frozenAt = nil
        }
        print("scale=\(factor)× anchored at \(ISO8601.format(state.scaledMockAnchor!))  (rev \(state.revision))")
    }
}

// MARK: - reset

struct Reset: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Stop mocking - app returns to real system time."
    )

    @OptionGroup var target: TargetOptions

    func run() throws {
        let store = target.store()
        let state = try store.update { s in
            s.mode = .real
            s.frozenAt = nil
            s.scaledRealAnchor = nil
            s.scaledMockAnchor = nil
            s.scale = nil
        }
        print("reset  (rev \(state.revision))")
    }
}

// MARK: - status

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show what the app currently sees."
    )

    @OptionGroup var target: TargetOptions

    @Flag(help: "Emit JSON for machine consumption.")
    var json: Bool = false

    func run() throws {
        let store = target.store()
        let state = try store.load()
        let realNow = Date()
        let mock = state.mockTime(forReal: realNow)

        if json {
            struct Out: Encodable {
                let mode: String
                let real: String
                let mock: String
                let scale: Double?
                let revision: UInt64
                let path: String
            }
            let out = Out(
                mode: state.mode.rawValue,
                real: ISO8601.format(realNow),
                mock: ISO8601.format(mock),
                scale: state.scale,
                revision: state.revision,
                path: store.path
            )
            let data = try JSONEncoder().encode(out)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } else {
            print("mode:     \(state.mode.rawValue)")
            print("real now: \(ISO8601.format(realNow))")
            print("mock now: \(ISO8601.format(mock))")
            if let scale = state.scale { print("scale:    \(scale)×") }
            print("revision: \(state.revision)")
            print("state:    \(store.path)")
        }
    }
}

Simtime.main()
