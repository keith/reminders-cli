import AppKit
import Commander

private let reminders = Reminders()
private func createCLI() -> Group {
    return Group {
        $0.command("show-lists") {
            reminders.showLists()
        }
        $0.command("show") { (listName: String) in
            reminders.showListItems(withName: listName)
        }
        $0.command("complete") { (listName: String, index: Int) in
            reminders.complete(itemAtIndex: index, onListNamed: listName)
        }
        $0.command("add") { (listName: String, parser: ArgumentParser) in
            let string = parser.remainder.joined(separator: " ")
            reminders.addReminder(string: string, toListNamed: listName)
        }
    }
}

reminders.requestAccess { granted in
    if granted {
        createCLI().run()
    } else {
        print("You need to grant reminders access")
        exit(1)
    }
}

private func isTestRun() -> Bool {
    return NSClassFromString("XCTestCase") != nil
}

if isTestRun() {
    // This skips setting up the app delegate
    NSApplication.shared.run()
} else {
    // For some magical reason, the AppDelegate is setup when
    // initialized this way
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
