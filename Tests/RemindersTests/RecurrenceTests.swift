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
}
