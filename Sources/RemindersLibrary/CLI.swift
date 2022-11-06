import ArgumentParser
import Foundation

private let reminders = Reminders()

private struct ShowLists: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the name of lists to pass to other commands")

    func run() {
        reminders.showLists()
    }
}

private struct Show: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the items on the given list")

    @Argument(
        help: "The list to print items from, see 'show-lists' for names")
    var listName: String

    @Flag(help: "Show completed items only")
    var onlyCompleted = false

    @Flag(help: "Include completed items in output")
    var includeCompleted = false

    @Option(
        name: .shortAndLong,
        help: "Show only reminders due on this date")
    var dueDate: DateComponents?

    func validate() throws {
        if self.onlyCompleted && self.includeCompleted {
            throw ValidationError(
                "Cannot specify both --show-completed and --only-completed")
        }
    }

    func run() {
        var displayOptions = DisplayOptions.incomplete
        if self.onlyCompleted {
            displayOptions = .complete
        } else if self.includeCompleted {
            displayOptions = .all
        }

        reminders.showListItems(
            withName: self.listName, dueOn: self.dueDate, displayOptions: displayOptions)
    }
}

private struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add a reminder to a list")

    @Argument(
        help: "The list to add to, see 'show-lists' for names")
    var listName: String

    @Argument(
        parsing: .remaining,
        help: "The reminder contents")
    var reminder: [String]

    @Option(
        name: .shortAndLong,
        help: "The date the reminder is due")
    var dueDate: DateComponents?

    @Option(
        name: .shortAndLong,
        help: "The priority of the reminder")
    var priority: Priority = .none

    func run() {
        reminders.addReminder(
            string: self.reminder.joined(separator: " "),
            toListNamed: self.listName,
            dueDate: self.dueDate,
            priority: priority)
    }
}

private struct Complete: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Complete a reminder")

    @Argument(
        help: "The list to complete a reminder on, see 'show-lists' for names")
    var listName: String

    @Argument(
        help: "The index of the reminder to complete, see 'show' for indexes")
    var index: Int

    func run() {
        reminders.complete(itemAtIndex: self.index, onListNamed: self.listName)
    }
}

private struct Delete: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Delete a reminder")

    @Argument(
        help: "The list to delete a reminder on, see 'show-lists' for names")
    var listName: String

    @Argument(
        help: "The index of the reminder to delete, see 'show' for indexes")
    var index: Int

    func run() {
        reminders.delete(itemAtIndex: self.index, onListNamed: self.listName)
    }
}

private struct NewList: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create a new list")

    @Argument(
        help: "The name of the new list")
    var listName: String

    @Option(
        name: .shortAndLong,
        help: "The name of the source of the list, if all your lists use the same source it will default to that")
    var source: String?

    func run() {
        reminders.newList(with: self.listName, source: self.source)
    }
}

public struct CLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "reminders",
        abstract: "Interact with macOS Reminders from the command line",
        subcommands: [
            Add.self,
            Complete.self,
            Delete.self,
            Show.self,
            ShowLists.self,
            NewList.self,
        ]
    )

    public init() {}
}
