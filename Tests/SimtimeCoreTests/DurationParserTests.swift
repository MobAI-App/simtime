import XCTest
@testable import SimtimeCore

final class DurationParserTests: XCTestCase {
    func test_basicUnits() throws {
        XCTAssertEqual(try DurationParser.parse("+7d"), 7 * 86400)
        XCTAssertEqual(try DurationParser.parse("-3h"), -3 * 3600)
        XCTAssertEqual(try DurationParser.parse("90m"), 90 * 60)
        XCTAssertEqual(try DurationParser.parse("45s"), 45)
    }

    func test_composite() throws {
        XCTAssertEqual(try DurationParser.parse("1d12h30m"), 86400 + 12 * 3600 + 30 * 60)
        XCTAssertEqual(try DurationParser.parse("-1d12h"), -(86400 + 12 * 3600))
    }

    func test_defaultPositive() throws {
        XCTAssertEqual(try DurationParser.parse("7d"), 7 * 86400)
    }

    func test_calendarUnitsRejected() {
        XCTAssertThrowsError(try DurationParser.parse("+1y"))
        XCTAssertThrowsError(try DurationParser.parse("+2w"))
    }

    func test_invalidUnit() {
        XCTAssertThrowsError(try DurationParser.parse("+5x"))
    }

    func test_malformed() {
        XCTAssertThrowsError(try DurationParser.parse(""))
        XCTAssertThrowsError(try DurationParser.parse("abc"))
        XCTAssertThrowsError(try DurationParser.parse("7"))
    }
}
