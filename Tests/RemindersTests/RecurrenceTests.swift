import EventKit
@testable import RemindersLibrary
import XCTest

final class RecurrenceTests: XCTestCase {
    func testDaily() throws {
        let recurrence = try XCTUnwrap(Recurrence(argument: "daily"))
        XCTAssertEqual(recurrence.frequency, .daily)
        XCTAssertEqual(recurrence.interval, 1)
    }

    func testWeekly() throws {
        let recurrence = try XCTUnwrap(Recurrence(argument: "weekly"))
        XCTAssertEqual(recurrence.frequency, .weekly)
        XCTAssertEqual(recurrence.interval, 1)
    }

    func testMonthly() throws {
        let recurrence = try XCTUnwrap(Recurrence(argument: "monthly"))
        XCTAssertEqual(recurrence.frequency, .monthly)
        XCTAssertEqual(recurrence.interval, 1)
    }

    func testYearly() throws {
        let recurrence = try XCTUnwrap(Recurrence(argument: "yearly"))
        XCTAssertEqual(recurrence.frequency, .yearly)
        XCTAssertEqual(recurrence.interval, 1)
    }

    func testAliases() throws {
        XCTAssertEqual(try XCTUnwrap(Recurrence(argument: "day")).frequency, .daily)
        XCTAssertEqual(try XCTUnwrap(Recurrence(argument: "days")).frequency, .daily)
        XCTAssertEqual(try XCTUnwrap(Recurrence(argument: "week")).frequency, .weekly)
        XCTAssertEqual(try XCTUnwrap(Recurrence(argument: "annually")).frequency, .yearly)
    }

    func testWithInterval() throws {
        let recurrence = try XCTUnwrap(Recurrence(argument: "2-weeks"))
        XCTAssertEqual(recurrence.frequency, .weekly)
        XCTAssertEqual(recurrence.interval, 2)

        let recurrence2 = try XCTUnwrap(Recurrence(argument: "3-months"))
        XCTAssertEqual(recurrence2.frequency, .monthly)
        XCTAssertEqual(recurrence2.interval, 3)
    }

    func testCaseInsensitive() throws {
        let recurrence = try XCTUnwrap(Recurrence(argument: "WEEKLY"))
        XCTAssertEqual(recurrence.frequency, .weekly)
    }

    func testInvalidFrequency() {
        XCTAssertNil(Recurrence(argument: "fortnightly"))
        XCTAssertNil(Recurrence(argument: "blah"))
    }

    func testInvalidInterval() {
        XCTAssertNil(Recurrence(argument: "0-weeks"))
        XCTAssertNil(Recurrence(argument: "-1-weeks"))
    }

    func testRecurrenceRule() throws {
        let recurrence = try XCTUnwrap(Recurrence(argument: "2-weeks"))
        let rule = recurrence.recurrenceRule
        XCTAssertEqual(rule.frequency, .weekly)
        XCTAssertEqual(rule.interval, 2)
    }

    func testShortDescription() throws {
        XCTAssertEqual(try XCTUnwrap(Recurrence(argument: "daily")).recurrenceRule.shortDescription, "daily")
        XCTAssertEqual(try XCTUnwrap(Recurrence(argument: "weekly")).recurrenceRule.shortDescription, "weekly")
        XCTAssertEqual(try XCTUnwrap(Recurrence(argument: "3-months")).recurrenceRule.shortDescription, "3-months")
    }
}
