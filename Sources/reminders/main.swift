import Darwin
import RemindersLibrary

switch Reminders.requestAccess() {
case (true, _):
    CLI.main()
case (false, let error):
    print("error: you need to grant reminders access")
    if let error {
        print("error: \(error.localizedDescription)")
    }
    exit(1)
}
