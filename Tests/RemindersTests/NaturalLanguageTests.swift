import Foundation
@testable import RemindersLibrary
import XCTest

final class NaturalLanguageTests: XCTestCase {
    func testYesterday() throws {
        let components = try XCTUnwrap(DateComponents(argument: "yesterday"))
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        let expectedComponents = Calendar.current.dateComponents(
            calendarComponents(except: timeComponents), from: tomorrow)

        XCTAssertEqual(components, expectedComponents)
    }

    func testTomorrow() throws {
        let components = try XCTUnwrap(DateComponents(argument: "tomorrow"))
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        let expectedComponents = Calendar.current.dateComponents(
            calendarComponents(except: timeComponents), from: tomorrow)

        XCTAssertEqual(components, expectedComponents)
    }

    func testTomorrowAtTime() throws {
        let components = try XCTUnwrap(DateComponents(argument: "tomorrow 9pm"))
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        let tomorrowAt9 = try XCTUnwrap(
            Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: tomorrow))
        let expectedComponents = Calendar.current.dateComponents(calendarComponents(), from: tomorrowAt9)

        XCTAssertEqual(components, expectedComponents)
    }

    func testRelativeDayCount() throws {
        let components = try XCTUnwrap(DateComponents(argument: "in 2 days"))
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 2, to: Date()))
        let expectedComponents = Calendar.current.dateComponents(
            calendarComponents(except: timeComponents), from: tomorrow)

        XCTAssertEqual(components, expectedComponents)
    }

    func testNextSaturday() throws {
        let components = try XCTUnwrap(DateComponents(argument: "next saturday"))
        let date = try XCTUnwrap(Calendar.current.date(from: components))

        XCTAssertTrue(Calendar.current.isDateInWeekend(date))
    }

    // This unfortunately doesn't work
    func disabled_testNextWeekend() throws {
        let components = try XCTUnwrap(DateComponents(argument: "next weekend"))
        let date = try XCTUnwrap(Calendar.current.date(from: components))

        XCTAssertTrue(Calendar.current.isDateInWeekend(date))
    }

    func testSpecificDays() throws {
        XCTAssertNotNil(DateComponents(argument: "next monday"))
        XCTAssertNotNil(DateComponents(argument: "on monday at 9pm"))
    }

    func testIgnoreRandomString() {
        XCTAssertNil(DateComponents(argument: "blah tomorrow 9pm"))
    }
}
