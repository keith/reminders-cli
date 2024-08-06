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

private func format(_ reminder: EKReminder, at index: Int?, listName: String? = nil) -> String {
    let dateString = formattedDueDate(from: reminder).map { " (\($0))" } ?? ""
    let priorityString = Priority(reminder.mappedPriority).map { " (priority: \($0))" } ?? ""
    let listString = listName.map { "\($0): " } ?? ""
    let notesString = reminder.notes.map { " (\($0))" } ?? ""
    let indexString = index.map { "\($0): " } ?? ""
    return "\(listString)\(indexString)\(reminder.title ?? "<unknown>")\(notesString)\(dateString)\(priorityString)"
}

public enum OutputFormat: String, ExpressibleByArgument {
    case json, plain
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
    public static func requestAccess() -> (Bool, Error?) {
        let semaphore = DispatchSemaphore(value: 0)
        var grantedAccess = false
        var returnError: Error? = nil
        if #available(macOS 14.0, *) {
            Store.requestFullAccessToReminders { granted, error in
                grantedAccess = granted
                returnError = error
                semaphore.signal()
            }
        } else {
            Store.requestAccess(to: .reminder) { granted, error in
                grantedAccess = granted
                returnError = error
                semaphore.signal()
            }
        }

        semaphore.wait()
        return (grantedAccess, returnError)
    }

    func getListNames() -> [String] {
        return self.getCalendars().map { $0.title }
    }
    
    func getDefaultList() -> String {
        return Store.defaultCalendarForNewReminders()!.title
    }

    func showLists(outputFormat: OutputFormat) {
        switch (outputFormat) {
        case .json:
            print(encodeToJson(data: self.getListNames()))
        default:
            for name in self.getListNames() {
                print(name)
            }
        }
    }

    func showAllReminders(dueOn dueDate: DateComponents?,
                          displayOptions: DisplayOptions, outputFormat: OutputFormat) {
        let semaphore = DispatchSemaphore(value: 0)
        let calendar = Calendar.current

        self.reminders(on: self.getCalendars(), displayOptions: displayOptions) { reminders in
            var matchingReminders = [(EKReminder, Int, String)]()
            for (i, reminder) in reminders.enumerated() {
                let listName = reminder.calendar.title
                guard let dueDate = dueDate?.date else {
                    matchingReminders.append((reminder, i, listName))
                    continue
                }

                guard let reminderDueDate = reminder.dueDateComponents?.date else {
                    continue
                }

                let sameDay = calendar.compare(
                    reminderDueDate, to: dueDate, toGranularity: .day) == .orderedSame
                if sameDay {
                    matchingReminders.append((reminder, i, listName))
                }
            }

            switch outputFormat {
            case .json:
                print(encodeToJson(data: matchingReminders.map { $0.0 }))
            case .plain:
                for (reminder, i, listName) in matchingReminders {
                    print(format(reminder, at: i, listName: listName))
                }
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func showListItems(withName name: String, dueOn dueDate: DateComponents?, displayOptions: DisplayOptions,
                       outputFormat: OutputFormat, sort: Sort, sortOrder: CustomSortOrder)
    {
        let semaphore = DispatchSemaphore(value: 0)
        let calendar = Calendar.current

        self.reminders(on: [self.calendar(withName: name)], displayOptions: displayOptions) { reminders in
            var matchingReminders = [(EKReminder, Int?)]()
            let reminders = sort == .none ? reminders : reminders.sorted(by: sort.sortFunction(order: sortOrder))
            for (i, reminder) in reminders.enumerated() {
                let index = sort == .none ? i : nil
                guard let dueDate = dueDate?.date else {
                    matchingReminders.append((reminder, index))
                    continue
                }

                guard let reminderDueDate = reminder.dueDateComponents?.date else {
                    continue
                }

                let sameDay = calendar.compare(
                    reminderDueDate, to: dueDate, toGranularity: .day) == .orderedSame
                if sameDay {
                    matchingReminders.append((reminder, index))
                }
            }

            switch outputFormat {
            case .json:
                print(encodeToJson(data: matchingReminders.map { $0.0 }))
            case .plain:
                for (reminder, i) in matchingReminders {
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

    func edit(itemAtIndex index: String, onListNamed name: String, newText: String?, newNotes: String?, dueDateComponents: DateComponents? = nil, clearDueDate: Bool, priority: Priority?, clearPriority: Bool) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(on: [calendar], displayOptions: .incomplete) { reminders in
            guard let reminder = self.getReminder(from: reminders, at: index) else {
                print("No reminder at index \(index) on \(name)")
                exit(1)
            }

            do {
                reminder.title = newText ?? reminder.title
                reminder.notes = newNotes ?? reminder.notes
                
                
                if clearPriority {
                    // https://developer.apple.com/documentation/eventkit/ekreminderpriority/none
                    reminder.priority = 0
                }
                else if priority != nil {
                    reminder.priority = Int(priority?.value.rawValue ?? UInt(reminder.priority))
         
                }
                
                if clearDueDate || (dueDateComponents != nil) {
                    // remove previous time-based alarms, leaving location alarms.
                    reminder.dueDateComponents = nil
                    for alarm in reminder.alarms ?? [] {
                        if alarm.structuredLocation != nil { continue } else { reminder.removeAlarm(alarm) }
                    }
       
                }
                if dueDateComponents != nil {
                    reminder.dueDateComponents = dueDateComponents
                    if let dueDate = dueDateComponents?.date, dueDateComponents?.hour != nil {
                        reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
                    }
                }
                
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

    func setComplete(_ complete: Bool, itemAtIndex index: String, onListNamed name: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)
        let displayOptions = complete ? DisplayOptions.incomplete : .complete
        let action = complete ? "Completed" : "Uncompleted"

        self.reminders(on: [calendar], displayOptions: displayOptions) { reminders in
            print(reminders.map { $0.title! })
            guard let reminder = self.getReminder(from: reminders, at: index) else {
                print("No reminder at index \(index) on \(name)")
                exit(1)
            }

            do {
                reminder.isCompleted = complete
                try Store.save(reminder, commit: true)
                print("\(action) '\(reminder.title!)'")
            } catch let error {
                print("Failed to save reminder with error: \(error)")
                exit(1)
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func delete(itemAtIndex index: String, onListNamed name: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(on: [calendar], displayOptions: .incomplete) { reminders in
            guard let reminder = self.getReminder(from: reminders, at: index) else {
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

    func addReminder(
        string: String,
        notes: String?,
        toListNamed name: String,
        dueDateComponents: DateComponents?,
        priority: Priority,
        outputFormat: OutputFormat)
    {
        let calendar = self.calendar(withName: name)
        let reminder = EKReminder(eventStore: Store)
        reminder.calendar = calendar
        reminder.title = string
        reminder.notes = notes
        reminder.dueDateComponents = dueDateComponents
        reminder.priority = Int(priority.value.rawValue)
        if let dueDate = dueDateComponents?.date, dueDateComponents?.hour != nil {
            reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
        }

        do {
            try Store.save(reminder, commit: true)
            switch (outputFormat) {
            case .json:
                print(encodeToJson(data: reminder))
            default:
                print("Added '\(reminder.title!)' to '\(calendar.title)'")
            }
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

    private func getReminder(from reminders: [EKReminder], at index: String) -> EKReminder? {
        precondition(!index.isEmpty, "Index cannot be empty, argument parser must be misconfigured")
        if let index = Int(index) {
            return reminders[safe: index]
        } else {
            return reminders.first { $0.calendarItemExternalIdentifier == index }
        }
    }

}

private func encodeToJson(data: Encodable) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try! encoder.encode(data)
    return String(data: encoded, encoding: .utf8) ?? ""
}
