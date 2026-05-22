import Foundation

/// Parses shorthand durations used by `simtime travel`. Grammar:
///
///   <sign>? <number> <unit> ( <number> <unit> )*
///
/// where `<sign>` is `+` or `-` (default `+`), `<number>` is an integer, and
/// `<unit>` is `d`, `h`, `m`, or `s`. Whitespace allowed between segments.
///
/// Examples that parse:
///   "+7d"        → 7 days
///   "-3h"        → -3 hours
///   "1d12h30m"   → 1 day 12 hours 30 minutes
///   "90s"        → 90 seconds
///
/// Deliberately rejects calendar units (`mo`, `y`) - the Feb-30 problem is real
/// and `freeze` is the right tool for calendar moves.
public enum DurationParser {
    public enum ParseError: Error, CustomStringConvertible {
        case empty
        case invalidUnit(String)
        case calendarUnit(String)
        case malformed(String)

        public var description: String {
            switch self {
            case .empty:
                return "duration is empty"
            case .invalidUnit(let u):
                return "unknown unit '\(u)' - expected d/h/m/s"
            case .calendarUnit(let u):
                return "calendar unit '\(u)' not supported (use `freeze` for calendar moves)"
            case .malformed(let s):
                return "malformed duration '\(s)'"
            }
        }
    }

    public static func parse(_ raw: String) throws -> TimeInterval {
        var s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { throw ParseError.empty }

        var sign: TimeInterval = 1
        if s.hasPrefix("+") { s.removeFirst() }
        else if s.hasPrefix("-") { sign = -1; s.removeFirst() }
        s = s.replacingOccurrences(of: " ", with: "")
        guard !s.isEmpty else { throw ParseError.empty }

        var total: TimeInterval = 0
        var numberBuf = ""

        for ch in s {
            if ch.isASCII && (ch.isNumber || ch == ".") {
                numberBuf.append(ch)
            } else if ch.isLetter {
                guard let value = Double(numberBuf) else {
                    throw ParseError.malformed(raw)
                }
                numberBuf = ""
                let unit = String(ch).lowercased()
                switch unit {
                case "d": total += value * 86400
                case "h": total += value * 3600
                case "m": total += value * 60
                case "s": total += value
                case "y", "w":
                    throw ParseError.calendarUnit(unit)
                default:
                    throw ParseError.invalidUnit(unit)
                }
            } else {
                throw ParseError.malformed(raw)
            }
        }

        // Trailing number with no unit = bare seconds is too ambiguous; reject.
        if !numberBuf.isEmpty {
            throw ParseError.malformed(raw)
        }
        return sign * total
    }
}
