import XCTest
@testable import SimtimeCore

final class StateTests: XCTestCase {
    func test_realPassesThrough() {
        let s = SimtimeState(mode: .real)
        let now = Date()
        XCTAssertEqual(s.mockTime(forReal: now), now)
    }

    func test_frozenIgnoresReal() {
        let frozen = Date(timeIntervalSince1970: 1_700_000_000)
        let s = SimtimeState(mode: .frozen, frozenAt: frozen)
        XCTAssertEqual(s.mockTime(forReal: Date()), frozen)
    }

    func test_scaledLinearMapping() {
        let realAnchor = Date(timeIntervalSince1970: 1_700_000_000)
        let mockAnchor = Date(timeIntervalSince1970: 1_800_000_000)
        let s = SimtimeState(
            mode: .scaled,
            scaledRealAnchor: realAnchor,
            scaledMockAnchor: mockAnchor,
            scale: 60
        )
        // 10 real seconds later → 600 mock seconds later
        let real10 = realAnchor.addingTimeInterval(10)
        XCTAssertEqual(s.mockTime(forReal: real10), mockAnchor.addingTimeInterval(600))
    }

    func test_roundTripJSON() throws {
        let original = SimtimeState(
            mode: .scaled,
            scaledRealAnchor: Date(timeIntervalSince1970: 1_700_000_000),
            scaledMockAnchor: Date(timeIntervalSince1970: 1_800_000_000),
            scale: 60,
            revision: 7
        )
        let store = StateStore(udid: "TEST-UDID", bundleID: "io.simtime.test")
        try store.save(original)
        defer { try? store.clear() }
        let loaded = try store.load()
        XCTAssertEqual(loaded, original)
    }
}
