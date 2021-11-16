import EventKit
import Foundation

private let Store = EKEventStore()
private let dateFormatter = RelativeDateTimeFormatter()
private func formattedDueDate(from reminder: EKReminder) -> String? {
    return reminder.dueDateComponents?.date.map {
        dateFormatter.localizedString(for: $0, relativeTo: Date())
    }
}

private func format(_ reminder: EKReminder, at index: Int) -> String {
    let dateString = formattedDueDate(from: reminder).map { " (\($0))" } ?? ""
    return "\(index): \(reminder.title ?? "<unknown>")\(dateString)"
}

public final class Reminders {
    public static func requestAccess() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var grantedAccess = false
        Store.requestAccess(to: .reminder) { granted, _ in
            grantedAccess = granted
            semaphore.signal()
        }

        semaphore.wait()
        return grantedAccess
    }

    func showLists() {
        let calendars = self.getCalendars()
        for calendar in calendars {
            print(calendar.title)
        }
    }

    func showListItems(withName name: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(onCalendar: calendar) { reminders in
            for (i, reminder) in reminders.enumerated() {
                print(format(reminder, at: i))
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func complete(itemAtIndex index: Int, onListNamed name: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(onCalendar: calendar) { reminders in
            guard let reminder = reminders[safe: index] else {
                print("No reminder at index \(index) on \(name)")
                exit(1)
            }

            do {
                reminder.isCompleted = true
                try Store.save(reminder, commit: true)
                print("Completed '\(reminder.title!)'")
            } catch let error {
                print("Failed to save reminder with error: \(error)")
                exit(1)
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func punt(_ indexes: [Int], onListNamed name: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        // let nextWeekdayComponents = 

        let cal = Calendar.current
        let currentDay = cal.component(.weekday, from: Date())
        var newDay = currentDay + 1
        if newDay == 7 {
            newDay = 2
        }

        // 1 sun
        // 7 sat
        // 6 -> 2
        let newComponents = DateComponents(weekday: newDay)
        let nextDate = cal.nextDate(after: Date(), matching: newComponents,
                                    matchingPolicy: .strict)!
        let newComp = cal.dateComponents([.day, .year, .month], from: nextDate)

        self.reminders(onCalendar: calendar) { reminders in
            for index in indexes {
                guard let reminder = reminders[safe: index] else {
                    print("No reminder at index \(index) on \(name)")
                    exit(1)
                }

                do {
                    reminder.dueDateComponents = newComp
                    try Store.save(reminder, commit: true)
                    print("Updated '\(reminder.title!)' due date to: TODO")
                } catch let error {
                    print("Failed to save reminder with error: \(error)")
                    exit(1)
                }
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func addReminder(string: String, toListNamed name: String, dueDate: DateComponents?) {
        let calendar = self.calendar(withName: name)
        let reminder = EKReminder(eventStore: Store)
        reminder.calendar = calendar
        reminder.title = string
        reminder.dueDateComponents = dueDate
        // reminder.url = URL(string: "https://google.com")!

        do {
            try Store.save(reminder, commit: true)
            print("Added '\(reminder.title!)' to '\(calendar.title)'")
        } catch let error {
            print("Failed to save reminder with error: \(error)")
            exit(1)
        }
    }

    // MARK: - Private functions

    private func reminders(onCalendar calendar: EKCalendar,
                                      completion: @escaping (_ reminders: [EKReminder]) -> Void)
    {
        let predicate = Store.predicateForReminders(in: [calendar])
        Store.fetchReminders(matching: predicate) { reminders in
            let reminders = reminders?
                .filter { !$0.isCompleted }
            completion(reminders ?? [])
        }
    }

    private func calendar(withName name: String) -> EKCalendar {
        let calendars = self.getCalendars()
        if let calendar = calendars.find(where: { $0.title.lowercased() == name.lowercased() }) {
            return calendar
        } else if let calendar = calendars.find(where: { normalize($0.title) == normalize(name) }) {
            return calendar
        } else {
            print("No reminders list matching \(name)")
            exit(1)
        }
    }

    private func normalize(_ name: String) -> String {
        return name.lowercased().replacingOccurrences(of: " ", with: "")
    }

    private func getCalendars() -> [EKCalendar] {
        return Store.calendars(for: .reminder)
                    .filter { $0.allowsContentModifications }
    }
}
