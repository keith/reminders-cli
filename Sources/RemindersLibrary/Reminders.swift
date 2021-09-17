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
        // NOTE: If pm2 no longer has access, kill the process (ps aux | grep PM2, kill -9 [pid]), then resurrect
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
            // print(calendar.title);
            fputs(calendar.title+"\n",stderr);
        }
    }

    func showListItems(withName name: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(onCalendar: calendar) { reminders in
            for (i, reminder) in reminders.enumerated() {
                fputs(format(reminder, at: i), stderr);
                // print(format(reminder, at: i))
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func returnListItems(withName name: String) -> [EKReminder] {
        let calendar = self.calendar(withName: name)
        var remindersArray: [EKReminder] = [];
        let semaphore = DispatchSemaphore(value: 0)
        
        self.allReminders(onCalendar: calendar) { reminders in
            for (i, reminder) in reminders.enumerated() {
                remindersArray.append(reminder);
            }
            semaphore.signal()

        }
        semaphore.wait()
        return remindersArray;        
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

    func addReminder(string: String, toListNamed name: String, isComplete:Bool = false, dueDate: DateComponents?) {
        let calendar = self.calendar(withName: name)
        let reminder = EKReminder(eventStore: Store)
        reminder.calendar = calendar
        reminder.title = string
        reminder.dueDateComponents = dueDate
        reminder.isCompleted = isComplete;
        
        do {
            try Store.save(reminder, commit: true)
            print("Added '\(reminder.title!)' to '\(calendar.title)'")
        } catch let error {
            print("Failed to save reminder with error: \(error)")
            exit(1)
        }
    }

    // TODO add color setting ability
    func newList (calendarName: String) {
        if (self.getCalendars().find(where: { $0.title.lowercased() == calendarName.lowercased() }) != nil) {
          print("Reminders list '\(calendarName)' already exists");
          exit(1);
        }
        let calendar = EKCalendar(for: .reminder, eventStore: Store);
        calendar.title = calendarName;
        // Code adapted from https://stackoverflow.com/questions/8260752/how-do-i-create-a-new-ekcalendar-on-ios-device
        // Find icloud source
        var localSource:EKSource?;
        for source in Store.sources {    
            if (source.sourceType == EKSourceType.calDAV)
            {
                localSource = source;
                break;
            }
        }
        if (localSource == nil) {
            print("Could not find icloud source");
            exit(1);
        }
        calendar.source = localSource;
        do {
            try Store.saveCalendar(calendar, commit: true)
            print("Created reminders list '\(calendarName)'!")
        } catch let error {
            print("Failed create reminders list with error: \(error)")
            exit(1)
        }
    }

    func hasList (calendarName:String) -> Bool {
      return self.getCalendars().find(where: { $0.title.lowercased() == calendarName.lowercased() }) != nil;
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


    // Includes completed reminders
    private func allReminders(onCalendar calendar: EKCalendar,
                                      completion: @escaping (_ reminders: [EKReminder]) -> Void)
    {
        let predicate = Store.predicateForReminders(in: [calendar])
        Store.fetchReminders(matching: predicate) { reminders in
            completion(reminders ?? [])
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

    func getCalendars() -> [EKCalendar] {
        return Store.calendars(for: .reminder)
                    .filter { $0.allowsContentModifications }
    }
}
