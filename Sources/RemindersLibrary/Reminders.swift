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

extension EKReminder: Encodable {
    enum EncodingKeys: String, CodingKey {
        case externalId
        case title
        case notes
        case url
        case location
        case completionDate
        case isCompleted
        case priority
        case startDate
        case dueDate
        case list
    }
    
    public func encode(to encoder:Encoder) throws {
        var container = encoder.container(keyedBy: EncodingKeys.self)
        try container.encode(self.calendarItemExternalIdentifier, forKey: .externalId)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.isCompleted, forKey: .isCompleted)
        try container.encode(self.priority, forKey: .priority)
        try container.encode(self.calendar.title, forKey: .list)
        
        if let notes = self.notes {
            try container.encode(notes, forKey: .notes)
        }
        
        if let url = self.url {
            try container.encode(url, forKey: .url)
        }
        
        if let location = self.location {
            try container.encode(location, forKey: .location)
        }
        
        if let completionDate = self.completionDate {
            try container.encode(completionDate, forKey: .completionDate)
        }
                        
        if let startDateComponents = self.startDateComponents {
            if #available(macOS 12.0, *) {
                try container.encode(startDateComponents.date?.ISO8601Format(), forKey: .startDate)
            } else {
                try container.encode(startDateComponents.date?.description(with: .current), forKey: .startDate)
            }
        }
                
        if let dueDateComponents = self.dueDateComponents {
            if #available(macOS 12.0, *) {
                try container.encode(dueDateComponents.date?.ISO8601Format(), forKey: .dueDate)
            } else {
                try container.encode(dueDateComponents.date?.description(with: .current), forKey: .dueDate)
            }
        }                
    }
    
    var mappedPriority: EKReminderPriority {
        UInt(exactly: self.priority).flatMap(EKReminderPriority.init) ?? EKReminderPriority.none
    }
}

extension String  {
    var isNumber: Bool {
        return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
}

private func format(_ reminder: EKReminder, at index: Int, listName: String? = nil, outputFormat: OutputFormat) -> String {
    let dateString = formattedDueDate(from: reminder).map { " (\($0))" } ?? ""
    let priorityString = Priority(reminder.mappedPriority).map { " (priority: \($0))" } ?? ""
    let listString = listName.map { "\($0): " } ?? ""
    let notesString = reminder.notes.map { " (\($0))" } ?? ""

    var indexString = ""
    switch(outputFormat) {
    case .plainWithIds:
        indexString = reminder.calendarItemIdentifier
    default:
        indexString = "\(index)"
    }

    return "\(listString)\(indexString): \(reminder.title ?? "<unknown>")\(notesString)\(dateString)\(priorityString)"
}

public enum OutputFormat: String, ExpressibleByArgument {
    case json, plainWithIds, plain        
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

    func showLists(outputFormat: OutputFormat) {
        switch (outputFormat) {
        case .json:
            print(self.encodeToJson(data: self.getListNames()))
        default:
            for name in self.getListNames() {
                print(name)
            }
        }
    }

    func showAllReminders(dueOn dueDate: DateComponents?, outputFormat: OutputFormat) {
        let semaphore = DispatchSemaphore(value: 0)
        let calendar = Calendar.current

        self.reminders(on: self.getCalendars(), displayOptions: .incomplete) { reminders in
            switch (outputFormat) {
            case .json:
                print(self.encodeToJson(data: reminders))
            default:
                for (i, reminder) in reminders.enumerated() {
                    let listName = reminder.calendar.title
                    guard let dueDate = dueDate?.date else {
                        print(format(reminder, at: i, listName: listName, outputFormat: outputFormat))
                        continue
                    }
                    
                    guard let reminderDueDate = reminder.dueDateComponents?.date else {
                        continue
                    }
                    
                    let sameDay = calendar.compare(
                        reminderDueDate, to: dueDate, toGranularity: .day) == .orderedSame
                    if sameDay {
                        print(format(reminder, at: i, listName: listName, outputFormat: outputFormat))
                    }
                }
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func showListItems(withName name: String, dueOn dueDate: DateComponents?, displayOptions: DisplayOptions, outputFormat: OutputFormat) {
        let semaphore = DispatchSemaphore(value: 0)
        let calendar = Calendar.current

        self.reminders(on: [self.calendar(withName: name)], displayOptions: displayOptions) { reminders in
            switch (outputFormat) {
            case .json:
                print(self.encodeToJson(data: reminders))
            default:
                for (i, reminder) in reminders.enumerated() {
                    guard let dueDate = dueDate?.date else {
                        print(format(reminder, at: i, outputFormat: outputFormat))
                        continue
                    }
                    
                    guard let reminderDueDate = reminder.dueDateComponents?.date else {
                        continue
                    }
                    
                    let sameDay = calendar.compare(
                        reminderDueDate, to: dueDate, toGranularity: .day) == .orderedSame
                    if sameDay {
                        print(format(reminder, at: i, outputFormat: outputFormat))
                    }
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

    func edit(itemAtIndex index: String, onListNamed name: String, newText: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(on: [calendar], displayOptions: .incomplete) { reminders in
            
            guard let reminder = self.getReminder(from: reminders, at: index) else {
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

    func complete(itemAtIndex index: String, onListNamed name: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(on: [calendar], displayOptions: .incomplete) { reminders in
            
            guard let reminder = self.getReminder(from: reminders, at: index) else {
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
        dueDate: DateComponents?,
        priority: Priority,
        outputFormat: OutputFormat)
    {
        let calendar = self.calendar(withName: name)
        let reminder = EKReminder(eventStore: Store)
        reminder.calendar = calendar
        reminder.title = string
        reminder.notes = notes
        reminder.dueDateComponents = dueDate
        reminder.priority = Int(priority.value.rawValue)

        do {
            try Store.save(reminder, commit: true)
            switch (outputFormat) {
            case .json:
                print(self.encodeToJson(data: reminder))
            case .plainWithIds:
                print("Added '\(reminder.calendarItemExternalIdentifier!)' to '\(calendar.title)'")
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
    
    private func getReminder(from reminders:[EKReminder], at index: String) -> EKReminder? {        
        return (index.isNumber) ? reminders[safe: Int(argument: index)!] : reminders.filter({$0.calendarItemExternalIdentifier == index}).first
    }
    
    private func encodeToJson(data: Encodable) -> String {
        let encoded:Data = (try? JSONEncoder().encode(data)) ?? Data()
        return String(data: encoded, encoding: .utf8) ?? ""
    }
}
