import EventKit
@testable import RemindersLibrary
import XCTest

final class RecurrenceTests: XCTestCase {
    func testDailyFrequencyMapping() throws {
        let rule = Recurrence.daily.recurrenceRule(interval: 1, until: nil)
        XCTAssertEqual(rule.frequency, .daily)
        XCTAssertEqual(rule.interval, 1)
        XCTAssertNil(rule.recurrenceEnd)
    }

    func testWeeklyFrequencyMapping() throws {
        let rule = Recurrence.weekly.recurrenceRule(interval: 1, until: nil)
        XCTAssertEqual(rule.frequency, .weekly)
    }

    func testMonthlyFrequencyMapping() throws {
        let rule = Recurrence.monthly.recurrenceRule(interval: 1, until: nil)
        XCTAssertEqual(rule.frequency, .monthly)
    }

    func testYearlyFrequencyMapping() throws {
        let rule = Recurrence.yearly.recurrenceRule(interval: 1, until: nil)
        XCTAssertEqual(rule.frequency, .yearly)
    }

    func testCustomInterval() throws {
        let rule = Recurrence.monthly.recurrenceRule(interval: 2, until: nil)
        XCTAssertEqual(rule.interval, 2)
    }

    func testRecurrenceEndDate() throws {
        let end = Date()
        let rule = Recurrence.weekly.recurrenceRule(interval: 1, until: end)
        XCTAssertNotNil(rule.recurrenceEnd)
        XCTAssertEqual(
            rule.recurrenceEnd?.endDate?.timeIntervalSince1970 ?? 0,
            end.timeIntervalSince1970,
            accuracy: 1.0)
    }

    func testHourlyIsNotRepresentable() throws {
        // EventKit has no hourly EKRecurrenceFrequency; this is asserted at the
        // model layer so CLI validation (which rejects it before ever building
        // a rule) has something concrete to check against.
        XCTAssertFalse(Recurrence.hourly.isRepresentable)
    }

    func testRepresentableFrequenciesAreAllRepresentable() throws {
        for frequency: Recurrence in [.daily, .weekly, .monthly, .yearly] {
            XCTAssertTrue(frequency.isRepresentable, "\(frequency.rawValue) should be representable")
        }
    }

    func testRecurrenceParsesFromArgument() throws {
        XCTAssertEqual(Recurrence(argument: "daily"), .daily)
        XCTAssertEqual(Recurrence(argument: "weekly"), .weekly)
        XCTAssertEqual(Recurrence(argument: "monthly"), .monthly)
        XCTAssertEqual(Recurrence(argument: "yearly"), .yearly)
        XCTAssertEqual(Recurrence(argument: "hourly"), .hourly)
        XCTAssertNil(Recurrence(argument: "biweekly"))
    }

    func testUntilDateOnlyIsInclusiveOfThatDay() throws {
        let components = try XCTUnwrap(DateComponents(argument: "2026-10-24"))
        let end = try XCTUnwrap(Recurrence.endDate(from: components))
        let calendar = Calendar(identifier: .gregorian)
        let nineAM = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 9)))
        let nextDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 0)))
        XCTAssertGreaterThan(end, nineAM)
        XCTAssertLessThan(end, nextDay)
    }

    func testUntilWithExplicitTimeIsUsedAsGiven() throws {
        let components = try XCTUnwrap(DateComponents(argument: "2026-10-24 10:00"))
        let end = try XCTUnwrap(Recurrence.endDate(from: components))
        XCTAssertEqual(end, components.date)
    }

    func testValidateRejectsHourly() throws {
        XCTAssertThrowsError(try validateRepeatOptions(repeat_: .hourly, interval: 1, until: nil))
    }

    func testValidateRejectsBadInterval() throws {
        XCTAssertThrowsError(try validateRepeatOptions(repeat_: .daily, interval: 0, until: nil))
    }

    func testValidateRequiresRepeatForIntervalAndUntil() throws {
        XCTAssertThrowsError(try validateRepeatOptions(repeat_: nil, interval: 2, until: nil))
        let until = try XCTUnwrap(DateComponents(argument: "2026-10-24"))
        XCTAssertThrowsError(try validateRepeatOptions(repeat_: nil, interval: 1, until: until))
        XCTAssertNoThrow(try validateRepeatOptions(repeat_: .weekly, interval: 2, until: until))
    }

    func testAddRepeatRequiresDueDate() throws {
        XCTAssertThrowsError(try CLI.parseAsRoot(["add", "L", "x", "--repeat", "daily"])) { error in
            XCTAssertTrue(
                CLI.message(for: error).contains("requires a due date"), "\(error)")
        }
        XCTAssertNoThrow(
            try CLI.parseAsRoot(["add", "L", "x", "--due-date", "2026-10-24", "--repeat", "daily"]))
    }

    func testAddRepeatOptionsRequireRepeat() throws {
        XCTAssertThrowsError(
            try CLI.parseAsRoot(["add", "L", "x", "--due-date", "2026-10-24", "--repeat-interval", "2"]))
    }

    func testEditRepeatParsing() throws {
        XCTAssertNoThrow(try CLI.parseAsRoot(["edit", "L", "0", "--repeat", "monthly"]))
        XCTAssertNoThrow(try CLI.parseAsRoot(["edit", "L", "0", "--clear-repeat"]))
        XCTAssertThrowsError(
            try CLI.parseAsRoot(["edit", "L", "0", "--repeat", "daily", "--clear-repeat"]))
        XCTAssertThrowsError(
            try CLI.parseAsRoot(["edit", "L", "0", "--repeat", "daily", "--clear-due-date"]))
        XCTAssertThrowsError(try CLI.parseAsRoot(["edit", "L", "0", "--repeat-interval", "2"]))
        XCTAssertThrowsError(try CLI.parseAsRoot(["edit", "L", "0", "--repeat", "hourly"]))
    }
}
