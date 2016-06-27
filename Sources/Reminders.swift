import EventKit

private let Store = EKEventStore()

final class Reminders {
    func requestAccess(completion: (granted: Bool) -> Void) {
        Store.requestAccessToEntityType(.Reminder) { granted, _ in
            executeOnMainQueue {
                completion(granted: granted)
            }
        }
    }

    func showLists() {
        let calendars = self.getCalendars()
        for calendar in calendars {
            print(calendar.title)
        }
    }

    func showListItems(withName name: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = dispatch_semaphore_create(0)

        self.reminders(onCalendar: calendar) { reminders in
            for (i, reminder) in reminders.enumerate() {
                print(i, reminder.title)
            }

            dispatch_semaphore_signal(semaphore)
        }

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
    }

    func complete(itemAtIndex index: Int, onListNamed name: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = dispatch_semaphore_create(0)

        self.reminders(onCalendar: calendar) { reminders in
            guard let reminder = reminders[safe: index] else {
                print("No reminder at index \(index) on \(name)")
                exit(1)
            }

            do {
                reminder.completed = true
                try Store.saveReminder(reminder, commit: true)
            } catch let error {
                print("Failed to save reminder with error: \(error)")
            }

            dispatch_semaphore_signal(semaphore)
        }

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
    }

    func addReminder(string string: String, toListNamed name: String) {
        let calendar = self.calendar(withName: name)
        let reminder = EKReminder(eventStore: Store)
        reminder.calendar = calendar
        reminder.title = string

        do {
            try Store.saveReminder(reminder, commit: true)
        } catch let error {
            print("Failed to save reminder with error: \(error)")
        }
    }

    // MARK: - Private functions

    private func reminders(onCalendar calendar: EKCalendar,
                                      completion: (reminders: [EKReminder]) -> Void)
    {
        let predicate = Store.predicateForRemindersInCalendars([calendar])
        Store.fetchRemindersMatchingPredicate(predicate) { reminders in
            let reminders = reminders?.filter { !$0.completed }
                                      .sort { $0.creationDate < $1.creationDate }
            completion(reminders: reminders ?? [])
        }
    }

    private func calendar(withName name: String) -> EKCalendar {
        if let calendar = self.getCalendars()
                              .find({ $0.title.lowercaseString == name.lowercaseString })
        {
            return calendar
        } else {
            print("No reminders list matching \(name)")
            exit(1)
        }
    }

    private func getCalendars() -> [EKCalendar] {
        return Store.calendarsForEntityType(.Reminder)
                    .filter { $0.allowsContentModifications }
    }
}
