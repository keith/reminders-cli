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

struct ReminderData: Encodable {
    private enum CodingKeys: String, CodingKey {
        case id
        case calendarTitle
        case title
        case creationDate
        case lastModifiedDate
        case startDate
        case dueDate
        case notes
        case priority
        case isCompleted
        case completionDate
        case alarms
        case recurrenceRules
    }

    let id: String
    let calendarTitle: String?
    let title: String?
    let creationDate: Date?
    let lastModifiedDate: Date?
    let startDate: Date?
    let dueDate: Date?
    let notes: String?
    let priority: Int
    let isCompleted: Bool
    let completionDate: Date?
    let alarms: [EKAlarm]?
    let recurrenceRules: [EKRecurrenceRule]?

    public func encode(to encoder: Encoder) throws {
        func formattedDate(date: Date) -> String {
            return date.formatted(Date.ISO8601FormatStyle())
        }

        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(calendarTitle, forKey: .calendarTitle)
        try container.encode(title, forKey: .title)
        try container.encode(creationDate.map(formattedDate), forKey: .creationDate)
        try container.encode(lastModifiedDate.map(formattedDate), forKey: .lastModifiedDate)
        try container.encode(startDate.map(formattedDate), forKey: .startDate)
        try container.encode(dueDate.map(formattedDate), forKey: .dueDate)
        try container.encode(notes, forKey: .notes)
        try container.encode(priority, forKey: .priority)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(completionDate.map(formattedDate), forKey: .completionDate)
        // TODO: error: referencing instance method 'encode(_:forKey:)' on 'Array' requires that 'EKAlarm' conform to 'Encodable'
        //   Ref: https://developer.apple.com/documentation/eventkit/ekalarm
        // try container.encode(alarms, forKey: .alarms)
        // TODO: error: referencing instance method 'encode(_:forKey:)' on 'Array' requires that 'EKRecurrenceRule' conform to 'Encodable'
        //   Ref: https://developer.apple.com/documentation/eventkit/ekrecurrencerule
        // try container.encode(recurrenceRules, forKey: .recurrenceRules)
    }
}

private func format(_ reminder: EKReminder, at index: Int, listName: String? = nil) -> String {
    let dateString = formattedDueDate(from: reminder).map { " (\($0))" } ?? ""
    let priorityString = Priority(reminder.mappedPriority).map { " (priority: \($0))" } ?? ""
    let listString = listName.map { "\($0): " } ?? ""
    return "\(listString)\(index): \(reminder.title ?? "<unknown>")\(dateString)\(priorityString)"
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

    func getListNames() -> [String] {
        return self.getCalendars().map { $0.title }
    }

    func showLists() {
        for name in self.getListNames() {
            print(name)
        }
    }

    func exportAllReminders(prettyPrint: Bool) {
        let semaphore = DispatchSemaphore(value: 0)
        let encoder = JSONEncoder()

        if prettyPrint {
            encoder.outputFormatting = .prettyPrinted
        }

        self.reminders(on: self.getCalendars(), displayOptions: .incomplete) { reminders in
            let remindersByCalendarTitle = Dictionary(grouping: reminders) { reminder -> String in
                return reminder.calendar?.title ?? "Unknown"
            }

            let mappedRemindersByCalendarTitle = remindersByCalendarTitle.mapValues { values in
                values.map { reminder -> ReminderData in
                    return ReminderData(
                        id: reminder.calendarItemIdentifier,
                        calendarTitle: reminder.calendar?.title,
                        title: reminder.title,
                        creationDate: reminder.creationDate,
                        lastModifiedDate: reminder.lastModifiedDate,
                        startDate: reminder.startDateComponents?.date,
                        dueDate: reminder.dueDateComponents?.date,
                        notes: reminder.notes,
                        priority: reminder.priority,
                        isCompleted: reminder.isCompleted,
                        completionDate: reminder.completionDate,
                        alarms: reminder.alarms,
                        recurrenceRules: reminder.recurrenceRules
                    )
                }
            }

            do {
                let data = try encoder.encode(mappedRemindersByCalendarTitle)
                FileHandle.standardOutput.write(data)
            } catch {
                print(error)
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func showAllReminders(dueOn dueDate: DateComponents?) {
        let semaphore = DispatchSemaphore(value: 0)
        let calendar = Calendar.current

        self.reminders(on: self.getCalendars(), displayOptions: .incomplete) { reminders in
            for (i, reminder) in reminders.enumerated() {
                let listName = reminder.calendar.title
                guard let dueDate = dueDate?.date else {
                    print(format(reminder, at: i, listName: listName))
                    continue
                }

                guard let reminderDueDate = reminder.dueDateComponents?.date else {
                    continue
                }

                let sameDay = calendar.compare(
                    reminderDueDate, to: dueDate, toGranularity: .day) == .orderedSame
                if sameDay {
                    print(format(reminder, at: i, listName: listName))
                }
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func showListItems(withName name: String, dueOn dueDate: DateComponents?, displayOptions: DisplayOptions) {
        let semaphore = DispatchSemaphore(value: 0)
        let calendar = Calendar.current

        self.reminders(on: [self.calendar(withName: name)], displayOptions: displayOptions) { reminders in
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

        self.reminders(on: [calendar], displayOptions: .incomplete) { reminders in
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

        self.reminders(on: [calendar], displayOptions: .incomplete) { reminders in
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

        self.reminders(on: [calendar], displayOptions: .incomplete) { reminders in
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

    private func reminders(
        on calendars: [EKCalendar],
        displayOptions: DisplayOptions,
        completion: @escaping (_ reminders: [EKReminder]) -> Void)
    {
        let predicate = Store.predicateForReminders(in: calendars)
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
