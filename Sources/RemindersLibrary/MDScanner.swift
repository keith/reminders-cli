import Foundation
import EventKit
import SystemPackage

/* 
* TODO: Reminders w/ due dates
* TODO: Deleting reminders
* TODO: Nested reminders??
* TODO: Grouped reminders lists??
*/

private let Store = EKEventStore();

let reminders2 = Reminders();

struct URLUpdates {
   var path:String;
   var updatedAt:Date
   var todos:[String.SubSequence];
}

struct ReminderUpdates {
   var title:String;
   var reminderTitles:[String];
}

public final class MDScanner {

   var urls:[URLUpdates] = [];
   var cals:[ReminderUpdates] = [];

   private func shell(_ command: String) -> String {
         let task = Process()
         let pipe = Pipe()
         task.standardOutput = pipe
         task.standardError = pipe
         task.arguments = ["-c", command]
         task.launchPath = "/bin/zsh"
         task.launch()
         
         let data = pipe.fileHandleForReading.readDataToEndOfFile()
         let output = String(data: data, encoding: .utf8)!
         
         return output
      }

   public func scan() {
      fputs("hi\n",stderr);
      reminders2.showLists();
      let queue = DispatchQueue(label: "com.mytask", attributes: .concurrent)
      NotificationCenter.default.addObserver(self, selector: #selector(self.reloadModelData(notification:)), name: Notification.Name.EKEventStoreChanged, object: nil)         
      watch(queue: queue);
      RunLoop.current.run();

   }

   private func watch(queue:DispatchQueue) {
      queue.async {
         var text:String;

         fputs("where", stderr);
         text = self.shell("fswatch -1 -e '*' -i '*.scan.md$' /Users/pascalvonfintel/Documents")
         fputs("File notification: " + text+"\n", stderr);
         self.fire(notif: true)
         self.watch(queue:queue);
      }
   }
   @objc private func reloadModelData(notification: NSNotification) {
      fputs("Recieved notification\n", stderr);
      fire(notif: true);
   }

   @objc private func fire(notif:Bool = false) {
      scan2(notif: notif);
   }

   public func scan2(notif:Bool = false) {
      // Check if Do Not Delete list has the reminder, if not it means that this app has disconnected and should not act
      if (reminders2.returnListItems(withName: String("Do Not Delete")).count == 0) {
         return;
      }
      let folderUrls = [URL.init(fileURLWithPath: "/Users/pascalvonfintel/Documents")];
      // let url = Bundle.main.bundleURL;
      // fputs(url), stderr;
      let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey])
      var fileURLs: [URL] = []
      let suffix = ".scan.md";

      for url in folderUrls {
         let directoryEnumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles)!
         // Find all files with .scan.md in 'url'
         for case let fileURL as URL in directoryEnumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
               let isDirectory = resourceValues.isDirectory,
               let name = resourceValues.name
               else {
                     continue
               }
            
            if !isDirectory {
               if (name.suffix(suffix.count) == suffix) {
                  fileURLs.append(fileURL)
                  // fputs(name), stderr;
               }
            }
         }
      }
      // Loop through each file with .scan.md
      for url in fileURLs {
         do {
            var arrayOfStrings = try String(contentsOf: url).components(separatedBy: "\n")

            let resourceValues = try url.resourceValues(forKeys: [.nameKey, .pathKey, .contentModificationDateKey]);
            // If urls not initialized, or if notification was recieved, bypass
            if (urls.count != 0 && !notif) {
               // If file not more recent, break
               if (urls[urls.firstIndex(where: {$0.path == resourceValues.path})!].updatedAt == resourceValues.contentModificationDate!) {
                  break;
               }
            }
            // Name of file without .scan.md
            let name = resourceValues.name!.dropLast(8);
            let lastmodified = resourceValues.contentModificationDate;

            let todos = arrayOfStrings.filter({line in 
               return line.prefix(5) == "- [ ]" || line.prefix(5) == "- [x]"; 
            });
            // If list does not exist, create it
            if !reminders2.hasList(calendarName: String(name)) {
               reminders2.newList(calendarName: String(name));
            }
            let remindersArray = reminders2.returnListItems(withName: String(name));
            var reminderTitleArray:[String] = [];
            for rem in remindersArray {
               reminderTitleArray.append(rem.title);
            }
            for todo in todos {
               // Get rid of '- [ ] '
               var todoName = todo.dropFirst(6);
               // Get date, if there is one
               let dateString = getDate(todo: String(todoName));
               todoName
               // If dateString, remove dateString from todoName
               todoName = removeDate(todo: String(todoName));
               // Convert dateString to date
               let date = DateComponents(argument: String(dateString));
               // If reminder in md and not reminders app
               if !reminderTitleArray.contains(String(todoName)) {
                  // If todo is in previous record of reminderTitleArray (has it been deleted?)
                  if (cals.firstIndex(where: {$0.title == name}) != nil && cals[cals.firstIndex(where: {$0.title == name})!].reminderTitles.contains(String(todoName))) {
                     fputs("removing \(todoName) in \(name)\n", stderr)
                     // Remove todo
                     arrayOfStrings.remove(at: arrayOfStrings.firstIndex(of: todo)!);
                     let path:FilePath = FilePath.init(url.path);
                     let fd = try FileDescriptor.open(path, .readWrite, options: [.truncate]);
                     // Loop through and rewrite file without line
                     try fd.closeAfter {
                        for str in arrayOfStrings {
                           _ = try fd.writeAll((str + "\n").utf8);
                        }
                     }
                  } else {
                     // Add reminder
                     reminders2.addReminder(string: String (todoName), toListNamed: String(name), isComplete: todo.prefix(5) == "- [x]", dueDate: date);
                  }
               } else {
                  let rem = remindersArray.find(where: {$0.title == todoName})!;
                  // File updated more recently than reminder
                  if (rem.lastModifiedDate! < lastmodified!) {
                     // Compare dates
                     var dateDifference:Bool;
                     if (rem.dueDateComponents != nil) {
                        // True if dates are different
                        // Or if one of them has the hour property and the other doesn't 
                        dateDifference = date?.date != rem.dueDateComponents?.date || (date?.hour == nil) != (rem.dueDateComponents?.hour == nil)
                     } else {
                        // True if date is existent and rem.dueDateComponents is not
                        dateDifference = date != nil;
                     }
                     let isComplete = todo.prefix(5) == "- [x]";
                     // If difference in completeness
                     if (isComplete != rem.isCompleted || dateDifference) {
                        rem.isCompleted = isComplete;
                        rem.dueDateComponents = date
                        rem.startDateComponents = date;
                        rem.alarms = [EKAlarm.init(relativeOffset: 0)]
                        try Store.save(rem, commit: true);
                        fputs("Updated '\(rem.title!)' in \(name)\n", stderr)
                        if (dateDifference) {fputs("Updated date for \(todoName) in \(name) to \(date?.date)\n", stderr)}
                        else {fputs("Set isCompleted to \(isComplete)\n", stderr)}
                     }
                  // Reminder updated more recently than file
                  } else {
                     // Determine whether to complete or uncomplete item
                     let isComplete = rem.isCompleted;
                     // Determine whether to update date
                     // TODO: The fix to the relative date problem might just be getting rid of this section
                     // Can test by setting dateDifference to true
                     var dateDifference:Bool;
                     if (rem.dueDateComponents != nil) {
                        // True if dates are different
                        // Or if one of them has the hour property and the other doesn't 
                        dateDifference = date?.date != rem.dueDateComponents?.date || (date?.hour == nil) != (rem.dueDateComponents?.hour == nil)
                     } else {
                        // True if date is existent and rem.dueDateComponents is not
                        dateDifference = date != nil;
                     } 
                     // If no difference
                     if (isComplete == (todo.prefix(5) == "- [x]") && !dateDifference) {
                        continue;
                     }
                     let pos = arrayOfStrings[0..<arrayOfStrings.firstIndex(of: todo)!].reduce(0, {x, y in
                        var buf:[UInt8] = Array(y.utf8);
                        buf.append(contentsOf: [10]);
                        return x + buf.count;
                     });
                     let path:FilePath = FilePath.init(url.path);
                     let fd = try FileDescriptor.open(path, .readWrite);
                     try fd.seek(offset: Int64.init(pos+3), from: .start);
                     try fd.closeAfter {
                        let char = isComplete ? "x" : " ";
                        _ = try fd.writeAll(char.utf8);
                        if (isComplete == (todo.prefix(5) == "- [x]")) {
                           fputs("Set isCompleted for \(todoName) in \(name) to \(isComplete)\n", stderr)
                        }
                     }
                     if (dateDifference) {
                        let fd = try FileDescriptor.open(path, .readWrite, options: [.truncate]);
                        
                        let index = arrayOfStrings.firstIndex(of: todo)
                        let updatedTodo = removeDate(todo: todo) + formatDate(rem: rem);
                        arrayOfStrings[index!] = String(updatedTodo);
                        // Gets rid of last line if last line is a newline
                        if (arrayOfStrings[arrayOfStrings.endIndex-1] == "") {
                           arrayOfStrings = arrayOfStrings.dropLast()
                        }
                        try fd.closeAfter {
                           for str in arrayOfStrings {
                              // Don't add newline if str is a newline, otherwise do
                              _ = try fd.writeAll((str + "\n").utf8);
                           }
                           fputs("Updated date for \(todoName) in \(name) to \(date?.date)\n", stderr)
                        }
                     }
                  }
               }
               // fputs(todoName), stderr;
            }
            // Stores the names without - [(x)]
            let todoNames = mapToNames(todos:todos);
            // Loop through reminders in reminders list
            for rem in remindersArray {
               var dateString:String = "";
               if (rem.dueDateComponents != nil) {
                  dateString = formatDate(rem: rem);
               }   
               // If reminder not in md file
               if !todoNames.contains(Substring.init(rem.title)) {
                  let section = "## Todos added from cli";
                  // Check if there's not a '## Todos added from cli' section
                  let path:FilePath = FilePath.init(url.path);

                  // If todo is in previous record of todoNames (has it been deleted?)
                  if (urls.firstIndex(where: {$0.path == url.path}) != nil && urls[urls.firstIndex(where: {$0.path == url.path})!].todos.contains(String.SubSequence(rem.title))) {
                     // Remove todo
                     try Store.remove(rem, commit: true);
                  } else {
                     if (arrayOfStrings.firstIndex(of: section) == nil) {
                        let fd = try FileDescriptor.open(path, .readWrite, options: [.append]);
                        let str = "\n" + section + "\n\n";
                        try fd.closeAfter {
                           _ = try fd.writeAll(str.utf8);
                        }
                        // Update arrayOfStrings
                        arrayOfStrings = try String(contentsOf: url).components(separatedBy: "\n")
                     }
                     let remString = "- [" + (rem.isCompleted ? "x" : " ") + "] \(rem.title!)\(dateString)\n";
                     let fd = try FileDescriptor.open(path, .readWrite, options: [.append]);
                     try fd.closeAfter {
                        _ = try fd.writeAll(remString.utf8);
                        fputs("added \(rem.title!) with dateString \(dateString) to \(name)\n", stderr);
                     }
                  }
               }
            }
            // print (test);
         } catch let error {
            fputs(error.localizedDescription, stderr);
            fputs("error", stderr);
            exit(1);
         }   
      }
      urls = [];
      cals = [];
      // Second loop through files in order to keep record of what cals and files contained at last go through
      // This is done so we know which file or calendar list has most recently been updated so we can properly sync items
      do {
         for url in fileURLs {
            let resourceValues = try url.resourceValues(forKeys: [.pathKey, .nameKey, .contentModificationDateKey]);
            let arrayOfStrings = try String(contentsOf: url).components(separatedBy: "\n")
            // Name of file without .scan.md
            let name = resourceValues.name!.dropLast(8);
            let lastmodified = resourceValues.contentModificationDate!;
            let path = resourceValues.path!;
            let todos = arrayOfStrings.filter({line in 
               return line.prefix(5) == "- [ ]" || line.prefix(5) == "- [x]"; 
            });
            let todoNames = mapToNames(todos: todos);
            // If list does not exist, create it
            if !reminders2.hasList(calendarName: String(name)) {
               reminders2.newList(calendarName: String(name));
            }
            let remindersArray = reminders2.returnListItems(withName: String(name));
            var reminderTitleArray:[String] = [];
            for rem in remindersArray {
               reminderTitleArray.append(rem.title);
            }
            urls.append(URLUpdates.init(path:path, updatedAt: lastmodified, todos:todoNames))
            cals.append(ReminderUpdates.init(title: String(name), reminderTitles: reminderTitleArray));
         }
      } catch {
         print ("error");
      }
   }
   // Gets the date suffix if there is one, otherwise returns an empty string
   private func getDate(todo:String) -> String.SubSequence {
      if (todo.lastIndex(of: "–") != nil) {
        return todo.suffix(from: todo.index(todo.lastIndex(of: "–") ?? todo.index(todo.endIndex, offsetBy: -2), offsetBy: 2));
      }
      return "";
   }
   // Returns the todo without a date suffix, if there is one
   private func removeDate(todo:String) -> String.SubSequence {
      if (todo.lastIndex(of: "–") != nil) {
         return todo.prefix(upTo: todo.index(todo.lastIndex(of: "–")!, offsetBy: -1));
      }
      return String.SubSequence(todo);
   }
   // Remose - [ ] prefix and date suffix
   private func mapToNames(todos:[String])->[String.SubSequence]{
      return todos.map({todo in  
         return removeDate(todo: String(todo.dropFirst(6)));
      })
   }
   private func formatDate(rem:EKReminder) -> String {
      let formatter = DateFormatter()
      // Check if date is all day
      if (rem.dueDateComponents!.hour != nil) {
         formatter.dateFormat = " – EEEE d MMM 'at' h:mm a"
      } else {
         formatter.dateFormat = " – EEEE d MMM"
      }
      return formatter.string(from: rem.dueDateComponents!.date!)
   }
}

