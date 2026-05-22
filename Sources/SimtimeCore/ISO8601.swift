import Foundation

/// Lenient ISO 8601 parsing. `ISO8601DateFormatter` is picky about combinations
/// of fractional seconds and time zones; we try a small set of common shapes
/// and fall back to a clear error.
public enum ISO8601 {
    public enum ParseError: Error, CustomStringConvertible {
        case malformed(String)
        public var description: String {
            switch self {
            case .malformed(let s): return "not a valid ISO 8601 timestamp: '\(s)'"
            }
        }
    }

    public static func parse(_ raw: String) throws -> Date {
        for opts in candidateOptions {
            let f = ISO8601DateFormatter()
            f.formatOptions = opts
            if let d = f.date(from: raw) { return d }
        }
        throw ParseError.malformed(raw)
    }

    public static func format(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    private static let candidateOptions: [ISO8601DateFormatter.Options] = [
        [.withInternetDateTime, .withFractionalSeconds],
        [.withInternetDateTime],
        [.withInternetDateTime, .withFractionalSeconds, .withTimeZone],
    ]
}
