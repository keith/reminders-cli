import ArgumentParser
import Foundation

private let calendar = Calendar.current
private let allComponents: Set<Calendar.Component> = [
    .era, .year, .yearForWeekOfYear, .quarter, .month,
    .weekOfYear, .weekOfMonth, .weekday, .weekdayOrdinal, .day,
    .hour, .minute, .second, .nanosecond,
    .calendar, .timeZone
]
let timeComponents: Set<Calendar.Component> = [
    .hour, .minute, .second, .nanosecond,
]

func calendarComponents(except removedComponents: Set<Calendar.Component> = []) -> Set<Calendar.Component> {
    return allComponents.subtracting(removedComponents)
}

private func components(from string: String) -> DateComponents? {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
        fatalError("error: failed to create NSDataDetector")
    }

    let range = NSRange(string.startIndex..<string.endIndex, in: string)

    let matches = detector.matches(in: string, options: .anchored, range: range)
    guard matches.count == 1, let match = matches.first, let date = match.date else {
        return nil
    }

    var includeTime = true
    if match.responds(to: NSSelectorFromString("timeIsSignificant")) {
        includeTime = match.value(forKey: "timeIsSignificant") as? Bool ?? true
    } else {
        print("warning: timeIsSignificant is not available, please report this to keith/reminders-cli")
    }

    let timeZone = match.timeZone ?? .current
    let parsedComponents = calendar.dateComponents(in: timeZone, from: date)
    if includeTime {
        return parsedComponents
    } else {
        return calendar.dateComponents(calendarComponents(except: timeComponents), from: date)
    }
}

extension DateComponents: ExpressibleByArgument {
      public init?(argument: String) {
          if let components = components(from: argument) {
              self = components
          } else {
              return nil
          }
      }
}
