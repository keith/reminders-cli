import ArgumentParser
import EventKit
import Foundation

private let Store = EKEventStore()
private let dateFormatter = RelativeDateTimeFormatter()
private func formattedDueDate(from reminder: EKReminder) -> String? {
    return reminder.dueDateComponents?.date.map {
        dateFormatter.localizedString(for: $0, relativeTo: Date())
    }
}

private extension EKReminder {
    var mappedPriority: EKReminderPriority {
        UInt(exactly: self.priority).flatMap(EKReminderPriority.init) ?? EKReminderPriority.none
    }
}

private func format(_ reminder: EKReminder, at index: Int) -> String {
    let dateString = formattedDueDate(from: reminder).map { " (\($0))" } ?? ""
    let priorityString = Priority(reminder.mappedPriority).map { " (priority: \($0))" } ?? ""
    return "\(index): \(reminder.title ?? "<unknown>")\(dateString)\(priorityString)"
}

public enum DisplayOptions: String, Decodable {
    case all
    case incomplete
    case complete
}

public enum Priority: String, ExpressibleByArgument {
    case none
    case low
    case medium
    case high

    var value: EKReminderPriority {
        switch self {
            case .none: return .none
            case .low: return .low
            case .medium: return .medium
            case .high: return .high
        }
    }

    init?(_ priority: EKReminderPriority) {
        switch priority {
            case .none: return nil
            case .low: self = .low
            case .medium: self = .medium
            case .high: self = .high
        @unknown default:
            return nil
        }
    }
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

    func showListItems(withName name: String, dueOn dueDate: DateComponents?, displayOptions: DisplayOptions) {
        let semaphore = DispatchSemaphore(value: 0)
        let calendar = Calendar.current

        self.reminders(onCalendar: self.calendar(withName: name), displayOptions: displayOptions) { reminders in
            for (i, reminder) in reminders.enumerated() {
                guard let dueDate = dueDate?.date else {
                    print(format(reminder, at: i))
                    continue
                }

                guard let reminderDueDate = reminder.dueDateComponents?.date else {
                    continue
                }

                let sameDay = calendar.compare(
                    reminderDueDate, to: dueDate, toGranularity: .day) == .orderedSame
                if sameDay {
                    print(format(reminder, at: i))
                }
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func newList(with name: String, source requestedSourceName: String?) {
        let store = EKEventStore()
        let sources = store.sources
        guard var source = sources.first else {
            print("No existing list sources were found, please create a list in Reminders.app")
            exit(1)
        }

        if let requestedSourceName = requestedSourceName {
            guard let requestedSource = sources.first(where: { $0.title == requestedSourceName }) else
            {
                print("No source named '\(requestedSourceName)'")
                exit(1)
            }

            source = requestedSource
        } else {
            let uniqueSources = Set(sources.map { $0.title })
            if uniqueSources.count > 1 {
                print("Multiple sources were found, please specify one with --source:")
                for source in uniqueSources {
                    print("  \(source)")
                }

                exit(1)
            }
        }

        let newList = EKCalendar(for: .reminder, eventStore: store)
        newList.title = name
        newList.source = source

        do {
            try store.saveCalendar(newList, commit: true)
            print("Created new list '\(newList.title)'!")
        } catch let error {
            print("Failed create new list with error: \(error)")
            exit(1)
        }
    }

    func edit(itemAtIndex index: Int, onListNamed name: String, newText: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(onCalendar: calendar, displayOptions: .incomplete) { reminders in
            guard let reminder = reminders[safe: index] else {
                print("No reminder at index \(index) on \(name)")
                exit(1)
            }

            do {
                reminder.title = newText
                try Store.save(reminder, commit: true)
                print("Updated reminder '\(reminder.title!)'")
            } catch let error {
                print("Failed to update reminder with error: \(error)")
                exit(1)
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func complete(itemAtIndex index: Int, onListNamed name: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(onCalendar: calendar, displayOptions: .incomplete) { reminders in
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

    func delete(itemAtIndex index: Int, onListNamed name: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(onCalendar: calendar, displayOptions: .incomplete) { reminders in
            guard let reminder = reminders[safe: index] else {
                print("No reminder at index \(index) on \(name)")
                exit(1)
            }

            do {
                try Store.remove(reminder, commit: true)
                print("Deleted '\(reminder.title!)'")
            } catch let error {
                print("Failed to delete reminder with error: \(error)")
                exit(1)
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func addReminder(string: String, toListNamed name: String, dueDate: DateComponents?, priority: Priority) {
        let calendar = self.calendar(withName: name)
        let reminder = EKReminder(eventStore: Store)
        reminder.calendar = calendar
        reminder.title = string
        reminder.dueDateComponents = dueDate
        reminder.priority = Int(priority.value.rawValue)

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
                           displayOptions: DisplayOptions,
                           completion: @escaping (_ reminders: [EKReminder]) -> Void)
    {
        let predicate = Store.predicateForReminders(in: [calendar])
        Store.fetchReminders(matching: predicate) { reminders in
            let reminders = reminders?
                .filter { self.shouldDisplay(reminder: $0, displayOptions: displayOptions) }
            completion(reminders ?? [])
        }
    }

    private func shouldDisplay(reminder: EKReminder, displayOptions: DisplayOptions) -> Bool {
        switch displayOptions {
        case .all:
            return true
        case .incomplete:
            return !reminder.isCompleted
        case .complete:
            return reminder.isCompleted
        }
    }

    private func calendar(withName name: String) -> EKCalendar {
        if let calendar = self.getCalendars().find(where: { $0.title.lowercased() == name.lowercased() }) {
            return calendar
        } else {
            print("No reminders list matching \(name)")
            exit(1)
        }
    }

    private func getCalendars() -> [EKCalendar] {
        return Store.calendars(for: .reminder)
                    .filter { $0.allowsContentModifications }
    }
}
