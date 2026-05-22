import Foundation

/// Wire format shared between the CLI (writer) and the runtime dylib (reader).
///
/// One file per (udid, bundleID) at `/private/tmp/simtime-<udid>-<bundleid>.json`.
/// The path is identical on host and inside the simulator's filesystem (same
/// `/private/tmp` mount), so no path translation is needed.
public struct SimtimeState: Codable, Equatable {
    public enum Mode: String, Codable {
        case real    // pass-through, no mocking
        case frozen  // app sees `frozenAt` regardless of real time
        case scaled  // app time advances at `scale` × real time from anchors
    }

    public var mode: Mode

    /// When `mode == .frozen`: the wall-clock instant the app should see.
    public var frozenAt: Date?

    /// When `mode == .scaled`: the real-time instant we anchored the scale at.
    /// App-time(realNow) = scaledMockAnchor + scale * (realNow - scaledRealAnchor)
    public var scaledRealAnchor: Date?
    public var scaledMockAnchor: Date?
    public var scale: Double?

    /// Set every time the state changes; runtime watches mtime + this counter.
    public var revision: UInt64

    public init(
        mode: Mode = .real,
        frozenAt: Date? = nil,
        scaledRealAnchor: Date? = nil,
        scaledMockAnchor: Date? = nil,
        scale: Double? = nil,
        revision: UInt64 = 0
    ) {
        self.mode = mode
        self.frozenAt = frozenAt
        self.scaledRealAnchor = scaledRealAnchor
        self.scaledMockAnchor = scaledMockAnchor
        self.scale = scale
        self.revision = revision
    }

    /// The mock time corresponding to a given real-time instant. Pure function -
    /// safe to call from inside hooks. Returns `realNow` if `mode == .real`.
    public func mockTime(forReal realNow: Date) -> Date {
        switch mode {
        case .real:
            return realNow
        case .frozen:
            return frozenAt ?? realNow
        case .scaled:
            guard let realAnchor = scaledRealAnchor,
                  let mockAnchor = scaledMockAnchor,
                  let scale = scale else { return realNow }
            let elapsed = realNow.timeIntervalSince(realAnchor)
            return mockAnchor.addingTimeInterval(elapsed * scale)
        }
    }
}

/// Locates and reads/writes the per-(udid,bundleID) state file. The same path
/// is visible from both the host (where the CLI runs) and inside the iOS
/// Simulator (where the runtime dylib runs) because `/private/tmp` is shared.
public struct StateStore {
    public let udid: String
    public let bundleID: String

    public init(udid: String, bundleID: String) {
        self.udid = udid
        self.bundleID = bundleID
    }

    public var path: String {
        // /private/tmp is writable, sticky, accessible from inside the sim.
        // No translation needed between host and guest namespace.
        "/private/tmp/simtime-\(udid)-\(bundleID).json"
    }

    public func load() throws -> SimtimeState {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            return SimtimeState()
        }
        let data = try Data(contentsOf: url)
        return try Self.decoder.decode(SimtimeState.self, from: data)
    }

    /// Atomic write: serialize to a temp file in the same dir, then rename. POSIX
    /// rename(2) is atomic, so a concurrent reader (the dylib) never sees a
    /// half-written file.
    public func save(_ state: SimtimeState) throws {
        let data = try Self.encoder.encode(state)
        let tmpPath = "\(path).tmp.\(getpid()).\(arc4random())"
        let tmpURL = URL(fileURLWithPath: tmpPath)
        try data.write(to: tmpURL, options: .atomic)
        // Move into place atomically.
        if rename(tmpPath, path) != 0 {
            let err = String(cString: strerror(errno))
            try? FileManager.default.removeItem(atPath: tmpPath)
            throw NSError(domain: "simtime.state", code: Int(errno),
                          userInfo: [NSLocalizedDescriptionKey: "rename: \(err)"])
        }
    }

    public func update(_ mutate: (inout SimtimeState) -> Void) throws -> SimtimeState {
        var state = (try? load()) ?? SimtimeState()
        mutate(&state)
        state.revision &+= 1
        try save(state)
        return state
    }

    public func clear() throws {
        try? FileManager.default.removeItem(atPath: path)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
