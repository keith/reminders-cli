import AppKit

if Reminders.requestAccess() {
    CLI.main()
} else {
    print("You need to grant reminders access")
    exit(1)
}
