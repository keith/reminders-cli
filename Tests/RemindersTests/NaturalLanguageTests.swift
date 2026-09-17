import Foundation
@testable import RemindersLibrary
import XCTest

final class NaturalLanguageTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testYesterday() throws {
        let components = try XCTUnwrap(DateComponents(argument: "yesterday"))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: Date()))
        let expectedComponents = calendar.dateComponents(
            calendarComponents(except: timeComponents), from: tomorrow)

        XCTAssertEqual(components, expectedComponents)
    }

    func testTodayString() throws {
        let components = try XCTUnwrap(DateComponents(argument: "today"))
        let expectedComponents = calendar.dateComponents(
            calendarComponents(except: timeComponents), from: Date())

        XCTAssertEqual(components, expectedComponents)
    }

    func testTodayNoon() throws {
        let components = try XCTUnwrap(DateComponents(argument: "12:00"))
        let today = try XCTUnwrap(calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date()))
        let expectedComponents = calendar.dateComponents(calendarComponents(), from: today)

        XCTAssertEqual(components, expectedComponents)
    }

    func testTonight() throws {
        let components = try XCTUnwrap(DateComponents(argument: "tonight"))
        let today = try XCTUnwrap(calendar.date(bySettingHour: 19, minute: 0, second: 0, of: Date()))
        let expectedComponents = calendar.dateComponents(calendarComponents(), from: today)

        XCTAssertEqual(components, expectedComponents)
    }

    func testTomorrow() throws {
        let components = try XCTUnwrap(DateComponents(argument: "tomorrow"))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: Date()))
        let expectedComponents = calendar.dateComponents(
            calendarComponents(except: timeComponents), from: tomorrow)

        XCTAssertEqual(components, expectedComponents)
    }

    func testUsesGregorianCalendar() throws {
        let components = try XCTUnwrap(DateComponents(argument: "tomorrow"))

        XCTAssertEqual(components.calendar?.identifier, .gregorian)
    }

    func testTomorrowAtTime() throws {
        let components = try XCTUnwrap(DateComponents(argument: "tomorrow 9pm"))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: Date()))
        let tomorrowAt9 = try XCTUnwrap(
            calendar.date(bySettingHour: 21, minute: 0, second: 0, of: tomorrow))
        let expectedComponents = calendar.dateComponents(calendarComponents(), from: tomorrowAt9)

        XCTAssertEqual(components, expectedComponents)
    }

    func testRelativeDayCount() throws {
        let components = try XCTUnwrap(DateComponents(argument: "in 2 days"))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: Date()))
        let expectedComponents = calendar.dateComponents(
            calendarComponents(except: timeComponents), from: tomorrow)

        XCTAssertEqual(components, expectedComponents)
    }

    func testNextSaturday() throws {
        let components = try XCTUnwrap(DateComponents(argument: "next saturday"))
        let date = try XCTUnwrap(calendar.date(from: components))

        XCTAssertTrue(calendar.isDateInWeekend(date))
    }

    // FB8921206
    func testNextWeekend() throws {
        // TODO: This should be inverted but DataDetector doesn't support it right now
        XCTAssertNil(DateComponents(argument: "next weekend"))
        // let components = try XCTUnwrap(DateComponents(argument: "next weekend"))
        // let date = try XCTUnwrap(calendar.date(from: components))

        // XCTAssertTrue(calendar.isDateInWeekend(date))
    }

    func testSpecificDays() throws {
        XCTAssertNotNil(DateComponents(argument: "next monday"))
        XCTAssertNotNil(DateComponents(argument: "on monday at 9pm"))
    }

    func testIgnoreRandomString() {
        XCTAssertNil(DateComponents(argument: "blah tomorrow 9pm"))
    }
}
