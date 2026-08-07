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

public enum Recurrence: String, ExpressibleByArgument {
    case hourly
    case daily
    case weekly
    case monthly
    case yearly

    var frequency: EKRecurrenceFrequency {
        switch self {
            case .hourly: return .daily  // EventKit has no hourly frequency; see interval note below.
            case .daily: return .daily
            case .weekly: return .weekly
            case .monthly: return .monthly
            case .yearly: return .yearly
        }
    }

    /// EventKit's `EKRecurrenceFrequency` has no hourly case, so `.hourly` is
    /// modeled as a daily rule with a 1-day interval and 24 hourly recurrences
    /// per day is not representable via `EKRecurrenceRule` alone. Since
    /// reminders don't carry a native hourly repeat concept in EventKit (the
    /// Reminders.app UI itself doesn't expose "hourly" either), `.hourly` is
    /// intentionally rejected at parse time in `RecurrenceOption` rather than
    /// silently degrading to daily. See CLI.swift for the actual validation;
    /// this case is kept in the enum only so `--repeat hourly` produces a
    /// clear, on-brand error message instead of an ArgumentParser "invalid
    /// value" message with no explanation.
    var isRepresentable: Bool {
        self != .hourly
    }

    func recurrenceRule(interval: Int, until: Date?) -> EKRecurrenceRule {
        let end = until.map { EKRecurrenceEnd(end: $0) }
        return EKRecurrenceRule(
            recurrenceWith: self.frequency,
            interval: interval,
            end: end)
    }
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

    func showAllReminders(dueOn dueDate: DateComponents?, includeOverdue: Bool,
        displayOptions: DisplayOptions, outputFormat: OutputFormat
    ) {
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
                let earlierDay = calendar.compare(
                    reminderDueDate, to: dueDate, toGranularity: .day) == .orderedAscending

                if sameDay || (includeOverdue && earlierDay) {
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

    func showListItems(withName name: String, dueOn dueDate: DateComponents?, includeOverdue: Bool,
        displayOptions: DisplayOptions, outputFormat: OutputFormat, sort: Sort, sortOrder: CustomSortOrder)
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
                let earlierDay = calendar.compare(
                    reminderDueDate, to: dueDate, toGranularity: .day) == .orderedAscending

                if sameDay || (includeOverdue && earlierDay) {
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

    func edit(
        itemAtIndex index: String, onListNamed name: String, newText: String?, newNotes: String?,
        newRecurrence: Recurrence?, newRecurrenceInterval: Int, newRecurrenceEnd: DateComponents?,
        clearRecurrence: Bool)
    {
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
                if clearRecurrence {
                    for rule in reminder.recurrenceRules ?? [] {
                        reminder.removeRecurrenceRule(rule)
                    }
                } else if let newRecurrence = newRecurrence {
                    for rule in reminder.recurrenceRules ?? [] {
                        reminder.removeRecurrenceRule(rule)
                    }
                    let rule = newRecurrence.recurrenceRule(
                        interval: newRecurrenceInterval, until: newRecurrenceEnd?.date)
                    reminder.addRecurrenceRule(rule)
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

        // Numeric indexes are only meaningful against the same display set that
        // `show` uses by default (incomplete-only), so keep that scope when the
        // caller passes a plain integer index — otherwise a numeric index would
        // resolve against a differently-ordered/sized array than the one the
        // user actually saw. External identifiers are stable regardless of
        // completion state, so widen the fetch to `.all` in that case, so a
        // reminder already marked complete can still be found and deleted by
        // its id instead of failing with "No reminder at index ...".
        let displayOptions: DisplayOptions = Int(index) == nil ? .all : .incomplete

        self.reminders(on: [calendar], displayOptions: displayOptions) { reminders in
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
        recurrence: Recurrence?,
        recurrenceInterval: Int,
        recurrenceEnd: DateComponents?,
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
        if let recurrence = recurrence {
            let rule = recurrence.recurrenceRule(
                interval: recurrenceInterval, until: recurrenceEnd?.date)
            reminder.addRecurrenceRule(rule)
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
